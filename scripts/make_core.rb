require "json"
require "set"
require "./lib/string_util.rb"
require "./lib/file_util.rb"
require "./lib/gloss.rb"
require "./lib/genos.rb"
require "./lib/vlist.rb"
require "./greek/lemma_util.rb"

=begin

This script is basically meant to be run once. It generates a list of
about 400 core vocab words for Homer. Words are taken from a certain
range of the frequency list tabulated for lemmas, and which gets
modified if they are on three hand-made lists embedded below in the
code.  To execute this script, do "make core".

=end

freq_file = "lemmas/homer_freq.json"
freq = json_from_file_or_die(freq_file)

=begin
{ ...
"γόνυ" : 122,
"ὠκύς" : 120,
"θάλασσα" : 119,
... }

very common words, 'scum words':
  These tend to be particles that are hard to define, pronouns, common prepositions.
  Freq of about 500 is roughly where half the words are in this category.
  After that, they die out from freq of about 300 to about 100.
  I have a hand-constructed list of these below.
  I don't call a word scum if it would otherwise be in the right frequency range, and is also possible to define in a brief gloss
  (but many words like μέν and ἄν are not).
good core words:
  most common of these: "ἀνήρ" : 1039,
  least common of these: "πατήρ" : 54, ... the 526th lemma on the list
'goofy' words:
  These are words that are omitted in order to avoid bulking up the list too much
  with things like specialized military terms and compounds. The idea is to make
  the list represent something more like a basic level of linguistic competence
  rather than a mechanically constructed frequency-based list like the one by
  Owen and Goodspeed. For example, if the reader has some background in modern,
  koine, or Attic Greek, we would like the core list to align somewhat with the
  kind of background they have.
words_added_by_hand:
  A good candidate for this list could be:
  -A word that occurs more frequently in compounds, derived terms, or multiple forms than
   would be indicated by its low frequency as an independent word (e.g., μῆτις, λέχος, ἥμισυς, χῶρος, ἐλεέω).
  -A word for a basic human concept that one should know in any
   language one is learning (e.g., ἀδελφός, γελάω).
super_easy:
  Like words_added_by_hand, but is for words that, although not particularly frequent or important, are
  very easy to learn, usually because it has obvious cognates.
Words in these lists, below, have to be given as the Perseus lemma (e.g., κλισία, not
κλισίη), or there will be an error.
=end

max_freq = 1039
min_freq = 54

# see above for criteria
words_added_by_hand = (<<-'BY_HAND'
ἀείδω ἀμείνων ἁνδάνω ἄποινα ἅπτω ἀράομαι ἀρητήρ ἀρχός βούλομαι γεραιός γέρας ἔρομαι ἤτοι
ἱερεύς ἱερόν ἱστός κήδω κῆδος λέχος μάντις ναός τιμάω ἀτιμάω τιμή τίνω χερείων
κρατέω κρίνω γηθέω σῶς βαρύς ὀνομάζω αἰδέομαι χώομαι χραισμέω μῆτις γελάω
ἀδελφός δάω ἀίω πέρθω εἴδω εὐνάω ἥμισυς μήν μόνος νεφέλη ὅρκος ὅρκιον ὄμνυμι
ἄγχι σχεδόν πονέω κάμνω τέλος
τρεῖς τέσσαρες δέκα ἑκατόν νεῖκος χῶρος ἐλεέω ἑκών
κλισία κράτος βουλεύω τέμνω βαθύς οὕτως φώς ἐρίζω ἔρδω μάν
δεύω ἠύτε κλισία ἔρις
BY_HAND
).split(/\s+/)

super_easy = (<<-'SUPER_EASY'
κλέπτω γλῶσσα σκῆπτρον ἑκατόμβη καρδία ὄρνις
SUPER_EASY
).split(/\s+/)

# see def above
scum = (<<-'SCUM'
δή ἕ ἐκ ἀτάρ κατά ἤ μιν μή πέρ ἠδέ
παρά ἀπό ὑπό ὅδε ὅτε ἦ μετά περί
πρός αὖτε ἀμφί ἐμός οὗτος ἔτι ἑός
τότε ὦ ἀνά σύν σός διά ἵνα
ἤδη ὅτι ὧδε τῷ τόσος
ὅθι τοῖος αὐτοῦ ὁπότε
ὑπέρ πως εἷς ἆρα οὔτε πρό ὅπως τίς
εἰς εἰ ὅσος ἐκεῖνος κεῖνος ἄμφω αὔτως ἠμέν ἐπεί ὅστις
SCUM
).split(/\s+/)

