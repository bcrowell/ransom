require 'json'
require 'sdbm'
require 'set'

require_relative "../lib/file_util"
require_relative "../lib/string_util"
require_relative "../lib/multistring"
require_relative "../lib/treebank"
require_relative "../lib/genos"
require_relative "../lib/frequency"
require_relative "../lib/gloss"
require_relative "../lib/clown"
require_relative "../greek/verbs"
require_relative "../greek/prepositions"
require_relative "../greek/lemma_util"
require_relative "../greek/writing"

author = "homer"
treebank = TreeBank.new(author)
foreign_genos = GreekGenos.new('epic')
db = GlossDB.from_genos(foreign_genos)


verbs = treebank.every_lemma_by_pos('v')

accent_lemma = {} # maps unaccented lemma to accented; needed because Preposition.prefix_to_verb doesn't know how to get accents right
verbs.each { |verb|
  accent_lemma[remove_accents(verb)] = verb
}

# Look for verbs that are a preposition plus some more basic parent verb.
parents = {}
Preposition.list_of_common.each { |prep|
  verbs.each { |parent|
    prefixed = Preposition.prefix_to_verb(prep,parent) # multistring
    #print "prep=#{prep}, parent=#{parent}, prefixed=#{prefixed}, prefixed.all_strings=#{prefixed.all_strings}\n" # qwe
    prefixed.all_strings.each { |s|
      s = remove_accents(s)
      if accent_lemma.has_key?(s) then parents[accent_lemma[s]] = parent end
    }
  }
}

families = {}
verbs.each { |verb|
  parent = parents[accent_lemma[remove_accents(verb)]] # may be nil
  if parent.nil? then parent=verb end
  if !families.has_key?(parent) then families[parent] = [] end
  families[parent].push(verb)
}

alpha_sort(families.keys).each { |parent|
  families[parent].each { |daughter|
    f = treebank.every_form_of_lemma(daughter,'v')
    if daughter=='ἄγω' then print f end
  }
  #print families[parent],"\n"
}


