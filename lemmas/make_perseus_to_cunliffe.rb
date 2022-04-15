#!/bin/ruby
# coding: utf-8

require "json"
require "set"

require '../lib/clown.rb'
require '../lib/string_util.rb'
require '../lib/file_util.rb'
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
example where two cunliffe lemmas map to the same perseus lemma:
  ( δάκρυ , δάκρυον ) -> δάκρυον
=end

def main
  author = "homer"
  treebank = TreeBank.new(author,data_dir:"../lemmas") # meant to be run froim lemmas subdirectory

  cun = CunliffeGlosses.new(filename:'../cunliffe/cunliffe.txt')

  c_to_p,unmatched_c,perseus = pass_a(cun)
  # ... the version of c_to_p returned by pass A is one-to-one

  $stderr.print "After pass A, found the following number of 1-1 matches: #{c_to_p.keys.length}\n"

  c_to_p_2 = pass_b(treebank,clown(c_to_p),unmatched_c) # a many-to-one mapping from Cunliffe to Perseus
  unmatched_c_2 = unmatched_c-c_to_p_2.keys

  $stderr.print "After pass B, found the following number of many-to-one maps from Cunliffe to Perseus: #{c_to_p_2.keys.length}\n"

  c_to_p_3 = pass_c(clown(c_to_p_2),unmatched_c_2,perseus,cun)
  unmatched_c_3 = unmatched_c_2-c_to_p_3.keys

  do_output(c_to_p_3,unmatched_c_3)

end # main

def do_output(c_to_p,unmatched_c)
  print pretty_json_hash(c_to_p)

  nontrivial = c_to_p.select { |k,v| k!=v}

  $stderr.print "statistics:\n"
  $stderr.print "  matches:            #{c_to_p.keys.length}\n"
  $stderr.print "  trivial matches:    #{c_to_p.keys.length-nontrivial.length}\n"
  $stderr.print "  nontrivial matches: #{nontrivial.length}\n"
  $stderr.print "  unmatched:          #{unmatched_c.length}\n"

  nontrivial_file = "temp.json"
  unmatched_file = "unmatched.txt"
  $stderr.print "The complete mapping from Cunliffe to Perseus has been printed to stdout. A list of the\n"
  $stderr.print "nontrivial ones is in #{nontrivial_file} . A list of unmatched words is in #{unmatched_file} .\n"
  File.open(nontrivial_file,"w") { |f|
    f.print pretty_json_hash(nontrivial)
  }
  File.open(unmatched_file,"w") { |f|
    f.print unmatched_c.map { |x| x+"\n" }.join('')
  }

end

#----------------------------------- C --------------------------------------
def pass_c(c_to_p,unmatched_c,perseus,cun)
  # By now we have about 90% of lemmas mapped. That means that on a typical line where an unmapped lemma occurs, it will be
  # the only unmapped word on that line. Based on cunliffe's set of line references, find a list of candidates in this way.
  # Look for one that occurs frequently and is phonetically similar.
  # perseus is the data structure from pass A,  a hash of hashes, first index is a line ref like Ψ762, second is perseus lemma
  known_p = c_to_p.values.to_set 
  m = MultiString.new('') # just need one object of the class for calling certain class methods, due to bad design
  1.upto(3) { |pass|
    $stderr.print "==== pass C#{pass} ====\n"
    k = 0
    unmatched_c.each { |c|
      if k%10==0 then $stderr.print "." end
      k += 1
      debug = (c=='ἁπλοΐς')
      lines = cun.extract_line_refs(c) # array such as ['Ξ412','Ψ762','ν103','ν347']
      candidates = []
      lines.each { |line|
        next if !perseus.has_key?(line) # e.g., Ι460
        perseus[line].keys.each { |p|
          next if known_p.include?(p)
          candidates.push(p)
        }
      }
      next if candidates.length==0
      count = {}
      candidates.each { |p|
        if !count.has_key?(p) then count[p]=0 end
        count[p] += 1
      }
      # Look to see if one choice dominates on both statistical and phonetic criteria.
      if debug then $stderr.print "\n" end
      best_p = nil
      candidates.each { |a|
        dominates_all = true
        candidates.each { |b|
          next if b==a
          dominates = (phonetic_similarity_score(a,c,m)>=phonetic_similarity_score(b,c,m) && count[a]>count[b]+3-pass)
          if debug then $stderr.print " #{c} #{dominates} #{a} #{b} #{phonetic_similarity_score(a,c,m)} #{phonetic_similarity_score(b,c,m)} #{count[a]} #{count[b]}\n" end
          if !dominates then dominates_all=false; break end
        }
        if dominates_all then best_p=a; break end
      }
      next if best_p.nil?
      c_to_p[c] = best_p
    }
    $stderr.print "\n"
  }
  return c_to_p
