require 'json'
require 'sdbm'
require 'set'
require_relative "lib/file_util"
require_relative "lib/string_util"
require_relative "lib/epos"
require_relative "lib/vlist"
require_relative "lib/linguistics"

def four_page_layout(stuff,g1,g2,t1,t2,start_chapter:nil)  
  # g1 and g2 are line refs of the form [book,line]
  # t1 and t2 are word globs
  lemmas_file,freq_file,greek,translation = stuff
  greek_text = greek.extract(greek.line_to_hard_ref(g1[0],g1[1]),greek.line_to_hard_ref(g2[0],g2[1]))
  v = vocab(Vlist.from_text(greek_text,lemmas_file,freq_file))
  print "\\pagebreak\n\n"
  if !(start_chapter.nil?) then print "\\mychapter{#{start_chapter}}\n\n" end
  print foreign(greek_text),"\n\n"
  if !(start_chapter.nil?) then print "\\myransomchapter{#{start_chapter}}\n\n" end
  print ransom(greek_text,v),"\n\n"
  translation_text = translation.extract(translation.word_glob_to_hard_ref(t1)[0],translation.word_glob_to_hard_ref(t2)[0])
  translation_text = Patch_names.patch(translation_text)
  if !(start_chapter.nil?) then print "\\mychapter{#{start_chapter}}\n\n" end
  print translation_text
end

def vocab(vl)
  # Input is a Vlist object.
  # The three sections are interpreted as common, uncommon, and rare.
  # Prints latex code for vocab page, and returns the three file lists for later reuse.
  if Options.if_render_glosses then $stderr.print vl.console_messages end
  print "\\begin{vocabpage}\n"
  vocab_helper('common',vl,0,0)
  vocab_helper('uncommon',vl,1,2)
  print "\\end{vocabpage}\n"
  return vl.list.map { |l| l.map{ |entry| entry[1] } }
end

def vocab_helper(commonness,vl,lo,hi)
  if commonness=='common' then tag='vocabcommon' else tag='vocabuncommon' end
  #if files.include?("κυων") then $stderr.print "doggies in vocab_helper\n" end
  l = []
  lo.upto(hi) { |i|
    vl.list[i].each { |entry|
      word,lexical,data = entry
      if data.nil? then data={} end
      #is_3rd_decl = (data.has_key?('is_3rd_decl') && data[is_3rd_decl])
      #if lexical=='κύων' then $stderr.print "doggies in vocab_helper, data=#{data}, #{data.keys} word=#{word} is_3rd_decl=#{is_3rd_decl}\n" end
      #if is_3rd_decl then $stderr.print "doggies in vocab_helper, data=#{data}, #{data.keys} word=#{word} is_3rd_decl=#{is_3rd_decl}\n" end
      file_under = get_gloss(lexical,word)['file_under']
      l.push([file_under,word,lexical,data])
    }
  }
  print "\\begin{#{tag}}\n"
  l.sort { |a,b| alpha_compare(a[0],b[0])}.each { |entry| 
    vocab1(entry)
  }
  print "\\end{#{tag}}\n"
end

def vocab1(stuff)
  file_under,word,lexical,data = stuff
  entry = get_gloss(lexical,word)
  return if entry.nil?
  word2,gloss,lexical2 = entry['word'],entry['gloss'],entry['lexical']
  if is_feminine_ending_in_os(remove_accents(lexical)) then gloss = "(f.) #{gloss}" end
  if entry.has_key?('lexical') || (data.has_key?('is_3rd_decl') && data['is_3rd_decl'] && word!=lexical)then
    s = "\\vocabinflection{#{word.downcase}}{#{lexical}}{#{gloss}}"
  else
    s = "\\vocab{#{lexical}}{#{gloss}}"
  end
  print "#{s}\\\\"
end

def word_to_filename(s)
  return remove_accents(s).downcase
end

def get_gloss(lexical,word)
  # It doesn't matter whether the inputs have accents or not. We immediately strip them off.
  # Return value looks like the following. The item lexical exists only if this is supposed to be an entry for the inflected form.
  # {  "word"=> "ἔθηκε",  "gloss"=> "put, put in a state",  "lexical"=> "τίθημι", "file_under"=>"ἔθηκε" }
  entry_lexical   = get_gloss_helper(word_to_filename(lexical))
  entry_inflected = get_gloss_helper(word_to_filename(word))
  if entry_inflected.nil? then
    entry = entry_lexical
    file_under = lexical
  else
    entry = entry_inflected
    file_under = word
  end
  return entry.merge({'file_under'=>file_under})
