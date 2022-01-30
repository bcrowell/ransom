require 'json'
require 'sdbm'
require 'set'

class Options
  if ARGV.length<1 then die("no command-line argument supplied") end
  @@the_options = JSON.parse(ARGV[0])
  def Options.if_prose_trial_run() return Options.has_flag('prose_trial_run') end
  def Options.if_write_pos() return Options.has_flag('write_pos') end
  def Options.if_render_glosses() return Options.has_flag('render_glosses') end
  def Options.if_clean() return Options.has_flag('clean') end # pre-delete .pos file; not actually needed, since we open it to write
  def Options.pos_file() return @@the_options['pos_file'] end
  def Options.has_flag(flag)
    return @@the_options.has_key?(flag) && @@the_options[flag]
  end
  def Options.set(key,value)
    @@the_options[key] = value
  end
  def Options.get(key)
    return @@the_options[key]
  end
end

require_relative "lib/file_util"
require_relative "lib/string_util"
require_relative "lib/multistring"
require_relative "lib/treebank"
require_relative "lib/epos"
require_relative "lib/genos"
require_relative "lib/wiktionary"
require_relative "lib/vlist"
require_relative "lib/vocab_page"
require_relative "lib/bilingual"
require_relative "lib/illustrations"
require_relative "lib/latex"
require_relative "lib/gloss"
require_relative "lib/clown"
require_relative "greek/nouns"
require_relative "greek/verbs"
require_relative "greek/lemma_util"
require_relative "greek/writing"
if Options.if_render_glosses then require_relative "lib/wiktionary" end # slow, don't load if not necessary


def four_page_layout(stuff,genos,db,wikt,layout,next_layout,vocab_by_chapter,start_chapter:nil,dry_run:false)
  # Doesn't get called if if_prose_trial_run is set.
  # The parameter wikt should be a WiktionaryGlosses object for the appropriate language; if nil, then no gloss help will be generated,
  # and only a brief warning will be printed to stderr.
  treebank,freq_file,greek,translation,notes,core = stuff
  return if dry_run
  print_four_page_layout(stuff,genos,db,wikt,layout,next_layout,vocab_by_chapter,start_chapter)
end

def print_four_page_layout(stuff,genos,db,wikt,bilingual,next_layout,vocab_by_chapter,start_chapter)  
  # vocab_by_chapter is a running list of all lexical forms, gets modified; is an array indexed on chapter, each element is a list
  # doesn't get called if if_prose_trial_run is set
  treebank,freq_file,greek,translation,notes,core = stuff
  ch = bilingual.foreign_ch1
  core,vl,vocab_by_chapter = VocabPage.helper(bilingual,genos,db,wikt,core,treebank,freq_file,notes,vocab_by_chapter,start_chapter,ch)
  if bilingual.foreign_ch1!=bilingual.foreign_ch2 then
    # This should only happen in the case where reference 2 is to the very first line of the next book.
    if !(bilingual.foreign_hr2[1]<=5 && bilingual.foreign_hr2[0]==bilingual.foreign_hr1[0]+1) then
      raise "four-page layout spans books, #{bilingual.foreign_hr1} - #{bilingual.foreign_hr2}"
    end
  end
  print_four_page_layout_latex_helper(db,bilingual,next_layout,vl,core,start_chapter,notes)
end

def print_four_page_layout_latex_helper(db,bilingual,next_layout,vl,core,start_chapter,notes)
  # prints
  # Doesn't get called if Options.if_prose_trial_run is set
  stuff = VocabPage.make(db,vl,core)
  tex,v = stuff['tex'],stuff['file_lists']
  print tex
  if notes.length>0 then print notes_to_latex(bilingual.foreign_linerefs,notes) end # FIXME: won't work if foreign text is prose, doesn't have linerefs
  print header_latex(bilingual) # includes pagebreak
  print foreign(db,bilingual,bilingual.foreign_first_line_number,start_chapter),"\n\n"
  print "\\renewcommand{\\rightheaderwhat}{\\rightheaderwhatglosses}%\n"
  print ransom(db,bilingual,v,bilingual.foreign_first_line_number,start_chapter),"\n\n"
  print bilingual.translation_text
  # https://tex.stackexchange.com/a/308934
  layout_for_illustration = next_layout  # place illustration at bottom of page coming immediately before the *next* four-page layout
  if !layout_for_illustration.nil? then print Illustrations.do_one(layout_for_illustration) end
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

