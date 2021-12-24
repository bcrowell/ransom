class Writing
  # ruby -e "require './greek/writing.rb'; require './lib/string_util.rb'; print Writing.phoneticize('ῥέω')"
  # ruby -e "require './greek/writing.rb'; require './lib/string_util.rb'; Writing.test_phoneticize"
  def Writing.test_phoneticize()
    tests = [
      ["ῥέω","hρε!ω"],
      ["ῥηΐδιος","hρηι!διοσ"],
      ["δαμᾷ","δαμα~ι"],
      ["μὲν","με!ν"],
      ["ἀγλαός","αγλαο!σ"],
      ["ἑλώριον","hελω!ριον"]
    ]
    tests.each { |x|
      inp,out = x
      result = Writing.phoneticize(inp)
      if result!=out then
        $stderr.print "test failed, in=#{inp} out=#{result} expected=#{out}\n"
        exit(-1)
      else
        print "        passed: #{inp} #{result}\n"
      end
    }
  end
  def Writing.phoneticize(s)
    # Turn a Greek string into a phoneticized version that works better with
    # algorithms like longest common subsequence.
    s = s.downcase
    s = grave_to_acute(s) # we don't care about phonetic differences that only occur due to neighboring words
    s = Writing.remove_diar(s)
    s = Writing.archaicize_iota_subscript(s)
    s = Writing.phoneticize_breathing(s)
    s = Writing.accents_to_digraphs(s)
    s = s.sub(/ς/,'σ')
    return s
  end
  def Writing.accents_to_digraphs(s)
    # doesn't handle uppercase, grave accents, breathing marks, or ι subscripts
    result = ''
    s.chars.each { |c|
      noa = remove_accents(c)
      if noa!=c then
        c.sub!(/([άέίόύήώ])/) { noa+"!" }
        c.sub!(/([ᾶῖῦῆῶ])/) { noa+"~" }
      end
      result += c
    }
    return result
  end
  def Writing.archaicize_iota_subscript(s)
    result = ''
    s.chars.each { |c|
      noi = Writing.remove_iota_subscript(c)
      if noi==c then result += c else result += (noi+"ι") end
    }
    return result
  end
  def Writing.remove_iota_subscript(s)
    # https://en.wikipedia.org/wiki/Iota_subscript
    # doesn't handle uppercase, or grave accents
    s = s.tr('ᾳῃῳ','αηω')
    s = s.tr('ᾷῇῷ','ᾶῆῶ')
    s = s.tr('ᾴῄῴ','άήώ')
    return s
  end
  def Writing.remove_diar(s)
    # doesn't handle uppercase, grave accents, breathing
    s = s.tr('ϊϋΐΰ','ιυίύ')
    return s
  end
  def Writing.phoneticize_breathing(s)
    result = ''
    s.chars.each { |c|
      c = Writing.remove_soft_breathing(c)
      nor = Writing.remove_rough_breathing(c)
      if nor==c then result += c else result += ("h"+nor) end
    }
    return result
  end
  def Writing.remove_soft_breathing(s)
    # doesn't handle uppercase, or grave accents
    s = s.tr('ἀἐἰὀὐἠὠ','αειουηω')
    s = s.tr('ἄἔἴὄὔἤὤ','άέίόύήώ')
    s = s.tr('ἆἶὖἦὦ','ᾶῖῦῆῶ')
    return s
  end
  def Writing.remove_rough_breathing(s)
    # doesn't handle uppercase, or grave accents
    s = s.tr('ἁἑἱὁὑἡὡ','αειουηω')
    s = s.tr('ἅἕἵὅὕἥὥ','άέίόύήώ')
    s = s.tr('ἇἷὗἧὧ','ᾶῖῦῆῶ')
    s = s.tr('ῥ','ρ')
    return s
  end
end
