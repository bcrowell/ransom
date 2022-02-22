class Interlinear

# examples of how people do this:
#   https://biblehub.com/interlinear/genesis/1.htm
#   https://www.eva.mpg.de/lingua/resources/glossing-rules.php

def Interlinear.assemble(foreign_genos,words,layout:'wgp',format:'txt',left_margin:[0,''])
  # To generate output, use scripts/do_interlinear.rb
  # Words is a list of Word objects representing one line of text.
  # Format can be 'txt', 'tex', or 'html'.
  # Layout gives the order of the items, as defined in Word.to_h:
  #   'w'=>self.word,'r'=>self.romanization,'g'=>self.gloss,'p'=>self.pos.to_s,'l'=>self.lemma
  # For latex output, this currently assumes that small caps are to be accomplished using {\scriptsize ...},
  # and that there is an environment called greek that can be used to surround Greek characters.
  # Also, the foreign-language texs is formatted as {\large ...}.
  # All of this should be flexible, not hardcoded.
  n_rows = layout.length
  n_cols = words.length
  table = words.map { |word| word.to_a(format:layout,nil_to_null_string:true) }
  if format=='txt' then
    col_width = Interlinear.col_width_helper(table,n_rows,n_cols)
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
    result = ''
    result += "\\begin{tabular}{#{'l'*(n_cols+1)}}\n"
    lines = []
    0.upto(n_rows-1) { |row|
      elements = []
      if row==0 then m=left_margin[1] else m='' end
      elements.push(m)
      0.upto(n_cols-1) { |col|
        e = table[col][row]
        if layout[row]=~/[wl]/ then is_foreign=true else is_foreign=false end
        if layout[row]=~/[p]/ then is_pos=true else is_pos=false end
        if is_pos then e = e.sub(/([A-Z]+)/) {"{\\scriptsize #{$1}}"} end
        if foreign_genos.greek && is_foreign then e="\\begin{greek}\\large #{e}\\end{greek}" end
        elements.push(e)
      }
      lines.push(elements.join(' & '))
    }
    result += lines.join("\\\\\n")+"\n"
    result += %q(\end{tabular})+"\n"
    return result
  end
  raise "format #{format} not implemented"
end

def Interlinear.col_width_helper(table,n_rows,n_cols)
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
