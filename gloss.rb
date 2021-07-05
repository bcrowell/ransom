#!/bin/ruby
# coding: utf-8

require 'oily_png'  # ubuntu package ruby-oily-png
require 'set'
require 'json'

require_relative "lib/file_util"
require_relative "lib/string_util"
require_relative "lib/clown"

# Given a block of text input from stdin, output :
# (1) a list of lexical forms and their frequencies, and
# (2) eruby code to generate a glossary.

def main
  t = $stdin.gets(nil)
  lemmas = json_from_file_or_die("ιλιας.lemmas")
  freq_list = json_from_file_or_die("ιλιας.freq_lem")

  t.gsub!(/\d/,'')
  t.gsub!(/᾽(?=[[:alpha:]])/,"᾽ ") # e.g., ποτ᾽Ἀθήνη
  t = t.unicode_normalize(:nfc)

  freq_list.sort! { |a,b| b[1] <=> a[1]} # descending order by frequency; is probably already sorted, so this will be fast
  freq = {}
  norm = 0
  # Make the frequency list into a hash. If we have duplicates, combine them. This happens when we have apostrophes.
  freq_list.each { |a|
    lemma,count = a
    key = Patch_lemmas.patch(to_key(lemma))
    if !freq.has_key?(key) then
      freq[key] = 0
    else 
      # print "warning: two entries for #{key}"
    end
    freq[key] += count
    norm += count
  }
  freq_rank = {}
  rank = 1
  freq_list.each { |a|
    lemma,count = a
    freq_rank[to_key(lemma)] = rank
    rank += 1
  }

  index = {}
  ns = 0
  lemmas.each { |sentence|
    nw = 0
    sentence.each { |word|
      inflected,lemma,pos,cltk_pos = word
      lemma = Patch_lemmas.patch(lemma)
      key = to_key(inflected)
      if !index.has_key?(key) then index[key] = [] end
      index[key].push([ns,nw])
      nw += 1
    }
    ns += 1
  }

  result = []
  did_lemma = {}
  t.scan(/[^\s—]+/).each { |word_raw|
    word = word_raw.gsub(/[^[:alpha:]᾽']/,'')
    next unless word=~/[[:alpha:]]/
    key = to_key(word)
    if !index.has_key?(key) || index[key].nil? then print "error: no index entry for #{word_raw}, #{key}\n"; next end
    #print "#{index[key]}\n"
    ns,nw = index[key][0] # The mapping from inflected form to lemma is not one-to-one, but right now I'm ignoring that issue and taking the first entry.
    inflected,lemma,pos,cltk_pos = lemmas[ns][nw]
    lemma = guess_apostrophe(lemma)
    lemma = Patch_lemmas.patch(lemma)
    if lemma.nil? then print "lemma is nil for #{key} in .lemmas file\n"; next end
    if did_lemma.has_key?(lemma) then next end
    did_lemma[lemma] = 1
    rank = freq_rank[to_key(lemma)]
    f = freq[to_key(lemma)]
    entry = word_raw,word,lemma,rank,f,pos,cltk_pos # word and word_raw are not super useful, in many cases will be just the first example in this passage
    result.push(entry)
  }

  result.sort! { |a,b| b[4] <=> a[4] } # descending order by frequency

  result.each { |entry|
    word_raw,word,lemma,rank,f,pos,cltk_pos = entry
    if add_cap_to_lemma(lemma) then lemma=capitalize(lemma) end
    print "#{word},#{lemma},#{rank},#{f},#{pos},#{cltk_pos}\n"
  }

  threshold = 700 # words ranked higher than this are listed as common
  threshold2 = 1700 # words ranked lower than this get ransom notes
  save_up_complaints = []
  0.upto(2) { |commonness|
    result.sort { |a,b| to_key(a[1]) <=> to_key(b[1]) } .each { |entry|
      word_raw,word,lemma,rank,f,pos,cltk_pos = entry
      if rank.nil? then rank=9999 end
      next if Ignore_words.patch(word) || Ignore_words.patch(lemma)
      next unless rank<threshold && commonness==0 or rank>=threshold && rank<threshold2 && commonness==1 or rank>=threshold2 && commonness==2
      next unless rank>100
      if add_cap_to_lemma(lemma) then lemma=capitalize(lemma) end
      key1 = remove_accents(to_key(word)).downcase
      key2 = remove_accents(to_key(lemma)).downcase
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
        save_up_complaints.push("no entry for #{foo}")
      end
      print "#{key}\n"
    }
    print "\n"
  }
  print save_up_complaints.join("\n"),"\n"
end

def to_key(s)
  result = s.downcase.unicode_normalize(:nfkc) # should be :nfkc, but that produces strange results on "μυρί᾽"
  result.gsub!(/[^[:alpha:]]/,'') # otherwise we get strange behavior on words that have an apostrophe at the end
  result = guess_apostrophe(result)
  return result
end

def capitalize(x)
  if x=~/^([[:alpha:]])/ then
    return x.sub(/^[[:alpha:]]/,$1.upcase)
  else
    return x
  end
end

def add_cap_to_lemma(x) # kludge; only returns true for lemmas that are not already capitalized in my data file, but should have been
  list = ["λητώ","ἀχαιός","ἀπόλλων"]
  return list.include?(x.downcase)
end

def guess_apostrophe(x)
  map = {
    "δ᾽"=>"δὲ",
    "τ᾽"=>"τε"
  }
  if map.has_key?(x) then return map[x] else return x end
end

def grave_to_acute(x)
  return x.tr("ὰὲὶὸὺὴὼ","άέίόύήώ")
end

def remove_acute(x)
  return x.tr("άέίόύήώ","αειουηω")
end

class Patch_lemmas
  @@source = {
    "οἰωνός" => "οἰωνοὶ,οἰωνὸν,οἰωνοὺς,οἰωνοῖσί",
    "λύω" => "λυσόμενος",
    "χείρ" => "χερσὶν",
    "ἄλγος" => "ἄλγε᾽",
    "ἑκηβόλος" => "ἑκηβόλου",
    "θοός" => "θοάς",
    "βασιλεύς" => "βασιλῆϊ",
    "μυρίος" => "μυρί᾽",
    "προϊάπτω" => "προΐαψεν",
    "χολόω" => "χολωθείς",
    "ψυχή" => "ψυχὰς",
    "κακός" => "κακήν"
  }
  @@map = {}
  @@source.each { |lemma,forms|
    forms.split(/,/) { |form|
      @@map[grave_to_acute(form)] = lemma
    }
  }
  def Patch_lemmas.patch(orig)
    x = shallow_copy(orig)
    x = grave_to_acute(x)
    x.gsub!(/(.*[άέίόύήώ].*)([άέίόύήώ])(.*)/) {$1+remove_acute($2)+$3} # if it has 2 accents, assume 2nd is from an enclitic that follows it
    if @@map.has_key?(x) then x=@@map[x] end
    return x
  end
end

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


main()
