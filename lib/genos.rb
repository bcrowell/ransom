# coding: utf-8
=begin
An object of the Genos class represents a particular language and dialect,
such as English or Homeric Greek. Variations such as dialects are implemented
using mixins.
=end

class Genos
  def initialize(lang,is_verse:false)
    # On input, language codes "grc" and "el" are treated as synonyms for "grc," and "he" for "hbo."
    if lang=='el' then lang='grc' end
    if lang=='he' then lang='hbo' end
    @lang = lang
    # Whatever string is returned by genos.script has to be the	name of	an appropriate latex environment.
    if ['en','la'].include?(@lang) then @script='latin' end
    if ['grc'].include?(@lang) then @script='greek' end
    if ['hbo'].include?(@lang) then @script='hebrew' end
    @is_verse = is_verse
  end

  attr_reader :is_verse,:lang,:script

  def to_s
    return "lang=#{@lang}, script=#{@script}"
  end

  def english() return (@lang=='en') end
  def latin() return (@lang=='la') end
  def greek() return (@lang=='grc') end
  def hebrew() return (@lang=='hbo') end

  def verbosity()
    # For use in making sanity checks more precise. A measure of how verbose this language is.
    return 1.0 if self.english()
    return 0.8 if self.greek() # possibly this is just for Homeric, which is probably terser than Attic or Koine?
    return 1.2 if self.latin()
    return 1.0
  end
  
end # class Genos

class AncientGreekRegion
  # This is only meant to describe periods before Koine. Koine was "supra-regional" ( https://en.wikipedia.org/wiki/Koine_Greek ).
  # https://en.wikipedia.org/wiki/File:AncientGreekDialects_(Woodard)_en.svg
  # The default is set up for Homer. If you want classical Attic, use eastern:true,attic:true.
  # If you want Doric or Achaean, use eastern:false.
  # To do: allow finer distinctions like Doric as distinguished from Achaean.
  def initialize(eastern:true,attic:false)
    @eastern = eastern
    @attic = attic
  end

  attr_reader :eastern,:attic
end

class GreekGenos < Genos
  @@period_labels = {'mycenaean'=>0, 'epic'=>1, 'attic'=>2, 'koine'=>3, 'medieval'=>4, 'νεα_ελληνικα'=>5} # https://en.wikipedia.org/wiki/Modern_Greek
  def initialize(period,is_verse:false,region:AncientGreekRegion.new())
    # See below for allowed values of the string period.
    super('grc',is_verse:is_verse)
    @period = @@period_labels[period]
    if @period.nil? then raise "unrecognized period: #{period}, allowed values are #{@@period_labels.keys.join(' ')}" end
    @region = region
  end

  attr_reader :period

  def period_name_to_number(name)
    return @@period_labels[name]
  end

  def to_s
    return "lang=#{@lang}, script=#{@script}, period=#{@@period_labels.invert[@period]}"
  end

  def has_sotera_rule
    # applies to Attic, Ionic, and koine according to
    #       https://referenceworks.brillonline.com/entries/encyclopedia-of-ancient-greek-language-and-linguistics/sotera-rule-SIM_000042?lang=en
    if @period>3 then return false end
    if !@region.eastern && @period<2 then return false end
    # ... not sure if this is precisely right, but apparently Doric doesn't have the sotera rule
    return true
  end

end # class GreekGenos

class LatinGenos < Genos
  @@period_labels = {'old'=>0, 'classical'=>1, 'late'=>2} # https://en.wikipedia.org/wiki/History_of_Latin
  def initialize(period,is_verse:false)
    # See below for allowed values of the string period.
    super('la',is_verse:is_verse)
    @period = @@period_labels[period]
    if @period.nil? then raise "unrecognized period: #{period}, allowed values are #{@@period_labels.keys.join(' ')}" end
  end

  attr_reader :period

  def period_name_to_number(name)
    return @@period_labels[name]
  end

  def to_s
    return "lang=#{@lang}, script=#{@script}, period=#{@@period_labels.invert[@period]}"
  end
end # class LatinGenos