# words that are more common than πατήρ but seem too weird to be on the core list; often these are compound verbs,
# military terms, or words that occur in Homer's favorite set phrase
goofy = (<<-'GOOFY'
προσαυδάω πτερόεις βροτός δῆμος
ἀμφότερος ἀσπίς γλαυκῶπις
κῆρυξ πυκνός γλαφυρός φαεινός κάρα
μίγνυμι πέπνυμαι σάκος μεγάθυμος
κλυτός ὗς εἰσοράω ἀμφίπολος νήπιος
φαίδιμος καταλέγω πυνθάνομαι
μεγαλήτωρ κονία μετεῖπον τόφρα
κατακτείνω λυγρός ἀντίθεος ὄχος
εὕδω ἀργαλέος ἐπέρχομαι ἐρύκω
δαίφρων περίφρων ὀδύρομαι χρή
ἐπιτέλλω αἰγίοχος περικαλλής
χαλεπός ὀιστός ὀπίσω ἐπιβαίνω
GOOFY
).split(/\s+/)

contradiction = (scum | goofy) & (words_added_by_hand | super_easy)
if contradiction.length>0 then
  $stderr.print "words in words_added_by_hand or super_easy are also present in scum or goofy: #{contradiction}\n"
  exit(-1)
end

words = freq.keys.sort { |a,b| freq[b] <=> freq[a] }.select { |w| freq[w]<=max_freq && freq[w]>=min_freq }
words = words.to_set.merge((words_added_by_hand | super_easy).to_set).to_a
words = words.select { |w| w==w.downcase }.select { |w| w!='υνκνοων'}


words = words.select { |w| ! (scum.include?(w) || goofy.include?(w))}

#print words,"\n"

greek_genos = GreekGenos.new('epic')
db = GlossDB.from_genos(greek_genos)

glosses = {}
words.each { |w|
  if w=='πάτηρ' then w='πατήρ' end # Perseus has vocative πάτηρ as its own lemma???
  data = Gloss.get(db,w) # change optional arg prefer_length if I want the long def
  # This should never result in a warning to stderr about ambiguity, because if the same lemma string has two senses, I define them as not
  # an ambiguity. If a warning occurs, it means I've erroneously constructed a gloss file with two glosses having the same lemma string.
  # Return value looks like the following. The item lexical exists only if this is supposed to be an entry for the inflected form.
  # {  "word"=> "ἔθηκε",  "gloss"=> "put, put in a state",  "lexical"=> "τίθημι", "file_under"=>"ἔθηκε" }
  if data.nil? then $stderr.print "gloss not found for #{w}\n"; exit(-1) end
  if data.nil? then
    g=nil
  else
    g = [data['gloss']]
    if data.has_key?('mnemonic_cog') then g.push(data['mnemonic_cog']) end
  end
  if !data.has_key?('word') then $stderr.print "gloss for #{w} has no word key, data=#{data}\n"; exit(-1) end
  preferred_form = data['word'] # e.g., if w='ξένος', then switch this to ξείνος
  glosses[preferred_form] = g
}

print (<<-'COMMENT'
// This file is generated by doing a 'make core'. Don't edit it by hand
COMMENT
)+ JSON.pretty_generate(glosses)+"\n"

# Used to do sorting like this, but now that values are arrays, it doesn't work...?
#)+ JSON.pretty_generate(Hash[*glosses.sort { |a,b| alpha_compare(a[0],b[0])}.flatten])+"\n"

words.select { |w| !freq[w].nil? }.sort.each { |w|
  if freq[w].nil? then $stderr.print "WARNING: word #{w} has no frequency data; make sure all words are Perseus lemmas, which will be translated into the correct Homeric forms automatically\n" end
}

freq_report = "core/homer.freq"
File.open(freq_report,"w") { |f|
  f.print words.select { |w| !freq[w].nil? }.sort_by { |w| [-freq[w],w] }.map { |w| "#{w} #{freq[w]}\n" }.join()
  alpha_sort(words).each { |w|
    if freq[w].nil? then f.print "#{w} ?\n" end
  }
  $stderr.print "frequency analysis written to #{freq_report}\n"
}

$stderr.print "total core words: #{words.length}\n"

