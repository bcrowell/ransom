require 'json'
require 'sdbm'
require 'set'
require_relative "lib/file_util"
require_relative "lib/string_util"
require_relative "lib/multistring"
require_relative "lib/treebank"
require_relative "lib/epos"
require_relative "lib/genos"
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

class Bilingual
  def initialize(g1,g2,t1,t2,foreign,translation,max_chars:5000,length_ratio_expected:1.23,length_ratio_tol_factor:1.38)
    # Foreign and translation are Epos objects, which should have non-nil genos with is_verse set correctly.
    # G1, g2, t1, and t2 are references for input to Epos initializer. If a text is verse, then these should be
    # of the form [book,line]. If prose, then they should be word globs.
    # sanity checks:
    #   max_chars -- maximum length of translated text
    #   length_ratio_expected -- expected value of length of translation divided by length of foreign text
    #   length_ratio_tol_factor -- tolerance factor for the above ratio
    Bilingual.type_check_refs_helper(g1,g2,t1,t2,foreign,translation)
    @foreign = foreign
    @translation = translation
    if foreign.genos.is_verse then
      @foreign_linerefs = [g1,g2]
      @foreign_chapter_number = g1[0]
      @foreign_first_line_number = g1[1]
      @foreign_hr1,@foreign_hr2 = foreign.line_to_hard_ref(g1[0],g1[1]),foreign.line_to_hard_ref(g2[0],g2[1])
      @foreign_ch1,@foreign_ch2 = @foreign_hr1[0],@foreign_hr2[0]
    else
      $stderr.print "g1 -> #{foreign.word_glob_to_hard_ref(g1)}\n"
      @foreign_hr1,@foreign_hr2 = foreign.word_glob_to_hard_ref(g1)[0],foreign.word_glob_to_hard_ref(g2)[0]
    end
    @foreign_text = foreign.extract(@foreign_hr1,@foreign_hr2)
    # Let word globs contain, e.g., Hera rather than Juno:
    t1 = Patch_names.antipatch(t1)
    t2 = Patch_names.antipatch(t2)
    translation_hr1_with_errs = translation.word_glob_to_hard_ref(t1)
    translation_hr2_with_errs = translation.word_glob_to_hard_ref(t2)
    translation_hr1,translation_hr2 = translation_hr1_with_errs[0],translation_hr2_with_errs[0]
    if translation_hr1_with_errs[1] then raise "ambiguous word glob: #{t1}, #{translation_hr1_with_errs[2]}" end
    if translation_hr2_with_errs[1] then raise "ambiguous word glob: #{t2}, #{translation_hr2_with_errs[2]}"end
    if translation_hr1.nil? then raise "bad word glob, #{t1}" end
    if translation_hr2.nil? then raise "bad word glob, #{t2}" end
    @translation_text = translation.extract(translation_hr1,translation_hr2)
    @translation_text = Patch_names.patch(@translation_text) # change, e.g., Juno to Hera

    # A hash that is intended to be unique to this particular spread. For example, Homer sometimes repeats entire passages,
    # but this hash should still be different for the different passages. This is needed by foreign_verse in eruby_ransom.rb.
    @hash = Digest::MD5.hexdigest([translation_hr1,translation_hr2,@foreign_hr1,@foreign_hr2].to_s)

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
  def Bilingual.type_check_refs_helper(foreign1,foreign2,t1,t2,foreign,translation)
    Bilingual.type_check_refs_helper2(foreign1,foreign2,foreign)
    Bilingual.type_check_refs_helper2(t1,t2,translation)
  end
  def Bilingual.type_check_refs_helper2(ref1,ref2,epos)
    if epos.is_verse && !(ref1.kind_of?(Array) && ref2.kind_of?(Array)) then raise "epos says verse, but refs are not arrays" end
    if !epos.is_verse && !(ref1.kind_of?(String) && ref2.kind_of?(String)) then raise "epos says prose, but refs are not strings" end
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
  attr_reader :foreign_hr1,:foreign_hr2,:foreign_ch1,:foreign_ch2,:foreign_text,:translation_text,:foreign_first_line_number,:foreign_chapter_number,
          :foreign_linerefs,:foreign,:translation,:hash
end

