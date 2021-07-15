class Epos

  def initialize(text,script,is_verse,postfilter:nil)
    # Text is the pathname of either a file or a directory containing some files. If it's a directory, then
    # any files inside it are taken to be texts, unless they have extensions .freq, .index, .dir, .pag, or .meta.
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
    return s.sub(/\s+\Z/,'').sub(/\A\s+/,'')
  end

  def word_glob_to_hard_ref(glob)
    # Glob is a string such as "sing-destructive-wrath" (with hyphens or whitespace). It defines a chunk in which these three words occur in this order,
    # but possibly with other words in between. Case-insensitive.
    # A chunk is a contiguous portion of the text that doesn't contain certain chunk-ending characters and doesn't span files.
    # For verse, the only chunk-ending character is \n. For latin-script prose, they're . ? ; and \n\n.
    # An example where the \n\n matters is near the beginning of Buckley, where a paragraph ends with a colon setting off quoted speech.
    # The API is structured so that usually we think of a chunk as a pointer to just before its own first character.
    # A string like "irritate me not>", with a > at the end, produces a ref to the end of this chunk, i.e., it's as if you were
    # referencing the following chunk.
    # Example:
    #   rm -f text/ιλιας.cache* && ruby -e 'require "sdbm"; require "./lib/epos.rb"; require "./lib/file_util.rb"; require "json"; e=Epos.new("text/ιλιας","greek",true); print e.word_glob_to_hard_ref("μῆνιν-ἄειδε")'
    #   For a non-unique match, try ῥοδοδάκτυλος-Ἠώς.
    #   rm -f text/buckley_iliad.cache* && ruby -e 'require "sdbm"; require "./lib/epos.rb"; require "./lib/file_util.rb"; require "json"; e=Epos.new("text/buckley_iliad.txt","latin",false); print e.word_glob_to_hard_ref("irritate me not>")'
    # Returns [hard_ref,non_unique]. Hard_ref is a hard reference, meaning an internal data structure that is not likely to
    # remain valid when the text is edited. Currently hard_ref is implemented as [file_number,character_index], where both
    # indices are zero-based, and character_index is the first character in the chunk.
    cache = self.auxiliary_filename_helper("cache")
    result = nil
    if File.exists?(cache+".dir") then
      SDBM.open(cache) { |db| if db.has_key?(glob) then result=JSON.parse(db[glob]) end }
    end
    if !(result.nil?) then return result end # return cached result
    result = word_glob_to_hard_ref_helper(glob)
    SDBM.open(cache) { |db| db[glob]=JSON.generate(result) }
    return result
  end

  def word_glob_to_hard_ref_helper(glob)
    # Handles the case where the result is not cached.
    if glob=~/(.*)\>\s*$/ then
      x = word_glob_to_hard_ref_helper2($1)
      return [self.next_chunk(x[0]),x[1]]
    end
    if glob=~/(.*)\|(.*)/ then
      left,right = $1,$2
      basic = "#{left} #{right}"
      r1,non_unique = word_glob_to_hard_ref_helper2(basic) # ref to beginning of chunk
      if r1.nil? then return [nil,nil] end
      r2,garbage = word_glob_to_hard_ref_helper("#{basic} >") # ref to end (recurse because helper2 doesn't support >)
      t = extract(r1,r2,remove_numerals:false)
      left_regex = plain_glob_to_regex(left)
      raise "internal error, left=#{left}" unless t=~/(#{left_regex})/ # shouldn't happen, because r1 was not nil
      left_match = $1
      offset = t.index(left_match)
      return [r1[0],r1[1]+offset]
    end
    return word_glob_to_hard_ref_helper2(glob)
  end

  def whole_word_regex(word)
    return "(?<![[:alpha:]])"+word+"(?![[:alpha:]])" # negative lookahead and lookbehind so it's an isolated word
  end

  def regex_no_splitters
    spl = self.splitters
    return "[^#{spl}@]*" # The @ is a convenience for word_glob_to_hard_ref_helper2 when it calls matches_without_containing_paragraph_break.
  end

  def plain_glob_to_regex(glob)
    # glob can't contain special characters like | or >
    return glob.split(/[\-\s]+/).map { |key| whole_word_regex(key) }.join(regex_no_splitters())
  end

  def word_glob_to_hard_ref_helper2(glob)
    # Does the actual work for word_glob_to_hard_ref(). Glob must not contain stuff like >.
    whole_regex = plain_glob_to_regex(glob)
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
      break if i>=2 && s[i-1]=="\n" && s[i-2]=="\n" # only relevant for prose, in which double newline is a chunk separator
      i = i-1
    end
    return i
  end

  def next_chunk(ref)
    # returns a ref
    # if used at the end of the last file, can return a reference to a first character of a fictitious next file
    if ref.nil? then raise "nil ref" end
    s = self.get_contents[ref[0]]
    spl = self.splitters
    i = ref[1]
    while true do
      if i==s.length-1 || (s[i+1]=~/[#{spl}]/) then bump=2; break end
      if i<=s.length-3 && s[i+1]=="\n" && s[i+2]=="\n" then bump=3; break end # only relevant for prose, in which double newline is a chunk separator
      i = i+1
    end
    ref = clown([ref[0],i])
    1.upto(bump) { |k| ref=self.increment_ref(ref) }
    return ref
  end

  def increment_ref(ref)
    # increments it by one character (not one chunk)
    # if used at the end of the last file, can return a reference to a first character of a fictitious next file
    s = self.get_contents[ref[0]]
    i = ref[1]
    if i<s.length-1 then
      return [ref[0],i+1]
    else
      return [ref[0]+1,0]
    end
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
        next if file=~/\.(freq|dir|pag|index|meta)/
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
    return self.auxiliary_filename_helper("freq")
  end

  def auxiliary_filename_helper(ext)
    if File.directory?(self.text) then
      return dir_and_file_to_path(self.text,"epos.#{ext}")
    else
      if self.text=~/\./ then return self.text.sub(/\..*/,".#{ext}") else return self.text+".#{ext}" end
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

