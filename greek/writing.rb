class Writing
  # ruby -e "require './greek/writing.rb'; require './lib/string_util.rb'; print Writing.phoneticize('ῥέω')"
  # ruby -e "require './greek/writing.rb'; require './lib/string_util.rb'; Writing.test_phoneticize"
  def Writing.romanize(s)
    # https://en.wikipedia.org/wiki/Romanization_of_Greek
    orig = s
    s = Writing.phoneticize(s,remove_accents:false,respell_final_sigma:true,preserve_graves:true)
    s = s.tr("αβγδεζηικλμνοπρστυφω","abgdezēiklmnoprstyfō")
    s = s.gsub(/([aeēoō])y/) {$1+'u'}
    s = s.gsub(/yi/) {'ui'}
    s = s.gsub(/θ/,'th')
    s = s.gsub(/ξ/,'ks')
    s = s.gsub(/χ/,'ch')
    s = s.gsub(/ψ/,'ps')
    s = s.gsub(/ē\!/,'ḗ')
    s = s.gsub(/ō\!/,'ṓ')
    s = s.gsub(/ē\@/,'ḕ')
    s = s.gsub(/ō\@/,'ṑ')
    s = s.gsub(/ē\~/,'e~')
    s = s.gsub(/ō\~/,'o~')
    s = Writing.digraphs_to_accents(s)
    if orig[0].downcase!=orig[0] then s = s.sub(/^(.)/) {$1.upcase} end # if input was in titlecase, put it back that way
    return s
  end
  def Writing.test_phoneticize()
    tests = [
      ["ῥέω","hρε!ω"],
      ["ῥηΐδιος","hρηι!διοσ"],
      ["δαμᾷ","δαμα~ι"],
      ["μὲν","με!ν"],
      ["ἀγλαός","αγλαο!σ"],
      ["ἑλώριον","hελω!ριον"],
      ["ἅπτω","hα!πτω"]
    ]
    tests.each { |x|
      inp,out = x
      result = Writing.phoneticize(inp,remove_accents:false,respell_final_sigma:true)
      if result!=out then
        $stderr.print "test failed, in=#{inp} out=#{result} expected=#{out}\n"
        exit(-1)
      else
        print "        passed: #{inp} #{result}\n"
      end
    }
  end
  def Writing.phoneticize(s,remove_accents:true,respell_final_sigma:false,reduce_double_sigma:false,preserve_graves:false)
    # Turn a Greek string into a phoneticized version that works better with
    # algorithms like longest common subsequence.
    # My main application is judging whether noun and verb inflections look irregular. For this purpose, it seems
    # best to use remove_accents:false, because the accents are basically never what's irregular.
    # For these applications, it's also not helpful to respell the final ς as σ, just creates confusion in things like stripping inflectional endings.
    s = s.downcase
    s = to_single_accent(s) unless preserve_graves # we don't care about phonetic differences that only occur due to neighboring words
    s = s.sub(/ψ/,'πσ')
    s = s.sub(/ξ/,'κσ')
    s = s.sub(/γκ/,'νκ')
    s = s.sub(/γξ/,'νκσ')
    s = s.sub(/γχ/,'νχ')
    if reduce_double_sigma then s = s.sub(/σσ/,'σ') end
    s = Writing.remove_diar(s)
    s = Writing.archaicize_iota_subscript(s)
    s = Writing.phoneticize_breathing(s)
    s = Writing.accents_to_digraphs(s)
    if respell_final_sigma then s = s.sub(/ς/,'σ') else s = s.sub(/σ$/,'ς') end
    if remove_accents then s=s.gsub(/[\!\~]/,'') end
    return s
  end
  def Writing.digraphs_to_accents(s)
    # same limitations as Writing.accents_to_digraphs
    "aeiouyαειουηω".chars.each { |c|
      s = s.gsub(/#{c}\!/) {add_acute(c)}
      s = s.gsub(/#{c}\@/) {add_grave(c)}
      s = s.gsub(/#{c}\~/) {add_circumflex(c)}
    }
    return s
  end
  def Writing.accents_to_digraphs(s)
    # doesn't handle uppercase, grave accents, breathing marks, or ι subscripts
    result = ''
    s.chars.each { |c|
      noa = remove_accents(c)
      if noa!=c then
        c.sub!(/([άέίόύήώ])/) { noa+"!" }
        c.sub!(/([ὰὲὶὸὺὴὼ])/) { noa+"@" }
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
    s = s.tr('ᾄᾔᾤ','ἄἤὤ')
    s = s.tr('ᾅᾕᾥ','ἅἥὥ')
    s = s.tr('ᾅᾕᾥ','ἅἥὥ')
    s = s.tr('ᾆᾖᾦ','ἆἦὦ')
    s = s.tr('ᾇᾗᾧ','ἇἧὧ')
    s = s.tr('ᾀᾐᾠ','ἀἠὠ')
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
