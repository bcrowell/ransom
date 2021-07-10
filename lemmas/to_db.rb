require 'json'
require 'sdbm' # part of the standard ruby distribution, https://en.wikipedia.org/wiki/DBM_(computing)

log_file = "homer_lemmas.log"
json_file = "homer_lemmas.json"
sdbm_file = "homer_lemmas" # gets expanded to two files, .dir and .pag

def die(message)
  #  $stderr.print message,"\n"
  raise message # gives a stack trace
  exit(-1)
end

# input is csv:
# iliad,1,1,ἄειδε,ἀείδω,1,v2spma---
# output is a hash where key is a word and value is [lemma,lemma_number,pos,count,if_ambiguous,ambig].
# If if_ambiguous is true, then ambig is a list of possible lemmas, each in the format [lemma,lemma_number,pos,count],
# but the most common lemma is the one listed in front.

table = {}
# intermediate format, hash of lists of entries of the format [lemma,lemma_number,pos,count]
$stdin.each_line { |line|
  next unless line=~/[[:alpha:]]/
  line.sub!(/\n/,'')
  a = line.split(/,/)
  if a.length!=7 then die("csv has wrong length, line=#{line}") end
  text,book,near_line,word,lemma,lemma_number,pos = a
  next unless word=~/[[:alpha:]]/
  seen_before = nil
  if table.has_key?(word) then
    j = 0
    table[word].each { |x|
      lemma2,lemma_number2,pos2 = x
      if lemma2.downcase==lemma.downcase && lemma_number2==lemma_number then seen_before=j; break end
      # Don't require POS to be the same. Sometimes the same lemmatization is recorded with slightly different POS tags, e.g.:
      #   ῥίγιον,,a-s---nn-
      #   ῥίγιον,,a-s---nnc
      # Don't require case to be the same, e.g., they have both αἰνείας and Αἰνείας, which are just redundant.
      j += 1
    }
  end
  if seen_before.nil?
    if lemma.downcase==lemma then word=word.downcase end
    entry = [lemma,lemma_number,pos,1]
    if table.has_key?(word) then table[word].push(entry) else table[word] = [entry] end
  else
    old_lemma = table[word][j][0]
    if lemma.downcase!=lemma && old_lemma.downcase==old_lemma then
      # Sometimes they fail to capitalize the lemma for a proper noun. Fix this.
      table[word][j][0].sub!(/^(.)/) {$1.upcase}
    end
    table[word][j][3] += 1 # bump count
  end
}

if false then
table.keys.sort.each { |word|
  print "#{word}\n"
  table[word].each { |entry|
    lemma,lemma_number,pos,count = entry
    print "  #{lemma},#{lemma_number},#{pos},#{count}\n"
  }
}
end

db = {}
table.keys.sort.each { |word|
  x = table[word]
  if x.length==1 then
    lemma,lemma_number,pos,count = x[0]
    db[word] = [lemma,lemma_number,pos,count,false,nil]
  else
    x = x.sort { |a,b| b[3] <=> a[3] } # descending order by count
    lemma,lemma_number,pos,count = x[0] # most common one
    db[word] = [lemma,lemma_number,pos,count,true,x]
  end
}

print "writing log to #{log_file}\n"

File.open(log_file,'w') { |f|
  db.keys.sort.each { |word|
    x = db[word]
    lemma,lemma_number,pos,count,if_ambiguous,ambig = x
    f.print "#{word} : #{lemma},#{lemma_number},#{pos},#{count},#{if_ambiguous},#{ambig}\n"
  }
}

print "writing json version to #{json_file}\n"

File.open(json_file,'w') { |f|
  f.print JSON.pretty_generate(db)
}

if false then

stringified_db = {}
db.keys.sort.each { |word|
  stringified_db[word] = JSON.generate(db[word])
}

print "writing sdbm database to #{sdbm_file}.*\n"

SDBM.open(sdbm_file) { |disk_db|
  disk_db.clear
  disk_db.update(stringified_db)
}

else
  print "not writing sdbm files\n"

end