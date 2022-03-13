# examples of how people do this:
#   https://biblehub.com/interlinear/genesis/1.htm
#   https://www.eva.mpg.de/lingua/resources/glossing-rules.php

class LineRange
  def initialize(s,max_book_sanity:24)
    # s is a string such as "iliad 1.37-39"
    text,num = s.downcase.split(/\s+/)
    num=~/(\d+)\.(.*)/
    book = $1.to_i
    line_range = $2
    if line_range=~/(\d+)\-(\d+)/ then
      line1,line2 = [$1.to_i,$2.to_i]
    else
      line1 = line_range.to_i
      line2 = line1
    end
    raise "illegal book number: #{book}" unless book>=1 && book<=max_book_sanity
    raise "line numbers fail sanity check: #{line1} #{line2}" unless line1>=1 && line2>=line1
    @text,@book,@line1,@line2 = text,book,line1,line2
  end

  attr_accessor :text,:book,:line1,:line2

  def to_a
    return [@text,@book,@line1,@line2]
  end

  def to_s
    if @line1==@line2 then x=@line1.to_s else x="#{@line1}-#{@line2}" end
    return "#{@text.sub(/^(.)/) {$1.upcase}} #{@book}.#{x}"
  end
end

class InterlinearStyle

  @@pt_per_mm = 2.8346456692913 # conversion factor

  def initialize(layout:'wgp',format:'txt',left_margin:[0,''],paper_width:7.0,point_size:11.0)
    # Layout gives the order of the items, as defined in Word.to_h:
    #   'w'=>self.word,'r'=>self.romanization,'g'=>self.gloss,'p'=>self.pos.to_s,'l'=>self.lemma
    # Paper width is in inches.
    @layout = layout
    @format = format
    @left_margin = left_margin
    @point_size = point_size
    @column_sep = 3 # horizontal separation between columns, in pt (LaTeX tabcolsep)
    # style and estimation for proportional fonts:
    @prop_p = 1.8*(point_size/12.0)  # average width of a character, in millimeters; (meas of default Latin font in ransom.cls gives more like 1.9 mm)
    @greek_font_name = "GFS Porson"
    @latin_font_name = "GFS Didot"
    @prop_gloss_size = 'footnotesize' # also tried small
    @prop_foreign_size = 'normalsize'
    @prop_gloss_q = 0.55 # if font size is small, should be more like 0.6; used for estimating size of glosses in col_width_helper_proportional
    in_to_mm = 25.4 # convert inches to millimeters
    total_page_margin = 54.4 # set sort of empirically by looking at output; changing this usually makes zero change in output
    @prop_max_total_width = paper_width*in_to_mm-total_page_margin # millimeters
    @prop_space_between_groups = 2.5 # millimeters; when we have interlinears stacked one above the other, this is the extra whitespace in between
  end

  attr_accessor :layout,:format,:left_margin,:prop_gloss_size,:prop_gloss_q,:prop_p,:prop_max_total_width,:prop_space_between_groups,
            :point_size,:latin_font_name,:column_sep,:greek_font_name,:prop_foreign_size

  def to_s
    return "layout=#{self.layout}, format=#{self.format}"
  end

  def InterlinearStyle.pt_to_mm(p)
    return p/@@pt_per_mm
  end

end

class Interlinear

def Interlinear.assemble_lines_from_treebank(foreign_genos,db,treebank,epos,linerange,style:InterlinearStyle.new())
  # linerange can be either a LineRange object or a string used to construct one
  if linerange.kind_of?(String) then linerange_cooked=LineRange.new(linerange) else linerange_cooked=linerange end
  text,book,line1,line2 = linerange_cooked.to_a
  all_lines = []
  raise "wrong types" unless linerange.kind_of?(LineRange) && epos.kind_of?(Epos)
  line1.upto(line2) { |line|
    style_this_line = clown(style)
    if style_this_line.format=='bbcode' then style_this_line.format='txt' end
    style_this_line.left_margin[1].gsub!(/__LINE__/,line.to_s)
    words = treebank.get_line(foreign_genos,db,text,book,line,interlinear:true)
    r1 = epos.line_to_hard_ref(linerange.book,line)
    r2 = epos.line_to_hard_ref(linerange.book,line+1)
    punctuated = epos.extract(r1,r2) # includes punctuation, may also be a different edition with different words
    all_lines.push(Interlinear.assemble_one_line(foreign_genos,words,punctuated,style:style_this_line))
  }
  if style.format=='tex' then
    result = all_lines.join("\n\n\\vspace{#{style.prop_space_between_groups}mm}\n\n") # FIXME -- formatting shouldn't be hardcoded here
  end
  if style.format=='txt' || style.format=='bbcode' then
    result = all_lines.join("\n\n")
  end
  return result
