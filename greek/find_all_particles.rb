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

desired_pos_tag = 'g'

x = TreeBank.new('homer').lemmas

a = []
x.each { |word,data|
  lemma,glub1,pos,glub2,ambig,stuff = data
  part_of_speech,person,number,gender,c = pos[0],pos[1],pos[2],pos[6],pos[7]
  next if word=~/᾽/
  next if (part_of_speech!=desired_pos_tag)  && !ambig
  is_desired_pos = false
  if stuff.nil? then
    # data=["ἀτάρ", "", "g--------", 11, false, nil]
    is_desired_pos = (data[2][0]==desired_pos_tag)
  else
    stuff.each { |lem| if lem[2][0]==desired_pos_tag then is_desired_pos=true end }
  end
  next if !is_desired_pos
  word = to_single_accent(word) # don't double count
  # A word can have both an acute and a grave, and then this converts it into a word with two acutes, which is bogus.
  n_acute = 0
  word.chars.each { |c| if remove_acute_and_grave(c)!=c then n_acute +=1 end }
  next if n_acute>1
  word='ἦ' if lemma=='ἤ' # occurs because it's ambiguous, lemma can be ἦ for the word stripped of accents
  a.push(word)
}
a = a.uniq

# When these particles have both accented and unaccented forms, the only difference is that the accented one is
# used for emphasis. Delete the accented ones, which are less common.
mark_for_deletion = []
0.upto(a.length-1) { |i|
  0.upto(a.length-1) { |j|
    next if i==j
    mark_for_deletion.push(i) if remove_acute_and_grave(a[i])==a[j]
  }
}
b = []
0.upto(a.length-1) { |i|
  b.push(a[i]) unless mark_for_deletion.include?(i)
}
a = b

print a.length,"\n"
print alpha_sort(a).join(" ")


