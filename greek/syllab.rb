module Syllab

  def Syllab.run_tests()
    # testing:
    #   ruby -e 'require "./lib/string_util"; require "./greek/syllab"; Syllab.run_tests()'
    t = %q{
      ἅλς
      ἄλ λος
      ἔ πος
      ἱ ε ρῆ α
      ταύ ρων
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

  def Syllab.ify(s)
    # Returns an array of syllables.
    # To do: handle diaresis, e.g., Ἀτρεΐδης
    d = Syllab.diphthong_maps()
    x = Syllab.encode_diphthongs(remove_accents(s).downcase,d)
    m = Syllab.helper(x)
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

  def Syllab.helper(s)
    # Input is assumed to have already been simplified.
    # Returns an array in which each element is the length of that syllable.
    v = "αειουηω012345678" # list of vowels, including the codes for the diphthongs
    cons = "βγδζθκλμνξπρσςτφχψ"
    n_vowels = s.scan(/[#{v}]/).length
    if n_vowels<=1 then return [s.length] end
    "γκλμνπρστ".chars.each { |c| # consonants that can be doubled
      if s=~/^(.*#{c})(#{c}.*)$/ then
        return Syllab.helper($1)+Syllab.helper($2)
      end
    }
    if s=~/^(.*[#{v}])([#{cons}][#{v}].*)$/ then # VCV -> V-CV
      return Syllab.helper($1)+Syllab.helper($2)
    end
    if s=~/^(.*[#{v}])([#{v}].*)$/ then # VV -> V-V (because diphthongs have already been encoded as a single vowel)
      return Syllab.helper($1)+Syllab.helper($2)
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
end
