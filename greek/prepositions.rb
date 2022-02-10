module Preposition
  def Preposition.prefix_to_verb(prep,verb)
    # Doesn't attempt to get accent or breathing mark right, won't work if the verb has an augment.
    # Preposition should be provided in lemmatized form, meaning ἐκ rather than ἐξ, ἐν rather than ἐνί.
    # Returns a Multistring.
    # to do: phoneticize verb and handle stuff like από+ἵημι
    verb_phoneticized = Writing.phoneticize(verb)
    first_letter = remove_accents(verb_phoneticized[0]).downcase
    if first_letter=~/hαειουηω/ then vowel=true else vowel=false end
    if prep=='ἐκ' then
      return Multistring.new('ἐξ'+verb) if vowel
      return Multistring.new('ἐγ'+verb) if first_letter=~/βδλμ/
    end
    if prep=='ἐν' then
      return Multistring.new('ἐμ'+verb) if first_letter=~/βμπφψ/
      return Multistring.new('ἐγ'+verb) if first_letter=~/γκξχ/
      return Multistring.new([['ἐν','ἐνι'],[verb]]) # we do get forms like ἐνιπλήξωμεν
    end
    # I'm not sure if the following rules about π->φ are 100% right, but this seems like what's happening based on dictionary entries.
    if first_letter=='h' then
      return Multistring.new('ἀφ'+verb) if prep=='ἀπό'
      return Multistring.new('ἐφ'+verb) if prep=='ἐπί'
      return Multistring.new('ὑφ'+verb) if prep=='ὑπό'
    end
    if prep=='σύν' then return Multistring.new([['σύν','ξύν'],[verb]]) end # Homeric ξύν
    if prep=='ἀνά' && vowel then return Multistring.new('ἀν'+verb) end # Homeric ξύν
    # Fall through to default:
    return Multistring.new(prep+verb)
  end
end
