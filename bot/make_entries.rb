require 'json'
require 'set'
require_relative '../lib/treebank'
require_relative '../lib/gloss'
require_relative '../lib/file_util'
require_relative '../lib/string_util'
require_relative '../lib/wiktionary'

# This has to be run from the main directory.

treebank = TreeBank.new('homer')

#l = ["κεραίζω"]
# Homeric κεραΐζω

l = Gloss.all_lemmas(prefer_perseus:true)

#l = ['ἔλαφος','λέων','χήρα','λύω']
# ... use with force:true

l.each { |lemma|
  gloss = Gloss.get(lemma,prefer_length:2)
  if gloss.nil? then raise "no gloss found by Gloss.get for lemma #{lemma}" end
  lemma2,text,if_err,error_code,error_message = GenerateWiktionary.generate(gloss,treebank)
  next if if_err && (error_code=='exists' || error_code=='unclear_lemma')
  #print "#{lemma} #{lemma2}\n"
  if if_err then
    #print "error for #{lemma}: #{error_message}\n"
  else
    print "%%%%%%%%%%%%%%%%%%%%%%%% #{lemma2} %%%%%%%%%%%%%%%%%%%%%%%%\n",text
  end
}


