require "../lib/string_util.rb"

def die(message)
  #  $stderr.print message,"\n"
  raise message # gives a stack trace
  exit(-1)
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
  print a.join(","),"\n"
}
