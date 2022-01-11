require 'json'
require 'sdbm'
require 'set'
require_relative "lib/file_util"
require_relative "lib/string_util"
require_relative "lib/multistring"
require_relative "lib/treebank"
require_relative "lib/epos"
require_relative "lib/vlist"
require_relative "lib/gloss"
require_relative "lib/clown"
require_relative "greek/nouns"
require_relative "greek/verbs"
require_relative "greek/lemma_util"
require_relative "greek/writing"

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

class Bilingual
  def initialize(g1,g2,t1,t2,foreign,translation,max_chars:5000,length_ratio_expected:1.23,length_ratio_tol_factor:1.38)
    # g1 and g2 are line refs of the form [book,line]
    # t1 and t2 are word globs
    # sanity checks:
    #   max_chars -- maximum length of translated text
    #   length_ratio_expected -- expected value of length of translation divided by length of foreign text
    #   length_ratio_tol_factor -- tolerance factor for the above ratio
    @foreign_chapter_number = g1[0]
    @foreign_first_line_number = g1[1]
    @foreign_hr1,@foreign_hr2 = foreign.line_to_hard_ref(g1[0],g1[1]),foreign.line_to_hard_ref(g2[0],g2[1])
    @foreign_ch1,@foreign_ch2 = @foreign_hr1[0],@foreign_hr2[0]
    @foreign_text = foreign.extract(foreign_hr1,foreign_hr2)
    # Let word globs contain, e.g., Hera rather than Juno:
    t1 = Patch_names.antipatch(t1)
    t2 = Patch_names.antipatch(t2)
    translation_hr1_with_errs = translation.word_glob_to_hard_ref(t1)
    translation_hr2_with_errs = translation.word_glob_to_hard_ref(t2)
    translation_hr1,translation_hr2 = translation_hr1_with_errs[0],translation_hr2_with_errs[0]
    if translation_hr1_with_errs[1] then raise "ambiguous word glob: #{t1}, #{translation_hr1_with_errs[2]}" end
    if translation_hr2_with_errs[1] then raise "ambiguous word glob: #{t2}, #{translation_hr2_with_errs[2]}"end
    if translation_hr1.nil? || translation_hr2.nil? then raise "bad word glob, #{t1}->#{translation_hr1} or #{t2}->#{translation_hr2}" end
    @translation_text = translation.extract(translation_hr1,translation_hr2)
    @translation_text = Patch_names.patch(@translation_text) # change, e.g., Juno to Hera
    max_chars = 5000
    if @translation_text.length>max_chars || @translation_text.length==0 then
      message = "page of translated text has #{@translation_text.length} characters, failing sanity check"
      self.raise_failed_sanity_check(message,t1,t2,translation_hr1,translation_hr2)
    end
    l_t,l_f = @translation_text.length,@foreign_text.length
    length_ratio = l_t.to_f/l_f.to_f
    lo,hi = length_ratio_expected/length_ratio_tol_factor,length_ratio_expected*length_ratio_tol_factor
    if length_ratio<lo || length_ratio>hi then
      message = "length ratio=#{length_ratio}, outside of expected range of #{lo}-#{hi}"
      self.raise_failed_sanity_check(message,t1,t2,translation_hr1,translation_hr2)
    end
  end
  def raise_failed_sanity_check(basic_message,t1,t2,translation_hr1,translation_hr2)
    debug_file = "epos_debug.txt"
    message = "Epos text selection fails sanity check\n" \
         + basic_message + "\n" \
         + "  '#{t1}-'\n  '#{t2}'\n  #{translation_hr1}-#{translation_hr2}\n"
    File.open(debug_file,"w") { |f|
      f.print message,"\n-------------------\n",self.foreign_text,"\n-------------------\n",self.translation_text,"\n"
    }
    raise message + "\n  See #{debug_file}"
  end
  attr_reader :foreign_hr1,:foreign_hr2,:foreign_ch1,:foreign_ch2,:foreign_text,:translation_text,:foreign_first_line_number,:foreign_chapter_number
end

if Options.if_render_glosses then require_relative "lib/wiktionary" end # slow, don't load if not necessary

def four_page_layout(stuff,g1,g2,t1,t2,vocab_by_chapter,start_chapter:nil,dry_run:false)
  # g1 and g2 are line refs of the form [book,line]
  # t1 and t2 are word globs
  treebank,freq_file,greek,translation,notes,core = stuff
  bilingual = Bilingual.new(g1,g2,t1,t2,greek,translation)
  return if dry_run
  print_four_page_layout(stuff,bilingual,vocab_by_chapter,start_chapter)
end

