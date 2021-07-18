class WiktionaryGlosses

filename = "wiktextract/grc_en.json"

@@glosses = {}
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


end