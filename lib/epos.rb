class Epos

  def initialize(text,script)
    # Text is the pathname of either a file or a directory containing some files. If it's a directory, then
    # any files inside it are taken to be texts, unless they have extensions .freq, .index, or .meta.
    # Script can be 'latin', 'greek', or 'hebrew'.
    @text = text
    @script = script
    attr_reader :text,:script
  end

  def words(s)
    # Split a string into words, discarding any punctuation except for punctuation that can occur in a word, e.g.,
    # the apostrophe in "don't."
    if self.script=='latin' then return s.scan(/[[:alpha:]']+/) end
    if self.script=='greek' then return s.scan(/[[:alpha:]᾽]+/) end
    return s.scan(/[[:alpha:]]+/)
  end

  def all_files
    # Returns a list of files, or nil on an error.
    if File.directory?(self.text) then
      files = []
      Dir.each_child(self.text).each { |file|
        next if File.directory?(file)
        next if file=~/\.(freq|index|meta)/
        files.push(file)
      }
      if files.length==0 then raise "No files found in directory #{self.text}" end
      return files
    else
      if not File.exists?(self.text) then raise "No such file: #{self.text}" end
      return [self.text] end
    end
  end

end

