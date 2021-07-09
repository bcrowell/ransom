class Epos

  def initialize(text,script,is_verse,postfilter:nil)
    # Text is the pathname of either a file or a directory containing some files. If it's a directory, then
    # any files inside it are taken to be texts, unless they have extensions .freq, .index, or .meta.
    # Script can be 'latin', 'greek', or 'hebrew'.
    # Is_verse is boolean
    @text = text
    @script = script
    @is_verse = is_verse
    @postfilter = postfilter
    @contents = nil
  end

  attr_reader :text,:script,:is_verse,:postfilter

  def words(s)
    # Split a string into words, discarding any punctuation except for punctuation that can occur in a word, e.g.,
    # the apostrophe in "don't."
    if self.script=='latin' then return s.scan(/[[:alpha:]']+/) end
    if self.script=='greek' then return s.scan(/[[:alpha:]᾽’]+/) end
    return s.scan(/[[:alpha:]]+/)
  end

  def extract(r1,r2,remove_numerals:true)
    # r1 and r2 are hard refs
    # Returns chunk r1 (inclusive) to r2 (not inclusive). Leading and trailing whitespace is stripped, except that
    # if it's verse, then the result has exactly one trailing newline.
    # One-liner for testing:
    #   ruby -e 'require "./lib/epos.rb"; require "./lib/file_util.rb"; require "json"; e=Epos.new("text/ιλιας","greek",true); r1=e.word_glob_to_hard_ref("μῆνιν-ἄειδε")[0]; r2=e.word_glob_to_hard_ref("ἐϋκνήμιδες-Ἀχαιοί")[0]; print e.extract(r1,r2)'
    c = self.get_contents
    if r1[0]==r2[0] then
      result = c[r1[0]][r1[1]..(r2[1]-1)]
    else
      a = []
      a.push(c[r1[0]][r1[1]..-1])
      (r1[0]+1).upto(r2[0]-1) { |i| a.push(c[i]) }
      if r2[1]>0 then a.push(c[r2[0]][0..(r2[1]-1)]) end # the case r2[1]=0 would produce anomalous behavior because index -1 has a special meaning
      result = join_file_contents(a)
    end
    result = strip_whitespace(result)
    if self.is_verse then result=result+"\n" end
    if remove_numerals then result.gsub!(/\s+\d+/,'') end
    return result
  end

  def strip_whitespace(s)
    return s.sub(/\s+$/,'').sub(/^\s+/,'')
  end

  def word_glob_to_hard_ref(glob)
    # Glob is a string such as "sing-destructive-wrath". It defines a chunk in which these three words occur in this order,
    # but possibly with other words in between. Case-insensitive.
    # A chunk is a contiguous portion of the text that doesn't contain certain chunk-ending characters and doesn't span files.
    # For verse, the only chunk-ending character is \n. For latin-script prose, they're . ? ; and \n\n.
    # An example where the \n\n matters is near the beginning of Buckley, where a paragraph ends with a colon setting off quoted speech.
    # Example:
    #   ruby -e 'require "./lib/epos.rb"; require "./lib/file_util.rb"; require "json"; e=Epos.new("text/ιλιας","greek",true); print e.word_glob_to_hard_ref("μῆνιν-ἄειδε")'
    #   For a non-unique match, try ῥοδοδάκτυλος-Ἠώς.
    # Returns [hard_ref,non_unique]. Hard_ref is a hard reference, meaning an internal data structure that is not likely to
    # remain valid when the text is edited. Currently hard_ref is implemented as [file_number,character_index], where both
    # indices are zero-based, and character_index is the first character in the chunk.
    keys = glob.split(/-/)
    spl = self.splitters
    regex_no_splitters = "[^#{spl}@]*" # The @ is a convenience for when we call matches_without_containing_paragraph_break.
    word_regexen = keys.map { |key| "(?<![[:alpha:]])"+key+"(?![[:alpha:]])" } # negative lookahead and lookbehind so it's an isolated word
    whole_regex = word_regexen.join(regex_no_splitters)
    c = self.get_contents
    non_unique = false
    found = false
    result = nil
    0.upto(c.length-1) { |i|
      m = c[i].scan(/#{whole_regex}/i)
      m = m.select { |x| Epos.matches_without_containing_paragraph_break(whole_regex,x) }
      if m.length>0 && found then non_unique=true; break end
      if m.length>0 && !found then
        result = [i,c[i].index(m[0])]
        found = true
      end
      if m.length>1 then non_unique=true; break end
    }
    #if glob=~/greaved/ then raise "glob=#{glob}, result=#{result}\n" end # qwe
    if result.nil? then
      raise "failed match for #{glob}"
      return [nil,nil]
    end
    result[1] = first_character_in_chunk(result)
    return [result,non_unique]
  end

  def first_character_in_chunk(ref)
    # In an example like ...κοσμήτορε λαῶν·\n\n«Ἀτρεΐδαι τε καὶ..., the second chunk starts at the opening quote, because
    # the newlines are chunk separators in verse.
    if ref.nil? then raise "nil ref" end
    s = self.get_contents[ref[0]]
    spl = self.splitters
    i = ref[1]
    while true do
      break if i==0 || (s[i-1]=~/[#{spl}]/)
      break if i>=2 && s[i-1]=="\n" && s[i-2]=="\n"
      i = i-1
    end
    return i
  end

  def splitters
    # Returns a string suitable for inserting into a regex as [...] or [^...].
    if self.is_verse then
      return "\r\n"
    else 
      if self.script=='greek' then
        return "\\.;"
      else
        return "\\.\\?;" # defaults, appropriate for latin script
      end
    end
  end

  def line_to_hard_ref(book,line)
    # This is meant for a source text in which there are lines of verse, separated by newlines.
    # Sometimes such texts have arabic numerals at the end of lines stating the line numbers. Currently
    # we ignore them, so we depend on the assumption that there are no lines such as chapter headers or footnotes.
    # Both book and line are 1-based.
    s = self.get_contents[book-1]
    if s.nil? then raise "Book #{book} doesn't exist, number of books is #{self.get_contents.length} (numbering is 1-based)." end
    a = s.scan(/[^\r\n]*[\r\n]+/)
    count = 0
    offset = 0
    a.each { |l|
      if l=~/[[:alpha:]]/ then count+=1 end
      if count==line then return [book-1,offset] end
      offset += l.length
    }
    raise "Line #{line} doesn't exist in book #{book}, number of lines is #{count}"
  end

  def get_contents
    # returns an array in which each element is a string holding the contents of a file.
    if !(@contents.nil?) then return @contents end
    s = self.all_files.map { |file| slurp_file(file) }
    s = s.map { |x| x.gsub(/\r\n/,"\n") }
    if !(self.postfilter.nil?) then s=s.map { |x| self.postfilter.call(x)} end
    @contents = s
    return @contents
  end

  def get_contents_one_string
    # concatenates contents of files, with exactly two newlines separating each
    return join_file_contents(self.get_contents)
  end

  def join_file_contents(a)
    return a.join("\n\n").sub(/\n{3,}/,"\n\n")
  end

  def all_files
    # Returns a list of files, or nil on an error. The list is sorted in alphabetical order by filename.
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

  # One-liner to update or create a frequency file (needn't be done explicitly, but can be a good test):
  #   ruby -e 'require "./lib/epos.rb"; require "./lib/file_util.rb"; require "json"; e=Epos.new("text/ιλιας","greek",true); e.freq'

  def freq(cutoff_rank:100)
    # Returns a cached word-frequency table.
    # Words will not be indexed if they rank in the top 100 by frequency or if they don't contain at least two alphabetical characters.
    # This is needed in order to generate word glob references for a given hard reference.
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

  def Epos.strip_pg_footnotes(s)
    return s.gsub(/Footnote \d+([^\n]+\n)+/,'')
  end

  def Epos.matches_without_containing_paragraph_break(regex,x)
    # For our convenience, the regex refuses to match @.
    x = x.gsub(/\n\n/,"@")
    if x=~/#{regex}/i then return true else return false end
  end

end

