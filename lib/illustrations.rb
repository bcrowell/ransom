=begin
This needs to be loaded after the Options class has already been set up.

FIXME: Contains hard-coded dimensions in Illustrations.do_one().
=end

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

def Illustrations.do_one(layout)
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

end