end

def phonetic_similarity_score(a,b,m)
  l = [a.length,b.length].min
  d = m.atomic_lcs_distance(remove_accents(a),remove_accents(b))
  similarity =  1.0-d.to_f/l
  if a[0]==b[0] then similarity+=0.3 end
  return similarity
end

#----------------------------------- B --------------------------------------

def pass_b(treebank,c_to_p,unmatched_c)
$stderr.print %Q{
Pass B: Looks for additional mappings from Cunliffe to Perseus in which the Cunliffe lemma is an attested form and
therefore is lemmatized in Perseus. These additional mappings may be many-to-one, e.g., (δάκρυ,δάκρυον)->δάκρυον.
}

unmatched_c.each { |c|
  debug = (c=='δώδεκα')
  p,success = treebank.lemmatize(c)
  if debug then $stderr.print "c=#{c}, treebank lemmatization=#{p}, #{success}\n" end
  next if !success
  c_to_p[c] = p
}
return c_to_p
end

#----------------------------------- A --------------------------------------

def pass_a(cun)

$stderr.print %Q{
Pass A: Looks for strict 1-1 mappings between cunliffe and perseus, based on the fingerprint of what lines they occur at,
plus a requirement of phonetic similarity.
}

author = 'homer'
csv_file = "#{author}_lemmas.csv"
perseus = {} # a hash of hashes, first index is a line ref like Ψ762, second is perseus lemma
perseus2 = {} # same as perseus, but with indices transposed
last_book = -1
$stderr.print "Reading Perseus data: "
File.open(csv_file,"r") { |f|
  f.each_line { |line|
    a = TreeBank.parse_csv_helper(line)
    next if a.nil?
    text,book,line,word_in_text,lemma,lemma_number,pos = a
    # typical line: iliad,1,2,οὐλομένην,οὐλόμενος,,a-s---fa-
    next if lemma!=lemma.downcase # Don't do proper nouns.
    c = cun.csv_line_ref_to_cunliffe([text,book,line]) # c is a Cunliffe-style line reference such as Α2
    if book!=last_book then $stderr.print c[0]; last_book=book end
    if !perseus.has_key?(c) then perseus[c] = {} end
    perseus[c][lemma] = 1
    if !perseus2.has_key?(lemma) then perseus2[lemma] = {} end
    perseus2[lemma][c] = 1
  }
}
$stderr.print "\n"

