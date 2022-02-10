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

families = Verb_util.find_all_families(treebank)

alpha_sort(families.keys).each { |parent|
  voices = { 'a'=>0, 'p'=>0, 'm'=>0, 'e'=>0 }
  families[parent].each { |daughter|
    f = treebank.every_form_of_lemma(daughter,'v')
    f = f.map { |x| [x[0],Vform.new(x[1])] }
    #if daughter=='ἄγω' then print f end
    f.each { |x|
      voice = x[1].voice
      next if voice=='-' # can happen for infinitives that are ambiguous, e.g., ἀγασσάμενοι
      if !voices.has_key?(voice) then raise "illegal voice #{voice}, #{x}" end
      voices[voice] += 1
    }
  }
  next if voices['a']>0 # only print out deponent ones
  print parent,"  ",families[parent].join(','),"  #{voices}\n"
}


