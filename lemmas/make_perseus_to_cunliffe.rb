#!/bin/ruby
# coding: utf-8

require '../lib/string_util.rb'
require '../lib/multistring.rb'
require '../lib/treebank.rb'
require '../lib/cunliffe.rb'

=begin
examples for testing (perseus, cunliffe)
  ἀζηχής ἀζηκής
  πορσύνω πορσαίνω
  χολάς χολάδες
  χῶρα χῶρη
  παρήιον παρήϊον
  ψεύδω ψεύδομαι
=end

def main

cun = CunliffeGlosses.new(filename:'../cunliffe/cunliffe.txt')

author = 'homer'
csv_file = "#{author}_lemmas.csv"
perseus = {}
last_book = -1
File.open(csv_file,"r") { |f|
  f.each_line { |line|
    a = TreeBank.parse_csv_helper(line)
    next if a.nil?
    text,book,line,word_in_text,lemma,lemma_number,pos = a
    # typical line: iliad,1,2,οὐλομένην,οὐλόμενος,,a-s---fa-
    c = cun.csv_line_ref_to_cunliffe([text,book,line]) # c is a Cunliffe-style line reference such as Α2
    if book!=last_book then $stderr.print c[0]; last_book=book end
    if !perseus.has_key?(c) then perseus[c] = {} end
    perseus[c][lemma] = 1
  }
}
$stderr.print "\n"

m = MultiString.new('') # just need one object of the class for calling certain class methods, due to bad design
map = {} # key=cunliffe lemma, value=perseus lemma
reverse_map = {} # reversed version of map
1.upto(4) { |pass|
  $stderr.print "-------------------pass #{pass}----------------------\n"
  1.upto(3) { |subpass|
    cun.all_lemmas.each { |cunliffe|
      next if map.has_key?(cunliffe) # done in a previous pass
      lines = cun.extract_line_refs(cunliffe) # array such as ['Ξ412','Ψ762','ν103','ν347']
      coinc = {}
      lines.each { |line|
        next if !perseus.has_key?(line) # shouldn't really happen, but avoid crashes if it does
        perseus[line].keys.each { |perseus_lemma|
          next if reverse_map.has_key?(perseus_lemma)
          if !coinc.has_key?(perseus_lemma) then coinc[perseus_lemma]=0 end
          coinc[perseus_lemma] += 1
        }
      }
      next if coinc.keys.length==0
      ranked = coinc.keys.sort_by { |perseus_lemma| -coinc[perseus_lemma] } # sort in decreasing order by number of coincidences
      ranked.each { |perseus_lemma| # loop over ones that have the best fingerprints
        if perseus_lemma==ranked[0] then
          coinc_next_best_perseus=coinc[ranked[1]]
          if coinc_next_best_perseus.nil? then coinc_next_best_perseus=0 end
        else
          coinc_next_best_perseus=coinc[ranked[0]]
        end
        hit = if_hit(pass,subpass,perseus_lemma,cunliffe,coinc[perseus_lemma],coinc_next_best_perseus,lines.length,m)
        #----
        if hit then
          map[cunliffe] = perseus_lemma
          reverse_map[perseus_lemma] = cunliffe
          print "#{cunliffe},#{perseus_lemma}\n"
          break
        end
      }
    }
  }
}

unmatched = cun.all_lemmas.select { |cunliffe| !map.has_key?(cunliffe) }
$stderr.print "The following #{unmatched.length} Cunliffe lemmas were not matched (first 300 listed):\n"
$stderr.print unmatched[0..299].join(' '),"\n"
$stderr.print "\n"


end # main

def if_hit(pass,subpass,perseus,cunliffe,coinc_best_perseus,coinc_next_best_perseus,min_expected,m)
  if coinc_best_perseus<min_expected then return false end
  # ... Cunliffe has it on lines that this Perseus lemma never occurs on. This should never happen except in rare cases like an error in the OCR of Cunliffe.
  #     The converse is not true, because for very common lemmas, Cunliffe doesn't list all occurrences.
  hit = if_hit_helper(pass,subpass,perseus,cunliffe,coinc_best_perseus,coinc_next_best_perseus,min_expected,m)
  if !hit && pass>=3 then
    [['μαι','ω'],['η','α']].each { |x|
      c,p = x
      if cunliffe=~/#{c}$/ && perseus=~/#{p}$/ then
        hit = if_hit_helper(pass,subpass,perseus,cunliffe.sub(/#{c}$/,p),coinc_best_perseus,coinc_next_best_perseus,min_expected,m)
      end
    }
  end
  return hit
end

def if_hit_helper(pass,subpass,perseus,cunliffe,coinc_best_perseus,coinc_next_best_perseus,min_expected,m)
  # How much better does the fingerprint of line numbers match up for perseus compared to next_best_perseus?
  if coinc_next_best_perseus.nil? then
    how_superior = 1
  else
    how_superior=coinc_best_perseus-coinc_next_best_perseus-6+2*subpass 
  end
  #----
  hit = false
  if pass==1 then
    if perseus==cunliffe && how_superior>=0 then hit=true end # strings are identical and next-best fingerprint is worse
  end
  if pass==2 || pass==3 then
    l = [cunliffe.length,perseus.length].min
    d = m.atomic_lcs_distance(cunliffe,perseus)
    similarity =  1.0-d.to_f/l
    if similarity>1.0-0.2*subpass && how_superior>=0 then hit=true end
  end
  if pass==4 then
    if how_superior>=1 then hit=true end
  end
  return hit
end

main
