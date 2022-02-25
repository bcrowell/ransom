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
    return "#{@text.sub(/^(.)/) {$1.upcase}} #{@book}.#{@line1}-#{@line2}"
  end
end

class InterlinearStyle

  def initialize(layout:'wgp',format:'txt',left_margin:[0,''])
    # Layout gives the order of the items, as defined in Word.to_h:
    #   'w'=>self.word,'r'=>self.romanization,'g'=>self.gloss,'p'=>self.pos.to_s,'l'=>self.lemma
    @layout = layout
    @format = format
    @left_margin = left_margin
    # style and estimation for proportional fonts:
    @prop_p = 1.8  # average width of a character, in millimeters; (meas of default Latin font in ransom.cls gives more like 1.9 mm)
    @prop_gloss_size = 'footnotesize' # also tried small
    @prop_gloss_q = 0.55 # if font size is small, should be more like 0.6; used for estimating size of glosses in col_width_helper_proportional
    @prop_max_total_width = 98.0 # millimeters; this value is about right for a 6"x9" book
    @prop_space_between_groups = 2.5 # millimeters; when we have interlinears stacked one above the other, this is the extra whitespace in between
  end

  attr_accessor :layout,:format,:left_margin,:prop_gloss_size,:prop_gloss_q,:prop_p,:prop_max_total_width,:prop_space_between_groups

end

class Interlinear

def Interlinear.assemble_lines_from_treebank(foreign_genos,db,treebank,linerange,style:InterlinearStyle.new())
  # linerange can be either a LineRange object or a string used to construct one
  if linerange.kind_of?(String) then linerange_cooked=LineRange.new(linerange) else linerange_cooked=linerange end
  text,book,line1,line2 = linerange_cooked.to_a
  all_lines = []
  line1.upto(line2) { |line|
    style_this_line = clown(style)
    style_this_line.left_margin[1].gsub!(/__LINE__/,line.to_s)
    words = treebank.get_line(foreign_genos,db,text,book,line,interlinear:true)
    all_lines.push(Interlinear.assemble_one_line(foreign_genos,words,style:style_this_line))
  }
  if style.format=='tex' then
    result = all_lines.join("\n\n\\vspace{#{style.prop_space_between_groups}mm}\n\n") # FIXME -- formatting shouldn't be hardcoded here
  end
  if style.format=='txt' then
    result = all_lines.join("\n\n")
  end
  return result
end

def Interlinear.assemble_one_line(foreign_genos,words,style:InterlinearStyle.new())
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
  n_cols = words.length
  table = words.map { |word| word.to_a(format:layout,nil_to_null_string:true) }
  if format=='txt' then
    col_width = Interlinear.col_width_helper_monospaced(table,n_rows,n_cols)
    lines = []
    0.upto(n_rows-1) { |row|
      elements = []
      0.upto(n_cols-1) { |col|
        elements.push(sprintf("%-#{col_width[col]}s",table[col][row]))
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
    result += "\\noindent\\begin{tabular}{#{width_string}}\n"
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
        if is_pos then e = e.gsub(/([A-Z]+)/) {"{\\scriptsize #{$1}}"} end
        if is_gloss then e = "{\\#{style.prop_gloss_size} #{e}}" end
        if foreign_genos.greek && is_foreign then e="\\begin{greek}\\large #{e}\\end{greek}" end
        elements.push(e)
      }
      lines.push(elements.join(' & '))
    }
    result += lines.join("\\\\\n")+"\n"
    result += %q(\end{tabular})+"\n"
    result = "{\\renewcommand{\\arraystretch}{1.1}\\setstretch{0.7}\n#{result}\\par}"
    # Setstretch is from package setspace; \par is necessary; https://tex.stackexchange.com/questions/83855/change-line-spacing-inside-the-document
    # The arraystretch is to add more space between rows, compensating for the setstretch.
    # Both of these effects are localized to the group formed by the outer {}.
    return result
  end
  raise "format #{format} not implemented"
end

def Interlinear.col_width_helper_proportional(style,table,n_rows,n_cols,layout,max_total_width,max_gloss_lines:3)
  widths = nil
  1.upto(max_gloss_lines) { |n|
    widths = []
    0.upto(n_cols-1) { |col|
      cell_widths = []
      p = style.prop_p # average width of a character, in millimeters
      0.upto(n_rows-1) { |row|
        what = layout[row]
        q = 1.0 # unitless coefficient that basically represents the font size, compared to the main font
        if what=='g' then q=style.prop_gloss_q end
        n_chars = table[col][row].length
        if what=='g' then b=n_chars.to_f/n else b=n_chars end
        cell_widths.push(q*b)
      }
      widths.push(p*cell_widths.max) # width of this column, in mm, if we use n lines of text for the glosses
    }
    total_width = widths.sum
    break if total_width<=max_total_width
  }
  return widths
end

def Interlinear.col_width_helper_monospaced(table,n_rows,n_cols)
  col_width = []
  0.upto(n_cols-1) { |col|
    col_width.push(0)
  }
  0.upto(n_cols-1) { |col|
    0.upto(n_rows-1) { |row|
      col_width[col] = [col_width[col],table[col][row].length].max
    }
  }
  return col_width
end

end
