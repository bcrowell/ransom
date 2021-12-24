class Writing
  def Writing.phoneticize(s)
    # decompose iota subscript into a vowel plus an iota
    s = s.downcase
    s = grave_to_acute(s) # we don't care about phonetic differences that only occur due to neighboring words
    s = Writing.archaicize_iota_subscript(s)
    s = Writing.phoneticize_breathing(s)
    s = Writing.accents_to_digraphs(s)
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
