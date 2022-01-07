# coding: utf-8

=begin
class WiktionaryGlosses -- accesses wiktextract entries from a file on disk
class GenerateWiktionary -- generates wiktionary entries from my gloss files
=end

class GenerateWiktionary
  
  def GenerateWiktionary.generate(gloss,treebank)
    # Inputs: gloss is a hash in the format returned by Gloss.get.
    # returns [lemma,text,if_err,error_code,error_message]
    possible_lemmas = [gloss['word'],gloss['perseus']]
    # ...It's OK if perseus gloss is nil.
    if WiktionaryGlosses.has_gloss(possible_lemmas) then return [nil,nil,true,'exists',"entry exists already as one of: #{possible_lemmas}"] end
    # ...This only tests against the weekly wiktextract download, not the current live version.
    pos_list = treebank.lemma_to_pos(lemma)
    if pos_list.length>1 then return [nil,nil,true,'ambiguous_pos',"POS is ambiguous: #{pos_list}"] end
    pos = pos_list[0]
    if pos=='n' then gender=treebank.noun_to_gender(lemma) end
    pos_long = {'n'=>'noun','v'=>'verb','a'=>'adjective','d'=>'adverb'}[pos]
    if pos_long.nil? then return [nil,nil,true,'unsupported_pos',"unsupported part of speech: #{pos}"] end
    if gloss.has_key?('perseus') then lemma=gloss['perseus']; alt=gloss['word'] else lemma=gloss['word']; alt=nil end
    # ... go with Perseus's judgment as to what is the proper general-purpose lemma
    pieces = []
    pieces.push("==Ancient Greek==")
    if !(alt.nil?) then
      pieces.push("===Alternative forms===\n* #{alt} (epic)")
    end
    if gloss.has_key?('etym') then
      pieces.push("===Etymology===\n#{gloss['etym']}")
    end
    pieces.push("===Pronunciation===\n{{grc-IPA}}")
    pieces.push("===#{pos_long.capitalize}===\n{{grc-#{pos_long}}}")
    english = nil
    possible_lemmas.each { |l|
      next if l.nil?
      english = Gloss.get(l,prefer_length:2)
      break unless english.nil?
    }
    if english.nil? then return [nil,nil,true,'gloss_not_found',"no gloss found for lemmas: #{possible_lemmas}"] end
    english.split(/;/).each { |d|
      # I've tried to do a consistent style in which entirely separate senses are separated by semicolons
      pieces.push("# #{d}")
    }
    return [lemma,pieces.join("\n\n"),false,nil,nil]
  end
end

class WiktionaryGlosses

filename = "wiktextract/grc_en.json"

@@glosses = {}
@@unaccented_index = {}
if not File.exists?(filename) then
  $stderr.print %q{
    Warning: file #{filename} not found, so we won't be able to give automatic suggestions of glosses.
    See wiktextract/notes.txt re how to create this file.
    This has no effect on production of the pdf files. It just makes it more work to create glosses for new pages.
    }
else  
  # $stderr.print "Reading #{filename}...\n"
  IO.foreach(filename) { |line|
    x = JSON.parse(line)
    w = remove_macrons_and_breves(x['word']).downcase # should be the lexical form
    @@glosses[w] = x
    unaccented = remove_accents(w)
    if !(@@unaccented_index.has_key?(unaccented)) then @@unaccented_index[unaccented]=[] end
    @@unaccented_index[unaccented].push(w)
  }
  # $stderr.print "...done\n"
end

# Typical entry:
# {"pos":"noun",
#  "heads":[{"1":"ἄποινᾰ","2":"ἀποίνων","3":"n-p","4":"second","template_name":"grc-noun"}],
#  "forms":[{"form":"ἄποινᾰ","tags":["canonical"]},{"form":"ápoina","tags":["romanization"]},{"form":"ἀποίνων","tags":["genitive"]}],"inflection":[{"1":"ᾰ̓́ποινον","2":"ου","form":"P","template_name":"grc-decl"}],
#  "word":"ἄποινα",
#  "lang_code":"grc",
#  "senses":[
#    {
#      "glosses":["ransom"],"id":"ἄποινα-noun-lt.FvtvU"
#      "tags":["neuter","plural","plural-only","second-declension"],
#      "synonyms":[{"word":"λύτρα"}],
#    },
#    {
#      "glosses":["compensation (recompense or reward for some loss or service)"],"id":"ἄποινα-noun-EztcciPc"
#      "tags":["neuter","plural","plural-only","second-declension"],
#    }
#  ]
# }

def WiktionaryGlosses.has_gloss(possible_lemmas)
  # possible_lemmas is a list of strings; if any are nil, they're silently ignored; this is to allow for cases where there is a Homeric
  # lemma and also a different lemma used by Perseus's treebank for that Homeric form
  possible_lemmas.each { |lemma|
    next if lemma.nil?
    if !(WiktionaryGlosses.get_glosses(lemma).nil?) then return true end
  }
  return false
end

def WiktionaryGlosses.get_glosses(lexical)
  # Input is a lemmatized form, whose accents are significant, but not its case or macrons and breves.
  # Output is an array of strings, possibly empty.
  key = remove_macrons_and_breves(lexical).downcase
  return [] if !(@@glosses.has_key?(key))
  a = @@glosses[key]
  return [] if !(a.has_key?('senses'))
  glosses = []
  a['senses'].each { |s|
    if s.has_key?('glosses') then glosses = glosses+s['glosses'] end # is usually a singleton array
  }
  return [] if glosses.length==0
  glosses = glosses.map { |x| x.sub(/\A(to|I) /,'')}
  return glosses
end

# {"pos":"noun","heads":[{"head":"χᾰλῑνός",
# a={"pos"=>"noun", "heads"=>[{"head"=>"χᾰλῑνός", 

def WiktionaryGlosses.macronized(lexical_possibly_unaccented)
  # used by the macronize.rb script
  # Input is a lemmatized form. If input doesn't have accents, an attempt will be made to disambiguate.
  # Output is [found,macronized,err]. If there is no macronized string available, then found is false and an error message is in err.
  ok,lexical,err = WiktionaryGlosses.disambiguate_unaccented_lemma(lexical_possibly_unaccented)
  if !ok then return [false,nil,""] end
  key = remove_macrons_and_breves(lexical).downcase
  return [false,nil,"key #{lexical} not found"] if !(@@glosses.has_key?(key))
  a = @@glosses[key]
  return [false,nil,"no heads found for key #{lexical}"] if !(a.has_key?('heads'))
  a['heads'].each { |x|
    x.each_pair { |k,v|
      if remove_macrons_and_breves(v)==lexical && v!=lexical then return [true,v,nil] end
    }
  }
  return [false,nil,"no macronized head found for key #{key}, a=#{a}"]
end

def WiktionaryGlosses.disambiguate_unaccented_lemma(lexical_possibly_macronized)
  # Allows convenience features where the user can type in words without accents and do a query, as in the macronize.rb script.
  lexical = remove_macrons_and_breves(lexical_possibly_macronized)
  unaccented = remove_accents(lexical)
  if unaccented!=lexical then return [true,lexical,nil] end # doesn't need to be disambiguated
  if !(@@unaccented_index.has_key?(unaccented)) then return [false,nil,"no accented entry found to match unaccented input #{lexical}"] end
  a = @@unaccented_index[unaccented]
  if a.length>1 then return [false,nil,"unaccented input #{lexical} is ambiguous, could be any of: #{a}"] end
  return [true,@@unaccented_index[unaccented][0]]
end

end
