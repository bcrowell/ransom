module Preposition
  def Preposition.list_of_common
    # FIXME: make a more complete list by searching perseus data
    return ['ἐκ','ἐν','ἀπό','ἐπί','ὑπό','σύν','ἀνά','κατά','πρό','πρός','διά','ὑπέρ']
  end

  def Preposition.prefix_to_verb(prep,verb)
    # Doesn't attempt to get accent or breathing mark right, won't work if the verb has an augment.
    # Preposition should be provided in lemmatized form, meaning ἐκ rather than ἐξ, ἐν rather than ἐνί.
    # Returns a MultiString.
    # to do: phoneticize verb and handle stuff like από+ἵημι
    verb_phoneticized = Writing.phoneticize(verb)
    first_letter = remove_accents(verb_phoneticized[0]).downcase
    if first_letter=~/hαειουηω/ then vowel=true else vowel=false end
    if prep=='ἐκ' then
      return MultiString.new('ἐξ'+verb) if vowel
      return MultiString.new('ἐγ'+verb) if first_letter=~/βδλμ/
    end
    if prep=='ἐν' then
      return MultiString.new('ἐμ'+verb) if first_letter=~/βμπφψ/
      return MultiString.new('ἐγ'+verb) if first_letter=~/γκξχ/
      return MultiString.new([['ἐν','ἐνι'],[verb]]) # we do get forms like ἐνιπλήξωμεν
    end
    # I'm not sure if the following rules about π->φ are 100% right, but this seems like what's happening based on dictionary entries.
    if first_letter=='h' then
      return MultiString.new('ἀφ'+verb) if prep=='ἀπό'
      return MultiString.new('ἐφ'+verb) if prep=='ἐπί'
      return MultiString.new('ὑφ'+verb) if prep=='ὑπό'
    end
    if prep=='σύν' then return MultiString.new([['σύν','ξύν'],[verb]]) end # Homeric ξύν
    if prep=='ἀνά' && vowel then return MultiString.new('ἀν'+verb) end # Homeric ξύν
    if prep=='διά' && vowel then return MultiString.new('δι'+verb) end # Homeric ξύν
    # Fall through to default:
    return MultiString.new(prep+verb)
  end
end
