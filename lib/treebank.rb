# This class provides a wrapper for the Project Perseus treebank data.
# Could also be expanded to give convenient access to the line-by-line data in the .csv file.

class TreeBank
  def initialize(corpus)
    if corpus!='homer' then $stderr.print "warning: unrecognized corpus #{corpus}\n" end
    data_dir = "#{Dir.home}/Documents/programming/ransom/lemmas"
    @lemmas_file = "#{data_dir}/#{corpus}_lemmas.json"
    @lemmas = json_from_file_or_die(@lemmas_file)
    @inverse_index = nil
  end
  attr_reader :lemmas,:lemmas_file

  def word_to_lemma_entry(word)
    if @lemmas.has_key?(word) then return @lemmas[word] end
    if @lemmas.has_key?(word.downcase) then return @lemmas[word.downcase] end
    return nil
  end

  def word_to_lemmas(word)
    # Returns an array of entries for possible lemmas; in most cases the array will be a singleton.
    # Elements are of the form [lemma,pos_tag], where pos_tag is a 9-character Project Perseus tag.
    x = self.word_to_lemma_entry(word)
    if x.nil? then return [] end
    if !x[4] then return [[x[0],x[2]]] end # not ambiguous
    return x[5].map { |a| [a[0],a[2]] }
  end

  def lemma_to_words(lemma)
    # Given a lemma, returns a list whose elements are of the form [word,pos], or returns nil.
    if @inverse_index.nil? then
      @inverse_index = {}
      @lemmas.keys.each { |word|
        word_to_lemmas(word).each { |e|
          lemma2,pos = e
          if !(@inverse_index.has_key?(lemma2)) then @inverse_index[lemma2]=[] end
          @inverse_index[lemma2].push([word,pos])
        }
      }
    end
    return @inverse_index[lemma]
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
      print "word=#{word}, pos=#{pos}\n" # qwe
      h[pos[0]] = 1
    }
    return h.keys
  end

end