end

def Interlinear.assemble_one_line(foreign_genos,words,text,style:InterlinearStyle.new())
  # To generate output, use scripts/do_interlinear.rb
  # Words is a list of Word objects representing one line of text.
  # Format can be 'txt', 'tex', or 'html'.
  # For latex output, this currently assumes that small caps are to be accomplished using {\scriptsize ...},
  # and that there is an environment called greek that can be used to surround Greek characters.
  # Also, the foreign-language texs is formatted as {\large ...}.
  # All of this should be flexible, not hardcoded.
  layout = style.layout
  format = style.format
  left_margin = style.left_margin
  n_rows = layout.length
  words = Interlinear.reconcile_treebank_with_text_helper(words,text)
  n_cols = words.length
  table = words.map { |word| word.to_a(format:layout,nil_to_null_string:true) }
  if format=='txt' then # also covers bbcode
    col_width = Interlinear.col_width_helper_monospaced(table,n_rows,n_cols,layout)
    lines = []
    0.upto(n_rows-1) { |row|
      elements = []
      0.upto(n_cols-1) { |col|
        e = table[col][row]
        if layout[row]=~/[p]/ then is_pos=true else is_pos=false end
        if is_pos then narrower,e=Interlinear.chop_up_pos_helper(e,format,col_width[col]) end        
        elements.push(sprintf("%-#{col_width[col]}s",e))
      }
      if row==0 then m=left_margin[1] else m='' end
      marg = sprintf("%-#{left_margin[0]}s",m)
      lines.push(marg+elements.join(' '))
    }
    return lines.map { |x| x+"\n" }.join('')
  end
  if format=='tex' then
    have_left_margin = (left_margin[0]>0)
    max_total_width = style.prop_max_total_width
    if have_left_margin then max_total_width -= style.prop_p*left_margin[0] end
    widths = Interlinear.col_width_helper_proportional(style,table,n_rows,n_cols,layout,max_total_width)
    width_string = widths.map { |x| "p{#{x.round(2)}mm}" }.join('')
    if have_left_margin then
      width_string='l'+width_string
    end
    width_string = "@{}#{width_string}@{}" # the @{} removes extra whitespace at sides
    result = ''
    result += "\\noindent{\\setlength{\\tabcolsep}{#{style.column_sep}pt}\\begin{tabular}{#{width_string}}\n"
    lines = []
    0.upto(n_rows-1) { |row|
      elements = []
      if have_left_margin then
        if row==0 then m=left_margin[1] else m='' end
        elements.push(m)
      end
      0.upto(n_cols-1) { |col|
        e = table[col][row]
        if layout[row]=~/[wl]/ then is_foreign=true else is_foreign=false end
        if layout[row]=~/[p]/ then is_pos=true else is_pos=false end
        if layout[row]=~/[g]/ then is_gloss=true else is_gloss=false end
        if is_pos then
          narrower,e = Interlinear.chop_up_pos_helper(e,format,widths[col])
          e = e.gsub(/([A-Z]+)/) {"{\\scriptsize #{$1}}"}
        end
        if is_gloss then e = "{\\#{style.prop_gloss_size} #{e}}" end
        if foreign_genos.greek && is_foreign then e="\\begin{greek}\\large #{e}\\end{greek}" end
        elements.push(e)
      }
      lines.push(elements.join(' & '))
    }
    result += lines.join("\\\\\n")+"\n"
    result += %q(\end{tabular}})+"\n" # second } closes off the group inside of which we set tabcolsep
    result = "{\\renewcommand{\\arraystretch}{1.1}\\setstretch{0.7}\n#{result}\\par}"
    # Setstretch is from package setspace; \par is necessary; https://tex.stackexchange.com/questions/83855/change-line-spacing-inside-the-document
    # The arraystretch is to add more space between rows, compensating for the setstretch.
    # Both of these effects are localized to the group formed by the outer {}.
    return result
  end
  raise "format #{format} not implemented"
end

