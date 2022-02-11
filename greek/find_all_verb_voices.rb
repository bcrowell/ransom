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

categories = ['unclear','both','p','m']
results = {}
categories.each { |cat| results[cat]=[] }

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
  total = voices.values.sum
  next if voices['a']>0 || total<7
  # ... only print out deponent ones, and only judge them to be deponent if we have decent statistics
  deponent_type='unclear'
  if voices['p']==0 && voices['m']>0 then deponent_type='m' end
  if voices['m']==0 && voices['p']>0 then deponent_type='p' end
  if voices['m']>0 && voices['p']>0 then deponent_type='both' end
  results[deponent_type].push([parent,voices])
}

categories.each { |deponent_type|
  print "deponent_type=#{deponent_type}\n"
  results[deponent_type].each { |x|
    parent,voices = x
    gloss = Gloss.get(db,parent,prefer_length:1)
    if !gloss.nil? then gloss=gloss['gloss'] else gloss='' end
    daughters = families[parent].filter { |x| x!=parent }.join(',')
    if daughters!='' then daughters=" (#{daughters})" end
    #print "  ",parent,"  ",daughters,"                     #{voices.filter { |k,v| k!='a'} }\n"
    print "    ",parent,daughters," - #{gloss}\n"
  }
}



