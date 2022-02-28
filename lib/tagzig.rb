class Tagzig

=begin
An object of this class encapsulates the kind of part-of-speech tagging that is described in the
Leipzig Glossing Rules for morpheme-by-morpheme interlinear text,
https://www.eva.mpg.de/lingua/resources/glossing-rules.php .
=end

def initialize(pos,data)
  # If you want to create a Tagzig object directly from a 9-character Perseus POS tag, don't use this, use from_perseus().
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
  @number = data['number'] if data['number'] && data['number']!='s'
  # info for nouns and adjectives
  @gender = data['gender']
  @case = data['case']
  @degree = data['degree']
end

def Tagzig.from_perseus(pos)
  data = {}
  {'person'=>1,'number'=>2,'tense'=>3,'mood'=>4,'voice'=>5,'gender'=>6,'case'=>7,'degree'=>8}.each_pair { |key,val|
    c = pos[val]
    data[key] = c if c!='-'
  }
  return Tagzig.new(pos[0],data)
end

def ==(y)
  # Sometimes the same lemmatization is recorded with slightly different POS tags, e.g.:
  #   ῥίγιον,,a-s---nn-
  #   ῥίγιον,,a-s---nnc
  #   ρίγιον,,a-s---n-c ... but note the lack of a rough breathing mark on this one ...!?!?
  # This logic is duplicated in to_db/rb.
  if self.super_identical(y) then return true end
  if !self.first_seven_identical(y) then return false end
  return (self.case==y.case || self.case=='-' || y.case=='-') \
         && (self.degree==y.degree || self.degree=='-' || y.degree=='-')
end

def super_identical(y)
  return false if !self.first_seven_identical(y)
  return false if self.case!=y.case
  return false if self.degree!=y.degree
  return true
end

def first_seven_identical(y)
  return false if self.pos!=y.pos
  return false if self.person!=y.person
  return false if self.number!=y.number
  return false if self.tense!=y.tense
  return false if self.mood!=y.mood
  return false if self.voice!=y.voice
  return false if self.gender!=y.gender
  return true
end

# The following return nil if they're the unmarked possibility, e.g., if mood is indicative.
# So "if tag.mood then ..." executes something if the mood is not indicative.
attr_reader :pos,:tense,:mood,:voice,:person,:number,:gender,:case,:degree

def to_s
  list = []
  list.push(self.person) if self.person
  list.push(Tagzig.number_to_s(self.number)) if self.number
  list.push(Tagzig.tense_to_s(self.tense)) if self.tense
  list.push(Tagzig.mood_to_s(self.mood)) if self.mood
  list.push(Tagzig.voice_to_s(self.voice)) if self.voice
  list.push(self.gender) if self.gender && self.pos!='n'
  list.push(Tagzig.case_to_s(self.case)) if self.case
  # doesn't stringify comparative or superlative
  list = list.filter { |x| !x.nil? }
  if list.length==0 then
    return Tagzig.pos_to_s(self.pos)
  else
    return list.join('.')
  end
end

def Tagzig.pos_to_s(pos)
  result = {'n'=>'noun','v'=>'verb','t'=>'ptcp','a'=>'adj','d'=>'adv','l'=>'art','g'=>'pcl',
            'c'=>'conj','r'=>'prep','p'=>'pron','m'=>'num','i'=>'interj','e'=>'excl','u'=>'punct','x'=>'?'}[pos]
  # The use of x is not in the perseus documentation; I think it must be a marker for ambiguous cases; it occurs
  # for forms of τίς, τέττα, τέκμωρ, ὕπαρ.
  if result.nil? then return pos.upcase else return result.upcase end
end

def Tagzig.number_to_s(number)
  return {'s'=>'sing','p'=>'pl','d'=>'dual'}[number]
end

def Tagzig.tense_to_s(tense)
  return {'p'=>'PRS','i'=>'IMPF','r'=>'PF','l'=>'PLPF','t'=>'FUT PF','f'=>'FUT','a'=>'AOR'}[tense]
end

def Tagzig.mood_to_s(mood)
  return {'i'=>'IND','s'=>'SBJV','o'=>'OPT','n'=>'INF','m'=>'IMPV','p'=>'PTCP'}[mood]
end

def Tagzig.voice_to_s(voice)
  return {'a'=>'ACT','p'=>'PASS','m'=>'MID','e'=>'MP'}[voice]
end

def Tagzig.case_to_s(the_case)
  return {'n'=>'NOM','g'=>'GEN','d'=>'DAT','a'=>'ACC','v'=>'VOC','l'=>'LOC'}[the_case]
end

end
