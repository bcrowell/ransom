require 'json'
require_relative "../lib/file_util"
require_relative "../lib/string_util"
require_relative "../lib/treebank"


# Mostly duplicates a subset of the code in find_all_pronouns.rb.

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

x = TreeBank.new('homer').lemmas

a = []
x.each { |word,data|
  lemma,glub1,pos,glub2,ambig,stuff = data
  part_of_speech,person,number,gender,c = pos[0],pos[1],pos[2],pos[6],pos[7]
  next if word=~/᾽/
  next if (part_of_speech!='l')  && !ambig
  is_article = false
  stuff.each { |lem| if lem[2][0]=='l' then is_article=true end }
  next if !is_article
  word = to_single_accent(word) # don't double count
  # A word can have both an acute and a grave, and then this converts it into a word with two acutes, which is bogus.
  n_acute = 0
  word.chars.each { |c| if remove_acute_and_grave(c)!=c then n_acute +=1 end }
  next if n_acute>1
  a.push(word)
}
a = a.uniq
print alpha_sort(a).join(' ')
print a.length

