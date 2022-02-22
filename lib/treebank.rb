# This class provides a wrapper for the Project Perseus treebank data.
# Functions:
#   lemmatize a given word
#   access POS analysis given line number in the text

class TreeBank
  def initialize(corpus)
    # Fails by raising an exception if the appropriate lemmas file doesn't exist.
    # It's not a problem if the POS file doesn't exist.
    data_dir = "lemmas"
    @lemmas_file = "#{data_dir}/#{corpus}_lemmas.json"
    @lemmas = json_from_file_or_die(@lemmas_file)
    @inverse_index = nil
    @pos_file = "#{data_dir}/#{corpus}_lemmas.csv" # needn't exist, gets changed to nil below if it doesn't
    if !File.exist?(@pos_file) then
      @pos_file=nil
    else
      pos_index_file = "#{data_dir}/#{corpus}_lemmas.line_index.json"
      if !File.exist?(pos_index_file) then raise "file #{@pos_index_file} does not exist; generate it using the makefile in the lemmas subdirectory" end
      @pos_index = json_from_file_or_die(pos_index_file)
    end
  end
  attr_reader :lemmas,:lemmas_file,:pos_file

  def get_line(genos,db,text,book,line_number)
    # returns an array of Word objects
    # FIXME: inefficiently reads the whole file every time
    # The following code is mostly duplicated from lemmas/to_db.rb.
    raise "illegal types for inputs" unless book.class==1.class && line_number.class==1.class
    if !File.exist?(@pos_file) then raise "file #{@pos_file} does not exist; generate it using the makefile in the lemmas subdirectory" end
    words = []
    line_index_key = "#{text},#{book},#{line_number}"
    File.open(@pos_file,'r') { |f|
      raise "line index key #{line_index_key} not found" unless @pos_index.has_key?(line_index_key)
      f.seek(@pos_index[line_index_key]) # works only because position is guaranteed to be at a utf8 character boundary
      while true
        line = f.readline
        a = TreeBank.parse_csv_helper(line)
        next if a.nil?
        this_text,this_book,this_line,word,lemma,lemma_number,pos = a
        next unless word=~/[[:alpha:]]/
        break unless this_text==text && this_book.to_i==book && this_line.to_i==line_number
        gloss_data = Gloss.get(db,lemma,prefer_length:0,if_texify_quotes:false)
        if gloss_data.nil? then gloss=Writing.romanize(lemma) else gloss=gloss_data['gloss'] end
        words.push(Word.new(genos,word,Tagzig.from_perseus(pos),gloss,lemma:lemma))
      end
    }
    raise "line not found: #{line_index_key}" if words.length==0
    return words
  end

  def TreeBank.parse_csv_helper(line)
    # returns nil or array
    line = remove_macrons_and_breves(line)
    return nil unless line=~/[[:alpha:]]/
    line.sub!(/\n/,'')
    a = line.split(/,/)
    if a.length!=7 then die("csv has wrong length, line=#{line}") end
    return a
  end

  def every_lemma_by_pos(pos)
    # input is a perseus part of speech tag such as 'v' for verbs
    result_hash = {}
    self.lemmas.keys.each { |inflected|
      lemma,garbage,whole_pos,garbage,if_ambig,ambig = self.lemmas[inflected]
      if if_ambig then data=ambig else data = [[lemma,garbage,whole_pos,garbage]] end
      data.each { |x|
        lemma,garbage,whole_pos,garbage = x
        next unless whole_pos[0]==pos
        result_hash[lemma] = 1
      }
    }
    return alpha_sort(result_hash.keys)
  end

  def every_form_of_lemma(lemma,pos,discard_elided_greek_forms:true)
    # pos is a perseus part of speech tag such as 'v' for verbs; used for disambiguation
    # returns a list whose elements are of the form [word,whole_pos]
    result_hash = {}
    self.lemmas.keys.each { |inflected|
      this_lemma,garbage,whole_pos,garbage,if_ambig,ambig = self.lemmas[inflected]
      if if_ambig then data=ambig else data = [[this_lemma,garbage,whole_pos,garbage]] end
      data.each { |x|
        this_lemma,garbage,whole_pos,garbage = x
        next unless this_lemma==lemma && whole_pos[0]==pos
        result_hash[inflected+' '+whole_pos] = 1
      }
    }
    result = alpha_sort(result_hash.keys) # initial quick and dirty sort because later sorting will involve slow comparisons
    result = result.map { |x| x.split(/\s+/) }.sort { |a,b| alpha_compare(a[0],b[0]) }
    result = result.filter { |x| !contains_greek_elision(x[0]) } if discard_elided_greek_forms
    return result
  end

  # Why do I have both this and word_to_lemma_entry?
  def lemmatize(word)
    # returns [lemma,success]
    if @lemmas.has_key?(word) then return self.lemma_helper(word) end
    if @lemmas.has_key?(word.downcase) then return self.lemma_helper(word.downcase) end
    if @lemmas.has_key?(capitalize(word)) then return self.lemma_helper(capitalize(word)) end
    return [word,false]
  end

  def lemma_helper(word)
    lemma,lemma_number,pos,count,if_ambiguous,ambig = @lemmas[word]
    return [lemma,true]
  end

  # Why do I have both this and lemmatize?
  def word_to_lemma_entry(word)
    # This only handles the case where the word occurs as an inflected form of some lemma. If word is a lemma but never occurs
    # in the text (e.g., λύω in the Iliad), then this function returns nil.
    if @lemmas.has_key?(word) then return @lemmas[word] end
    if @lemmas.has_key?(word.downcase) then return @lemmas[word.downcase] end
    return nil
  end

  def word_to_lemmas(forms)
    # Input is a list of possible forms, e.g., ["κεραΐζω","κεραίζω"]. It's OK if some elements are nil.
    # Returns an array of entries for possible lemmas; in most cases the array will be a singleton.
    # Elements are of the form [lemma,pos], where pos is a 1-character Project Perseus tag such as "n" for noun.
    # This works both in the case where word occurs in the text and in the case where word is a Perseus lemma but does
    # not itself occur in the text. It will return nil in the case where word is not the Perseus lemma and does not
    # occur in the text, e.g., if word is a Homeric form.
    results = []
    forms.each { |word|
      next if word.nil?
      results = results + self.word_in_text_to_lemmas(word)
      results = results + self.lemma_to_words(word).map { |e| [word,e[1][0]] }
    }
    results = results.map { |e| [e[0],e[1][0]] }.uniq
    return results
  end

  def word_in_text_to_lemmas(word)
    # Returns an array of entries for possible lemmas; in most cases the array will be a singleton.
    # Elements are of the form [lemma,pos_tag], where pos_tag is a 9-character Project Perseus tag.
    x = self.word_to_lemma_entry(word)
    if x.nil? then return [] end
    if !x[4] then return [[x[0],x[2]]] end # not ambiguous
    return x[5].map { |a| [a[0],a[2]] }
  end

  def lemma_to_words(lemma)
    # Given a lemma, returns a list whose elements are of the form [word,pos]. The list may be empty.
    if @inverse_index.nil? then
      @inverse_index = {}
      @lemmas.keys.each { |word|
        word_in_text_to_lemmas(word).each { |e|
          lemma2,pos = e
          if !(@inverse_index.has_key?(lemma2)) then @inverse_index[lemma2]=[] end
          @inverse_index[lemma2].push([word,pos])
        }
      }
    end
    x = @inverse_index[lemma]
    if x.nil? then return [] else return x end
  end

  def lemma_to_pos(lemma)
    # Given a lemma, returns a list whose-elements are characters such as "n" for noun, as defined 
    # by the first char of the perseus 9-character pos tags. In the normal case, the lemma has only
    # one possible pos, e.g., it's a verb, so the return value is a singleton array containing a character.
    # If the lemma is not recognized, the return value can be an empty list. This can happen, e.g., if
    # the input was a Homeric lemma rather than Project Perseus's lemma.
    h = {}
    self.lemma_to_words(lemma).each { |e|
      word,pos = e
      h[pos[0]] = 1
    }
    return h.keys
  end

  def noun_to_gender(lemma)
    # Given a lemma for a noun, returns "m", "f", "n", or "c" for its gender. In cases where the treebank has the
    # noun tagged with more than one gender (e.g., ἔλαφος), we return "c" for common gender. There may be cases where a noun is
    # really common gender, but it only occurs as one gender in the corpus, so we incorrectly return a fixed gender.
    # If the lemma never occurs as a noun in the treebank, or it's never tagged by gender, we return nil.
    h = {}
    self.lemma_to_words(lemma).each { |e|
      word,pos = e
      next if pos[0]!='n'
      gender = pos[6]
      next if gender=='-'
      h[gender] = 1
    }
    if h.keys.length==0 then return nil end
    if h.keys.length==1 then return h.keys[0] end # this is the normal case
    return 'c'
  end

end
