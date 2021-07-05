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
  lemmas = json_from_file_or_die("lemmas/homer_lemmas.json")
  # typical entry when there's no ambiguity:
  #   "βέβασαν": [    "βαίνω",    "1",    "v3plia---",    1,    false,    null  ],
  freq = json_from_file_or_die("lemmas/homer_freq.json")
  freq_list = freq.to_a
  freq_list.sort! { |a,b| b[1] <=> a[1]} # descending order by frequency; is probably already sorted, so this will be fast
  # ... a list of pairs like [["δέ", 12136], ["ὁ" , 5836], ...]

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
    if !(lemmas.has_key?(word)) then print "error: no index entry for #{word_raw}, key=#{word}\n"; next end
    lemma,lemma_number,pos,count,if_ambiguous,ambig = lemmas[word]
    if if_ambiguous then 
      warn_ambig[word]= "warning: lemma for #{word_raw} is ambiguous, taking most common one; #{ambig}"
    end
    if lemma.nil? then print "lemma is nil for #{word} in lemmas file\n"; next end
    if did_lemma.has_key?(lemma) then next end
    did_lemma[lemma] = 1
    rank = freq_rank[lemma]
    f = freq[lemma]
    entry = word_raw,word,lemma,rank,f,pos # word and word_raw are not super useful, in many cases will be just the first example in this passage
    result.push(entry)
  }

  result.sort! { |a,b| b[4] <=> a[4] } # descending order by frequency

  result.each { |entry|
    word_raw,word,lemma,rank,f,pos = entry
    print "#{word},#{lemma},#{rank},#{f},#{pos}\n"
  }

  threshold = 700 # words ranked higher than this are listed as common
  threshold2 = 1700 # words ranked lower than this get ransom notes
  save_up_complaints = []
  0.upto(2) { |commonness|
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
        save_up_complaints.push("no entry for #{foo}")
      end
      if warn_ambig.has_key?(word) then save_up_complaints.push(warn_ambig[word]) end
      print "#{key}\n"
    }
    print "\n"
  }
  print save_up_complaints.join("\n"),"\n"
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