def notes_to_latex(linerefs,notes)
  lineref1,lineref2 = linerefs
  if lineref2[1]-lineref1[1]>20 then raise "sanity check failed for inputs to notes_to_latex, #{lineref1}->#{lineref2}" end
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
    # File.open("debug.txt",'a') { |f| f.print "          #{word} #{lexical} #{pos} \n" }
    return "\\vocabverbinflection{#{word.downcase}}{#{lexical}}{#{Vform.new(pos).to_s_fancy(tex:true,relative_to_lemma:lexical,
                   omit_easy_number_and_person:true,omit_voice:true)}}"
  end
  return "\\vocabinflectiononly{#{word.downcase}}{#{lexical}}"
end

def vocab1(db,stuff)
  file_under,word,lexical,data = stuff
  entry = Gloss.get(db,lexical)
  return if entry.nil?
  preferred_lex = entry['word']
  # ...If there is a lexical form used in the database (such as Perseus), but we want some other form (such as Homeric), then
  #    preferred_lex will be different from the form inside stuff.
  word2,gloss,lexical2 = entry['word'],entry['gloss'],entry['lexical']
  if is_feminine_ending_in_os(remove_accents(lexical)) then gloss = "(f.) #{gloss}" end
  explain_inflection = entry.has_key?('lexical') || (data.has_key?('is_3rd_decl') && data['is_3rd_decl'] && !alpha_equal(word,lexical))
  # Count chars, and if it looks too long to fit on a line, switch to the short gloss:
  if explain_inflection then
    text = [word.downcase,preferred_lex,gloss]
  else
    text = [preferred_lex,gloss]
  end
  total_chars = text.map { |t| t.length}.sum+text.length-1 # final terms count blanks
  if total_chars>35 && entry.has_key?('short') then gloss=entry['short'] end
  # Generate latex:
  if explain_inflection then
    s = "\\vocabinflection{#{word.downcase}}{#{preferred_lex}}{#{gloss}}"
  else
    s = "\\vocab{#{preferred_lex}}{#{gloss}}"
  end
  return s
end


def foreign(db,bilingual,first_line_number,start_chapter)
  if bilingual.foreign.is_verse then
    return foreign_verse(db,bilingual,false,first_line_number,start_chapter,left_page_verse:true)
  else
    return foreign_prose(db,bilingual,false,first_line_number,start_chapter,left_page_verse:true)
  end
end

def ransom(db,bilingual,v,first_line_number,start_chapter)
  common,uncommon,rare = v
  if bilingual.foreign.is_verse then
    code = foreign_verse(db,bilingual,true,first_line_number,start_chapter,gloss_these:rare)
  else
    code = foreign_prose(db,bilingual,true,first_line_number,start_chapter,gloss_these:rare)
  end
  code = clean_up_unicode(code)
  print code
end

def foreign_prose(db,bilingual,ransom,first_line_number,start_chapter,gloss_these:[],left_page_verse:false)
  code = ''
  code += "\\begin{foreignprose}\n"
  code += "\\enlargethispage{\\baselineskip}\n"
  code += bilingual.foreign_text.sub(/\s+$/,'') # strip trailing newlines to make sure that there is no paragraph break before the following:
  code += '{\parfillskip=0pt \emergencystretch=.5\textwidth \par}'
  # ... Force the final paragraph to be typeset as a paragraph, which is how it was typeset in the trial run.
  #     https://tex.stackexchange.com/a/116573
  code += "\n\n"
  code += "\\end{foreignprose}\n"
  return code
end

