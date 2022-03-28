require 'json'
require 'sdbm'
require 'set'

require './lib/file_util.rb'
require './lib/latex.rb'
require './lib/debug.rb'

class Options
  if ARGV.length<1 then die("no command-line argument supplied") end
  @@the_options = JSON.parse(ARGV[0])
  def Options.if_prose_trial_run() return Options.has_flag('prose_trial_run') end
  def Options.if_write_pos() return Options.has_flag('write_pos') end
  def Options.if_render_glosses() return Options.has_flag('render_glosses') end
  def Options.if_clean() return Options.has_flag('clean') end # pre-delete .pos file; not actually needed, since we open it to write
  def Options.pos_file() return @@the_options['pos_file'] end
  def Options.check_aux() return @@the_options['check_aux'] end
  def Options.if_warn() return Options.has_flag('if_warn') end
  def Options.vol() return @@the_options['vol'] end
  def Options.has_flag(flag)
    return @@the_options.has_key?(flag) && @@the_options[flag]
  end
  def Options.set(key,value)
    @@the_options[key] = value
  end
  def Options.get(key)
    return @@the_options[key]
  end
  if !Options.check_aux().nil? then
    $stderr.print "Checking for text that overflows a page...\n"
    aux_file = Options.check_aux()
    contents,message = slurp_file_with_detailed_error_reporting(aux_file)
    if contents.nil? then raise message end
    labels,layouts = Latex.parse_aux_file(contents)
    # The following assume four-page spreads labeled with -a through -d.
    layouts.each { |layout|
      pp = []
      ['a','b','c','d'].each { |x|
        key = layout+"-"+x
        if !labels.has_key?(key) then raise "label #{key} not present in #{aux_file}" end
        pp.push(labels[key])
        # The following assumes that the a page is supposed to be odd.
      }
      1.upto(4) { |i|
        if (pp[i-1]-i)%2!=0 then raise "Text overflowed from p. #{pp[i-1]-2} onto the next page, or for some other reason the parity of p. #{pp[i-1]} was unexpected. Layout=#{layout}. Vocab pages should be odd page numbers. The fix for this is normally to add a reduce_max_entries option to the relevant page-break data, or shrink the notes." end
      }
    }
    $stderr.print "...No problems found.\n"
  end
end

require_relative "lib/load_common"
require_relative "greek/load_common"

if Options.if_render_glosses then require_relative "lib/wiktionary" end # slow, don't load if not necessary


def four_page_layout(stuff,context,genos,db,wikt,layout,next_layout,vocab_by_chapter,start_chapter:nil,dry_run:false,
         if_warn:true,reduce_max_entries:0)
  # Doesn't get called if if_prose_trial_run is set.
  # The parameter wikt should be a WiktionaryGlosses object for the appropriate language; if nil, then no gloss help will be generated,
  # and only a brief warning will be printed to stderr.
  treebank,freq,greek,translation,notes,core = stuff
  return if dry_run
  print_four_page_layout(stuff,context,genos,db,wikt,layout,next_layout,vocab_by_chapter,start_chapter,
           if_warn:if_warn,reduce_max_entries:reduce_max_entries)
end

def print_four_page_layout(stuff,context,genos,db,wikt,bilingual,next_layout,vocab_by_chapter,start_chapter,
            if_warn:true,reduce_max_entries:0)
  # vocab_by_chapter is a running list of all lexical forms, gets modified; is an array indexed on chapter, each element is a list
  # doesn't get called if if_prose_trial_run is set
  treebank,freq,greek,translation,notes,core = stuff
  ch = bilingual.foreign_ch1
  n_lines_of_notes = Notes.estimate_n_lines(bilingual.foreign_linerefs,notes)
  reduce_max_entries += 2*n_lines_of_notes
  #Debug.print(n_lines_of_notes>0) {"#{bilingual.foreign_linerefs} #{reduce_max_entries}"}
  core,vl,vocab_by_chapter = VocabPage.helper(bilingual,context,genos,db,wikt,core,treebank,freq,notes,vocab_by_chapter,start_chapter,ch,
          if_warn:if_warn,reduce_max_entries:reduce_max_entries)
  if bilingual.foreign_ch1!=bilingual.foreign_ch2 then
    # This should only happen in the case where reference 2 is to the very first line of the next book.
    if !(bilingual.foreign_hr2[1]<=5 && bilingual.foreign_hr2[0]==bilingual.foreign_hr1[0]+1) then
      raise "four-page layout spans books, #{bilingual.foreign_hr1} - #{bilingual.foreign_hr2}"
    end
  end
  print_four_page_layout_latex_helper(treebank,db,bilingual,next_layout,vl,core,start_chapter,notes)
