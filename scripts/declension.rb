require "json"
require_relative "../lib/treebank"

this_lemma = ARGV[0]
print "this lemma=#{this_lemma}\n"
exit(-1)

lemmas = TreeBank.new('homer').lemmas

# typical entry when there's no ambiguity:
#   "βέβασαν": [    "βαίνω",    "1",    "v3plia---",    1,    false,    null  ],

freq = {}
entry = lemmas[this_lemma]
if entry.nil? then
  print "lemma not found: #{this_lemma}\n"
  exit(-1)
end

lemma,lemma_number,pos,count,if_ambiguous,ambig = entry
if if_ambiguous then entries=ambig else entries = [[lemma,lemma_number,pos,count]] end

entries.each { |e2|
  lemma2,lemma_number2,pos2,count2 = e2
  lemma2 = lemma2.unicode_normalize(:nfc) # should have already been done, but make sure
  print sprintf("%15s %15s\n",)
}  