end

def get_gloss_helper(key)
  path = "glosses/#{key}"
  if FileTest.exist?(path) then
    return json_from_file_or_die(path)
    # {  "word": "ἔθηκε",  "gloss": "put, put in a state",  "lexical": "τίθημι" }
  else
    return nil
  end
end

def foreign(t)
  foreign_helper(t,false)
end

def ransom(t,v)
  common,uncommon,rare = v
  foreign_helper(t,true,gloss_these:rare)
end

def foreign_helper(t,ransom,gloss_these:[])
  # If gloss_these isn't empty, then we assume it contains a list of rare lemmatized forms.
  gloss_code = ''
  main_code = "\\begin{foreignpage}\n"
  if ransom then main_code = main_code + "\\begin{graytext}\n" end
  lines = t.split(/\s*\n\s*/)
  if gloss_these.length>0 then
    gg = gloss_these.map { |x| remove_accents(x)}
    0.upto(lines.length-1) { |i|
      line_hash = Digest::MD5.hexdigest(lines[i])
      w = words(lines[i])
      ww = w.map { |x| remove_accents(Lemmatize.lemmatize(x)[0]).downcase} # if the lemmatizer fails, it just returns the original word
      #$stderr.print "ww=#{ww}\n" # qwe
      gg.each { |x|
        if ww.include?(x) then # lemmatized version of line includes this rare lemma that we were asked to gloss
          j = ww.index(x)
          word = w[j] # original inflected form
          key = to_key(x)
          entry = get_gloss(x,word) # it doesn't matter whether inputs have accents
          if entry.nil? then entry=get_gloss(to_key(word)) end # see if there's a gloss for the inflected form
          if !(entry.nil?) then gloss=entry['gloss'] else gloss="??" end
          code = nil
          new_gloss_code = nil
          if Options.if_write_pos then
            # Re the need for \immediate in the following, see https://tex.stackexchange.com/q/604110/6853
            code = %q{\savebox{\myboxregister}{WORD}%
              %\smash{\pdfsavepos\usebox{\myboxregister}}%
              \makebox{\pdfsavepos\usebox{\myboxregister}}%
              \immediate\write\posoutputfile{LINE_HASH,\thepage,LINE,KEY,,,\the\wd\myboxregister,\the\ht\myboxregister,\the\dp\myboxregister}%
              \write\posoutputfile{LINE_HASH,\thepage,LINE,KEY,\the\pdflastxpos,\the\pdflastypos,,,}}
            code.gsub!(/LINE_HASH/,line_hash)
            code.gsub!(/WORD/,word)
            code.gsub!(/LINE/,i.to_s)
            code.gsub!(/KEY/,key)
            #code = "#{code}#{word}"
          end
          if Options.if_render_glosses then
            pos = Init.get_pos_data(line_hash,key) # a hash whose keys are "x","y","width","height","depth"
            x,y,width,height = pos['x'],pos['y'],pos['width'],pos['height'] # all floats in units of pts
            a =                 %q(\parbox[b]{WIDTH}{CONTENTS})  # https://en.wikibooks.org/wiki/LaTeX/Boxes
            a.sub!(/WIDTH/,     "#{width}pt"  )
            a.sub!(/CONTENTS/,  %q(\begin{blacktext}\begin{latin}__\end{latin}\end{blacktext})  )
            a.sub!(/__/,        gloss  )
            new_gloss_code = %q(\begin{textblock*}{_WIDTH_pt}(_XPOS_,_YPOS_)_GLOSS_\end{textblock*}) + "\n"
            new_gloss_code.sub!(/_WIDTH_/,"#{width}")
            new_gloss_code.sub!(/_XPOS_/,"#{x}pt")
            new_gloss_code.sub!(/_YPOS_/,"\\pdfpageheight-#{y}pt-#{0.7*height}pt")
            # ... Uses calc package; textpos's coordinate system goes from top down, pdfsavepos from bottom up.
            #     The final term scoots up the gloss so that its top is almost as high as the top of the Greek text.
            new_gloss_code.sub!(/_GLOSS_/,a)
          end
          if !(new_gloss_code.nil?) then gloss_code = gloss_code + new_gloss_code end
          if !(code.nil?) then lines[i] = lines[i].sub(/#{word}/,code) end
        end
      }
    }
  end
  main_code = main_code + verse_lines_to_latex(lines) + "\n\n"
  if ransom then main_code = main_code + "\\end{graytext}\n" end
  gloss_code = "\n{\\linespread{1.0}\\footnotesize #{gloss_code} }\n"
  code = main_code + gloss_code + "\\end{foreignpage}\n"
  print code
end

def verse_lines_to_latex(lines)
  return lines.join("\\\\\n")
end

def to_key(word)
  return remove_accents(word).downcase
end

def words(s)
  # fixme: handle apostrophes
  return s.scan(/[[:alpha:]]+/)
end

class Patch_names
  @@patches = {"Latona"=>"Leto","Ulysses"=>"Odysseus","Jove"=>"Zeus","Atrides"=>"Atreides","Minerva"=>"Athena"}
  def Patch_names.patch(text)
    @@patches.each { |k,v|
      text = text.gsub(/#{k}/,v)
    }
    return text
  end
end

class Lemmatize
  @@lemmas = json_from_file_or_die("lemmas/homer_lemmas.json")
  # typical entry when there's no ambiguity:
  #   "βέβασαν": [    "βαίνω",    "1",    "v3plia---",    1,    false,    null  ],
  def Lemmatize.lemmatize(word)
    # returns [lemma,success]
    if @@lemmas.has_key?(word) then return Lemmatize.lemma_helper(word) end
    if @@lemmas.has_key?(word.downcase) then return Lemmatize.lemma_helper(word.downcase) end
    if @@lemmas.has_key?(capitalize(word)) then return Lemmatize.lemma_helper(capitalize(word)) end
    return [word,false]
  end

  def Lemmatize.lemma_helper(word)
    lemma,lemma_number,pos,count,if_ambiguous,ambig = @@lemmas[word]
    return [lemma,true]
  end
end

class Options
  if ARGV.length<1 then die("no command-line argument supplied") end
  @@the_options = JSON.parse(ARGV[0])
  def Options.if_write_pos() return Options.has_flag('write_pos') end
  def Options.if_render_glosses() return Options.has_flag('render_glosses') end
  def Options.if_clean() return Options.has_flag('clean') end
  def Options.pos_file() return @@the_options['pos_file'] end
  def Options.has_flag(flag)
    return @@the_options.has_key?(flag) && @@the_options[flag]
  end
end

class Init
  # Code that gets run when the eruby script starts, but after code that's higher up in the file.
  require 'fileutils'
  require 'digest'
  if Options.if_clean then FileUtils.rm_f(Options.pos_file) end # Currently I open the file to write, not append, so this isn't necessary.
  if Options.if_write_pos then
    print %Q{
      \\newsavebox\\myboxregister
      \\newwrite\\posoutputfile
      \\immediate\\openout\\posoutputfile=#{Options.pos_file}
    }
  end
  @@pos = {} # will be a hash of hashes, @@pos[gloss_key][name_of_datum]
  if Options.if_render_glosses then
    IO.foreach(Options.pos_file) { |line| 
      line.sub!(/\s+$/,'') # trim trailing whitespace, such as a newline
      a = line.split(/,/,-1)
      line_hash,page,line,word_key,x,y,width,height,depth = a
      key = [line_hash,word_key].join(",")
      data = [x,y,width,height,depth]
      if !(@@pos.has_key?(key)) then @@pos[key] = {} end
      0.upto(data.length-1) { |i|
        name_of_datum = ["x","y","width","height","depth"][i]
        value = data[i]
        next if value==''
        value.sub!(/pt/,'')
        value = value.to_f
        if ["x","y"].include?(name_of_datum) then value = value/65536.0 end # convert to points
        if @@pos[key][name_of_datum].nil? then @@pos[key][name_of_datum]=value end
      }
    }
  end
  def Init.get_pos_data(line_hash,word_key)
    # returns a hash whose keys are "x","y","width","height","depth", all in units of pts
    return @@pos[[line_hash,word_key].join(",")]
  end
end

END {
  if Options.if_write_pos then
    print %q{
      \closeout\posoutputfile
    }
  end
  print %q{
    \end{document}
  }
}

def capitalize(x)
  return x.sub(/^(.)/) {$1.upcase}
end


def die(message)
  #  $stderr.print message,"\n"
  raise message # gives a stack trace
  exit(-1)
end

