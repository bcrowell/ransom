=begin
This needs to be loaded after the Options class has already been set up.
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
end
