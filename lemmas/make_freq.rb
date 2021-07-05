require "json"

lemmas = nil
File.open("homer_lemmas.json","r") { |f| 
  lemmas=JSON.parse(f.gets(nil))
}

# typical entry when there's no ambiguity:
#   "βέβασαν": [    "βαίνω",    "1",    "v3plia---",    1,    false,    null  ],

freq = {}
lemmas.each { |word,entry|
  lemma,lemma_number,pos,count,if_ambiguous,ambig = entry
  if if_ambiguous then entries=ambig else entries = [[lemma,lemma_number,pos,count]] end
  entries.each { |e2|
    lemma2,lemma_number2,pos2,count2 = e2
    lemma2 = lemma2.unicode_normalize(:nfc) # should have already been done, but make sure
    if !(freq.has_key?(lemma2)) then freq[lemma2] = 0 end
    freq[lemma2] += count2
  }  
}

data = []
freq.keys.sort { |a,b| freq[b]<=>freq[a] }.each { |lemma|
  data.push("\"#{lemma}\" : #{freq[lemma]}")
}
print "{\n"+data.join(",\n")+"\n}\n"
