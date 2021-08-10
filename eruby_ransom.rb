require 'json'
require 'sdbm'
require 'set'
require_relative "lib/file_util"
require_relative "lib/string_util"
require_relative "lib/epos"
require_relative "lib/vlist"
require_relative "lib/clown"
require_relative "greek/nouns"

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

if Options.if_render_glosses then require_relative "lib/wiktionary" end # slow, don't load if not necessary

def four_page_layout(stuff,g1,g2,t1,t2,vocab_by_chapter,start_chapter:nil)  
  # g1 and g2 are line refs of the form [book,line]
  # t1 and t2 are word globs
  # vocab_by_chapter is a running list of all lexical forms, gets modified; is an array indexed on chapter, each element is a list
  ch = g1[0]
  lemmas_file,freq_file,greek,translation,notes = stuff
  rg1,rg2 = greek.line_to_hard_ref(g1[0],g1[1]),greek.line_to_hard_ref(g2[0],g2[1])
  raise "four-page layout spans books" if rg1[0]!=rg2[0] # will cause all kinds of problems, including with notes
  first_line_number = g1[1]
  greek_text = greek.extract(rg1,rg2)
  vl = Vlist.from_text(greek_text,lemmas_file,freq_file,exclude_glosses:list_exclude_glosses(g1,g2,notes))
  if !(start_chapter.nil?) then vocab_by_chapter[ch] = [] end
  vocab_by_chapter[ch] = alpha_sort((vocab_by_chapter[ch]+vl.all_lexicals).uniq)
  v = vocab(vl) # prints
  print "\\renewcommand{\\rightheaderinfo}{#{g1[0]}.#{g1[1]}}%\n"
  print "\\renewcommand{\\rightheaderwhat}{\\rightheaderwhatvocab}%\n"
  print "\\pagebreak\n\n"
  print "\\renewcommand{\\leftheaderinfo}{#{g1[0]}.#{g1[1]}}%\n"
  if !(start_chapter.nil?) then print "\\mychapter{#{start_chapter}}\n\n" end
  print foreign(greek_text,first_line_number),"\n\n"
  if !(start_chapter.nil?) then print "\\myransomchapter{#{start_chapter}}\n\n" end
  print "\\renewcommand{\\rightheaderwhat}{\\rightheaderwhatglosses}%\n"
  print ransom(greek_text,v,first_line_number),"\n\n"
  rt1,rt2 = translation.word_glob_to_hard_ref(t1)[0],translation.word_glob_to_hard_ref(t2)[0]
  if rt1.nil? || rt2.nil? then raise "bad word glob, #{t1}->#{rt1} or #{t2}->#{rt2}" end
  translation_text = translation.extract(rt1,rt2)
  translation_text = Patch_names.patch(translation_text)
  if !(start_chapter.nil?) then print "\\mychapter{#{start_chapter}}\n\n" end
  print translation_text
  print notes_to_latex(g1,g2,notes)
end

def notes_to_latex(lineref1,lineref2,notes)
  stuff = []
  find_notes(lineref1,lineref2,notes).each { |note|
    h = note[1]
    next if !(h.has_key?('explain'))
    this_note = "#{note[0][0]}.#{note[0][1]} \\textbf{#{h['about_what']}}: #{h['explain']}"
    stuff.push(this_note)
  }
  if stuff.length==0 then return '' end
  return %Q{
    \\par
    \\textit{notes}\\\\
    #{stuff.join("\\\\")}
    }
end

def list_exclude_glosses(lineref1,lineref2,notes)
  result = []
  find_notes(lineref1,lineref2,notes).each { |note|
    h = note[1]
    next if !(h.has_key?('prevent_gloss'))
    result = result+h['prevent_gloss'].map { |x| remove_accents(x).downcase}
  }
  return result
end

def find_notes(lineref1,lineref2,notes)
  # Finds notes that apply to the given range of linerefs. Converts the 0th element from a string into [book,line]. 
  # Sorts the results.
  raise "four-page layout spans books" if lineref1[0]!=lineref2[0]
  book = lineref1[0]
  result = []
  notes.each { |note|
    note[0] =~ /(.*)\.(.*)/
    next if $1.to_i!=book
    line = $2.to_i
    if lineref1[1]<=line && line<=lineref2[1] then
      note = clown(note)
      note[0] = [book,line]
      result.push(note)
    end
  }
  return result.sort { |a,b| a[0] <=> b[0] } # array comparison is lexical
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
      g = get_gloss(lexical,word)
      next if g.nil?
      file_under = g['file_under']
      if file_under.nil? then raise "get_gloss = #{g}, doesn't have a file_under key" end
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
  word2,gloss,lexical2 = entry['word'],entry['medium'],entry['lexical']
  if is_feminine_ending_in_os(remove_accents(lexical)) then gloss = "(f.) #{gloss}" end
  if entry.has_key?('lexical') || (data.has_key?('is_3rd_decl') && data['is_3rd_decl'] && !alpha_equal(word,lexical)) then
    s = "\\vocabinflection{#{word.downcase}}{#{lexical}}{#{gloss}}"
  else
    s = "\\vocab{#{lexical}}{#{gloss}}"
  end
  print clean_up_unicode("#{s}\\\\")
end

def word_to_filename(s)
  return remove_accents(s).downcase.sub(/᾽/,'')
