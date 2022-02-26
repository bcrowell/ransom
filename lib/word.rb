class Word

=begin
An object of this class encapsulates the data about a word that would go into 
an interlinear text. Example:
  mênin
  Μῆνιν
  rage
  ACC
testing:
  ruby -e "require './greek/writing.rb'; require './lib/genos.rb'; require './lib/string_util.rb'; require './lib/word.rb'; require './lib/tagzig.rb'; w=Word.new(Genos.new('grc'),'μῆνιν',Tagzig.from_perseus('n-s---fa-'),'rage'); print w"
=end

def initialize(genos,word,pos,gloss,lemma:nil,punctuated:nil)
  # Word is the original word in the text; can be a transliteration if there will be no presentation in the original writing system.
  # Pos is a Tagzig object, e.g., showing that the word is a verb in the passive voice.
  # When the word is to be presented both in the original writing system and in transliteration, that's worked out later, not in this constuctor.
  # Gloss is an optional gloss; can be nil.
  @genos = genos
  @word = word
  @pos = pos
  @gloss = gloss # can be nil
  if genos.greek then @romanization=Writing.romanize(word) else @romanization=nil end
  @lemma = lemma
  @punctuated = punctuated
end

attr_reader :genos,:word,:pos,:gloss,:romanization,:lemma
attr_accessor :punctuated

def to_a(format:'wrgpl',nil_to_null_string:false,remove_nils:false)
  # returns an array whose elements are strings or nil, based on the fields in the given format.
  # key 'w' is treated
  h = self.to_h
  result = []
  format.chars.each { |field|
    result.push(h[field])
  }
  if nil_to_null_string then result = result.map { |x| if x.nil? then '' else x end } end
  if remove_nils then result = result.filter { |x| !x.nil? } end
  return result
end

def to_h
  # Returns a hash whose keys are one-character codes and whose values are strings or nil.
  # Key 't' has a value that is the version of the word from the treebank, without punctuation.
  # Value 'w' is the punctuated value from the text, if available, or else a copy of the value for 't'.
  h = {'t'=>self.word,'r'=>self.romanization,'g'=>self.gloss,'p'=>self.pos.to_s,'l'=>self.lemma}
  if !self.punctuated.nil? then h['w']=self.punctuated else h['w']=self.word end
  return h
end

def to_s
  list = self.to_a
  list = list.filter { |x| !x.nil? }
  return list.join(' ')
end

end
