# coding: utf-8
=begin

This is a general-purpose library for use in selecting or referring to
portions of a text file.  The name Epos is from the Greek word επος,
meaning a word or speech. In the past, people have usually accomplished
such tasks either using line number references (e.g., Iliad 1.33)
or, in efforts such as Project Perseus, by massive XML markup projects,
which are extremely complex and time-consuming. Epos makes this
easier.

The text should be in one or more files on disk, but in the present
implementation is always read into memory. Additional data files will
be created automatically with names based on the name of the directory
or file containing the text.

The user supplies a string that defines a certain spot in the
text. This is called a soft reference. A soft reference can be
ambiguous, and it is meant to be as robust as possible against editing
of the file. The library provides routines that convert a soft
reference to a hard reference, which is just a numerical pointer to a
position in a file.

A soft reference can be either a word glob or line reference. 

Line references are simple: you just give a book and a line number,
e.g., by calling iliad.line_to_hard_ref(1,33).  They are actually not
very robust, although changing the file for book 7 will not affect
line numbers in book 12.

A word glob basically is a set of keywords that are meant to occur
in order, within one sentence. The keywords can be separated by whitespace
or by the character -. For example, the word glob "sing-wrath-achilles"
will match the first sentence of Buckley's translation of the Iliad,
which is "Sing, O goddess, the destructive wrath of Achilles, ..."

The true linguistic notion of a sentence is actually complicated, because
you can have quoted speech with sentences within sentences, and also
speech tags that are not themselves complete sentences, and quoted speech
that spans paragraphs. Therefore instead of sentences, Epos actually defines
"chunks" instead. 

A chunk is a contiguous portion of the text that doesn't contain
certain chunk-ending characters and doesn't span files.  For verse,
the only chunk-ending character is \n. For latin-script prose, they're
. ? ; and \n\n.  An example where the \n\n rule matters is near the
beginning of Buckley, where a paragraph ends with a colon setting off
quoted speech. To accommodate US-style punctuation of quotes, when
a sentence ends "like this;", the quote is included in the sentence.

The API is structured so that usually we think of a chunk as a pointer
to just before its own first character.  A string like "irritate me
not>", with a > at the end, produces a ref to the end of this chunk,
i.e., it's as if you were referencing the following chunk.

One can also refer to spots within a chunk using the operator |<. For
example, "withhold heavy hands |< pestilence" refers to the spot
immediately after the word "hands." The mnemonic is that we don't have
a < operator, because going back to the beginning of the chunk is the
default behavior, but the |< acts sort of like that except that it
runs into a wall.

Because locating a word glob can be an expensive operation, the
library automatically caches the resulting hard refs on disk for later
use, in files ending with the extensions .cache.pag and .cache.dir.
If the software changes and you need to test whether it's still
actually working, you need to prevent reuse of this caching, and
likewise if you make any changes to the text. To do this, either
do a 'make flush_epos_cache' or call the constructor using
Epos.new(...,use_cache:false).

A text may contain material like footnotes that we want to pretend are
not there. This is done using the postfilter facility. Example:
Epos.new("text/buckley_iliad.txt","latin",false,postfilter:lambda { |s| Epos.strip_pg_footnotes(s) })

Sometimes you want to refer to a sentence that appears, verbatim, more
than once in the text. There could be a lot of handy ways of dealing
with this, but presently the only method is to use a syntax such as
"47 % rosy fingered dawn", meaning to constrain the match to lie close
to 47% of the way through the entire text. "Close" is defined as +-2%.

Testing:

When testing, make sure to do use_cache:false. Otherwise nothing will actually be tested.
We also, for example, don't want to run a test without postfiltering, cache the result,
and then read it back later from the case without postfiltering.

To do:

Allow relative addressing, e.g., the second word in the third line after a certain word glob.

Allow other methods for disambiguation. Possibly do this by letting the user
put some kind of data structure in a JSON hash before the % sign.

Given a word glob, suggest an alternative glob that is less ambiguous
or less verbose.

=end

