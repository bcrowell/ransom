require "../lib/string_util.rb"

def die(message)
  #  $stderr.print message,"\n"
  raise message # gives a stack trace
  exit(-1)
end

def patch(a)
  inflected = a[3]
  lemma = a[4]
  pos = a[6]

  patched_lemma = nil

  if inflected=='φυλάξομεν' && a[0]=='iliad' then patched_lemma='φυλάσσω' end
  # iliad,8,529,φυλάξομεν,φυλάζω,,v1pfia---
  # This should be φυλάσσω. (φυλάζω is a different verb with a meaning that doesn't make sense here.)
  # https://github.com/PerseusDL/treebank_data/issues/33

  if lemma=='Ἀί' then patched_lemma='Ἄϊδος' end
  if lemma=='βουλεύς' then patched_lemma='βουλή' end
  if lemma=='αἶσις' then patched_lemma='αἶσα' end
  # ... Cunliffe's entry for αἶσα refers to both Α416 and Α418. There is a river Αἶσις, and possibly also a personification of fate.
  if lemma=='σιμοείσιος' then patched_lemma='Σιμόεις' end

  # Simple typos by Perseus:
  if lemma=='ἐυκνψμις' then patched_lemma='ἐυκνήμις' end
  if lemma=='ἐυκϝήμις' then patched_lemma='ἐυκνήμις' end
  if lemma=='ϝέκταρ' then patched_lemma='νέκταρ' end
  if lemma=='ἱππόσυνος' then patched_lemma='ἱπποσύνη' end
  if lemma=='σοί' then patched_lemma='ἐγω' end # Iliad 1.170

  if lemma=='χάλκειος' then patched_lemma='χάλκεος' end # not clear to me why Cunliffe and Perseus both lemmatize this separately

  # Lemmas that are just redundant; Perseus invents a different lemma because the form is different. Other sources like Cunliffe
  # don't give these as head-words:
  if lemma=='δαίτη' then patched_lemma='δαίς' end
  if lemma=='δαίτης' then patched_lemma='δαίς' end
  if lemma=='νευρή' then patched_lemma='νευρά' end
  if lemma=='ἐυμελίης' then patched_lemma='ἐυμμελίης' end
  if lemma=='ἥλιος' then patched_lemma='ἠέλιος' end
  if lemma=='πολλός' then patched_lemma='πολύς' end
  if lemma=='ἀλκί' then patched_lemma='ἀλκή' end
  if lemma=='βοείη' then patched_lemma='βόειος' end
  if lemma=='ἐλύω' then patched_lemma='εἰλύω' end
  if lemma=='ἐργαθεῖν' then patched_lemma='ἔργω' end
  if lemma=='ζάω' then patched_lemma='ζώω' end # The latter is the form almost always used in Homer.
  if lemma=='ζυγός' then patched_lemma='ζυγόν' end
  if lemma=='ζώς' then patched_lemma='ζωός' end
  if lemma=='ἡνιοχεύς' then patched_lemma='ἡνίοχος' end
  if lemma=='πρόσθεϝ' then patched_lemma='πρόσθεν' end
  if lemma=='πρυμνόν' then patched_lemma='πρύμνα' end
  if lemma=='χραύω' then patched_lemma='χράω' end

  # Lemmas that are different, but in an obvious way. No reason for learners to learn them separately.
  if lemma=='ἑλώριον' then patched_lemma='ἕλωρ' end
  if lemma=='ῥινόν' then patched_lemma='ῥινός' end

  # Redundant lemmas, one just looks like a mistake:
  if lemma=='ὀνειρόπολος' then patched_lemma='ὀνειροπόλος' end # Iliad 1.63 and 5.149
 
  # Redundant lemmas, one for an Attic form and one for an epic one:
  if lemma=='ῥόα' && inflected=='ῥοάων' then patched_lemma='ῥοή' end # There is also Attic ῥόα=pomegranate, epic ῥοιή.

  # Redundant lemma based on the genitive stem:
  if lemma=='καλλιγύναικος' then patched_lemma='καλλιγύναιξ' end
  if lemma=='κόρσης' then patched_lemma='κόρση' end
  if lemma=='λεχεποίης' then patched_lemma='λεχεποίη' end
  if lemma=='χαλκοῦς' then patched_lemma='χαλκός' end

  # Feminine form of an adjective lemmatized separately:
  if lemma=='θοῦρις' then patched_lemma='θοῦρος' end # θοῦρις is feminine
  if lemma=='ἱερή' then patched_lemma='ἱερός' end
  if lemma=='μέλαινα' then patched_lemma='μέλας' end
  if lemma=='χαλκεία' then patched_lemma='χάλκεος' end

  # Redundant lemmas for verbs, both active and passive:
  if lemma=='παραλέγω' then patched_lemma='παραλέχομαι' end
  

  # For the following, the neuter adjective in -ον is used as ad adverb, and Cunliffe lemmatizes it under ths -ος headword.
  # Perseus creates a separate -ον lemma, which is redundant, and also gives a POS analysis as a noun, which is weird.
  if lemma=='ἀντίον' then patched_lemma='ἀντίος' end
  if lemma=='ἄριστον' then patched_lemma='ἄριστος' end

  if lemma=='ὄσσα' && pos[2]=='d' then patched_lemma='ὄσσε' end
  # iliad,3,427,ὄσσε,ὄσσα,,n-d---na-
  # https://www.textkit.com/greek-latin-forum/viewtopic.php?t=71621

  if lemma=='κραναός' && inflected=='Κραναῇ' then patched_lemma='Κρανάη' end
  # iliad,3,445,Κραναῇ,κραναός,,a-s---fd-
  # OCT, Cunliffe, and Buckley all read this as a proper noun. The lemma Κρανάη is Buckley's.


  if !patched_lemma.nil? then a[4]=patched_lemma end
  return a
