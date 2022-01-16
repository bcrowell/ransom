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

x = TreeBank.new('homer').lemmas

a = []
x.each { |word,data|
  lemma,glub1,pos,glub2,glub3,stuff = data
  part_of_speech,person,number,gender,c = pos[0],pos[1],pos[2],pos[6],pos[7]
  next if (part_of_speech!='p') || c=='-' || lemma=='υνκνοων'  || word=~/᾽/
  #print sprintf("%9s %8s %8s\n",pos,word,lemma)
  word = grave_to_acute(word) # don't double count
  # A word can have both an acute and a grave, and then this converts it into a word with two acutes, which is bogus.
  n_acute = 0
  word.chars.each { |c| if remove_acute_and_grave(c)!=c then n_acute +=1 end }
  next if n_acute>1
  a.push(word)
}
a = a.uniq
print alpha_sort(a).join(' ')
print a.length

