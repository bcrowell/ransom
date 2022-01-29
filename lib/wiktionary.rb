# coding: utf-8

=begin
class WiktionaryGlosses -- accesses wiktextract entries from a file on disk
=end


class WiktionaryGlosses

filename = "wiktextract/grc_en.json"

@@glosses = {}
@@unaccented_index = {}
if not File.exists?(filename) then
  $stderr.print %Q{
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
    if WiktionaryGlosses.get_glosses(lemma).length>0 then return true end
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