def Interlinear.chop_up_pos_helper(pos,format,width,p:2.0)
  # reduce the width of very long POS tags like pl.FUT.PTCP.MID.n.ACC (Iliad 1.70)
  if format=='tex' then
    chars_width=width/p # the input called width is in mm and is based on all the other rows
    l = pos.split(/\./)
    n = l.length
    return [pos.length,pos] if pos.length<=chars_width || n<2
    a = l[0..(n/2-1)]
    b = l[(n/2)..n]
    narrower = [a.length,b.length+1].max
    return [narrower,a.join('.')+' .'+b.join('.')]
  else
    return [pos.length,pos] if pos.length<=width
    target_width = [[width,15].max,pos.length].min
    return [target_width,pos[0..target_width-4]+"..."]
  end
end

def Interlinear.col_width_helper_proportional(style,table,n_rows,n_cols,layout,max_total_width,max_gloss_lines:3)
  if layout=~/p/ then layout=layout.sub(/p/,'')+'p' end # do POS last
  widths = nil
  1.upto(max_gloss_lines) { |n|
    # $stderr.print "n=#{n}, first word=#{table[0][0]}\n"
    widths = []
    0.upto(n_cols-1) { |col|
      cell_widths = []
      p = style.prop_p # average width of a character, in millimeters
      0.upto(n_rows-1) { |row|
        what = layout[row]
        q = 1.0 # unitless coefficient that basically represents the font size, compared to the main font
        if what=='g' then q=style.prop_gloss_q end
        e = table[col][row]
        n_chars = e.length
        if what=='p' then # guaranteed to be the last
          width_so_far = p*cell_widths.max # formula duplicated below; preliminary estimate based on all cols so far
          n_chars,e=Interlinear.chop_up_pos_helper(e,'tex',width_so_far,p:p) 
        end      
        cell_width = p*q*n_chars # default is crude character counting
        if what=='g' then
          cell_width = Typesetting.width_to_fit_para_in_n_lines(e,n,
                          style.point_size,"\\setmainfont{#{style.latin_font_name}}","\\#{style.prop_gloss_size}{}")
        end
        if what=='w' then
          # FIXME: assumes foreign is greek
          cell_width = Typesetting.width_to_fit_para_in_n_lines(e,1,
                          style.point_size,"\\setmainfont{#{style.greek_font_name}}","\\#{style.prop_foreign_size}{}")
        end
        cell_widths.push(cell_width+1.5)
        # ... the 1.5 mm is because otherwise it seems to refuse to squeeze it in in some cases; the symptom is then that I get a two-line
        #     gloss where there could have been a one-line gloss, and there's lots of extra, mysterious whitespace; a good test case is Iliad 1.4
      }
      widths.push(cell_widths.max) # width of this column, in mm, if we use n lines of text for the glosses
    }
    total_width = widths.sum+InterlinearStyle.pt_to_mm(style.column_sep)*(n_cols-1)
    break if total_width<=max_total_width
  }
  # $stderr.print "widths=#{widths}\n---------------------------------------------\n"
  return widths
end

def Interlinear.col_width_helper_monospaced(table,n_rows,n_cols,layout)
  if layout=~/p/ then layout=layout.sub(/p/,'')+'p' end # do POS last
  col_width = []
  0.upto(n_cols-1) { |col|
    col_width.push(0)
  }
  0.upto(n_cols-1) { |col|
    0.upto(n_rows-1) { |row|
      what = layout[row]
      width_so_far = col_width[col]
      e=table[col][row]
      n_chars = e.length
      if what=='p' then n_chars,e=Interlinear.chop_up_pos_helper(e,'txt',width_so_far) end # guaranteed to be the last
      col_width[col] = [width_so_far,n_chars].max
    }
  }
  return col_width
end

def Interlinear.reconcile_treebank_with_text_helper(words,text)
  # Decorate words with punctuation from the text.
  # Is meant to work on one line of text at a time.
  # FIXME: won't work if the same word occurs twice on the same line, but with different punctuation
  words = clown(words)
  text = standardize_greek_punctuation(text)
  0.upto(words.length-1) { |i|
    bare = standardize_greek_punctuation(words[i].word)
    if text=~/([[:punct:]]*#{bare}[[:punct:]]*)/i then
      decorated = $1
    else
      decorated = bare
    end
    words[i].punctuated = decorated
  }
  return words
end

end
