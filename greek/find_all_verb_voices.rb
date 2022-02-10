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


print treebank.every_lemma_by_pos('v')


