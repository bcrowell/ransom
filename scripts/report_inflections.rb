#!/bin/ruby
# coding: utf-8

lib_dir = "lib"
require_relative "../lib/file_util"
require_relative "../lib/string_util"
require 'json'

# https://github.com/cltk/greek_treebank_perseus
$fields = ["pos","person","number","tense","mood","voice","gender","case","degree"]
$all_values = {'person'=>['1','2','3'],'number'=>['s','d','p'],'tense'=>['p','i','r','l','t','f','a'],'mood'=>['i','s','o','n','m','p'],
           'voice'=>['a','p','m','e'],'case'=>['n','g','d','a','v','l']}

=begin

usage:
  report_inflections.rb ολεκω
  report_inflections.rb person=3 mood=* voice=a tense=pia number=sp καλεω 
The rightmost key changes most rapidly, as expected intuitively from the way we write decimal notation.
The lemma can be given in any position, is detected by the absence of an equals sign. Accents in the lemma are ignored.
Using * causes results to be broken down by that key. If you just don't care about that key and want to accept all its possible
values, then simply don't include the key on the command line.

  Typical database entry:
  "ἀγείρετο": [
    "ἀγείρω",
    "1",
    "v3siie---",
    1, <--- number of occurrences
    false,
    null
  ],
=end

def main
  warnings = []
  total_matches = 0
  total_occurrences = 0
  indentation_spacing = 2
  file = "#{Dir.home}/Documents/programming/ransom/lemmas/homer_lemmas.json"
  homer = json_from_file_or_die(file)
  lemma = nil
  ARGV.each { |arg|
    if !(arg=~/=/) then
      lemma = arg
    end
  }
  if lemma.nil? then print "no lemma given\n"; exit(-1) end
  if lemma=~/[a-zA-Z,\."\-]/ then print "lemma #{lemma} contains punctuation or Latin characters\n"; exit(-1) end
  if lemma=~/ς./ then print "lemma #{lemma} contains ς in a non-final position\n"; exit(-1) end
  selector_strings = ARGV.dup
  selector_strings.delete(lemma)
  #print "lemma=#{lemma} selectors=#{selector_strings}\n"
  keys = []
  values = []
  lemma_matches = []
  selector_strings.each { |s|
    key,val = s.split(/=/)
    if !($fields.include?(key)) then print "illegal key: #{key}\n"; exit(-1) end
    keys.push(key)
    if val=='*' then
      vv = $all_values[key]
      if vv.nil? then print "* not implemented for key=#{key}\n"; exit(-1) end
    else
      vv = val.chars
      if $all_values.has_key?(key) then
        vv.each { |c| if !($all_values[key].include?(c)) then print "illegal key-value pair #{key}=#{c}; legal values are #{$all_values[key].join}\n"; exit(-1) end}
      end
    end
    values.push(vv)
  }
  nvals = values.map { |x| x.length}
  n = nvals.length
  n_varying = (nvals-[1]).length # number of elements that are > 1
  total_odometer_values = nvals.inject(1, :*)
  #print "keys=#{keys}\nvalues=#{values}\nnvals=#{nvals}\ntotal_odometer_values=#{total_odometer_values}\n"
  homer_filtered = {}
  homer.each_pair { |inflected,data|
    next unless remove_accents(data[0])==remove_accents(lemma)
    lemma_matches.push(data[0])
    ambiguous = data[4]
    if !ambiguous then
      homer_filtered[inflected] = [data]
    else
      homer_filtered[inflected] = data[5]
    end
  }
  last_odo = Array.new(n, -1)
  0.upto(total_odometer_values-1) { |o|
    odo = count_to_odometer(o,nvals)
    #print "odo=#{odo}\n"
    matches = []
    n_occurrences = []
    all_the_same_pos = ''
    homer_filtered.each_pair { |inflected,ambig|
      ambig.each { |data|
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
        n_occurrences.push(data[3])
      }
    }
    n_matches = matches.length
    total_matches += n_matches

    indent = 0
    changed_past_here = false
    0.upto(n-1) { |i|
      if last_odo[i]!=odo[i] && nvals[i]!=1 then changed_past_here = true end
      next if nvals[i]==1
      if changed_past_here && ! (n_matches==0 && i==n-1) then
        print " "*indent*indentation_spacing,describe_tag(keys[i],values[i][odo[i]]),"\n"
      end
      indent +=1 
    }

    if true then
      # Not 100% reliable.
      if all_the_same_pos=~/^v+$/ then matches,n_occurrences=deredundantize_verb([matches,n_occurrences]) end # all verbs
    end
    if n_matches>=1 then
      results=0.upto(matches.length-1).map { |i| "#{matches[i]} (#{n_occurrences[i]})"}.join(', ')
      total_occurrences += n_occurrences.sum
      print " "*n_varying*indentation_spacing,results,"\n"
    end
    last_odo = odo
  }

  lemma_matches = lemma_matches.uniq
  if lemma_matches.length>0 && remove_accents(lemma)!=lemma && !lemma_matches.include?(lemma) then
    warnings.push("The given lemma #{lemma} appears to be incorrectly accented compared to the matches: #{lemma_matches}")
  end
  if lemma_matches.length>0 then
    if lemma_matches.length==1 && lemma_matches[0]==lemma then
      print "The given lemma #{lemma} is an exact and unique match to the database, including accentuation.\n"
    else
      if lemma_matches.length==1 then
        print "The given lemma is a unique match to: ",lemma_matches[0],"\n"
      else
        print "The given lemma matches: ",lemma_matches,"\n"
      end
    end
  end

  print "total matches: #{total_matches}, total occurrences: #{total_occurrences}\n"  
  if warnings.length>0 then
    print "**************************** WARNINGS *****************************\n"
    warnings.each { |w|
      print w,"\n"
    }
  end
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

def deredundantize_verb(x)
  l,n_occurrences = x
  if l.length<2 then return [l,n_occurrences] end
  0.upto(l.length-1) { |i|
    0.upto(l.length-1) { |j|
      next if i==j
      if remove_accents(l[i])==remove_accents(l[j]+"ν") && remove_accents(l[j])=~/ε$/ then
        return deredundantize_verb(deredundantize_helper(l,n_occurrences,i,l[j]))
      end
      # if remove_accents(l[i])==remove_accents("ε"+l[j]) then return deredundantize_verb(deredundantize_helper(l,n_occurrences,i,l[j])) end
      # ... don't consider them redundant if they differ by augment; sometimes I want to know whether a verb takes the augment or not more frequently
      if l[j]=~/(.*)᾽/ then
        stem = $1
        m = stem.length
        if l[i][0,m]==stem then return deredundantize_verb(deredundantize_helper(l,n_occurrences,i,l[j])) end
      end
    }
  }
  return [l,n_occurrences]
end

def deredundantize_helper(array1,array2,i_keep,value_to_delete)
  i = array1.index(value_to_delete)
  if i.nil? then return [array1,array2] end
  array2[i_keep] += array2[i]
  a1 = array1.dup
  a2 = array2.dup
  a1.delete_at(i)
  a2.delete_at(i)
  return [a1,a2]
end

# https://github.com/cltk/greek_treebank_perseus
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
  if tag=='mood' then
    if value=='i' then return 'indicative' end
    if value=='s' then return 'subjunctive' end
    if value=='o' then return 'optative' end
    if value=='n' then return 'infinitive' end
    if value=='m' then return 'imperative' end
    if value=='p' then return 'participle' end
  end
  return "#{tag} = #{value}"
end

main