def foreign_verse(db,bilingual,ransom,first_line_number,start_chapter,gloss_these:[],left_page_verse:false)
  # If gloss_these isn't empty, then we assume it contains a list of rare lemmatized forms.
  # Returns a string containing latex code.
  t = bilingual.foreign_text
  gloss_code = ''
  main_code = ''
  main_code += "\\begin{foreignverse}\n"
  if ransom then main_code += "\\begin{graytext}\n" end
  if !(start_chapter.nil?) then main_code += "\\mychapter{#{start_chapter}}\n\n" end # will be gray if on ransom page, because inside graytext environment
  lines = t.split(/\s*\n\s*/)
  if gloss_these.length>0 then
    gg = gloss_these.map { |x| remove_accents(x)}
    0.upto(lines.length-1) { |i|
      hashable = [lines[i],bilingual.hash,i] # should be totally unique to this line, even if a line of poetry is repeated
      line_hash = WhereAt.hash(hashable)
      w = words(lines[i])
      ww = w.map { |x| remove_accents(Lemmatize.lemmatize(x)[0]).downcase} # if the lemmatizer fails, it just returns the original word
      gg.each { |x|
        if ww.include?(x) then # lemmatized version of line includes this rare lemma that we were asked to gloss
          j = ww.index(x)
          word = w[j] # original inflected form
          key = to_key(x)
          entry = Gloss.get(db,x,prefer_length:0) # it doesn't matter whether inputs have accents
          if !(entry.nil?) then gloss=entry['gloss'] else gloss="??" end
          code = nil
          new_gloss_code = nil
          if Options.if_write_pos then code=WhereAt.latex_code_to_print_and_write_pos(word,key,line_hash,line_number:i)  end
          if Options.if_render_glosses then code,new_gloss_code=render_gloss_for_foreign_page(line_hash,word,key,gloss,bilingual) end
          if !(new_gloss_code.nil?) then gloss_code = gloss_code + new_gloss_code end
          if !(code.nil?) then lines[i] = lines[i].sub(/#{word}/,code) end
        end
      }
    }
  end
  main_code = main_code + verse_lines_to_latex(lines,first_line_number,left_page_verse) + "\n\n"
  if ransom then main_code = main_code + "\\end{graytext}\n" end
  gloss_code = "\n{\\linespread{1.0}\\footnotesize #{gloss_code} }\n"
  code = main_code + gloss_code + "\\end{foreignverse}\n"
  if bilingual.foreign.genos.greek then code = "\\begin{greek}\n#{code}\\end{greek}\n" end
  return code
end

def render_gloss_for_foreign_page(line_hash,word,key,gloss,bilingual)
  # Word is the inflected string. Key is the database key, i.e., the lemma with no accents. Gloss is a string.
  # Returns [code,new_gloss_code], where code writes the original word in white ink, i.e., erases it, and
  # new_gloss_code is the latex code to put the gloss in black, positioned on top of that.
  pos = WhereAt.get_pos_data(line_hash,key) # a hash whose keys are "x","y","width","height","depth"
  if pos.nil? then raise "in foreign_helper, rendering ransom notes, position is nil for line_hash=#{line_hash}, key=#{key}" end
  pos = RansomGloss.tweak_gloss_geom_kludge_fixme(pos)
  a = RansomGloss.text_in_box(gloss,pos['width'],bilingual.translation.genos)
  new_gloss_code = RansomGloss.text_at_position(a,pos)
  code = %q{\begin{whitetext}WORD\end{whitetext}}
  code.gsub!(/WORD/,word)
  return [code,new_gloss_code]
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
  @@patches = {"Latona"=>"Leto","Ulysses"=>"Odysseus","Jove"=>"Zeus","Atrides"=>"Atreides","Minerva"=>"Athena","Juno"=>"Hera","Saturn"=>"Cronus",
                "Vulcan"=>"Hephaestus"}
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
  if Options.if_clean then FileUtils.rm_f(WhereAt.file_path) end # Currently I open the file to write, not append, so this isn't necessary.
  if Options.if_write_pos then print WhereAt.latex_code_to_create_pos_file() end
  if Options.if_render_glosses then @@pos=WhereAt.read_back_pos_file()  end
end

END {
  if Options.if_write_pos then print WhereAt.latex_code_to_close_pos_file() end
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