def print_four_page_layout(stuff,bilingual,vocab_by_chapter,start_chapter)  
  # vocab_by_chapter is a running list of all lexical forms, gets modified; is an array indexed on chapter, each element is a list
  treebank,freq_file,greek,translation,notes,core = stuff
  ch = bilingual.foreign_ch1
  core,vl,vocab_by_chapter = four_page_layout_vocab_helper(bilingual,core,treebank,freq_file,notes,vocab_by_chapter,start_chapter,ch)
  if bilingual.foreign_ch1!=bilingual.foreign_ch2 then
    # This should only happen in the case where reference 2 is to the very first line of the next book.
    if !(bilingual.foreign_hr2[1]<=5 && bilingual.foreign_hr2[0]==bilingual.foreign_hr1[0]+1) then
      raise "four-page layout spans books, #{bilingual.foreign_hr1} - #{bilingual.foreign_hr2}"
    end
  end
  print_four_page_layout_latex_helper(bilingual,vl,core,start_chapter,notes)
end

def four_page_layout_vocab_helper(bilingual,core,treebank,freq_file,notes,vocab_by_chapter,start_chapter,ch)
  core = core.map { |x| remove_accents(x).downcase }
  vl = Vlist.from_text(bilingual.foreign_text,treebank,freq_file,exclude_glosses:list_exclude_glosses(bilingual.foreign_hr1,bilingual.foreign_hr2,notes))
  if !(start_chapter.nil?) then vocab_by_chapter[ch] = [] end
  if vocab_by_chapter[ch].nil? then vocab_by_chapter[ch]=[] end
  vocab_by_chapter[ch] = alpha_sort((vocab_by_chapter[ch]+vl.all_lexicals).uniq)
  return core,vl,vocab_by_chapter
end

def print_four_page_layout_latex_helper(bilingual,vl,core,start_chapter,notes)
  # prints
  v = vocab(vl,core) # prints
  print header_latex(bilingual)
  if !(start_chapter.nil?) then print "\\mychapter{#{start_chapter}}\n\n" end
  print foreign(bilingual.foreign_text,bilingual.foreign_first_line_number),"\n\n"
  if !(start_chapter.nil?) then print "\\myransomchapter{#{start_chapter}}\n\n" end
  print "\\renewcommand{\\rightheaderwhat}{\\rightheaderwhatglosses}%\n"
  print ransom(bilingual.foreign_text,v,bilingual.foreign_first_line_number),"\n\n"
  if !(start_chapter.nil?) then print "\\mychapter{#{start_chapter}}\n\n" end
  print bilingual.translation_text
  print notes_to_latex(bilingual.foreign_hr1,bilingual.foreign_hr2,notes)
end

def header_latex(bilingual)
  foreign_header = "#{bilingual.foreign_chapter_number}.#{bilingual.foreign_first_line_number}" # e.g., 2.217 for book 2, line 217
  x = ''
  x += "\\renewcommand{\\rightheaderinfo}{#{foreign_header}}%\n"
  x += "\\renewcommand{\\rightheaderwhat}{\\rightheaderwhatvocab}%\n"
  x += "\\pagebreak\n\n"
  x += "\\renewcommand{\\leftheaderinfo}{#{foreign_header}}%\n"
  return x
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
  # Finds notes that apply to the given range of linerefs. Converts the 0th element from a note's string into [book,line]. 
  # Sorts the results.
  if lineref1[0]==lineref2[0] then
    return find_notes_one_book(lineref1,lineref2,notes)
  else
    result = []
    lineref1[0].upto(lineref2[0]) { |book|
      if book==lineref1[0] then x=lineref1 else x=[book,1] end
      if book==lineref2[0] then y=lineref2 else y=[book,99999] end
      result = result + find_notes_one_book(x,y,notes)
    }
    if result.length>50 then raise "result in find_notes fails sanity check, #{results.length} notes" end
    return result
  end
end

def find_notes_one_book(lineref1,lineref2,notes)
  # Helper routine for find_notes().
  raise "error in find_notes_one_book, four-page layout spans books" if lineref1[0]!=lineref2[0]
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

def vocab(vl,core)
  # Input is a Vlist object.
  # The three sections are interpreted as common, uncommon, and rare.
  # Prints latex code for vocab page, and returns the three file lists for later reuse.
  if Options.if_render_glosses then $stderr.print vl.console_messages end
  print "\\begin{vocabpage}\n"
  print vocab_helper('uncommon',vl,0,2,core) # I used to have common (0) as one section and uncommon (1 and 2) as another. No longer separating them.
  print "\\end{vocabpage}\n"
  return vl.list.map { |l| l.map{ |entry| entry[1] } }
end

