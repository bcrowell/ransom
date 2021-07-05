def die(message)
  #  $stderr.print message,"\n"
  raise message # gives a stack trace
  exit(-1)
end

def clean_up_greek(s)
  # Some cases where cltk fails to convert beta code correctly, maybe because the beta code syntax wasn't legal.
  # https://github.com/PerseusDL/treebank_data/issues/30
  s = s.sub(/\((.)/) { $1.tr("αειουηω","ἁἑἱὁὑἡὡ") }
  s = s.sub(/\)(.)/) { $1.tr("αειουηω","ἀἐἰὀὐἠὠ") } 
  s = s.sub(/(.)~/) { $1.tr("αιυηω","ᾶῖῦῆῶ") } 
  s = s.sub(/\|/,'ϊ') 
  s = s.sub(/\/(.)/) { $1.tr("αειουηω","άέίόύήώ") }
  s = s.sub(/&θυοτ;/,'')
  s = s.sub(/σ$/,'ς').unicode_normalize(:nfc).sub(/&?απο[σς];/,"᾽")
  s = s.sub(/θεοισ=ν/,'θεοῖσιν')
  s = s.sub(/ὀ=νοψ1/,'οἴνοπα1')
  s = s.sub(/π=ας/,'πᾶς')
  if s=~/[^[:alpha:]᾽[0-9]\?;]/ then die("word #{s} contains unexpected characters\n") end
  return s
end

$text,$book,$near_line = nil,nil,nil

$stdin.each_line { |line|
  if line=~/<sentence/ then
    if line=~/Perseus:text:1999.01.0133/ then $text="iliad" end
    if line=~/Perseus:text:1999.01.0135/ then $text="odyssey" end
    if line=~/book=(\d+)/ then $book=$1 end
    if line=~/card=(\d+)/ then $near_line=$1 end
    #print "text=#{$text}, $book=#{book}, line=#{$near_line}\n"
  end
  if line=~/<word/ then
    count = 0
    data = {}
    ["form","lemma","postag"].each { |tag|
      if line=~/#{tag}="([^"]*)"/ then data[tag]=$1; count+=1 end
    }
    form,lemma,pos = [data['form'],data['lemma'],data['postag']]
    next if form=='' || lemma=~/πυνξ\d/
    if count<3 then die("only #{count} tags found in line #{line}") end
    next unless form=~/[[:alpha:]]/ && lemma=~/[[:alpha:]]/
    if form=~/,/ || lemma=~/,/ || pos=~/,/ then die("oh no, a comma in line #{line}") end
    form = clean_up_greek(form)
    lemma = clean_up_greek(lemma)
    which_lemma = ''
    if lemma=~/(\d+)$/ then which_lemma=$1 end
    lemma.gsub!(/(\d+)$/,'')
    next if lemma=~/\?/
    a = [$text,$book,$near_line,form,lemma,which_lemma,pos]
    print a.join(","),"\n"
  end
}
