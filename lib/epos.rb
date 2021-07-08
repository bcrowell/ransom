class Epos

  # One-liner to update or create a frequency file (needn't be done explicitly, but can be a good test):
  #   ruby -e 'require "./lib/epos.rb"; require "./lib/file_util.rb"; require "json"; e=Epos.new("text/ιλιας","greek"); e.freq'

  def initialize(text,script)
    # Text is the pathname of either a file or a directory containing some files. If it's a directory, then
    # any files inside it are taken to be texts, unless they have extensions .freq, .index, or .meta.
    # Script can be 'latin', 'greek', or 'hebrew'.
    @text = text
    @script = script
  end

  attr_reader :text,:script

  def words(s)
    # Split a string into words, discarding any punctuation except for punctuation that can occur in a word, e.g.,
    # the apostrophe in "don't."
    if self.script=='latin' then return s.scan(/[[:alpha:]']+/) end
    if self.script=='greek' then return s.scan(/[[:alpha:]᾽’]+/) end
    return s.scan(/[[:alpha:]]+/)
  end

  def all_files
    # Returns a list of files, or nil on an error.
    if File.directory?(self.text) then
      files = []
      Dir.each_child(self.text).each { |file|
        next if File.directory?(file)
        next if file=~/\.(freq|index|meta)/
        files.push(dir_and_file_to_path(self.text,file))
      }
      if files.length==0 then raise "No files found in directory #{self.text}" end
      return files.sort
    else
      if not File.exists?(self.text) then raise "No such file: #{self.text}" end
      return [self.text]
    end
  end

  def freq(cutoff_rank:100)
    # Words will not be indexed if they rank in the top 100 by frequency or if they don't contain at least two alphabetical characters.
    file = self.freq_filename_helper
    if File.exists?(file) && latest_modification(file)>self.all_files.map { |t| latest_modification(t) }.max then
      return json_from_file_or_die(file)
    end
    result = {}
    self.all_files.each { |file|
      result = make_freq_one_file(file,result)
    }
    data = []
    rank = 0
    result.keys.sort { |a,b| result[b]<=>result[a] }.each { |word|
      rank += 1
      next if rank<=cutoff_rank || !(word=~/[[:alpha:]].*[[:alpha:]]/)
      data.push("\"#{word}\" : #{result[word]}")
    }
    if result.keys.length<cutoff_rank+1 then raise "Number of words for frequency count is less than cutoff_rank=#{cutoff_rank}" end
    json = "{\n"+data.join(",\n")+"\n}\n"
    File.open(file,'w') { |f|
      f.print json
    }
    return JSON.parse(json)
  end

  def make_freq_one_file(file,previous)
    # Mungs previous. If you don't want that to happen, then clone before calling.
    result = previous
    if !File.exists?(file) then raise "File not found: #{file}" end
    t = self.words(slurp_file(file))
    t.each { |word|
      key = word.downcase
      if result.has_key?(key) then result[key] += 1 else result[key] = 1 end
    }
    return result
  end

  def freq_filename_helper
    if File.directory?(self.text) then
      return dir_and_file_to_path(self.text,"epos.freq")
    else
      if self.text=~/\./ then return self.text.sub(/\..*/,".freq") else return self.text+".freq" end
    end
  end

end

