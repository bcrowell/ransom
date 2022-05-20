require 'set'

=begin

A module to be used for syllabification of Greek words.
This should be fairly accurate, but won't be perfect because it uses heuristics to guess
what things are compounds.

=end

module Syllab

  def Syllab.run_tests()
    # testing:
    #   ruby -e 'require "./lib/string_util"; require "./lib/genos"; require "./greek/syllab"; Syllab.run_tests()'
    t = %q{
      ἅλς
      ἄλ λος
      ἔ πος
      ἱ ε ρῆ α
      ταύ ρων
      νυ κτὶ
      Ἀρ γυ ρό τοξ’
      ἀ να πίμ πλη μι
      ἐκ βάλ λω
      ἐκ τεί νω
      ἔπ ει μι
      ἀν τι κρὺ
      Ἀ τρε ΐ δης
    }
    t.split(/\s*\n\s*/) { |x|
      next if x==''
      a = x.split(/\s+/)
      word = a.join('')
      b = Syllab.ify(word)
      err = false
      if a.length!=b.length then err=true end
      if !err then
        0.upto(a.length-1) { |i|
          if a[i]!=b[i] then err=true end
        }
      end
      if err then raise "test failed: #{word} gives #{b}, expected #{a}" end
      print "test passed: #{word} -> #{a}\n"
    }
  end

  def Syllab.ify(s,genos:GreekGenos.new('epic'))
    # Returns an array of syllables.
    d = Syllab.diphthong_maps()
    cl = Syllab.word_initial_clusters()
    return Syllab.helper3(s,genos,d,cl)
  end

  def Syllab.helper3(s,genos,d,cl)
    # Handle diareses.
    c = 'ϊΐῒϋΰῢ' # probably not a complete list
    if s=~/^(.+)([#{c}].*)$/ then
      return Syllab.helper3($1,genos,d,cl)+Syllab.helper3($2,genos,d,cl)
    else
      return Syllab.helper1(s,genos,d,cl)
    end
  end

  def Syllab.helper1(s,genos,d,cl)
    # Try to recognize compounds made using prepositions.
    # This is hard to perfectly automate, because compounds are broken so as to respect their etymology, but software may not 
    # be able to tell with 100% reliability. Compounds may also not be made of prepositions.
    has_preposition,prefix,stem,preposition = Preposition.recognize_prefix(s,genos:genos)
    if has_preposition && stem.length>=4 then
      # The check on stem.length is a heuristic to try to guess that something like ἔπος is not a compound, while ἔπειμι is.
      return Syllab.helper2(prefix,genos,d,cl)+Syllab.helper1(stem,genos,d,cl)
    else
      return Syllab.helper2(s,genos,d,cl)
    end
  end

  def Syllab.helper2(s,genos,d,cl)
    # doesn't handle compounds
    x = Syllab.encode_diphthongs(remove_accents(s).downcase,d)
    m = Syllab.helper(x,cl)
    mm = []
    start = 0
    m.each { |len|
      syll = Syllab.decode_diphthongs(x[start..(start+len-1)],d) # convert encoded length to decoded length
      mm.push(syll.length)
      start += len
    }
    result = []
    start = 0
    mm.each { |len|
      syll = s[start..(start+len-1)]
      result.push(syll)
      start += len
    }
    return result
  end

  def Syllab.helper(s,cl)
    # Input is assumed to have already been simplified.
    # Returns an array in which each element is the length of that syllable.
    # https://www.billmounce.com/greekalphabet/greek-punctuation-syllabification
    v = "αειουηω012345678" # list of vowels, including the codes for the diphthongs
    cons = "βγδζθκλμνξπρσςτφχψ"
    n_vowels = s.scan(/[#{v}]/).length
    if n_vowels<=1 then return [s.length] end
    "γκλμνπρστ".chars.each { |c| # consonants that can be doubled
      if s=~/^(.*#{c})(#{c}.*)$/ then
        return Syllab.helper($1,cl)+Syllab.helper($2,cl)
      end
    }
    if s=~/^(.*[#{v}])([#{cons}][#{v}].*)$/ then # VCV -> V-CV
      return Syllab.helper($1,cl)+Syllab.helper($2,cl)
    end
    if s=~/^(.*[#{v}])([#{v}].*)$/ then # VV -> V-V (because diphthongs have already been encoded as a single vowel)
      return Syllab.helper($1,cl)+Syllab.helper($2,cl)
    end
    if s=~/^(.*[#{v}][#{cons}]*)([#{cons}])([#{cons}])([#{v}].*)$/ then # VCCV or longer clusters
      a,b,c,d = [$1,$2,$3,$4]
      if cl.include?(b+c) then x=a; y=b+c+d else x=a+b; y=c+d end
      return Syllab.helper(x,cl)+Syllab.helper(y,cl)
    end
    return [s.length]
  end

  def Syllab.encode_diphthongs(s,d)
    # assumes all accents have already been removed
    diphthongs,diphthong_encode,diphthong_decode = d
    diphthongs.each { |dip|
      s.gsub!(/#{dip}/,diphthong_encode[dip])
    }
    return s
  end

  def Syllab.decode_diphthongs(s,d)
    diphthongs,diphthong_encode,diphthong_decode = d
    diphthongs.each { |dip|
      s.gsub!(/#{diphthong_encode[dip]}/,dip)
    }
    return s
  end

  def Syllab.diphthong_maps
    diphthongs = ['αι','ει','οι','υι','αυ','ευ','ηυ','ου','ωυ']
    k = 0
    diphthong_encode = {}
    diphthong_decode = {}
    diphthongs.each { |d|
      diphthong_encode[d] = k.to_s
      diphthong_decode[k.to_s] = d
      k += 1
    }
    return [diphthongs,diphthong_encode,diphthong_decode]
  end


=begin
The list in Syllab.word_initial_clusters was found using the following script:

cons = "βγδζθκλμνξπρσςτφχψ"
h = {}
Dir.glob( 'glosses/*').map { |x| x=~/glosses\/(.*)/; $1}.each { |word|
  next unless word=~/^([#{cons}])([#{cons}])/
  a = $1+$2
  h[a] = 1
}
print h.keys.sort
=end

  def Syllab.word_initial_clusters
    return ["βλ", "βρ", "γλ", "γν", "γρ", "δμ", "δν", "δρ", "θλ", "θν", "θρ", "κλ", "κν", "κρ", "κτ", "μν", "πλ", "πν", "πρ", "πτ", "σθ", "σκ", "σμ",
            "σπ", "στ", "σφ", "σχ", "τλ", "τμ", "τρ", "φθ", "φλ", "φρ", "χθ", "χλ", "χρ"].to_set
  end
end
