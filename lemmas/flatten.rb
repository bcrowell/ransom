def die(message)
  #  $stderr.print message,"\n"
  raise message # gives a stack trace
  exit(-1)
end

def clean_up_greek(s)
  s = s.sub(/σ$/,'ς').unicode_normalize(:nfc).sub(/&?απο[σς];/,"᾽")
  s = s.unicode_normalize(:nfc)
  s = clean_up_combining_characters(s)
  s2 = clean_up_beta_code(s)
  if s2!=s then
    $stderr.print "cleaning up what appears to be beta code, #{s} -> #{s2}\n"
    s = s2
  end
  if s=~/[^[:alpha:]᾽[0-9]\?;]/ then die("word #{s} contains unexpected characters; unicode=#{s.chars.map { |x| x.ord}}\n") end
  return s
end

def clean_up_combining_characters(s)
  combining_comma_above = [787].pack('U')
  greek_koronis = [8125].pack('U')
  s = s.sub(/#{combining_comma_above}/,greek_koronis)
  # ... mistaken use of combining comma above rather than the spacing version
  #     https://github.com/PerseusDL/treebank_data/issues/31
  # seeming one-off errors in perseus:
  s2 = s
  s2 = s2.sub(/#{[8158, 7973].pack('U')}/,"ἥ") # dasia and oxia combining char with eta
  s2 = s2.sub(/#{[8142, 7940].pack('U')}/,"ἄ") # psili and oxia combining char with alpha
  s2 = s2.sub(/#{[8142, 7988].pack('U')}/,"ἴ")
  s2 = s2.sub(/ἄἄ/,'ἄ') # why is this necessary...??
  s2 = s2.sub(/ἥἥ/,'ἥ') # why is this necessary...??
  s2 = s2.sub(/#{[769].pack('U')}([μτ])/) {$1} # accent on a mu or tau, obvious error
  s2 = s2.sub(/#{[769].pack('U')}ε/) {'έ'}
  s2 = s2.sub(/#{[180].pack('U')}([κ])/) {$1} # accent on a kappa, obvious error
  s2 = s2.sub(/#{[834].pack('U')}/,'') # what the heck is this?  
  s2 = s2.sub(/ʽ([ἁἑἱὁὑἡὡ])/) {$1} # redundant rough breathing mark
  # another repeating error:
  s2 = s2.sub(/(?<=[[:alpha:]][[:alpha:]])([ἀἐἰὀὐἠὠ])(?![[:alpha:]])/) { $1.tr("ἀἐἰὀὐἠὠ","αειουηω")+"᾽" }
  # ... smooth breathing on the last character of a long word; this is a mistake in representation of elision
  #     https://github.com/PerseusDL/treebank_data/issues/31
  if s2!=s then
    $stderr.print "cleaning up what appears to be an error in a combining character, #{s} -> #{s2}, unicode #{s.chars.map { |x| x.ord}} -> #{s2.chars.map { |x| x.ord}}\n"
    s = s2
  end
  return s
end

def clean_up_beta_code(s)
  # This was for when I mistakenly used old beta code version of project perseus.
  # Even with perseus 2.1, some stuff seems to come through that looks like beta code, e.g., ἀργει~ος.
  # https://github.com/PerseusDL/treebank_data/issues/30
  s = s.sub(/\((.)/) { $1.tr("αειουηω","ἁἑἱὁὑἡὡ") }
  s = s.sub(/\)(.)/) { $1.tr("αειουηω","ἀἐἰὀὐἠὠ") } 
  s = s.sub(/(.)~/) { $1.tr("αιυηω","ᾶῖῦῆῶ") } 
  s = s.sub(/\|/,'ϊ') 
  s = s.sub(/\/(.)/) { $1.tr("αειουηω","άέίόύήώ") }
  s = s.sub(/&θυοτ;/,'')
  s = s.sub(/θεοισ=ν/,'θεοῖσιν')
  s = s.sub(/ὀ=νοψ1/,'οἴνοπα1')
  s = s.sub(/π=ας/,'πᾶς')
  return s
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
      form = clean_up_greek(form)
      lemma = clean_up_greek(lemma)
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

results = results.sort

results.each { |a|
  print a.join(","),"\n"
}