if Options.if_render_glosses then require_relative "lib/wiktionary" end # slow, don't load if not necessary

class Illustrations
  @@illus = []
  @@label_to_line = {}
  @@options = {}
  def Illustrations.init # call this after setting fig_dir in Options
    d = Options.get('fig_dir')
    Dir.each_child(d) { |filename|
      base = File.basename(filename)
      if base=~/(\d+)-(\d+)-([^.]+).*\.jpg/ then # naming convention I'm using for Iliad, e.g., 01-029-will-not-release-her.jpg
        book,line,label = $1.to_i,$2.to_i,$3
        path = "#{d}/#{filename}"
        width,height = `identify -format '%W' #{path}`,`identify -format '%H' #{path}`
        @@illus.push([book,line,path,width,height,label])
        @@label_to_line[label] = [book,line]
      end
    }
    @@credits_data = json_from_file_or_die("#{d}/credits.json")
    @@options = json_from_file_or_die("#{d}/options.json")
  end
  def Illustrations.is_landscape(label)
    if @@options.has_key?(label) && @@options[label].has_key?('portrait') && @@options[label]['portrait'] then return false end
    return true
  end
  def Illustrations.hand_written_caption(label)
    if @@options.has_key?(label) && @@options[label].has_key?('caption') then return @@options[label]['caption'] end
    return nil
  end
  def Illustrations.reduced_width(label)
    if @@options.has_key?(label) && @@options[label].has_key?('width') then return @@options[label]['width'] end
    return nil
  end
  def Illustrations.list_of
    return @@illus
  end
  def Illustrations.credits
    result = []
    @@credits_data.keys.sort.each { |artist|
      list = []
      @@credits_data[artist].each { |label|
        book,line = @@label_to_line[label]
        list.push("#{book}.#{line}")
      }
      result.push(list.join(", ") + ": " + artist)
    }
    return result.join(". ")+"."
  end
end

