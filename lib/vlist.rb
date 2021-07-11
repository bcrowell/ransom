class Vlist
# a vocabulary list

def initialize(list)
  # List is a list whose elements are lists of common, uncommon, and rare words.
  # Each element of a is a list of items of the form [word,lexical] or [word,lexical,data].
  @list = list
  list.each { |l| l.sort! { |a,b| alpha_compare(a[1],b[1]) } } # alphabetical order by lexical form
end

attr_reader :list
attr_accessor :console_messages

def to_s
  a = []
  @list.each { |l|
    x = alpha_sort(l.map{ |v| v[1] }).join(" ") # lemmas only
    a.push(x)
  }
  return a.join("\n")
end

def Vlist.from_text(t,lemmas_file,freq_file,thresholds:[30,50,700,900])
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
    lemma_entry = Vlist.get_lemma_helper(lemmas,word)
    if lemma_entry.nil? then whine.push("error: no index entry for #{word_raw}, key=#{word}"); next end
    lemma,lemma_number,pos,count,if_ambiguous,ambig = lemma_entry
    if if_ambiguous then 
      warn_ambig[word]= "warning: lemma for #{word_raw} is ambiguous, taking most common one; #{ambig}"
    end
    if lemma.nil? then whine.push("lemma is nil for #{word} in lemmas file"); next end
    if did_lemma.has_key?(lemma) then next end
    did_lemma[lemma] = 1
    rank = freq_rank[lemma]
    f = freq[lemma]
    entry = word_raw,word,lemma,rank,f,pos # word and word_raw are not super useful, in many cases will be just the first example in this passage
    #$stderr.print "entry=#{entry}\n"
    result.push(entry)
  }

  result.sort! { |a,b| b[4] <=> a[4] } # descending order by frequency

  threshold_difficult = thresholds[0] # words ranked lower than this may be glossed if they're difficult forms to recognize
  threshold_no_gloss = thresholds[1] # words ranked higher than this are not normally glossed
  threshold = thresholds[2] # words ranked higher than this are listed as common
  threshold2 = thresholds[3] # words ranked lower than this get ransom notes
  result2 = []
  ambig_warnings = []
  0.upto(2) { |commonness|
    this_part_of_result2 = []
    result.sort { |a,b| a[1] <=> b[1] } .each { |entry|
      word_raw,word,lemma,rank,f,pos = entry
      next if Ignore_words.patch(word) || Ignore_words.patch(lemma)
      next unless rank>=threshold_difficult
      is_3rd_decl = guess_whether_third_declension(word_raw,lemma,pos)
      difficult_to_recognize = is_3rd_decl
      next if rank<threshold_no_gloss && !difficult_to_recognize      
      next unless rank<threshold && commonness==0 or rank>=threshold && rank<threshold2 && commonness==1 or rank>=threshold2 && commonness==2
      #if lemma=~/(κύων|χείρ)/i then $stderr.print "============= doggies! is_3rd_decl=#{is_3rd_decl}, word_raw=#{word_raw}\n" end
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
        whine.push("no glossary entry for #{filename} -- contents would look like { \"word\":\"#{lemma}\",\"gloss\":\"\" }\n"+
                    "  https://en.wiktionary.org/wiki/#{lemma}")
      end
      if warn_ambig.has_key?(word) then ambig_warnings.push(warn_ambig[word]) end
      this_part_of_result2.push([word,lemma,{'is_3rd_decl' => is_3rd_decl}])
    }
    result2.push(this_part_of_result2)
  }
  whine = whine + ambig_warnings
  if whine.length>0 then
    whiny_file = "warnings"
    File.open(whiny_file,"w") { |f|
      whine.each { |complaint| f.print "#{complaint}\n" }
    }
  end
  vl = Vlist.new(result2)
  vl.console_messages = "#{whine.length} warnings written to the file #{whiny_file}\n"
  return vl
end

def Vlist.get_lemma_helper(lemmas,word)
  if lemmas.has_key?(word) then return lemmas[word] end
  if lemmas.has_key?(word.downcase) then return lemmas[word.downcase] end
  return nil
end

end # class Vlist

class Ignore_words
  # Words in the following list can be accented or unaccented, lemmatized or inflected. Case is nor significant. Accents are stripped.
  # If an inflected form is given here, then it will only match that inflected form.
  # First line is proper names.
  @@index = %q{
    λητους διος πηληιαδεω ατρειδα ατρειδης απολλων αιδι Χρύση Χρύσης αχιλλευς
    η τα τον ο τους αυτους
    επι ανα
    δυω πολλας δη
    κακος
  }.split(/\s+/).map { |x| remove_accents(x.downcase)}.to_set
  def Ignore_words.patch(word)
    w = remove_accents(word).downcase
    return @@index.include?(w)
  end

end

