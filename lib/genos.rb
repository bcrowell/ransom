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
    if ['en','la'].include?(@lang) then @script='latin' end
    if ['grc'].include?(@lang) then @script='greek' end
    if ['hbo'].include?(@lang) then @script='hebrew' end
  end

  def english() return (@lang=='en') end
  def latin() return (@lang=='la') end
  def greek() return (@lang=='grc') end
  def hebrew() return (@lang=='hbo') end
  
end

class GreekGenos < Genos
  def initialize(period,is_verse:false)
    # See below for allowed values of the string period.
    super('grc',is_verse:is_verse)
    period_labels = {'mycenaean'=>0, 'epic'=>1, 'attic'=>2, 'koine'=>3, 'νεα_ελληνικα'=>4} # https://en.wikipedia.org/wiki/Modern_Greek
    @period = period_labels[period]
    if @period.nil? then raise "unrecognized period: #{period}, allowed values are #{period_labels.keys.join(' ')}" end
  end
end
