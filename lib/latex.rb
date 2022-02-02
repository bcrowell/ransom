class Latex
  def Latex.envir(environment,contents)
    return "\\begin{#{environment}}\n" + contents + "\\end{#{environment}}\n"
  end
  def Latex.footnotesize(contents)
    return "{\\footnotesize " + contents + "}\n"
  end
  def Latex.linespread(x,contents)
    # x=1.0 for single spacing
    return "\n{\\linespread{#{x}} " + contents + "}\n"
  end
end

class RansomGloss
  # A utility class to generate latex code that places glosses superimposed on a ransom-note page.
  def RansomGloss.tweak_gloss_geom_kludge_fixme(pos)
    # The argument pos is a hash with keys "x","y","width","height","depth", as obtained from WhereAt.get_pos_data, all in units of pts.
    # Returns a tweaked version of the hash in which the width may be increased if it seems like there's space.
    # This implementation is a total kludge, with hardcoded numbers, and needs to be fixed.
    x,y,width,height = pos['x'],pos['y'],pos['width'],pos['height'] # all floats in units of pts
    if x>254.0 then
      width=355.0-x
    else
      if x>235.0 && width<42.0 then width=42.0 end # less aggressive, for cases where the width is super narrow, and we're fairly far to the right
    end
    # ... Likely to be the last glossed word on line, so extend its width.
    #     Kludge, fixme: hardcoded numbers, guessing whether last glossed word on line.
    pos2 = clown(pos)
    pos2['width'] = width
    return pos2
  end
  def RansomGloss.text_in_box(text,width,genos)
    # The argument width should be in units of points. We temporarily switch to black rather than gray text, using the graytext environment.
    # Genos should be the language that we're switching into temporarily for the gloss.
    # It may happen that the foreign language text is in one script, say Greek, while the gloss is in another, say 
    # Latin. We use the genos argument to surround the text with, e.g., \begin{latin}...\end{latin}.
    # Whatever string is returned by genos.script has to be the name of an appropriate latex environment.
    text_with_script_change = "\\begin{#{genos.script}}#{text}\\end{#{genos.script}}"
    code =                 %q(\parbox[b]{WIDTH}{CONTENTS})  # https://en.wikibooks.org/wiki/LaTeX/Boxes
    code.sub!(/WIDTH/,     "#{width}pt"  )
    code.sub!(/CONTENTS/,  %q(\begin{blacktext}__\end{blacktext})  )
    code.sub!(/__/,        text_with_script_change  )
    return code
  end
  def RansomGloss.text_at_position(text,pos)
    # The argument text should be some latex code that typesets some text in a box with the given width and height.
    # The hash pos should have keys x, y, width, and height, and values should all be in pts.
    # This function surrounds that with additional latex code that positions it at the given location.
    x,y,width,height = pos['x'],pos['y'],pos['width'],pos['height']
    code = %q(\begin{textblock*}{_WIDTH_pt}(_XPOS_,_YPOS_)_GLOSS_\end{textblock*}) + "\n"
    code.sub!(/_WIDTH_/,"#{width}")
    code.sub!(/_XPOS_/,"#{x}pt")
    code.sub!(/_YPOS_/,"\\pdfpageheight-#{y}pt-#{0.7*height}pt")
    # ... Uses calc package; textpos's coordinate system goes from top down, pdfsavepos from bottom up.
    #     The final term scoots up the gloss so that its top is almost as high as the top of the Greek text.
    code.sub!(/_GLOSS_/,text)
    return code
  end
end # class RansomGloss

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
  def WhereAt.reinitialize_auto_hash()
    @@auto_hash = ''
  end
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
      # some of the following code is duplicated in scrape_prose_layout.rb
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
  end  
  def WhereAt.adorn_string_with_commands_to_write_pos_data(text,paragraph_count:nil,file_count:nil,starting_offset:0)
    adorned = text.dup
    k = 0
    if !text.kind_of?(String) then raise "text=#{text} is not a string" end
    text =~ /^(\s*)/ # match leading whitespace; match is guaranteed to succeed, but may be a null string
    offset = $1.length # a pointer into the file; initialize it to point past any initial whitespace
    substitutions = []
    a = split_string_at_whitespace(text) # Returns an array like [['The',' '],['quick',' '],...]. Every element is guaranteed to be a two-element list.
    a.each { |x|
      word,whitespace = x
      l = word.length+whitespace.length
      d = {'offset':offset+starting_offset,'length':l}
      if !paragraph_count.nil? then d['para']=paragraph_count end
      if !file_count.nil? then d['file']=file_count end
      code = WhereAt.latex_code_to_print_and_write_pos(word,nil,nil,extra_data:d)
      offset += l
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
  def WhereAt.latex_code_to_print_and_write_pos(word,lemma_key,line_hash,line_number:nil,extra_data:{})
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
    # This also has the effect of typesetting the word in a box, which prevents hyphenation.
    # Inputs:
    #   word = the word that is actually going to be typeset on the page
    #   lemma_key = a convenient key, which for verse is normally the lemma for the word, stripped of accents
    #   line_hash = output of function hash above; can be nil, which then causes us to use auto_hash mechanism
    #   line_number = if known, the line number
    # We obtain the (page,x,y) and (w,h,d) information at different points, and therefore we have two separate lines, each of them
    # containing one part of the information.
    # Re the need for \immediate in the following, see https://tex.stackexchange.com/q/604110/6853
    if lemma_key.nil? then lemma_key=word end
    if line_hash.nil? then line_hash=WhereAt.auto_hash(word) end
    code = %q(\savebox{\myboxregister}{WORD}%
      \makebox{\pdfsavepos\usebox{\myboxregister}}%
      \immediate\write\posoutputfile{LINE_HASH;;LINE;KEY;;;\the\wd\myboxregister;\the\ht\myboxregister;\the\dp\myboxregister;EXTRA1;}%
      \write\posoutputfile{LINE_HASH;\thepage;LINE;KEY;\the\pdflastxpos;\the\pdflastypos;;;;;EXTRA2}
    )
    code.gsub!(/LINE_HASH/,line_hash)
    code.gsub!(/WORD/,word)
    code.gsub!(/LINE/,line_number.to_s)
    code.gsub!(/KEY/,lemma_key.gsub(/;/,'__SEMICOLON__'))
    code.gsub!(/EXTRA1/,JSON.generate(extra_data))
    code.gsub!(/EXTRA2/,"{}")
    return code
  end
end # class WhereAt
