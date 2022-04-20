#!/bin/ruby
# coding: utf-8

require 'json'
require_relative "../lib/file_util"
require_relative "../lib/string_util"
require_relative "../lib/treebank"


=begin

σέθεν
  "σέθεν": [
    "σύ",
    "1",
    "p-s----g-",
    22,
    true,
    [
      [
        "σύ",
        "1",
        "p-s----g-",
        22
      ],
      [
        "σύ",
        "",
        "p-s---mg-",
        4
      ]
    ]
  ],

=end

def main

x = TreeBank.new('homer').lemmas

possessive_lemmas = ['ἐμός','ἡμέτερος','ἁμός','σός','τεός','ὑμός','ὑμέτερος'] # Smyth 330

a = []
x.each { |word,data|
  lemma,glub1,pos,glub2,ambig,stuff = data
  part_of_speech,person,number,gender,c = pos[0],pos[1],pos[2],pos[6],pos[7]
  next if c=='-' || lemma=='υνκνοων'  || word=~/᾽/
  t = nil # type
  if part_of_speech=='p' then t='pronoun' end
  if part_of_speech=='l' then t='article' end # not really distinct from pronouns
  if t.nil? && ambig then
    is_article = false
    stuff.each { |lem| if lem[2][0]=='l' then is_article=true end }
    if is_article then t='article' end
  end
  if t.nil? && part_of_speech=='a' && possessive_lemmas.include?(lemma) then t='possessive' end
  next if t.nil?
  word = to_single_accent(word) # don't double count
  # A word can have both an acute and a grave, and then this converts it into a word with two acutes, which is bogus.
  n_acute = 0
  word.chars.each { |c| if remove_acute_and_grave(c)!=c then n_acute +=1 end }
  next if n_acute>1
  a.push(word)
  #$stderr.print sprintf("%9s %8s %8s %s\n",pos,word,lemma,t)
}
a = a.uniq

loop do
  victim = nil
  0.upto(a.length-1) { |i|
    x = a[i] # candidate for redundancy
    x_is_redundant = false
    # Don't delete the following in favor of the ones that have a ν on the end, which is a case difference, not just a nu-movable.
    next if x=='τό' || x=='ὅ' || x=='ἥ' || x=='σή'
    0.upto(a.length-1) { |j|
      next if j==i
      y = a[j]
      if remove_accents_no_i_s(x)==remove_accents_no_i_s(y) && remove_accents_no_i_s(y)!=y then x_is_redundant=true end
      if y==x+'ν' then x_is_redundant=true end
      if x_is_redundant then
        $stderr.print "deleting #{x}, redundant relative to #{y}\n"
        break
      end
    }
    if x_is_redundant then victim=x; break end
  }
  break if victim.nil?
  a = a-[victim]
end

print alpha_sort(a).join(' ')
print a.length

end # main

def remove_accents_no_i_s(s)
  if s=~/([ᾳῃῳᾴῄῴᾲῂῲᾷῇῷ])/ then
    c = $1
    s = s.sub(/#{c}/,'_')
    s = remove_accents(s)
    s = s.sub(/_/,c)
    return s
  else
    return remove_accents(s)
  end
end

main
