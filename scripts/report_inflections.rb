#!/bin/ruby
# coding: utf-8

lib_dir = "lib"
require_relative "../lib/file_util"
require_relative "../lib/string_util"
require 'json'

# https://github.com/cltk/greek_treebank_perseus
$fields = ["pos","person","number","tense","mood","voice","gender","case","degree"]

# usage:
#   report_inflections.rb καλεω person=3 mood=i voice=a tense=p,i,a number=s,p
# The rightmost key changes most rapidly, as expected intuitively from the way we write decimal notation.
# The first arg is the lemma. Accents in the lemma are ignored.

def main
  indentation_spacing = 2
  file = "#{Dir.home}/Documents/programming/ransom/lemmas/homer_lemmas.json"
  homer = json_from_file_or_die(file)
  lemma = ARGV.shift
  selector_strings = ARGV
  print "lemma=#{lemma} selectors=#{selector_strings}\n"
  keys = []
  values = []
  selector_strings.each { |s|
    key,val = s.split(/=/)
    keys.push(key)
    values.push(val.split(/,/))
  }
  nvals = values.map { |x| x.length}
  n = nvals.length
  n_varying = (nvals-[1]).length # number of elements that are > 1
  total_odometer_values = nvals.inject(1, :*)
  #print "keys=#{keys}\nvalues=#{values}\nnvals=#{nvals}\ntotal_odometer_values=#{total_odometer_values}\n"
  homer_filtered = {}
  homer.each_pair { |inflected,data|
    next unless remove_accents(data[0])==remove_accents(lemma)
    homer_filtered[inflected] = data
    #print "data=#{data}\n"
  }
  last_odo = Array.new(n, -1)
  0.upto(total_odometer_values-1) { |o|
    odo = count_to_odometer(o,nvals)
    indent = 0
    0.upto(n-1) { |i|
      if last_odo[i]!=odo[i] && nvals[i]!=1 then
        print " "*indent*indentation_spacing,describe_tag(keys[i],values[i][odo[i]]),"\n"
      end
      if nvals[i]!=1 then
        indent +=1 
      end
    }
    #print "odo=#{odo}\n"
    matches = []
    all_the_same_pos = ''
    homer_filtered.each_pair { |inflected,data|
      values_for_this_form = data[2].chars
      match = true
      0.upto(keys.length-1) { |i|
        k = $fields.index(keys[i])
        v = values_for_this_form[k]
        #if values[i][odo[i]] != v then print "#{inflected}, k=#{k}, #{data[2]}, i=#{i}, odo=#{odo}, failed because #{values[i][odo[i]]} != #{v}\n" end
        if values[i][odo[i]] != v then match=false; break end
      }
      next if !match
      part_of_speech = values_for_this_form[0] # e.g., 'v' if it's a verb
      all_the_same_pos = all_the_same_pos+part_of_speech
      matches.push(inflected)
    }
    if all_the_same_pos=~/^v+$/ then matches=deredundantize_verb(matches) end # all verbs
    if matches.length>=1 then results=matches.join(',') else results='-' end
    print " "*n_varying*indentation_spacing,results,"\n"
    last_odo = odo
  }
end

def count_to_odometer(count,nvals)
  n = nvals.length
  odo = []
  most_significant_part = count
  (n-1).downto(0) { |i|
    remainder = most_significant_part % nvals[i]
    most_significant_part = most_significant_part / nvals[i]
    odo = [remainder] + odo
  }
  return odo
end

def deredundantize_verb(l)
  if l.length<2 then return l end
  0.upto(l.length-1) { |i|
    0.upto(l.length-1) { |j|
      next if i==j
      if remove_accents(l[i])==remove_accents(l[j]+"ν") then return deredundantize_verb(l-[l[j]]) end
      if remove_accents(l[i])==remove_accents("ε"+l[j]) then return deredundantize_verb(l-[l[j]]) end
      if l[j]=~/(.*)᾽/ then
        stem = $1
        m = stem.length
        if l[i][0,m]==stem then return deredundantize_verb(l-[l[j]]) end
      end
    }
  }
  return l
end

def describe_tag(tag,value)
  if tag=='tense' then
    if value=='p' then return 'present' end
    if value=='i' then return 'imperfect' end
    if value=='a' then return 'aorist' end
  end
  if tag=='number' then
    if value=='s' then return 'singular' end
    if value=='d' then return 'dual' end
    if value=='p' then return 'plural' end
  end
  return "#{tag} = #{value}"
end

main
