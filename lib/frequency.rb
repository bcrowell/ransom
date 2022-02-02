class Frequency
  # The most useful method is rank(), which returns a hash of the form {"δέ"=>1, "ὁ"=>2, ...}, where the keys are
  # dictionary lemmas and each value is that lemma's rank in terms of frequency. This is convenient because you don't
  # need to do any normalization based on the size of the corpus.
  def initialize(filename)
    @hash = json_from_file_or_die(filename) # hash(lemma) gives the raw number of occurrences of the lemma in the corpus; not normalized
    @sorted = @hash.to_a.sort! { |a,b| b[1] <=> a[1]} # descending order by frequency; is probably already sorted, so this will be fast
    # ... a list of pairs like [["δέ", 12136], ["ὁ" , 5836], ...]
    @rank_hash = {}
    r = 1
    @sorted.each { |a|
      lemma,count = a
      @rank_hash[lemma] = r
      r += 1
    }
  end
  attr_reader :hash,:sorted,:rank_hash
  def rank(lemma)
    # If the lemma didn't occur in the corpus, then the return value will be nil. This should be treated as indicating a
    # rare word.
    return @rank_hash[lemma]
  end
end