m = MultiString.new('') # just need one object of the class for calling certain class methods, due to bad design
map = {} # key=cunliffe lemma, value=perseus lemma
reverse_map = {} # reversed version of map
1.upto(3) { |pass|
  $stderr.print "==== pass A#{pass} ====\n"
  1.upto(3) { |subpass|
    count = 0
    cun.all_lemmas.each { |cunliffe|
      debug = false
      #debug = (cunliffe=='προθέω')
      next if map.has_key?(cunliffe) # done in a previous pass
      lines = cun.extract_line_refs(cunliffe) # array such as ['Ξ412','Ψ762','ν103','ν347']
      delete_from_lines = [] # deal with, e.g., Odyssey 10.459, which is not in perseus
      if debug then $stderr.print "#{cunliffe}, cunliffe references these lines: #{lines}\n" end
      coinc = {}
      coinc_at = {} # for debugging
      lines.each { |line|
        if !perseus.has_key?(line) then
          # happens, e.g., at Odyssey 10.459, which is not in perseus
          delete_from_lines.push(line)
          next
        end
        perseus[line].keys.each { |perseus_lemma|
          next if reverse_map.has_key?(perseus_lemma)
          if !coinc.has_key?(perseus_lemma) then coinc[perseus_lemma]=0 end
          coinc[perseus_lemma] += 1
          if coinc_at[perseus_lemma].nil? then coinc_at[perseus_lemma]=[] end
          coinc_at[perseus_lemma].push(line)
        }
      }
      lines = lines - delete_from_lines
      if debug then $stderr.print "coinc_at=#{coinc_at}\n" end
      next if coinc.keys.length==0
      ranked = coinc.keys.sort_by { |perseus_lemma| -coinc[perseus_lemma] } # sort in decreasing order by number of coincidences
      ranked.each { |perseus_lemma| # loop over ones that have the best fingerprints
        if perseus_lemma==ranked[0] then
          coinc_next_best_perseus=coinc[ranked[1]]
          if coinc_next_best_perseus.nil? then coinc_next_best_perseus=0 end
        else
          coinc_next_best_perseus=coinc[ranked[0]]
        end
        hit = if_hit(pass,subpass,perseus_lemma,cunliffe,coinc[perseus_lemma],coinc_next_best_perseus,lines.length,m,debug)
        #----
        if hit then
          # Passes An are designed to look only for strict 1-1 mappings.
          map[cunliffe] = perseus_lemma
          reverse_map[perseus_lemma] = cunliffe
          #print "#{cunliffe},#{perseus_lemma}\n"
          $stderr.print "." if count%10==0
          count += 1
          break
        end
      }
    }
    $stderr.print "\n"
  }
}

unmatched = cun.all_lemmas.select { |cunliffe| !map.has_key?(cunliffe) }

return [map,unmatched,perseus]

end # pass_a

#----------------------------------- helper routines for pass A --------------------------------------

def if_hit(pass,subpass,perseus,cunliffe,coinc_best_perseus,coinc_next_best_perseus,min_expected,m,debug)
  #if debug then $stderr.print "cunliffe=#{cunliffe} perseus=#{perseus} coinc_best_perseus=#{coinc_best_perseus} min_expected=#{min_expected}\n" end
  if coinc_best_perseus<min_expected then
    # ... Cunliffe has it on lines that this Perseus lemma never occurs on. This should not happen except in unusual cases like an error in the OCR
    #     of Cunliffe. The converse is not true, because for very common lemmas, Cunliffe doesn't list all occurrences.
    if pass<3 then return false end
    if min_expected<8 || coinc_best_perseus<0.8*min_expected || coinc_best_perseus<min_expected-2 then return false end
    # ... On pass 3, allow cases where the expected number of coincidences was large and only one or two were absent.
  end
  hit = if_hit_helper(pass,subpass,perseus,cunliffe,coinc_best_perseus,coinc_next_best_perseus,min_expected,m,debug)
  if !hit && pass>=3 then
    [['μαι','ω'],['η','α']].each { |x|
      c,p = x
      if cunliffe=~/#{c}$/ && perseus=~/#{p}$/ then
        hit = if_hit_helper(pass,subpass,perseus,cunliffe.sub(/#{c}$/,p),coinc_best_perseus,coinc_next_best_perseus,min_expected,m,debug)
      end
    }
  end
  return hit
end

def if_hit_helper(pass,subpass,perseus,cunliffe,coinc_best_perseus,coinc_next_best_perseus,min_expected,m,debug)
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
  return hit
end

def pretty_json_hash(h)
  return JSON.pretty_generate(Hash[*h.sort { |a,b| (a[0] <=> b[0])}.flatten])
  #  https://stackoverflow.com/questions/5433241/sort-ruby-hash-when-using-json
end

main
