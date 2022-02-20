class Tagzig

=begin
A class that encapsulates the kind of part-of-speech tagging that is described in the
Leipzig Glossing Rules for morpheme-by-morpheme interlinear text,
https://www.eva.mpg.de/lingua/resources/glossing-rules.php .
=end

def initialize(pos,data)
  # pos should be a Project Perseus one-character part-of-speech tag, e.g., 'v' for verb, 't' for participle, ...
  # data is a hash such as {'tense'=>'f','mood'=>'o'}, again structured as in perseus
  # Key 'number' can have a value that is either an integer or a one-character string such as '3'.
  # A lot of the semantics and intended idiomatic usages here depend on the fact that in ruby only nil and false evaluate to a logical false.
  @pos = pos
  if data['number'].class==1.class then data['number']=data['number'].to_s end
  # info for verbs; any of these may be nil on input to the constructor, and in any case will be stored as nil if not the marked value
  @tense  = data['tense']  if data['tense'] && data['tense']!='p'
  @mood   = data['mood']   if data['mood']  && data['mood']!='i'
  @voice  = data['voice']  if data['voice'] && data['voice']!='a'
  @person = data['person'] if data['person'] && data['person']!='3'
  # info shared by nouns and verbs; singular is considered to be unmarked
  @number = data['number'].to_i if data['number'] && data['number']!='3'
  # info for nouns and adjectives
  @gender = data['gender']
  @case = data['case']
  @degree = data['degree']
end

# The following return nil if they're the unmarked possibility, e.g., if mood is indicative.
# So "if tag.mood then ..." executes something if the mood is not indicative.
attr_reader :pos,:tense,:mood,:voice,:person,:number,:gender,:case,:degree

def from_perseus(pos)
  data = {}
  {'person'=>1,'number'=>2,'tense'=>3,'mood'=>4,'voice'=>5,'gender'=>6,'case'=>7,'degree'=>8}.each_pair { |key,val|
    c = pos[val]
    data[key] = c if c!='-'
  }
  return Tagzig.new(pos[0],data)
end

end
