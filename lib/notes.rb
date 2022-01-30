class Notes

def Notes.to_latex(linerefs,notes)
  lineref1,lineref2 = linerefs
  if lineref2[1]-lineref1[1]>20 then raise "sanity check failed for inputs to Notes.to_latex, #{lineref1}->#{lineref2}" end
  stuff = []
  Notes.find(lineref1,lineref2,notes).each { |note|
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

def Notes.find(lineref1,lineref2,notes)
  # Finds notes that apply to the given range of linerefs. Converts the 0th element from a note's string into [book,line]. 
  # Sorts the results.
  if lineref1[0]==lineref2[0] then
    return Notes.find_one_book(lineref1,lineref2,notes)
  else
    result = []
    lineref1[0].upto(lineref2[0]) { |book|
      if book==lineref1[0] then x=lineref1 else x=[book,1] end
      if book==lineref2[0] then y=lineref2 else y=[book,99999] end
      result = result + Notes.find_one_book(x,y,notes)
    }
    if result.length>50 then raise "result in Notes.find fails sanity check, #{results.length} notes" end
    return result
  end
end

def Notes.find_one_book(lineref1,lineref2,notes)
  # Helper routine for Notes.find().
  raise "error in Notes.find_one_book, four-page layout spans books" if lineref1[0]!=lineref2[0]
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

end