end

def print_four_page_layout_latex_helper(treebank,db,bilingual,next_layout,vl,core,start_chapter,notes,ransom_spacing:0.85)
  # prints
  # Doesn't get called if Options.if_prose_trial_run is set
  # Ransom_spacing is the tightness inter-line spacing in the glosses given in the ransom notes.
  stuff = VocabPage.make(bilingual,db,vl,core)
  tex,v = stuff['tex'],stuff['file_lists']
  print tex
  if notes.length>0 then print Notes.to_latex(bilingual.foreign_linerefs,notes) end # FIXME: won't work if foreign text is prose, doesn't have linerefs
  print header_latex(bilingual) # includes pagebreak
  print foreign(treebank,db,bilingual,bilingual.foreign_first_line_number,start_chapter,ransom_spacing),"\n\n"
  if bilingual.foreign.genos.greek then header='Σχόλια' else header='Glosses' end
  print "\\renewcommand{\\rightheaderwhat}{#{header}}%\n"
  print ransom(treebank,db,bilingual,v,bilingual.foreign_first_line_number,start_chapter,ransom_spacing),"\n\n"
  print "\\label{#{bilingual.label}-d}"+bilingual.translation_text
  # https://tex.stackexchange.com/a/308934
  layout_for_illustration = next_layout  # place illustration at bottom of page coming immediately before the *next* four-page layout
  if !layout_for_illustration.nil? then print Illustrations.do_one(layout_for_illustration) end
end

def header_latex(bilingual)
  if bilingual.foreign.genos.greek then page_header='Λεξικόνιον' else header='Vocabulary' end
  foreign_header = "#{bilingual.foreign_chapter_number}.#{bilingual.foreign_first_line_number}" # e.g., 2.217 for book 2, line 217
  x = ''
  x += "\\renewcommand{\\rightheaderinfo}{#{foreign_header}}%\n"
  x += "\\renewcommand{\\rightheaderwhat}{#{page_header}}%\n"
  x += "\\pagebreak\n\n"
  x += "\\renewcommand{\\leftheaderinfo}{#{foreign_header}}%\n"
  return x
end


def list_exclude_glosses(lineref1,lineref2,notes)
  result = []
  Notes.find(lineref1,lineref2,notes).each { |note|
    h = note[1]
    next if !(h.has_key?('prevent_gloss'))
    result = result+h['prevent_gloss'].map { |x| remove_accents(x).downcase}
  }
  return result
end

def not_nil_or_zero(x)
  return !(x.nil? || x==0)
end

def foreign(treebank,db,bilingual,first_line_number,start_chapter,ransom_spacing)
  label_code = "\\label{#{bilingual.label}-b}"
  if bilingual.foreign.is_verse then
    main_code,garbage,environment = foreign_verse(treebank,db,bilingual,false,first_line_number,start_chapter,ransom_spacing,left_page_verse:true)
  else
    main_code,garbage,environment = foreign_prose(treebank,db,bilingual,false,first_line_number,start_chapter,ransom_spacing,left_page_verse:true)
  end
  print label_code+postprocess_foreign_or_ransom('foreign',bilingual,main_code,environment,start_chapter)
end

def ransom(treebank,db,bilingual,v,first_line_number,start_chapter,ransom_spacing)
  common,uncommon,rare = v
  label_code = "\\label{#{bilingual.label}-c}"
  if bilingual.foreign.is_verse then
    main_code,gloss_code,environment = foreign_verse(treebank,db,bilingual,true,first_line_number,start_chapter,ransom_spacing,gloss_these:rare)
  else
    main_code,gloss_code,environment = foreign_prose(treebank,db,bilingual,true,first_line_number,start_chapter,ransom_spacing,gloss_these:rare)
  end
  print label_code+postprocess_foreign_or_ransom('ransom',bilingual,main_code,environment,start_chapter,gloss_code:gloss_code)
end

