=begin

An object of the Hop class represents a particular inflected form of a
Greek verb.  All the information needed in order to conjugate it is
supposed to be encapsulated here: period, region, person, tense,
whether it's a participle, etc. The methods of the class are meant to
allow us to hop from one form to another, similar form, e.g., to
change a first-person form to a third-person form. It's designed to be
reliable, to give some indication of the reliability of its result,
and to be able to explain how it got its result.

=end

class Hop
  def initialize(word,pos,genos:GreekGenos.new('epic'),lemma:nil)
    # word is a unicode string
    # genos is a Genos object
    # pos is a Vform object (verbs.rb) saying what part of speech it is (number, tense, etc.)
    # lemma is a unicode string, if necessary in order to disambiguate
    # preposition is a unicode string, which can be supplied if auto_detect_preposition is false
    @word = word
    @genos = genos
    @pos = pos
    @lemma = lemma
    @preposition_is_detached = false
    @preposition = nil # means we don't know whether it has a preposition or not
    @history = []
  end

  attr_accessor :word,:genos,:pos,:lemma,:preposition_is_detached,:preposition,:history

  def to_s
    s = "#{@word} #{@pos}"
    if @preposition_is_detached then s="#{@preposition}- + "+s end
    return s
  end

  def detach_preposition
    # testing:
    #   ruby -e 'require "./lib/load_common"; require "./greek/load_common"; print Hop.new("αφίημι",Vform.new("v1spia---")).detach_preposition()'
    return self if @preposition_is_detached
    has_preposition,prefix,stem,preposition = Preposition.recognize_prefix(@word,genos:@genos)
    if !has_preposition then return self end
    if !@lemma.nil? then
      a = Preposition.recognize_prefix(@lemma,genos:@genos)
      if !a[0] then return self end # can remove preposition from inflected form, but not from lemma
    end
    x = self.morph("Separate the preposition #{preposition} from the stem #{stem}.")
    x.word = stem
    if !@lemma.nil? then x.lemma = a[2] end
    x.preposition_is_detached = true
    x.preposition = preposition
    x.adjust_accent
    return x
  end

  def adjust_accent
    is_recessive = false
    if @pos.infinitive || @pos.participle then is_recessive end
    # ... FIXME: this is oversimplified
    if is_recessive then
      n_syllables = Syllab.ify(@word,genos:@genos).length
      k = [2,n_syllables-1].max
    else
      k = Syllab.locate_accent(@word,genos:@genos) # This may not mean a no-op ... could invoke sotera rule.
    end
    @word = Syllab.move_accent_to(@word,k,vform:@pos,genos:@genos)
  end

  def morph(explanation)
    x = clown(self)
    x.history.push(explanation)
    return x
  end

end
