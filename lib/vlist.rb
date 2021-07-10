class Vlist
# a vocabulary list

def initialize(list)
  # List is a list whose elements are lists common, uncommon, and rare words.
  # Each element of a is a list of items of the form [word,lexical].
  @list = list
  list.each { |l| l.sort! { |a,b| alpha_compare(a[1],b[1]) } } # alphabetical order by lexical form
end

attr_reader :list

def to_s
  a = []
  @list.each { |l|
    x = alpha_sort(l.map{ |v| v[1] }).join(" ") # lemmas only
    a.push(x)
  }
  return a.join("\n")
end

def file_list(commonness)
  return self.list[commonness].map { |item| remove_accents(item[1]).downcase }
end

def Vlist.from_text(t,lemmas_file,freq_file,thresholds:[700,1700])
  lemmas = json_from_file_or_die(lemmas_file)
  # typical entry when there's no ambiguity:
  #   "βέβασαν": [    "βαίνω",    "1",    "v3plia---",    1,    false,    null  ],
  freq = json_from_file_or_die(freq_file)
  freq_list = freq.to_a
  freq_list.sort! { |a,b| b[1] <=> a[1]} # descending order by frequency; is probably already sorted, so this will be fast
  # ... a list of pairs like [["δέ", 12136], ["ὁ" , 5836], ...]
  whine = []

  t.gsub!(/\d/,'')
  t.gsub!(/᾽(?=[[:alpha:]])/,"᾽ ") # e.g., ποτ᾽Ἀθήνη
  t = t.unicode_normalize(:nfc)

  freq_rank = {}
  rank = 1
  freq_list.each { |a|
    lemma,count = a
    freq_rank[lemma] = rank
    rank += 1
  }

  result = []
  did_lemma = {}
  warn_ambig = {}
  t.scan(/[^\s—]+/).each { |word_raw|
    word = word_raw.gsub(/[^[:alpha:]᾽']/,'')
    next unless word=~/[[:alpha:]]/
    if !(lemmas.has_key?(word)) then whine.push("error: no index entry for #{word_raw}, key=#{word}"); next end
    lemma,lemma_number,pos,count,if_ambiguous,ambig = lemmas[word]
    if if_ambiguous then 
      warn_ambig[word]= "warning: lemma for #{word_raw} is ambiguous, taking most common one; #{ambig}"
    end
    if lemma.nil? then whine.push("lemma is nil for #{word} in lemmas file"); next end
    if did_lemma.has_key?(lemma) then next end
    did_lemma[lemma] = 1
    rank = freq_rank[lemma]
    f = freq[lemma]
    entry = word_raw,word,lemma,rank,f,pos # word and word_raw are not super useful, in many cases will be just the first example in this passage
    result.push(entry)
  }

  result.sort! { |a,b| b[4] <=> a[4] } # descending order by frequency

  threshold = thresholds[0] # words ranked higher than this are listed as common
  threshold2 = thresholds[1] # words ranked lower than this get ransom notes
  result2 = []
  0.upto(2) { |commonness|
    this_part_of_result2 = []
    result.sort { |a,b| a[1] <=> b[1] } .each { |entry|
      word_raw,word,lemma,rank,f,pos = entry
      next if Ignore_words.patch(word) || Ignore_words.patch(lemma)
      next unless rank<threshold && commonness==0 or rank>=threshold && rank<threshold2 && commonness==1 or rank>=threshold2 && commonness==2
      next unless rank>100
      key1 = remove_accents(word).downcase
      key2 = remove_accents(lemma).downcase
      filename1 = "glosses/#{key1}"
      filename2 = "glosses/#{key2}"
      if FileTest.exist?(filename1) then
        key=key1
      else
        if FileTest.exist?(filename2) then
          key=key2
        else
          key=key1
        end
      end
      filename = "glosses/#{key}"
      if !(FileTest.exist?(filename)) then
        if key1==key2 then foo=key1 else foo="#{key1} or #{key2}" end
        whine.push("no entry for #{foo}")
      end
      if warn_ambig.has_key?(word) then whine.push(warn_ambig[word]) end
      this_part_of_result2.push([word_raw,lemma])
    }
    result2.push(this_part_of_result2)
  }
  return Vlist.new(result2)
end

end # class Vlist

class Ignore_words
  @@index = [
    # Words in the following list can be accented or unaccented. Accents are stripped.
    "η","τα","τον","ο","τους","αυτους",
    "επι","ανα",
    "δυω","πολλας","δη",
    "λητους","διος","πηληιαδεω","ατρειδα","ατρειδης","απολλων","αιδι", # proper nouns
    "κακος"
  ].to_set
  def Ignore_words.patch(word)
    return @@index.include?(remove_accents(word).downcase)
  end
end