def foreign_prose(treebank,db,bilingual,ransom,first_line_number,start_chapter,ransom_spacing,gloss_these:[],left_page_verse:false)
  main_code = ''
  main_code += "\\enlargethispage{\\baselineskip}\n"
  text = clown(bilingual.foreign_text)
  gloss_code = ''
  # In the following, if this is the plain foreign-language page (as opposed to the facing ransom-note page), then
  # gloss_these with be an empty list, and that's OK. We still need to run this code in order to do other things,
  # such as preventing hyphenation.
  gg = gloss_these.map { |x| remove_accents(x)}
  hashes = []
  split_string_at_whitespace(text).each { |x|
    word_for_hash,whitespace = x
    hashes.push([word_for_hash,WhereAt.auto_hash(word_for_hash)]) # use this to pick data out of pos file
  }
  match_up = merge_word_lists(words(text),hashes)
  # result is list of triples like [word from words(text),word from split at whitespace,hash]
  k = 0
  substitutions = {}
  match_up.each { |x|
    word_bare,word_with_trailing_punct,hash = x
    lemma = remove_accents(treebank.lemmatize(word_bare)[0]).downcase  # if the lemmatizer fails, it just returns the original word
    code_for_word = "\\mbox{#{word_with_trailing_punct}}" # default if not to be glossed; \mbox prevents hyphenation
    marker = "__SUB#{k}__"
    k += 1
    gg.each { |x|
      if lemma==x then
        entry = Gloss.get(db,x,prefer_length:0) # it doesn't matter whether inputs have accents
        if !(entry.nil?) then gloss=entry['gloss'] else gloss="??" end
        code = nil
        new_gloss_code = nil
        # In both of the following lines, the code that is generated prevents hyphenation, and that's good.
        if Options.if_write_pos then code=WhereAt.latex_code_to_print_and_write_pos(word_with_trailing_punct,to_key(x),hash)  end
        if Options.if_render_glosses then code,new_gloss_code=render_gloss_for_foreign_page(hash,word_with_trailing_punct,to_key(x),gloss,bilingual) end
        if !(new_gloss_code.nil?) then gloss_code = gloss_code + new_gloss_code end
        if !(code.nil?) then code_for_word=code end
      end
    }
    text = text.sub(/#{word_with_trailing_punct}/,marker)
    substitutions[marker] = code_for_word
  }
  substitutions.keys.each { |marker|
    text.sub!(/#{marker}/,substitutions[marker])
  }
  main_code += text.sub(/\s+$/,'') # strip trailing newlines to make sure that there is no paragraph break before the following:
  main_code += '{\parfillskip=0pt \emergencystretch=.5\textwidth \par}'
  # ... Force the final paragraph to be typeset as a paragraph, which is how it was typeset in the trial run.
  #     https://tex.stackexchange.com/a/116573
  main_code += "\n\n"
  gloss_code = Latex.linespread(ransom_spacing,Latex.footnotesize(gloss_code))
  return [main_code,gloss_code,'foreignprose']
end

def foreign_verse(treebank,db,bilingual,ransom,first_line_number,start_chapter,ransom_spacing,gloss_these:[],left_page_verse:false)
  # If gloss_these isn't empty, then we assume it contains a list of rare lemmatized forms.
  # Returns a string containing latex code.
  t = bilingual.foreign_text
  gloss_code = ''
  main_code = ''
  t = t.gsub(/\n{2,}/,"\n__PAR__")
  t = t.sub(/\A\n/,'') # eliminate single newline, if it exists, on the front
  t = t.gsub(/__PAR__/,%q(\hspace{\verseparindent}))
  lines = t.split(/\s*\n\s*/)
  if gloss_these.length>0 then
    gg = gloss_these.map { |x| remove_accents(x)}
    0.upto(lines.length-1) { |i|
      hashable = [lines[i],bilingual.hash,i] # should be totally unique to this line, even if a line of poetry is repeated
      line_hash = WhereAt.hash(hashable)
      w = words(lines[i])
      ww = w.map { |x| remove_accents(treebank.lemmatize(x)[0]).downcase} # if the lemmatizer fails, it just returns the original word
      gloss_these.each { |lemma|
        x = remove_accents(lemma)
        if ww.include?(x) then # lemmatized version of line includes this rare lemma that we were asked to gloss
          j = ww.index(x)
          word = w[j] # original inflected form
          key = to_key(x)
          entry = Gloss.get(db,lemma,prefer_length:0) # use less ambiguous, accented form, for, e.g., ὦμος vs ὠμός
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
  gloss_code = Latex.linespread(ransom_spacing,Latex.footnotesize(gloss_code))
  return [main_code,gloss_code,'foreignverse']
end

def postprocess_foreign_or_ransom(which,bilingual,main_code,environment,start_chapter,gloss_code:nil)
  # which is 'foreign' or 'ransom'
  # gloss_code can be omitted or garbage if which is 'foreign'
  # start_chapter should be nil if this isn't the start of a chapter
  main_code = add_chapter_header(main_code,start_chapter)
  if which=='ransom' then main_code = Latex.envir('graytext',main_code)+gloss_code end
  code = Latex.envir(environment,main_code)
  if bilingual.foreign.genos.greek then code = Latex.envir('greek',code) end
  code = standardize_greek_punctuation(code)
  return code
end

def render_gloss_for_foreign_page(line_hash,word,key,gloss,bilingual)
  # Word is the inflected string. Key is the database key, i.e., the lemma with no accents. Gloss is a string.
  # Returns [code,new_gloss_code], where code writes the original word in white ink, i.e., erases it, and
  # new_gloss_code is the latex code to put the gloss in black, positioned on top of that.
  # Another (desired) effect of this is to prevent hyphenation, since the word is typeset inside an \mbox.
  pos = WhereAt.get_pos_data(line_hash,key) # returns pos = a hash whose keys are "x","y","width","height","depth"
  if pos.nil? then raise "in foreign_helper, rendering ransom notes, position is nil for line_hash=#{line_hash}, key=#{key}" end
  pos = RansomGloss.tweak_gloss_geom_kludge_fixme(pos)
  a = RansomGloss.text_in_box(gloss,pos['width'],bilingual.translation.genos)
  new_gloss_code = RansomGloss.text_at_position(a,pos)
  code = %q{\begin{whitetext}\mbox{WORD}\end{whitetext}}
  code.gsub!(/WORD/,word)
  return [code,new_gloss_code]
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

def add_chapter_header(main_code,start_chapter)
  if !(start_chapter.nil?) then
    return "\\mychapter{#{start_chapter}}\n\n"+main_code # will be gray if on ransom page, because inside graytext environment
  else
    return main_code
  end
end

def to_key(word)
  return remove_accents(word).downcase
end

def merge_word_lists(a,b)
  # Inputs: a is a list like ["Hello","how","are","you"], b is a list like [["Hello,",hash1],["how",hash2],["are",hash3],["you?",hash4]],
  # where the main difference between the results of the two splitting algorithms is expected to be that in b, words include trailing punctuation.
  # Returns [["Hello","Hello,",hash1],...].
  j = 0 # index into words(text)
  k = 0 # index into hashes
  match_up = []
  while j<=a.length-1 && k<=b.length-1 do
    # The two word-splitting algorithms differ a little, so if they get out of step, try to get them back in step.
    # I think the algorithms can disagree on, e.g., "don't" or on a dash with whitespace before and after it, but the following
    # should suffice for those cases because it's only a glitch that mismatches the two counters by one step.
    j+= 1 if !(word_match(a[j],b[k][0])) && j<=a.length-2 && word_match(a[j+1],b[k][0])
    k+= 1 if !(word_match(a[j],b[k][0])) && k<=b.length-2 && word_match(a[j],b[k+1][0])
    if word_match(a[j],b[k][0]) then
      match_up.push([a[j],b[k][0],b[k][1]]) 
    else
      raise("can't reconcile word lists, oh shit, j=#{j}, k=#{k}, #{a[j]}, #{b[k]}\n#{b}\n#{a}")
    end
    j += 1
    k += 1
  end
  return match_up
end

def word_match(x,y)
  return (remove_punctuation(x).downcase==remove_punctuation(y).downcase)
end

class Patch_names
  @@patches = {"Latona"=>"Leto","Ulysses"=>"Odysseus","Jove"=>"Zeus","Atrides"=>"Atreides","Minerva"=>"Athena","Juno"=>"Hera","Saturn"=>"Cronus",
                "Vulcan"=>"Hephaestus","Venus"=>"Aphrodite"}
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

class Init
  # Code that gets run when the eruby script starts, but after code that's higher up in the file.
  require 'fileutils'
  require 'digest'
  if Options.if_clean then FileUtils.rm_f(WhereAt.file_path) end # Currently I open the file to write, not append, so this isn't necessary.
  if Options.if_write_pos then print WhereAt.latex_code_to_create_pos_file() end
  if Options.if_render_glosses then WhereAt.read_back_pos_file()  end
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

