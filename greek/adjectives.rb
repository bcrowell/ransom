module Adjective
  temp = (<<-'IRREG'
  ἀγαθός;κρείσσων,λωίων;ἄριστος,κράτιστος
  κακός;χείρων,ἥσσων;
  μέγας;μείζων;
  μικρός;ἐλάσσων;ἐλάχιστος;
  ῥᾴδιος;ῥᾴων,ῥηίων;ῥᾷστος;
  ταχύς;θάσσων;
  IRREG
  ).split(/\s+/).filter { |x| x!='' }.map { |x| x.split(/;/).map { |y| y.split(/,/)} }
  @@irregular_comparatives = {}
  temp.each { |line|
    @@irregular_comparatives[line[0][0]] = [line[1],line[2]]
  }
  #$stderr.print @@irregular_comparatives
  def Adjective.test()
    # make test, which does this:
    #   ruby -e "require './greek/adjectives.rb'; require './lib/multistring.rb'; require './lib/string_util.rb'; Adjective.test()"
    tests = [
      ['θᾶσσον','ταχύς','c',true],
      ['δηλότερος','δῆλος','c',false],
    ]
    tests.each { |x|
      comparative_inflected,lemma,degree,desired = x
      result = Adjective.is_irregular_comparative(comparative_inflected,lemma,degree)
      if (result!=desired) then flag="***************** error ***************" else flag='' end
      print(sprintf("%10s %10s %s %s %s %s\n",comparative_inflected,lemma,degree,result.to_s,desired.to_s,flag))
      #     θᾶσσον      ταχύς c false true ***************** error ***************
    }
  end
  def Adjective.is_irregular_comparative(comparative_inflected,lemma,degree)
    # This is very conservative about what it labels as irregular. It's only labeled irregular if it appears to match pretty
    # closely with one of the words on our list of irregular comparatives.
    # degree is 'c' for comparative or 's' for superlative, as in perseus POS tags
    return false unless @@irregular_comparatives.has_key?(lemma)
    if degree=='c' then index=0 else index=1 end
    candidates = @@irregular_comparatives[lemma][index] # possible irregular lemmas of which comparative_inflected may be a form
    return false if candidates.nil?
    reg_stem = remove_accents(lemma).sub(/(ος|ας|υς)$/,'')
    candidates.each { |x|
      # x is irregular lemma
      irreg_stem = remove_accents(x).sub(/(ων|ος)$/,'')
      lcs = MultiString.longest_common_subsequence(reg_stem,irreg_stem)
      return true if lcs<=reg_stem.length/2 && lcs<reg_stem.length
    }
    return false # innocent unless proved guilty
  end
end