class Epos

  def initialize(text,script,is_verse,postfilter:nil,use_cache:true,genos:nil)
    # Text is the pathname of either a file or a directory containing some files. If it's a directory, then
    # any files inside it are taken to be texts, unless they have extensions .freq, .index, .dir, .pag, or .meta.
    # Script can be 'latin', 'greek', or 'hebrew'.
    # Is_verse is boolean
    # The use_cache flag is for testing and development. See more notes about this in documentation at top of code.
    @text = text
    @script = script
    @is_verse = is_verse
    @postfilter = postfilter
    @use_cache = use_cache
    @contents = nil
    @genos = genos # optional object of Genos class
  end

  attr_reader :text,:script,:is_verse,:postfilter,:genos

  def Epos.run_tests()
    # make test_epos, which does this:
    #   ruby -e "require './lib/epos.rb'; require './lib/file_util.rb'; require 'json'; require './lib/string_util.rb'; require './lib/clown.rb'; Epos.run_tests()"
    require 'tmpdir'
    Dir.mktmpdir { |d|
      tests = [
        ['pooh',"sometimes thought sadly","came stumping along",%q{Sometimes he thought},%q{thinking about.},"basic test"],
        ['pooh',"old grey","shook his head",%q{The Old},%q{Pooh.},"span paragraphs"],
        ['pooh',"sometimes thought sadly","wherefore",%q{Sometimes he thought sadly},%q{Why?"},%q{US-style punctuation}],
        ['pooh',"old grey>","shook his head",%q{Sometimes he thought sadly},%q{Pooh.},"> operator"],
        ['pooh',"corner of the forest |< his front feet","sometimes sadly",%q{his front},%q{about things.},"|< operator"],
        ['pooh',"Eeyore |< stood by himself","sometimes sadly",%q{stood by himself},%q{about things.},"|< operator after a comma"],
        ['foo',"b |< c","e",%q{c},%q{d.},"|< operator after a comma"],
      ]
      tests.each { |test|
        label,glob1,glob2,at_start,at_end,testing_what = test
        filename = "#{d}/#{label}.txt"
        File.open(filename,"w") { |f| f.print Epos.test_text(label) }
        e = Epos.new(d,'latin',false,use_cache:false)
        r1,non_unique_1,junk = e.word_glob_to_hard_ref(glob1)
        r2,non_unique_2,junk = e.word_glob_to_hard_ref(glob2)
        describe_test = "#{test}"
        if r1.nil? || r2.nil? || non_unique_1 || non_unique_2 then raise "error or not unique on this test: #{describe_test}" end
        re = Regexp.new("\\A#{Regexp::quote(at_start)}.*#{Regexp::quote(at_end)}\\Z",Regexp::MULTILINE)
        s = e.extract(r1,r2)
        if !re.match?(s) then raise "wrong result on this test: #{describe_test}\n  result=@@#{s}@@\n  re=#{re}" end
        #print s,"\n---------------------------\n"
        print "  test passed: #{testing_what}\n"
      }
    }
  end

  def Epos.test_text(label)
    if label=='foo' then
    x = %q{
        a. b, c d. e
    }
    end
    if label=='pooh' then
    # In celebration of Pooh freedom day, 2022:
    x = %q{
      The Old Grey Donkey, Eeyore, stood by himself in a thistly corner of the forest, his front feet well apart, his head on one side, and
      thought about things. Sometimes he thought sadly to himself, "Why?" and sometimes he thought, "Wherefore?" and sometimes he
      thought, "Inasmuch as which?" -- and sometimes he didn't quite know what he was thinking about. So when Winnie-the-Pooh came stumping
      along, Eeyore was very glad to be able to stop thinking for a little, in order to say "How do you do?" in a gloomy manner to him.

      "And how are you" said Winnie-the-Pooh.

      Eeyore shook his head from side to side.

      "Not very how," he said. "I don't seem to have felt at all how for a long time."
    }
    end
    x = x.gsub(/^\s+/,'').gsub(/\A\n/,'') # remove indentation and initial newline
    return x
  end

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
    #   ruby -e 'require "./lib/epos.rb"; require "./lib/file_util.rb"; require "json"; e=Epos.new("text/ιλιας","greek",true,use_cache:false); r1=e.word_glob_to_hard_ref("μῆνιν-ἄειδε")[0]; r2=e.word_glob_to_hard_ref("ἐϋκνήμιδες-Ἀχαιοί")[0]; print e.extract(r1,r2)'
    sanity_check_ref(r1)
    sanity_check_ref(r2)
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
    if remove_numerals then result = result.gsub(/\s+\d+/,'').gsub(/^\d+/,'') end
    return result
  end

  def sanity_check_ref(r,die_if_bad:true)
    # checks a hard ref, dies if not ok
    ok = true
    reason = nil
    if r.nil? then ok=false; reason="nil" end
    if ok && !(r.kind_of?(Array)) then ok=false; reason="not an array" end
    if ok && !(r.length==2) then ok=false; reason="length=#{r.length}" end
    if ok && !(r[0].class==1.class && r[1].class==1.class) then ok=false; reason="ref=#{r}, elements not integers" end
    if !ok && die_if_bad then raise "hard ref fails sanity check\n  reason=#{reason}\n  ref=#{r}\n" end
    return [ok,reason]    
  end

  def strip_whitespace(s)
    return s.sub(/\s+\Z/,'').sub(/\A\s+/,'')
  end

  def word_glob_to_hard_ref(glob)
    # Glob is a string such as "sing-destructive-wrath" (with hyphens or whitespace). It defines a chunk in which these three words occur in this order,
    # but possibly with other words in between. Case-insensitive.
    # Example:
    #   ruby -e 'require "sdbm"; require "./lib/epos.rb"; require "./lib/file_util.rb"; require "json"; e=Epos.new("text/ιλιας","greek",true,use_cache:false); print e.word_glob_to_hard_ref("μῆνιν-ἄειδε")'
    #   For a non-unique match, try ῥοδοδάκτυλος-Ἠώς.
    #   rm -f text/buckley_iliad.cache* && ruby -e 'require "sdbm"; require "./lib/epos.rb"; require "./lib/file_util.rb"; require "json"; e=Epos.new("text/buckley_iliad.txt","latin",false); print e.word_glob_to_hard_ref("irritate me not>")'
    # Returns [hard_ref,non_unique,ambig_list]. On a serious error, hard_ref is nil.
    # Hard_ref is a hard reference, meaning an internal data structure that is not likely to
    # remain valid when the text is edited. Currently hard_ref is implemented as [file_number,character_index], where both
    # indices are zero-based, and character_index is the first character in the chunk.
    if @use_cache then
      cache = self.auxiliary_filename_helper("cache")
      result = nil
      if File.exists?(cache+".dir") then
        SDBM.open(cache) { |db| if db.has_key?(glob) then result=JSON.parse(db[glob]) end }
      end
      if !(result.nil?) then return result end # return cached result
    end
    if glob=~/%.*%/ then raise "more than one % character in this glob: #{glob}" end
    if glob=~/(.*)%(.*)/ then
      constraint_string,bare_glob = $1,$2
      pct = constraint_string.to_f
      constraint_pct = [pct-2.0,pct+2.0] # by design, it's OK if these go below 0 or above 100%
    else
      bare_glob = glob
      constraint_pct = [0.0,100.0]
    end
    if Regexp.new("[#{self.splitters}]").match?(bare_glob) then
      raise "error, glob #{bare_glob} contains characters that match splitter characters #{self.splitters}"
    end
    bare_glob = bare_glob.gsub(/[\[\]]/,'') # filter out regex metacharacters
    constraint = constraint_pct.map { |pct| self.percentage_to_hard_ref(pct) }
    result = word_glob_to_hard_ref_helper(bare_glob,constraint)
    if @use_cache then
      SDBM.open(cache) { |db| db[glob]=JSON.generate(result) }
    end
    return result
  end

  def word_glob_to_hard_ref_helper(glob,constraint)
    # Handles the case where the result is not cached.
    # Returns [hard ref,if_ambiguous,ambig_list].
    if glob=~/\|(?!\<)/ then raise "error in glob #{glob}, there is no | operator; did you mean |< ?" end
    if glob=~/(?<!\|)\</ then raise "error in glob #{glob}, there is no < operator; did you mean |< ?" end
    if glob=~/\A\s*\|\</ then raise "error in glob #{glob}, |< at beginning of glob, which doesn't make sense" end
    if glob=~/(.*)\>\s*$/ then
      x = word_glob_to_hard_ref_helper2($1,constraint)
      return [self.next_chunk(x[0]),x[1],x[2]]
    end
    if glob=~/(.*)\|<(.*)/ then
      left,right = $1,$2
      basic = "#{left} #{right}"
      r1,non_unique,ambig_list = word_glob_to_hard_ref_helper2(basic,constraint) # ref to beginning of chunk
      if r1.nil? then return [nil,nil,nil] end
      if non_unique then return [nil,non_unique,ambig_list] end
      r2,garbage,garbage2 = word_glob_to_hard_ref_helper("#{basic} >",constraint) # ref to end (recurse because helper2 doesn't support >)
      t = extract(r1,r2,remove_numerals:false)
      left_regex = plain_glob_to_regex(left)
      raise "internal error, left=#{left}, r1=#{r1}, r2=#{r2}" unless t=~/(#{left_regex})/ # shouldn't happen, because r1 was not nil
      left_match = $1
      offset = t.index(left_match)
      ii = offset+left_match.length+1 # an index into t
      while ii<t.length-1 && !(t[ii]=~/[[:alpha:]]/) do ii+=1 end # skip past white space
      result = [r1[0],r1[1]+ii]
      return [result,non_unique,ambig_list]
    end
    return word_glob_to_hard_ref_helper2(glob,constraint)
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
    return glob.split(/[\-\s]+/).filter { |key| key!=''}.map { |key| whole_word_regex(key) }.join(regex_no_splitters())
  end

  def word_glob_to_hard_ref_helper2(glob,constraint)
    # Does the actual work for word_glob_to_hard_ref(). Glob must not contain stuff like >.
    # Returns [hard ref,if_ambiguous,ambig_list], where ambig_list is debugging info consisting
    # of a list of elements of the form [matching string, hard ref]
    whole_regex = plain_glob_to_regex(glob)
    c = self.get_contents
    non_unique = false
    found = false
    ambig_list = []
    result = nil
    constraint[0][0].upto(constraint[1][0]) { |i| # loop over files
      s = c[i]
      m,hrs = self.word_glob_to_hard_ref_helper3(glob,s,whole_regex,i,constraint) # array of matching strings
      if m.length>0 && found then
        # found a match in this file, but also found one in a previous file
        non_unique=true
        if ambig_list.length<=1 then ambig_list.push([m[0],hrs[0]]) end
        # ... help user by showing the match from the earlier file and also one match from this file, but show a maximum of two of these
        break
      end
      if m.length>0 && !found then
        if ambig_list.length<=1 then ambig_list.push([m[0],hrs[0]]) end
        result = hrs[0]
        found = true
      end
      if m.length>1 then 
        non_unique=true
        1.upto(1) { |k| ambig_list.push([m[k],hrs[k]]) } # show the user one more
        break
      end
    }
    if result.nil? then
      return [nil,nil,nil]
    end
    result[1] = first_character_in_chunk(result)
    return [result,non_unique,ambig_list]
  end

  def word_glob_to_hard_ref_helper3(glob,s,whole_regex,file_num,constraint)
    # Works on a single string at a time. Returns [array of matching strings,hard refs of first few matching strings].
    Epos.assert_integrity_of_constraint(constraint)
    re1 = Regexp.new(whole_regex,Regexp::IGNORECASE | Regexp::MULTILINE)
    m = s.scan(re1)
    m = m.select { |x| Epos.matches_without_containing_paragraph_break(re1,x) }
    matches_fitting_constraints = []
    hrs = []
    if m.length>0 then
      search_from = 0
      0.upto(m.length-1) { |k| # to help provide user with debugging of ambiguities, send back first 1 or 2 matches
        re = Regexp.new(Regexp.escape(m[k]),Regexp::IGNORECASE)
        ind = s.index(re,search_from) # result guaranteed to be non-nil because m[k] is known to be a match
        if ind.nil? then raise "result of s.index is nil, but this should never happen; does the regex contain metacharacters? -- re=#{re}" end
        hr = [file_num,ind]
        if hard_ref_triple_in_order(constraint[0],hr,constraint[1]) then
          matches_fitting_constraints.push(m[k])
          hrs.push(hr) 
        end
        break if hrs.length>=2 # show user only 2 matches from any given file
        search_from = ind+1
      }
    end
    return [matches_fitting_constraints,hrs]
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
    # Allow for US-style punctuation:
    if i>=1 && s[i]=='"' && i<=s.length-2 && s[i-1]=~/[,.?]/ then
      i += 1
      while i<=s.length-2 && s[i]=~/\s/ do i+=1 end
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
    if true then
      # Check for quotation mark that should be included with the preceding chunk.
      # This seems to be necessary and sufficient for the glob "irritate me not>, which occurs at Iliad 1.33.
      # I'm not certain at all whether this is correct in all cases.
      i=ref[1]
      if i<s.length-1 && s[i]=~/['`"“”\n]/ then ref=self.increment_ref(ref) end
    end
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
    if line.nil? then stack=caller[0..5].join("\n"); raise "nil line, #{stack}" end
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

  def hard_ref_triple_in_order(r1,r2,r3)
    # returns boolean, true if r1<=r2<=r3
    return hard_ref_pair_in_order(r1,r2) && hard_ref_pair_in_order(r2,r3)
  end

  def hard_ref_pair_in_order(r1,r2)
    # returns boolean, true if r1<=r2
    return ((r1 <=> r2) <=0 )
  end

  def percentage_to_hard_ref(pct)
    # Inputs outside of 0-100% are silently brought into that range.
    if pct<0.0 then pct=0.0 end
    if pct>100.0 then pct=100.0 end
    l = self.get_contents.map { |s| s.length }
    n = l.length
    total = l.sum
    if pct<=0.0 then return [0,0] end
    if pct>=100.0 then return [n-1,l[-1]] end
    if total==0 then raise "total==0??" end
    f = pct*0.01
    accum = 0
    which_file = n-1 # gives the right result when we exhaust the whole loop below
    0.upto(n-1) { |i|
      if accum>f*total then which_file=i-1; break end
      accum += l[i]
    }
    offset = accum-l[which_file] # back up one file
    return [which_file,(f*total).to_i-offset]
  end

  def get_contents
    # returns an array in which each element is a string holding the contents of a file.
    if !(@contents.nil?) then return @contents end
    s = self.all_files.map { |file| slurp_file(file) }
    s = s.map { |x| x.gsub(/\r\n/,"\n") } # convert DOS crlf to unix
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
    # This works on a single paragraph terminated by a newline.
    # For an example of how to use this from an external script, see remove_pg_footnotes.rb .
    s = s.gsub(/Footnote \d+([^\n]+\n)+/,'')
    s = s.gsub(/^ +([^\s][^\n]*\n?)+/,'')
    # indented lines sometimes occur inside footnotes, with blank lines above and below; also sometimes we have a footnote consisting of verse
    # which has the first line indented, but not the later lines
    return s
  end

  def Epos.matches_without_containing_paragraph_break(regex,x)
    # For our convenience, the regex refuses to match @.
    if !(regex.kind_of?(Regexp)) then raise "Regexp not supplied to Epos.matches_without_containing_paragraph_break" end
    x = x.gsub(/\n\n/,"@")
    if x.match?(regex) then return true else return false end
  end

  def Epos.assert_integrity_of_constraint(c)
    if c.length!=2 then raise "constraint has length not equal to 2, c=#{c}" end
    Epos.assert_integrity_of_hard_ref(c[0])
    Epos.assert_integrity_of_hard_ref(c[1])
  end

  def Epos.assert_integrity_of_hard_ref(r)
    if r.length!=2 then raise "hard ref has length not equal to 2, ref=#{r}" end
  end

end