end

script = ARGV[0]
# ... latin or greek

$stderr.print "script=#{script}\n"
if script!='latin' && script!='greek' then die("illegal script: #{script}") end

book_and_chapter=true
# ... if true, then subdoc tags are expected to be of the form "x.y" as for Homer; if false, then simply "x" as for Petronius

old_book = nil

$text,$book,$line = nil,nil,nil

results = []

$stdin.each_line { |line|
  if line=~/urn:cts:greekLit:tlg0012.tlg001.perseus-grc1.tb/ then $text="iliad" end
  if line=~/urn:cts:greekLit:tlg0012.tlg002.perseus-grc1.tb/ then $text="odyssey" end
  if line=~/urn:cts:latinLit:phi0972.phi001.perseus-lat1.tb/ then $text="satyricon"; book_and_chapter=false end
  if line=~/urn:cts:latinLit:phi0448.phi001.perseus-lat1.tb.xml/ then $text="caesar"; book_and_chapter=false end
  if line=~/urn:cts:latinLit:phi0474.phi013.perseus-lat1.tb.xml/ then $text="cicero"; book_and_chapter=false end
  if line=~/urn:cts:latinLit:phi0690.phi003.perseus-lat1.tb.xml/ then $text="vergil"; book_and_chapter=false end
  if line=~/urn:cts:latinLit:phi0959.phi006.perseus-lat1.tb.xml/ then $text="ovid"; book_and_chapter=false end
  if line=~/urn:cts:latinLit:phi1351.phi005.perseus-lat1.tb.xml/ then $text="tacitus"; book_and_chapter=false end
  if line=~/<sentence/ then
    if book_and_chapter && line=~/subdoc="(\d+)\.(\d+)/ then
      #     <sentence subdoc="1.1-1.2" id="2185541" document_id="urn:cts:greekLit:tlg0012.tlg002.perseus-grc1">
      $book,$line = $1,$2
    end
    if !book_and_chapter && line=~/subdoc="(\d+)/ then
      #     <sentence id="1" document_id="urn:cts:latinLit:phi0972.phi001.perseus-lat1" subdoc="26">
      $book = $1
    end
    if $book!=old_book then $stderr.print "text=#{$text}, book=#{$book}\n"; old_book=$book end
  end
  if line=~/<word/ && ! (line=~/(insertion_id|artificial)/) then
    count = 0
    data = {}
    ["form","lemma","postag","cite"].each { |tag|
      if line=~/#{tag}="([^"]*)"/ then data[tag]=$1; count+=1 end
    }
    form,lemma,pos,cite = [data['form'],data['lemma'],data['postag'],data['cite']]
    next if form=='' || lemma=~/πυνξ\d/ || lemma=~/\&/
    if count<3 then die("only #{count} tags found in line #{line}") end
    next unless form=~/[[:alpha:]]/ && lemma=~/[[:alpha:]]/
    # E.g., in Petronius we have lemma='delibero,' ...???
    form.gsub!(/,/,'')
    lemma.gsub!(/,/,'')
    if form=~/,/ || lemma=~/,/ || pos=~/,/ then die("oh no, a comma in line #{line}, pos=#{pos}, lemma=#{lemma}, form=#{form}") end
    if script=='greek' then
      form = clean_up_greek(form,thorough:true,silent:false)
      lemma = clean_up_greek(lemma,thorough:true,silent:false)
    end
    if cite=~/(\d+)\.(\d+)$/ then $book,$line = $1,$2 end
    which_lemma = ''
    if lemma=~/(\d+)$/ then which_lemma=$1 end
    lemma.gsub!(/(\d+)$/,'')
    next if lemma=~/\?/
    a = [$text,$book.to_i,$line.to_i,form,lemma,which_lemma,pos]
    results.push(a)
  end
}

results = results.sort { |a,b| [a[0],a[1]] <=> [b[0],b[1]]}

results.each { |a|
  a = patch(a)
  print a.join(","),"\n"
}
