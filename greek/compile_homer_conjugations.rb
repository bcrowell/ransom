#!/bin/ruby
# coding: utf-8

=begin
This script compiles a table of verb conjugations occurring in Homer, for use in testing
my verb conjugation function. The output is a JSON hash of hashes of lists,
indexed as [pos][lemma]. The list is usually a singleton, but may have multiple
members if there is more than possible way to inflect the verb for the desired form.
=end

require_relative '../lib/string_util.rb'
require_relative '../lib/file_util.rb'
require_relative '../lib/string_util.rb'
require 'json'

def main

a = json_from_file_or_die("../lemmas/homer_lemmas.json")

# See comments in to_db.rb for explanation of format.
# typical entry when there's no ambiguity:
#  "αἰσχύνει": [    "αἰσχύνω",    "1",    "v3spia---",    1,    false,    null  ],

t = {}

a.each { |word,entry|
  lemma,lemma_number,pos,count,if_ambiguous,ambig = entry
  if if_ambiguous then
    ambig.each { |x|
      lemma2,lemma_number2,pos2,count2 = x
      process(t,lemma2,pos2,word)
    }
  else
    process(t,lemma,pos,word)
  end
  break if t.keys.length>=10000 # qwe
}

# Ruby orders hash keys in insertion order by default, so make a version ordered that way.
s = {}
t.keys.sort.each { |pos| s[pos] = {} }
s.keys.each { |pos| alpha_sort(t[pos].keys).each { |lemma| s[pos][lemma] = t[pos][lemma] }}

print JSON.pretty_generate(s)

end # main

def process(t,lemma,pos,word)
  return unless pos[0]=~/[vt]/ # verb or participle
  return if lemma=='υνκνοων'
  if !(t.has_key?(pos)) then t[pos] = {} end
  if !(t[pos].has_key?(lemma)) then t[pos][lemma] = [] end
  x = t[pos][lemma]
  if !(x.include?(word)) then t[pos][lemma].push(grave_to_acute(word)) end
end

def die(message)
  #  $stderr.print message,"\n"
  raise message # gives a stack trace
  exit(-1)
end

main