end

def get_gloss(lexical,word,prefer_short:false)
  # It doesn't matter whether the inputs have accents or not. We immediately strip them off.
  # Return value looks like the following. The item lexical exists only if this is supposed to be an entry for the inflected form.
  # {  "word"=> "ἔθηκε",  "medium"=> "put, put in a state",  "lexical"=> "τίθημι", "file_under"=>"ἔθηκε" }
  entry_lexical   = get_gloss_helper(word_to_filename(lexical),prefer_short)
  entry_inflected = get_gloss_helper(word_to_filename(word),prefer_short)
  if entry_inflected.nil? then
    entry = entry_lexical
    file_under = lexical
  else
    entry = entry_inflected
    file_under = word
  end
  if !(entry.nil?) then entry = entry.merge({'file_under'=>file_under}) end
  return entry
end

def get_gloss_helper(key,prefer_short)
  path = "glosses/#{key}"
  if FileTest.exist?(path) then
    x = json_from_file_or_die(path)
    # {  "word": "ἔθηκε",  "medium": "put, put in a state",  "lexical": "τίθημι" }
    if prefer_short && x.has_key?('short') then x['medium']=x['short'] end
    return x
  else
    return nil
  end
end

def foreign(t,first_line_number)
  foreign_helper(t,false,first_line_number,left_page_verse:true)
end

def ransom(t,v,first_line_number)
  common,uncommon,rare = v
  foreign_helper(t,true,first_line_number,gloss_these:rare)
end

def foreign_helper(t,ransom,first_line_number,gloss_these:[],left_page_verse:false)
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
          entry = get_gloss(x,word,prefer_short:true) # it doesn't matter whether inputs have accents
          if !(entry.nil?) then gloss=entry['medium'] else gloss="??" end
          code = nil
          new_gloss_code = nil
          if Options.if_write_pos then
            # Re the need for \immediate in the following, see https://tex.stackexchange.com/q/604110/6853
            code = %q{\savebox{\myboxregister}{WORD}%
              \makebox{\pdfsavepos\usebox{\myboxregister}}%
              \immediate\write\posoutputfile{LINE_HASH,\thepage,LINE,KEY,,,\the\wd\myboxregister,\the\ht\myboxregister,\the\dp\myboxregister}%
              \write\posoutputfile{LINE_HASH,\thepage,LINE,KEY,\the\pdflastxpos,\the\pdflastypos,,,}}
            code.gsub!(/LINE_HASH/,line_hash)
            code.gsub!(/WORD/,word)
            code.gsub!(/LINE/,i.to_s)
            code.gsub!(/KEY/,key)
          end
          if Options.if_render_glosses then
            pos = Init.get_pos_data(line_hash,key) # a hash whose keys are "x","y","width","height","depth"
            x,y,width,height = pos['x'],pos['y'],pos['width'],pos['height'] # all floats in units of pts
            if x>254.0 then
              width=355.0-x
            else
              if x>235.0 && width<42.0 then width=42.0 end # less aggressive, for cases where the width is super narrow, and we're fairly far to the right
            end
            # ... Likely to be the last glossed word on line, so extend its width.
            #     Kludge, fixme: hardcoded numbers, guessing whether last glossed word on line.
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
            code = %q{\begin{whitetext}WORD\end{whitetext}}
            code.gsub!(/WORD/,word)
          end
          if !(new_gloss_code.nil?) then gloss_code = gloss_code + new_gloss_code end
          if !(code.nil?) then lines[i] = lines[i].sub(/#{word}/,code) end
        end
      }
    }
  end
  main_code = main_code + verse_lines_to_latex(lines,first_line_number,left_page_verse) + "\n\n"
  if ransom then main_code = main_code + "\\end{graytext}\n" end
  gloss_code = "\n{\\linespread{1.0}\\footnotesize #{gloss_code} }\n"
  code = main_code + gloss_code + "\\end{foreignpage}\n"
  code = clean_up_unicode(code)
  print code
end

def clean_up_unicode(s)
  # Olga and Porson lack B7 middle dot, have 387 Greek ano teleia.
  s = s.gsub(/\u{b7}/,"\u{387}")
  return s
end

def verse_lines_to_latex(lines,first_line_number,left_page_verse)
  cooked = []
  0.upto(lines.length-1) { |i|
    line_number = first_line_number+i
    c = clown(lines[i])
    want_line_number = (line_number%5==0)
    if left_page_verse then
      max_len_for_num = 53 # if longer than this, make sure text won't run into number; only 2 of the 1st 500 lines are this long
      if want_line_number && c.length<max_len_for_num then n=line_number.to_s else n='' end
      c = "\\leftpageverseline{\\linenumber{#{n}}}{#{c}}"
    else
      if want_line_number then c=c+"\\hfill{}\\linenumber{#{line_number}}" end
      c = c+"\\\\"
    end
    cooked.push(c)
  }
  return cooked.join("\n")
end

def to_key(word)
  return remove_accents(word).downcase
end

def words(s)
  # fixme: handle apostrophes
  return s.scan(/[[:alpha:]]+/)
end

class Patch_names
  @@patches = {"Latona"=>"Leto","Ulysses"=>"Odysseus","Jove"=>"Zeus","Atrides"=>"Atreides","Minerva"=>"Athena","Juno"=>"Hera"}
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

