class Word

=begin
An object of this class encapsulates the data about a word that would go into 
an interlinear text. Example:
  menis
  Μῆνιν
  rage
  ACC
testing:
  ruby -e "require './greek/writing.rb'; require './lib/genos.rb'; require './lib/string_util.rb'; require './lib/word.rb'; require './lib/tagzig.rb'; w=Word.new(Genos.new('grc'),'μῆνιν',Tagzig.from_perseus('n-s---fa-'),'rage'); print w"
=end

def initialize(genos,word,pos,gloss)
  # Word is the original word in the text; can be a transliteration if there will be no presentation in the original writing system.
  # Pos is a Tagzig object, e.g., showing that the word is a verb in the passive voice.
  # When the word is to be presented both in the original writing system and in transliteration, that's worked out later, not in this constuctor.
  # Gloss is an optional gloss; can be nil.
  @genos = genos
  @word = word
  @pos = pos
  @gloss = gloss # can be nil
  if genos.greek then @romanization=Writing.romanize(word) else @romanization=nil end
end

attr_reader :genos,:word,:pos,:gloss,:romanization

def to_a(format:'wrgp')
  # returns an array whose elements are strings or nil, based on the fields in the given format
  h = self.to_h
  result = []
  format.chars.each { |field|
    result.push(h[field])
  }
  return result
end

def to_h
  # returns a hash whose keys are one-character codes and whose values are strings or nil
  return {'w'=>self.word,'r'=>self.romanization,'g'=>self.gloss,'p'=>self.pos.to_s}
end

def to_s
  list = self.to_a
  list = list.filter { |x| !x.nil? }
  return list.join(' ')
end

end
