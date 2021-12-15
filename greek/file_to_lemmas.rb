#!/bin/ruby
# coding: utf-8

# Usage:
#   ./file_to_lemmas.rb ../text/ιλιας/01 >vocab.txt
# Reads a greek text from the file named in the arg, writes a list of lemmas to stdout, one per line.

require 'json'
require 'sdbm'
require 'set'

require_relative "../lib/file_util"
require_relative "../lib/string_util"
require_relative "../lib/treebank"
require_relative "../lib/epos"
require_relative "../lib/vlist"
require_relative "../lib/gloss"
require_relative "../lib/clown"
require_relative "nouns"

text_file = ARGV[0]

lemmas = TreeBank.new('homer').lemmas

words = nil
File.open(text_file,'r') { |f|
  t = f.gets(nil)
  # Split the text into words, discarding any punctuation except for punctuation that can occur in a word, e.g.,
  # the apostrophe in "don't." Code duplicated from Epos.word() for the case of Greek.
  words = t.scan(/[[:alpha:]᾽’]+/)
}

whine = []
results = []
words.each { |word_raw|
  word = word_raw.gsub(/[^[:alpha:]᾽']/,'')
  next unless word=~/[[:alpha:]]/
  lemma_entry = Vlist.get_lemma_helper(lemmas,word)
  if lemma_entry.nil? then whine.push("error: no index entry for #{word_raw}, key=#{word}"); next end
  lemma,lemma_number,pos,count,if_ambiguous,ambig = lemma_entry
  if if_ambiguous then whine.push("warning: lemma for #{word_raw} is ambiguous, taking most common one; #{ambig}") end
  if lemma.nil? then whine.push("lemma is nil for #{word} in lemmas file"); next end
  results.push(lemma)
}

results = alpha_sort(results.uniq)

if false then
  whine.each { |message|
    $stderr.print message,"\n"
  }
end

results.each { |lemma|
  print lemma,"\n"
}
