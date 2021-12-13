require "json"
require "set"
require "./lib/string_util.rb"
require "./lib/file_util.rb"
require "./lib/gloss.rb"
require "./lib/vlist.rb"

# This script is basically meant to be run once. It generates a list of about
# 350 core vocab words for Homer. Words are taken from a certain range of
# the frequency list tabulated for lemmas, and then excluded if they are
# on either of a couple of hand-made lists embedded below in the code.
# If a word has no gloss, an attempt is made to generate one in the help_gloss
# subdirectory (currently turned off for speed).
# To execute this script, do "make core".

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
good core words:
  most common of these: "ἀνήρ" : 1039,
  least common of these: "πάτηρ" : 54, ... the 526th lemma on the list

=end

max_freq = 1039
min_freq = 54

# see def above
scum = (<<-'SCUM'
δή ἕ ἐκ ἀτάρ κατά ἤ μιν μή πέρ ἠδέ
παρά ἀπό ὑπό ὅδε ὅτε ἦ μετά περί
πρός αὖτε ἀμφί ἐμός οὗτος ἔτι ἑός
τότε ὦ ἅμα ἀνά τοι σύν σός διά ἵνα
αὖ πού ἤδη ὅτι ὧδε τῷ πω τόσος ἤτοι
ὅθι οὕτως τοῖος αὐτοῦ ὁπότε οὖν
ὑπέρ πως εἷς ἆρα οὔτε πρό ὅπως τίς ἠέ
εἰς εἰ ὅσος ἐκεῖνος κεῖνος ἄμφω αὔτως ἠμέν ἐπεί ὅστις
SCUM
).split(/\s/)

# words that are more common than πάτηρ but seem too weird to be on the core list; often these are compound verbs,
# military terms, or words that occur in Homer's favorite set phrase
goofy = (<<-'GOOFY'
προσαυδάω πτερόεις βροτός δῆμος
ἀμφότερος οτηερ ἀσπίς γλαυκῶπις φώς
κῆρυξ πυκνός γλαφυρός φαεινός κάρα
μίγνυμι πέπνυμαι σάκος μεγάθυμος
κλυτός ὗς εἰσοράω ἀμφίπολος νήπιος
φαίδιμος καταλέγω πυνθάνομαι
μεγαλήτωρ κονία μετεῖπον τόφρα
κατακτείνω λυγρός ἀντίθεος ὄχος
εὕδω ἀργαλέος ἐπέρχομαι ἐρύκω
δαίφρων περίφρων ὀδύρομαι χρή
ἐπιτέλλω αἰγίοχος περικαλλής
χαλεπός ὀιστός ὀπίσω ἐπιβαίνω καρδια
GOOFY
).split(/\s/)

words = freq.keys.sort { |a,b| freq[b] <=> freq[a] }.select { |w| freq[w]<=max_freq && freq[w]>=min_freq }
words = words.select { |w| w==w.downcase }.select { |w| w!='υνκνοων'}


words = words.select { |w| ! (scum.include?(w) || goofy.include?(w))}

#print words,"\n"

glosses = {}
words.each { |w|
  data = Gloss.get(w,w) # change optional arg prefer_length if I want the long def
  # Return value looks like the following. The item lexical exists only if this is supposed to be an entry for the inflected form.
  # {  "word"=> "ἔθηκε",  "gloss"=> "put, put in a state",  "lexical"=> "τίθημι", "file_under"=>"ἔθηκε" }
  if data.nil? then g=nil else g = data['gloss'] end
  glosses[w] = g
}

words.each { |w|
  print "#{w},#{glosses[w]}\n"
}

if true then
  require "./lib/wiktionary.rb"
  gloss_help = []
  # The following code is mostly a copy of code from vlist.rb.
  words.each { |lemma|
    if glosses[lemma].nil? then
      key = remove_accents(lemma).downcase
      filename = "glosses/#{lemma}"
      gloss_help.push({
        'filename'=>key,
        'lemma'=>lemma,
        'url'=> "https://en.wiktionary.org/wiki/#{lemma} https://logeion.uchicago.edu/#{lemma}",
        'wikt'=> WiktionaryGlosses.get_glosses(lemma).join(', ')
      })
      if gloss_help.length>0 then
        Vlist.give_gloss_help(gloss_help) # prints message to stderr as side effect
      end
    end
  }
end