def vocab_helper(commonness,vl,lo,hi,core)
  l = []
  lo.upto(hi) { |i|
    vl.list[i].each { |entry|
      word,lexical,data = entry
      if data.nil? then data={} end
      pos = data['pos']
      is_verb = (pos=~/^[vt]/)
      g = Gloss.get(lexical)
      next if g.nil?
      difficult_to_recognize = data['difficult_to_recognize']
      debug = (word=='ἐρυσσάμενος')
      if debug then File.open("debug.txt","a") { |f| f.print "... 100 #{word} #{lexical} #{difficult_to_recognize}\n" } end # qwe
      difficult_to_recognize ||= (not_nil_or_zero(g['aorist_difficult_to_recognize']) && /^...a/.match?(pos) )
      if debug then File.open("debug.txt","a") { |f| f.print "... 150 #{word} #{lexical} #{difficult_to_recognize} #{not_nil_or_zero(g['aorist_difficult_to_recognize'])}\n" } end # qwe
      difficult_to_recognize ||= (is_verb && Verb_difficulty.guess(word,lexical,pos)[0])
      if debug then File.open("debug.txt","a") { |f| f.print "... 200 #{word} #{lexical} #{difficult_to_recognize} #{Verb_difficulty.guess(word,lexical,pos)[0]}\n" } end # qwe
      data['difficult_to_recognize'] = difficult_to_recognize
      data['core'] = core.include?(remove_accents(lexical).downcase)
      entry_type = nil
      if !data['core'] then entry_type='gloss' end
      if data['core'] && difficult_to_recognize then
        if is_verb then entry_type='conjugation' else entry_type='declension' end
      end
      if !entry_type.nil? then l.push([entry_type,[lexical,word,lexical,data]]) end
    }
  }
  secs = []
  ['gloss','conjugation','declension'].each { |type|
    envir = {'gloss'=>'vocaball','conjugation'=>'conjugations','declension'=>'declensions'}[type]
    ll = l.select { |entry| entry[0]==type }.map { |entry| entry[1] }
    if ll.length>0 then
      this_sec = ''
      this_sec += "\\begin{#{envir}}\n"
      ll.sort { |a,b| alpha_compare(a[0],b[0])}.each { |entry|
        s = nil
        if type=='gloss' then s=vocab1(entry) end
        if type=='conjugation' || type=='declension' then s=vocab_inflection(entry) end
        if !(s.nil?) then
          this_sec += clean_up_unicode("#{s}\\\\\n")
        else
          die("unrecognized vocab type: #{type}")
        end
      }
      this_sec += "\\end{#{envir}}\n"
      secs.push(this_sec)
    end
  }
  return secs.join("\n\\bigseparator\\vspace{2mm}\n")
end

def not_nil_or_zero(x)
  return !(x.nil? || x==0)
end

def vocab_inflection(stuff)
  file_under,word,lexical,data = stuff
  pos = data['pos']
  if pos[0]=='n' then
    return "\\vocabnouninflection{#{word.downcase}}{#{lexical}}{#{describe_declension(pos,true)[0]}}"
  end
  if pos[0]=~/[vt]/ then
    # File.open("debug.txt",'a') { |f| f.print "          #{word} #{lexical} #{pos} \n" } # qwe
    return "\\vocabverbinflection{#{word.downcase}}{#{lexical}}{#{Vform.new(pos).to_s_fancy(tex:true,relative_to_lemma:lexical,
                   omit_easy_number_and_person:true,omit_voice:true)}}"
  end
  return "\\vocabinflectiononly{#{word.downcase}}{#{lexical}}"
end

def vocab1(stuff)
  file_under,word,lexical,data = stuff
  entry = Gloss.get(lexical)
  return if entry.nil?
  word2,gloss,lexical2 = entry['word'],entry['gloss'],entry['lexical']
  if is_feminine_ending_in_os(remove_accents(lexical)) then gloss = "(f.) #{gloss}" end
  explain_inflection = entry.has_key?('lexical') || (data.has_key?('is_3rd_decl') && data['is_3rd_decl'] && !alpha_equal(word,lexical))
  if explain_inflection then
    text = [word.downcase,lexical,gloss]
  else
    text = [lexical,gloss]
  end
  total_chars = text.map { |t| t.length}.sum+text.length-1 # final terms count blanks
  if total_chars>35 && entry.has_key?('short') then gloss=entry['short'] end
  if explain_inflection then
    s = "\\vocabinflection{#{word.downcase}}{#{lexical}}{#{gloss}}"
  else
    s = "\\vocab{#{lexical}}{#{gloss}}"
  end
  return s
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
      gg.each { |x|
        if ww.include?(x) then # lemmatized version of line includes this rare lemma that we were asked to gloss
          j = ww.index(x)
          word = w[j] # original inflected form
          key = to_key(x)
          entry = Gloss.get(x,prefer_length:0) # it doesn't matter whether inputs have accents
          if !(entry.nil?) then gloss=entry['gloss'] else gloss="??" end
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
            if pos.nil? then raise "in foreign_helper, rendering ransom notes, position is nil for line_hash=#{line_hash}, key=#{key}" end
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
  def Patch_names.antipatch(text)
    @@patches.invert.each { |k,v|
      text = text.gsub(/#{k}/,v)
    }
    return text
  end
end

class Lemmatize
  @@lemmas = TreeBank.new('homer').lemmas
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

