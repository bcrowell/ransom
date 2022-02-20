class Tagzig

=begin
An object of this class encapsulates the kind of part-of-speech tagging that is described in the
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

def to_s
  list = []
  list.push(self.person) if self.person
  list.push(self.number) if self.number
  list.push(Tagzig.tense_to_s(self.tense)) if self.tense
  list.push(Tagzig.mood_to_s(self.mood)) if self.mood
  list.push(Tagzig.voice_to_s(self.voice)) if self.voice
  list.push(self.gender) if self.gender
  list.push(Tagzig.case_to_s(self.case)) if self.case
  # doesn't stringify comparative or superlative
  list = list.filter { |x| !x.nil? }
  return list.join('.')
end

def Tagzig.tense_to_s(tense)
  return {'p'=>'PRS','i'=>'IMPF','r'=>'PF','l'=>'PLPF',t=>'FUT PF','f'=>'FUT','a'=>'AOR'}[tense]
end

def Tagzig.mood_to_s(mood)
  return {'i'=>'IND','s'=>'SBJV','o'=>'OPT','n'=>'INF','m'=>'IMP','p'=>'PTCP'}[mood]
end

def Tagzig.voice_to_s(voice)
  return {'a'=>'ACT','p'=>'PASS','m'=>'MID','e'=>'MP'}[voice]
end

def Tagzig.case_to_s(the_case)
  return {'n'=>'NOM','g'=>'GEN','d'=>'DAT','a'=>'ACC','v'=>'VOC','l'=>'LOC'}[the_case]
end

end