class WhereAt
  # A utility class for a database of locations on the pages where words in the "ransom note" occur.
  def WhereAt.file_path
    return Options.pos_file
  end
  # Hashes:
  # Because of the design of latex, it's not possible to determine both the position on the page and the size of the word on the
  # page at the same time. Therefore we write two separate lines to the .pos or .prose file containing these different types of data,
  # and later on we need to match up these lines. What I've been doing in verse mode is to construct a hash based on data like the 
  # line number, the text of the line, and the word itself. This doesn't work well when we are starting with prose that hasn't yet
  # been broken up into lines, and this is the purpose of the @@auto_hash, which is based on a running hash of every word that
  # we've looked at so far.
  #
  @@auto_hash = ''
  def WhereAt.hash(hashable)
    # input = data that, if possible, are totally unique to this line on the page, even if a line of poetry is repeated
    # I've tried doing this with a flat array whose elements are strings and integers, and it works fine.
    return Digest::MD5.hexdigest(hashable.to_s) 
  end
  def WhereAt.auto_hash(hashable)
    # Hashable should be something that has a .to_s method and the kind of thing that could be fed to WhereAt.hash().
    @@auto_hash = WhereAt.hash(@@auto_hash+hashable.to_s)
    return @@auto_hash
  end
  def WhereAt.latex_code_to_create_pos_file()
    return %Q{
      \\newsavebox\\myboxregister
      \\newwrite\\posoutputfile
      \\immediate\\openout\\posoutputfile=#{WhereAt.file_path}
    }
  end
  def WhereAt.latex_code_to_close_pos_file()
    return %q{
      \closeout\posoutputfile
    }
  end
  def WhereAt.get_pos_data(line_hash,word_key)
    # returns a hash whose keys are "x","y","width","height","depth", all in units of pts
    return @@pos[[line_hash,word_key].join(",")]
  end
  def WhereAt.read_back_pos_file()
    @@pos = {} # will be a hash of hashes, @@pos[gloss_key][name_of_datum]
    IO.foreach(WhereAt.file_path) { |line|
      next if line=~/^\?/
      line.sub!(/\s+$/,'') # trim trailing whitespace, such as a newline
      a = line.split(/;/,-1)
      line_hash,page,line,word_key,x,y,width,height,depth = a
      word_key.gsub!(/__SEMICOLON__/,';')
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
    return @@pos
  end  
  def WhereAt.adorn_string_with_commands_to_write_pos_data(text)
    adorned = text.dup
    k = 0
    substitutions = []
    text.split(/\s+/) { |word|
      code = WhereAt.latex_code_to_print_and_write_line(word,nil,nil)
      code.sub!(/%\s+$/,'') # remove final %
      adorned.sub!(/#{Regexp::quote(word)}/) {"__GLUBBA__#{k}__"}
      substitutions.push(code)
      k += 1
    }
    k = 0
    text.split(/\s+/) { |word|
      adorned.sub!(/__GLUBBA__#{k}__/,substitutions[k])
      k += 1
    }
    return adorned
  end
  def WhereAt.latex_code_to_print_and_write_line(word,lemma_key,line_hash,line_number:nil)
    # We write a separate text file such as iliad.pos, which records the position of each word on the ransom-note page.
    # This allows us, on a later pass, to place the glosses at the correct positions.
    # The code returned by this function includes the code that actually prints the word on the page.
    # format of .pos file:
    #     unique hash                     ;page;line;lemma;x;y;width;height;depth;extra1;extra2
    #     9d8e0859efef6dc6d2d23419e0de8e7a;7;0;μηνις;;;31.32986pt;8.7386pt;2.80527pt;;
    #     9d8e0859efef6dc6d2d23419e0de8e7a;7;0;μηνις;3789043;36515889;;;;;
    #     Lines starting with ? are ignored.
    #     Here line is a 0-based count from the top of the page, if the text is in verse.
    #     If the lemma string contains a semicolon, that will be replaced with __SEMICOLON__.
    #     The extra1 and extra2 strings are JSON hashes designed to make it convenient to add enhancements to this system.
    #     Extra1 is written using \immediate\write, extra2 using \write. Even if they have some of the same latex source code,
    #     what gets written to the .pos file can be different because it depends on whether we use \immediate.
    # Inputs:
    #   word = the word that is actually going to be typeset on the page
    #   lemma_key = a convenient key, which for verse is normally the lemma for the word, stripped of accents
    #   line_hash = output of function hash above; can be nil, which then causes us to use auto_hash mechanism
    #   line_number = if known, the line number
    # We obtain the (x,y) and (w,h,d) information at different points, and therefore we have two separate lines, each of them
    # containing one part of the information.
    # Re the need for \immediate in the following, see https://tex.stackexchange.com/q/604110/6853
    if lemma_key.nil? then lemma_key=word end
    if line_hash.nil? then line_hash=WhereAt.auto_hash(word) end
    code = %q(\savebox{\myboxregister}{WORD}%
      \makebox{\pdfsavepos\usebox{\myboxregister}}%
      \immediate\write\posoutputfile{LINE_HASH;\thepage;LINE;KEY;;;\the\wd\myboxregister;\the\ht\myboxregister;\the\dp\myboxregister;EXTRA;}%
      \write\posoutputfile{LINE_HASH;\thepage;LINE;KEY;\the\pdflastxpos;\the\pdflastypos;;;;EXTRA}%
    )
    extra_data = %q({}) # json hash
    code.gsub!(/LINE_HASH/,line_hash)
    code.gsub!(/WORD/,word)
    code.gsub!(/LINE/,line_number.to_s)
    code.gsub!(/KEY/,lemma_key.gsub(/;/,'__SEMICOLON__'))
    code.gsub!(/EXTRA/,extra_data)
    return code
  end
end

def four_page_layout(stuff,genos,db,layout,next_layout,vocab_by_chapter,start_chapter:nil,dry_run:false)
  # doesn't get called if if_prose_trial_run is set
  treebank,freq_file,greek,translation,notes,core = stuff
  return if dry_run
  print_four_page_layout(stuff,genos,db,layout,next_layout,vocab_by_chapter,start_chapter)
end

def print_four_page_layout(stuff,genos,db,bilingual,next_layout,vocab_by_chapter,start_chapter)  
  # vocab_by_chapter is a running list of all lexical forms, gets modified; is an array indexed on chapter, each element is a list
  # doesn't get called if if_prose_trial_run is set
  treebank,freq_file,greek,translation,notes,core = stuff
  ch = bilingual.foreign_ch1
  core,vl,vocab_by_chapter = four_page_layout_vocab_helper(bilingual,genos,db,core,treebank,freq_file,notes,vocab_by_chapter,start_chapter,ch)
  if bilingual.foreign_ch1!=bilingual.foreign_ch2 then
    # This should only happen in the case where reference 2 is to the very first line of the next book.
    if !(bilingual.foreign_hr2[1]<=5 && bilingual.foreign_hr2[0]==bilingual.foreign_hr1[0]+1) then
      raise "four-page layout spans books, #{bilingual.foreign_hr1} - #{bilingual.foreign_hr2}"
    end
  end
  print_four_page_layout_latex_helper(db,bilingual,next_layout,vl,core,start_chapter,notes)
end

def four_page_layout_vocab_helper(bilingual,genos,db,core,treebank,freq_file,notes,vocab_by_chapter,start_chapter,ch)
  # doesn't get called if if_prose_trial_run is set
  core = core.map { |x| remove_accents(x).downcase }
  vl = Vlist.from_text(bilingual.foreign_text,treebank,freq_file,genos,db,core:core, \
               exclude_glosses:list_exclude_glosses(bilingual.foreign_hr1,bilingual.foreign_hr2,notes))
  if !ch.nil? then
    if !(start_chapter.nil?) then vocab_by_chapter[ch] = [] end
    if vocab_by_chapter[ch].nil? then vocab_by_chapter[ch]=[] end
    vocab_by_chapter[ch] = alpha_sort((vocab_by_chapter[ch]+vl.all_lexicals).uniq)
  else
    vocab_by_chapter = []
  end
  return core,vl,vocab_by_chapter
end

def print_four_page_layout_latex_helper(db,bilingual,next_layout,vl,core,start_chapter,notes)
  # prints
  # Doesn't get called if Options.if_prose_trial_run is set
  stuff = vocab(db,vl,core)
  tex,v = stuff['tex'],stuff['file_lists']
  print tex
  if notes.length>0 then print notes_to_latex(bilingual.foreign_linerefs,notes) end # FIXME: won't work if foreign text is prose, doesn't have linerefs
  print header_latex(bilingual) # includes pagebreak
  if !(start_chapter.nil?) then print "\\mychapter{#{start_chapter}}\n\n" end
  print foreign(db,bilingual,bilingual.foreign_first_line_number),"\n\n"
  if !(start_chapter.nil?) then print "\\myransomchapter{#{start_chapter}}\n\n" end
  print "\\renewcommand{\\rightheaderwhat}{\\rightheaderwhatglosses}%\n"
  print ransom(db,bilingual,v,bilingual.foreign_first_line_number),"\n\n"
  if !(start_chapter.nil?) then print "\\mychapter{#{start_chapter}}\n\n" end
  print bilingual.translation_text
  # https://tex.stackexchange.com/a/308934
  layout_for_illustration = next_layout  # place illustration at bottom of page coming immediately before the *next* four-page layout
  if !layout_for_illustration.nil? then print do_illustration(layout_for_illustration) end
end

def do_illustration(layout)
  # input layout may be the *next* layout if we're putting each illustration at the end of the one before the layout it represents
  # FIXME -- This contains lots of hardcoded numbers, styling, and layout info that should be in the class file or somewhere else.
  # FIXME -- It would be better to do this by writing the actual available space to a file and then reading it in on the next pass. The
  #          method used here is only approximate.
  from,to = layout.foreign_linerefs
  result = ''
  count = 0
  Illustrations.list_of.each { |ill|
    book,line,filename,width,height,label = ill
    lineref = [book,line]
    if (from<=>lineref)<=0 && (lineref<=>to)<=0 then
      if count>=1 then
        $stderr.print "WARNING: layout for #{layout.foreign_linerefs} contained more than one illustration, only one was used\n"
        next
      end
      landscape = Illustrations.is_landscape(label)
      if landscape then
        w_in = 4.66 # FIXME -- hardcoded
        if !Illustrations.reduced_width(label).nil? then w_in=Illustrations.reduced_width(label) end
        pts_per_in = 72.0
        margin = 0.5 # need this much space in inches between translation and image
        height_needed = (w_in*(height.to_f/width.to_f)+margin)*pts_per_in
        width_latex_code = "#{w_in}in"
      else
        height_needed = 3.5 # inches
        width_latex_code = (height_needed*(width.to_f/height.to_f)).to_s+"in"
      end
      foreign = layout.foreign
      if Illustrations.hand_written_caption(label).nil? then
        caption = foreign.extract(foreign.line_to_hard_ref(lineref[0],lineref[1]),foreign.line_to_hard_ref(lineref[0],lineref[1]+1))
        caption = caption.gsub(/\n/,' ')
      else
        caption = Illustrations.hand_written_caption(label)
      end
      caption = "\n\n\\hfill{}\\linenumber{#{book}.#{line}}\\hspace{3mm} "+caption+"\n"
      info = "#{filename}, height_needed=#{height_needed} in"
      x = %q{
        \vfill
        % illustration and caption, __INFO__
        \edef\measurepage{\the\dimexpr\pagegoal-\pagetotal-\baselineskip\relax}
        \ifdim\measurepage > __MIN_HT__pt \hfill\includegraphics[width=__WIDTH__]{__FILE__}__CAPTION__ \else \fi \relax
      }
      result += x.gsub(/__FILE__/,filename).gsub(/__MIN_HT__/,height_needed.to_s).gsub(/__CAPTION__/,caption).gsub(/__INFO__/,info). \
            gsub(/__WIDTH__/,width_latex_code)
      count +=1
    end
  }
  return result
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

def vocab(db,vl,core)
  # Input is a Vlist object.
  # The three sections are interpreted as common, uncommon, and rare.
  # Returns {'tex'=>...,'file_lists'=>...}, containing latex code for vocab page and the three file lists for later reuse.
  if Options.if_render_glosses then $stderr.print vl.console_messages end
  tex = ''
  tex +=  "\\begin{vocabpage}\n"
  tex +=  vocab_helper(db,'uncommon',vl,0,2,core) # I used to have common (0) as one section and uncommon (1 and 2) as another. No longer separating them.
  tex +=  "\\end{vocabpage}\n"
  v = vl.list.map { |l| l.map{ |entry| entry[1] } }
  result = {'tex'=>tex,'file_lists'=>v}
end

def vocab_helper(db,commonness,vl,lo,hi,core)
  l = []
  lo.upto(hi) { |i|
    vl.list[i].each { |entry|
      word,lexical,data = entry
      if data.nil? then data={} end
      pos = data['pos']
      is_verb = (pos=~/^[vt]/)
      g = Gloss.get(db,lexical)
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
        if type=='gloss' then s=vocab1(db,entry) end
        if type=='conjugation' || type=='declension' then s=vocab_inflection(entry) end
        if !(s.nil?) then
          this_sec += clean_up_unicode("#{s}\n")
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


def foreign(db,bilingual,first_line_number)
  if bilingual.foreign.is_verse then
    return foreign_verse(db,bilingual,false,first_line_number,left_page_verse:true)
  else
    return foreign_prose(db,bilingual,false,first_line_number,left_page_verse:true)
  end
end

def ransom(db,bilingual,v,first_line_number)
  common,uncommon,rare = v
  if bilingual.foreign.is_verse then
    return foreign_verse(db,bilingual,true,first_line_number,gloss_these:rare)
  else
    return foreign_prose(db,bilingual,true,first_line_number,gloss_these:rare)
  end
  return x
end

def foreign_prose(db,bilingual,ransom,first_line_number,gloss_these:[],left_page_verse:false)
  return "dummy text from foreign-prose: #{[first_line_number]}"
end

def foreign_verse(db,bilingual,ransom,first_line_number,gloss_these:[],left_page_verse:false)
  # If gloss_these isn't empty, then we assume it contains a list of rare lemmatized forms.
  t = bilingual.foreign_text
  gloss_code = ''
  main_code = "\\begin{foreignpage}\n"
  if ransom then main_code = main_code + "\\begin{graytext}\n" end
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
          if Options.if_write_pos then code=WhereAt.latex_code_to_print_and_write_line(word,key,line_hash,line_number:i)  end
          if Options.if_render_glosses then
            pos = WhereAt.get_pos_data(line_hash,key) # a hash whose keys are "x","y","width","height","depth"
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

