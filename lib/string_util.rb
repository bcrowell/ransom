# coding: utf-8

def capitalize(x)
  return x.sub(/^(.)/) {$1.upcase}
end

def words(s)
  # fixme: handle apostrophes
  # Don't use this for making word-by-word running hashes; that's what split_string_at_whitespace() is for.
  return s.scan(/[[:alpha:]]+/)
end

def split_string_at_whitespace(text)
  # Returns an array like [['The',' '],['quick',' '],...]. Every element is guaranteed to be a two-element list.
  # In the final pair, the whitespace will be a null string if the text doesn't end with whitespace.
  # This is basically meant for simple, reproducible word-by-word hashing (WhereAt.auto_hash), not for
  # human-readable text processing, so don't use it for other purposes or fiddle with it to make it work
  # for that purpose. For human-readable extraction of words, without punctuation, see words() above.
  a = text.scan(/([^\s]+)(\s+)/) # produces an array like [['The',' '],['quick',' '],...], without last word
  if text=~/([^\s]+)\Z/ then a.push([$1,'']) end # add final word
  return a
end

def split_string_into_paragraphs(text)
  # Returns a list like ["This is a paragraph.","\n\n","Another paragraph.","\n  \n\t\n",...].
  # Guaranteed to have even length, so final element may be a null string.
  # Like split_string_at_whitespace(), this is meant to be used for reproducible creation of hashes.
  paras_and_delimiters = text.split(/(\s*(?:\n[ \t]*){2,}\s*)/) # even indices=paragraphs, odd=delimiters
  if paras_and_delimiters.length%2==1 then paras_and_delimiters.push('') end # input doesn't end with a delimiter
  return paras_and_delimiters
end

def substr(x,i,len)
  # Basically returns x[i..(i+len-1)], but doesn't do screwy stuff in cases like i=0, len=0.
  result = ''
  i.upto(i+len-1) { |m|
    result = result+x[m]
  }
  return result
end

def texify_quotes(s)
  # testing: ruby -e "require './lib/string_util'; print texify_quotes('\"outer \'blah don\'t\'\"')"
  s = s.gsub(/((?<=[a-zA-Z]))'(?=[a-zA-Z])/,'__ENGLISH_INTERNAL_APOSTROPHE__')
  # We don't want [[:alpha:]], because Greek doesn't use mid-word apostrophes, and we don't want to get confused by cases where elision
  # was marked by an ASCII apostrophe.
  # Handle nested quotes, working from the inside out.
  1.upto(3) { |i| # handle up to three levels
    [[%q('),'SINGLE'],[%q("),'DOUBLE']].each { |x|
      char,kind = x
      s = s.gsub(/(?<![[:alpha:]])#{char}([^'"]+)#{char}(?![[:alpha:]])/) {"__OPEN_#{kind}_QUOTES__#{$1}__CLOSE_#{kind}_QUOTES__"}
      # ... negative lookbehind and negative lookahead help to ensure we don't get confused
    }
  }
  [['__OPEN_SINGLE_QUOTES__',%q(`)],    ['__CLOSE_SINGLE_QUOTES__',%q(')], 
   ['__OPEN_DOUBLE_QUOTES__',%q(``)],   ['__CLOSE_DOUBLE_QUOTES__',%q('')], 
   ['__ENGLISH_INTERNAL_APOSTROPHE__',%q(')]    ].each { |x|
    marker,replace_with = x
    s = s.gsub(/#{marker}/,replace_with)
  }
  return s
end

def char_to_code_block(c)
  # returns greek, latin, hebrew
  # for	punctuation or whitespace, returns latin
  # To test whether two characters are compatible with each other in terms of script, see compatible_scripts(), which handles punctuation.
  # For speed:
  cd = c.downcase
  if cd=~/[abcdefghijklmnopqrstuvwxyz]/ then return 'latin' end
  if cd=~/[αβγδεζηθικλμνξοπρστυφχψως]/ then return 'greek' end
  if c=~/[אבגדהוזחטילמנסעפצקרשתםןףץ]/ then return 'hebrew' end
  # For accented characters, we'll fall through to here:
  n = char_to_short_name(c)
  if is_name_of_greek_letter(n) then return 'greek' end
  if is_name_of_hebrew_letter(n) then return 'hebrew' end
  # If we fall through to here, then it will be really slow.
  b = char_unicode_property(c,'opt_unicode_block_desc')
  if b=~/(Latin|Greek|Hebrew)/ then return $1.downcase end
  return b
end

def compatible_scripts(c1,c2)
  if !(c1=~/[[:alpha:]]/) || !(c2=~/[[:alpha:]]/) then return true end
  return char_to_code_block(c1)==char_to_code_block(c2)
end

def common_script(c1,c2)
  if !compatible_scripts(c1,c2) then return nil end
  if !(c1=~/[[:alpha:]]/) then return char_to_code_block(c2) end
  return char_to_code_block(c1)
end

def char_is_rtl(c)
  script_name,garbage = char_to_script_and_case(c)
  script = Script.new(script_name)
  return script.rtl
end

def char_is_ltr(c)
  return !char_is_rtl(c)
end

def char_to_script_and_case(c)
  # Returns, e.g., ['greek','uppercase'] or ['hebrew',''].
  script = char_to_code_block(c)
  if script=='hebrew' then return [script,''] end
  if c.downcase==c then the_case='lowercase' else the_case='uppercase' end
  return [script,the_case]
end

def select_script_and_case_from_string(s,script,the_case)
  # Script and case should be strings. If script is hebrew, case should be a null string.
  return s.chars.select { |c| char_to_script_and_case(c).eql?([script,the_case]) }.join('')
end

def char_to_name(c)
  # This is extremely slow. Avoid using it.
  # Returns the official unicode name of the character.
  # Although these names are officially case-insensitive, this routine always returns uppercase.
  # Examples of names returned:
  #   LATIN SMALL LETTER A
  #   GREEK SMALL LETTER BETA
  #   HEBREW LETTER ALEF
  # The official name of lambda is spelled LAMDA, so that's what we return.
  return char_unicode_property(c,'name').upcase
end

def matches_case(c,the_case)
  script = char_to_code_block(c)
  if script=='hebrew' then return true end
  if the_case=='both' then return true end
  is_lowercase = (c.downcase==c)
  if is_lowercase && the_case=='lowercase' then return true end
  if !is_lowercase && the_case=='uppercase' then return true end
  return false
end

def char_to_short_name(c)
  # This mapping is meant to be one-to-one. The short name is supposed to be pure ascii, easy to type, and will not contain any spaces,
  # so it's appropriate for a filename.
  # Examples of returned values: a, A, alpha, Alpha, alef
  # Since this is meant to be human-readable, we change the spelling of lamda to lambda.
  # To test this:
  #  ruby -e "require 'json'; load 'lib/string_util.rb'; load 'lib/script.rb'; print char_to_short_name('ϊ')"
  x = char_to_short_name_from_table(c)
  if !(x.nil?) then return x end
  x = char_to_short_name_slow(c)
  warn("Short name #{x} was inferred for #{c}. This will be slow and may give a wrong result. See comments in char_to_short_name_hash() on how to speed this up.")
  if short_name_to_long_name(x)!=char_to_name(c) then warn("The short name #{x} inferred for #{c} expands to #{short_name_to_long_name(x)}, which is not the same as #{char_to_name(c)}") end # Make sure it works reversibly.
  return x
end

def char_to_short_name_slow(c)
  # This is abysmally slow. We use it only once when we generate the hard-coded table used in char_to_short_name_from_table.
  # Bug: doesn't work on accented latin characters.
  return char_to_short_name_helper(c)
end

def char_to_short_name_from_table(c)
  return char_to_short_name_hash()[c]
  end

def short_name_to_char(n)
  return char_to_short_name_hash().invert()[n]
end

def alpha_sort(l)
  return l.sort.sort { |a,b| alpha_compare(a,b) } # first, crude sort should make it more efficient because the comparisons in the second will be so slow
end

def alpha_equal(a,b)
  return (alpha_compare(a,b)==0)
end

def alpha_compare(a,b)
  return (remove_accents(a).downcase <=> remove_accents(b).downcase)
end

def canonicalize_greek_word(w)
  # works on a single word, not an entire string
  w = to_single_accent(w)
  w = standardize_greek_punctuation(w)
  return w
end

def has_circumflex(s)
  # regex constructed by hand, may not include every conceivable case
  if s.downcase=~/[ᾶῖῦῆῶἆἶὖἦὦἇἷὗἧὧᾷῇῷᾆᾖᾦᾇᾗᾧ]/ then return true else return false end
end

def to_single_accent(w)
  # In most cases, it's better to use canonicalize_greek_word() rather than this.
  # If the word has both an acute and a grave, remove the grave. If it has only a grave, change it to an acute.
  # This is used e.g. in LemmaUtil.make_inflected_form_flavored_like_lemma.
  # Testing: ruby -e "require './lib/string_util'; print to_single_accent('χεῖράς')"
  if remove_accents(w)==w then return w end # for efficiency
  if has_circumflex(w) then return remove_acute_and_grave(w) end
  acc = []
  0.upto(w.chars.length-1) { |i|
    c = w[i]
    if remove_acute_and_grave(c)!=c then acc.push(i) end
  }
  if acc.length>1 then
    # Remove every accent but the first.
    ww = w.dup
    1.upto(acc.length-1) { |m|
      i = acc[m]
      ww[i] = remove_acute_and_grave(ww[i])
    }
    return ww
  else
    return grave_to_acute(w)
  end
end

def add_rough_breathing(s)
  # testing: ruby -e 'require "./lib/string_util"; print add_rough_breathing("α")'
  if s.length>0 then s[0]=add_rough_breathing_to_character(s[0]) end
  return s
end

def add_rough_breathing_to_character(c)
  x = disassemble_greek_accent(c)
  x[0] = x[0].unicode_normalize(:nfc).tr("αειουηω","ἁἑἱὁὑἡὡ")
  return reassemble_greek_accent(x)
end

def disassemble_greek_accent(c)
  # Takes a Greek letter and breaks it down into a string like "α`" or "α`+", the latter being for uppercase; doesn't do anything with breathing.
  # Somewhat slow.
  if c!=c.downcase then return disassemble_greek_accent(c.downcase)+"+" end
  if has_circumflex(c) then return remove_circumflex(c)+"~" end
  if has_acute(c) then return remove_acute(c)+"'" end
  if has_grave(c) then return remove_grave(c)+"`" end
  return c
end

def reassemble_greek_accent(x)
  # inverse of disassemble_greek_accent
  if x=~/(.*)\+$/ then return reassemble_greek_accent($1).upcase end
  if x=~/(.*)\~$/ then return add_circumflex(reassemble_greek_accent($1)) end
  if x=~/(.*)\'$/ then return add_acute(reassemble_greek_accent($1)) end
  if x=~/(.*)\`$/ then return add_grave(reassemble_greek_accent($1)) end
  return x
end

def remove_punctuation(s)
  return s.gsub(/[^[:alpha:]]/,'')
end

# Code generated by code at https://stackoverflow.com/a/68338690/1142217
# See notes there on how to add characters to the list.
def remove_accents(s)
  return s.unicode_normalize(:nfc).tr("ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝàáâãäåæçèéêëìíîïñòóôõöøùúûüýÿΆΈΊΌΐάέήίΰϊϋόύώỏἀἁἂἃἄἅἆἈἉἊἌἍἎἐἑἒἓἔἕἘἙἜἝἠἡἢἣἤἥἦἧἨἩἫἬἭἮἯἰἱἲἳἴἵἶἷἸἹἼἽἾὀὁὂὃὄὅὈὉὊὋὌὍὐὑὓὔὕὖὗὙὝὠὡὢὣὤὥὦὧὨὩὫὬὭὮὯὰὲὴὶὸὺὼᾐᾑᾓᾔᾕᾖᾗᾠᾤᾦᾧᾰᾱᾳᾴᾶᾷᾸᾹῂῃῄῆῇῐῑῒῖῗῘῙῠῡῢῥῦῨῩῬῳῴῶῷῸ","AAAAAAÆCEEEEIIIINOOOOOOUUUUYaaaaaaæceeeeiiiinoooooouuuuyyΑΕΙΟιαεηιυιυουωoαααααααΑΑΑΑΑΑεεεεεεΕΕΕΕηηηηηηηηΗΗΗΗΗΗΗιιιιιιιιΙΙΙΙΙοοοοοοΟΟΟΟΟΟυυυυυυυΥΥωωωωωωωωΩΩΩΩΩΩΩαεηιουωηηηηηηηωωωωααααααΑΑηηηηηιιιιιΙΙυυυρυΥΥΡωωωωΟ")
end

# Code generated by grave_to_acute.rb
# See notes there on how to add characters to the list.
# If the intention is to canonicalize the form of a word, then don't use this, use to_single_accent().
def grave_to_acute(s)
  return s.unicode_normalize(:nfc).tr("ÀÈÌÒÙàèìòùἂἃἊἒἓἢἣἫἲἳὂὃὊὋὓὢὣὫὰὲὴὶὸὺὼῒῢῸ","ÁÉÍÓÚáéíóúἄἅἌἔἕἤἥἭἴἵὄὅὌὍὕὤὥὭάέήίόύώΐΰΌ")
end

# Code generated by code at https://stackoverflow.com/a/68338690/1142217
# See notes there on how to add characters to the list.
# changes to code:
#  name = char_to_name(c).gsub(/((with|and)\s*)?(grave|acute|tonos|oxia|varia)\s*/,'')
#  name.sub!(/and ypogegrammeni/,'with ypogegrammeni')
#  1.upto(3) { |i|
#    name.sub!(/with ([a-z]+) with ([a-z]+)/) { "with #{$1} and #{$2}" }
#    name.sub!(/and ([a-z]+) with ([a-z]+)/) { "with #{$1} and #{$2}" }
#  }
def remove_acute_and_grave(s)
  return s.unicode_normalize(:nfc).tr("ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝàáâãäåæçèéêëìíîïñòóôõöøùúûüýÿΆΈΊΌΐάέήίΰϊϋόύώỏἀἁἂἃἄἅἆἈἉἊἌἍἎἐἑἒἓἔἕἘἙἜἝἠἡἢἣἤἥἦἧἨἩἫἬἭἮἯἰἱἲἳἴἵἶἷἸἹἼἽἾὀὁὂὃὄὅὈὉὊὋὌὍὐὑὓὔὕὖὗὙὝὠὡὢὣὤὥὦὧὨὩὫὬὭὮὯὰὲὴὶὸὺὼᾐᾑᾓᾔᾕᾖᾗᾠᾤᾦᾧᾰᾱᾳᾴᾶᾷᾸᾹῂῃῄῆῇῐῑῒῖῗῘῙῠῡῢῥῦῨῩῬῳῴῶῷῸ","AAÂÃÄÅÆÇEEÊËIIÎÏÑOOÔÕÖØUUÛÜYaaâãäåæçeeêëiiîïñooôõöøuuûüyÿΑΕΙΟϊαεηιϋϊϋουωỏἀἁἀἁἀἁἆἈἉἈἈἉἎἐἑἐἑἐἑἘἙἘἙἠἡἠἡἠἡἦἧἨἩἩἨἩἮἯἰἱἰἱἰἱἶἷἸἹἸἹἾὀὁὀὁὀὁὈὉὈὉὈὉὐὑὑὐὑὖὗὙὙὠὡὠὡὠὡὦὧὨὩὩὨὩὮὯαεηιουωᾐᾑᾑᾐᾑᾖᾗᾠᾠᾦᾧᾰᾱᾳᾳᾶᾷᾸᾹῃῃῃῆῇῐῑϊῖῗῘῙῠῡϋῥῦῨῩῬῳῳῶῷΟ")
end

def remove_greek_tonal_accents(s)
  return remove_circumflex(remove_acute_and_grave(s))
end

def has_greek_tonal_accent(s)
  return remove_greek_tonal_accents(s)!=s
end

def add_acute(s)
  return s.unicode_normalize(:nfc).tr("aeiouyÀÁÂÆÇÈÉÊÌÍÏÒÓÔØÙÚÜÝàáâæçèéêìíïòóôøùúüýΆΈΊΌΐάέήίΰαεηιουωϊϋόύώἀἁἂἃἄἅἈἉἊἌἍἐἑἒἓἔἕἘἙἜἝἠἡἢἣἤἥἨἩἫἬἭἰἱἲἳἴἵἸἹἼἽὀὁὂὃὄὅὈὉὊὋὌὍὐὑὓὔὕὙὝὠὡὢὣὤὥὨὩὫὬὭὰὲὴὶὸὺὼᾓᾔᾕᾤᾴῂῄῒῢῴῸ","áéíóúýÁÁẤǼḈÉÉẾÍÍḮÓÓỐǾÚÚǗÝááấǽḉééếííḯóóốǿúúǘýΆΈΊΌΐάέήίΰάέήίόύώΐΰόύώἄἅἄἅἄἅἌἍἌἌἍἔἕἔἕἔἕἜἝἜἝἤἥἤἥἤἥἬἭἭἬἭἴἵἴἵἴἵἼἽἼἽὄὅὄὅὄὅὌὍὌὍὌὍὔὕὕὔὕὝὝὤὥὤὥὤὥὬὭὭὬὭάέήίόύώᾕᾔᾕᾤᾴῄῄΐΰῴΌ")
end

def has_acute(s)
  s.chars.each { |c|
    if add_acute(c)==c then return true end
  }
  return false
end

def remove_acute(s)
  if has_acute(s) then return remove_acute_and_grave(s) else return s end
end

def add_circumflex(s)
  # FIXME: very restricted compared to add_acute
  return s.unicode_normalize(:nfc).tr("αιυηωaeiouἀἰἠὠἁἱἡὡ","ᾶῖῦῆῶâêîôûἆἶἦὦἇἷἧὧ")
end

def remove_circumflex(s)
  # FIXME: same limitations as add_circumflex
  return s.unicode_normalize(:nfc).tr("ᾶῖῦῆῶâêîôûἆἶἦὦἇἷἧὧ","αιυηωaeiouἀἰἠὠἁἱἡὡ")
end

def has_grave(s)
  if remove_grave(s)!=s then return true else return false end
end

def add_grave(s)
  # FIXME: very restricted compared to add_acute
  return s.unicode_normalize(:nfc).tr("αειουηωaeiouἀἐἰὀὐἠὠἁἑἱὁὑἡὡ","ὰὲὶὸὺὴὼàèìòùἂἒἲὂὒἢὢἃἓἳὃὓἣὣ")
end

def remove_grave(s)
  # FIXME: same limitations as add_grave
  return s.unicode_normalize(:nfc).tr("ὰὲὶὸὺὴὼàèìòùἂἒἲὂὒἢὢἃἓἳὃὓἣὣ","αειουηωaeiouἀἐἰὀὐἠὠἁἑἱὁὑἡὡ")
end

def remove_macrons_and_breves(s)
  if !(s.kind_of?(String)) then return s end
  # ...convenience feature for stuff like parsing json data, which may include integers. Won't work for arrays containing strings.
  s = safe_normalize(s)
  s = s.tr("āēīōūӯ","aeiouy") # latin
  s = s.tr("ᾰᾱᾸᾹῐῑῘῙῠῡῨῩ","ααΑΑιιΙΙυυΥΥ")
  # Accent combined with macron. The monospaced fonts I'm using for coding display these incorrectly, and I also don't know how to type them.
  #         Furthermore, these seem to be represented as multiple characters, so that tr won't work. The following will be slow on short strings,
  #         but should perform well on long ones.
  #         The following isn't really an exhaustive list of vowels.
  "άίύὰὶὺΆΊΎᾺῚῪἀἐἰὀὐἠὠἁἑἱὁὑἡὡἄἔἴὄὔἤὤἂἒἲὂὒἢὢἅἕἵὅὕἥὥἃἓἳὃὓἣὣΐῒ".chars.each { |c|
    [772,774].each { |combining| # 772=combining macron, 774=combining breve (773=combining overline, presumably used for math)
      m = [c.ord, combining].pack("U*") # is not a single character
      s = s.gsub(/#{m}/,c)
    }
  }
  return s
end

def safe_normalize(s)
  begin
    return s.encode("UTF-8").unicode_normalize(:nfc)
  rescue
    # is probably 8-bit ascii/ISO-8859-1?
    return s
  end  
end

def char_to_short_name_hash()
  # The following JSON string is generated by Script.generate_table_for_char_to_short_name().
  # To generate an updated version, edit that routine so that it includes additional characters, then:
  #   ruby -e "require 'json'; load 'lib/string_util.rb'; load 'lib/script.rb'; print Script.generate_table_for_char_to_short_name"
  json = <<-"JSON"
{"a":"a","b":"b","c":"c","d":"d","e":"e","f":"f","g":"g","h":"h","i":"i","j":"j","k":"k","l":"l","m":"m","n":"n","o":"o","p":"p","q":"q","r":"r","s":"s","t":"t","u":"u","v":"v","w":"w","x":"x","y":"y","z":"z","A":"A","B":"B","C":"C","D":"D","E":"E","F":"F","G":"G","H":"H","I":"I","J":"J","K":"K","L":"L","M":"M","N":"N","O":"O","P":"P","Q":"Q","R":"R","S":"S","T":"T","U":"U","V":"V","W":"W","X":"X","Y":"Y","Z":"Z","Æ":"latin_capital_letter_ae","æ":"latin_small_letter_ae","Œ":"latin_capital_ligature_oe","œ":"latin_small_ligature_oe",".":"full_stop",",":"comma",";":"semicolon",":":"colon","-":"hyphen","?":"question_mark","/":"solidus","<":"less-than_sign",">":"greater-than_sign","[":"left_square_bracket","]":"right_square_bracket","{":"left_curly_bracket","}":"right_curly_bracket","_":"low_line","+":"plus_sign","=":"equals_sign","!":"exclamation_mark","#":"number_sign","%":"percent_sign","^":"circumflex_accent","&":"ampersand","~":"tilde","α":"alpha","β":"beta","γ":"gamma","δ":"delta","ε":"epsilon","ζ":"zeta","η":"eta","θ":"theta","ι":"iota","κ":"kappa","λ":"lambda","μ":"mu","ν":"nu","ξ":"xi","ο":"omicron","π":"pi","ρ":"rho","σ":"sigma","τ":"tau","υ":"upsilon","φ":"phi","χ":"chi","ψ":"psi","ω":"omega","ς":"final_sigma","Α":"Alpha","Β":"Beta","Γ":"Gamma","Δ":"Delta","Ε":"Epsilon","Ζ":"Zeta","Η":"Eta","Θ":"Theta","Ι":"Iota","Κ":"Kappa","Λ":"Lambda","Μ":"Mu","Ν":"Nu","Ξ":"Xi","Ο":"Omicron","Π":"Pi","Ρ":"Rho","Σ":"Sigma","Τ":"Tau","Υ":"Upsilon","Φ":"Phi","Χ":"Chi","Ψ":"Psi","Ω":"Omega","Ά":"Alpha_acute","Έ":"Epsilon_acute","Ί":"Iota_acute","Ό":"Omicron_acute","ΐ":"iota_diar_and_acute","ά":"alpha_acute","έ":"epsilon_acute","ή":"eta_acute","ί":"iota_acute","ϊ":"iota_diar","ό":"omicron_acute","ύ":"upsilon_acute","ώ":"omega_acute","ỏ":"latin_small_letter_o_with_hook_above","ἀ":"alpha_smooth","ἁ":"alpha_rough","ἃ":"alpha_rough_and_grave","ἄ":"alpha_smooth_and_acute","ἅ":"alpha_rough_and_acute","Ἀ":"Alpha_smooth","ἐ":"epsilon_smooth","ἑ":"epsilon_rough","ἒ":"epsilon_smooth_and_grave","ἔ":"epsilon_smooth_and_acute","ἕ":"epsilon_rough_and_acute","Ἐ":"Epsilon_smooth","Ἑ":"Epsilon_rough","Ἔ":"Epsilon_smooth_and_acute","ἡ":"eta_rough","ἢ":"eta_smooth_and_grave","ἣ":"eta_rough_and_grave","ἤ":"eta_smooth_and_acute","ἥ":"eta_rough_and_acute","ἦ":"eta_smooth_and_circ","Ἠ":"Eta_smooth","Ἡ":"Eta_rough","Ἣ":"Eta_rough_and_grave","Ἤ":"Eta_smooth_and_acute","Ἦ":"Eta_smooth_and_circ","ἰ":"iota_smooth","ἱ":"iota_rough","ἲ":"iota_smooth_and_grave","ἴ":"iota_smooth_and_acute","ἵ":"iota_rough_and_acute","ἶ":"iota_smooth_and_circ","Ἰ":"Iota_smooth","ὀ":"omicron_smooth","ὁ":"omicron_rough","ὂ":"omicron_smooth_and_grave","ὃ":"omicron_rough_and_grave","ὄ":"omicron_smooth_and_acute","ὅ":"omicron_rough_and_acute","Ὂ":"Omicron_smooth_and_grave","Ὅ":"Omicron_rough_and_acute","ὐ":"upsilon_smooth","ὑ":"upsilon_rough","ὓ":"upsilon_rough_and_grave","ὔ":"upsilon_smooth_and_acute","ὕ":"upsilon_rough_and_acute","ὖ":"upsilon_smooth_and_circ","ὗ":"upsilon_rough_and_circ","Ὕ":"Upsilon_rough_and_acute","ὡ":"omega_rough","ὢ":"omega_smooth_and_grave","ὣ":"omega_rough_and_grave","ὤ":"omega_smooth_and_acute","ὥ":"omega_rough_and_acute","ὧ":"omega_rough_and_circ","Ὠ":"Omega_smooth","Ὡ":"Omega_rough","ὰ":"alpha_grave","ὲ":"epsilon_grave","ὴ":"eta_grave","ὶ":"iota_grave","ὸ":"omicron_grave","ὺ":"upsilon_grave","ὼ":"omega_grave","ᾐ":"eta_smooth_and_ypogegrammeni","ᾗ":"eta_rough_and_circ_and_ypogegrammeni","ᾳ":"alpha_ypogegrammeni","ᾴ":"alpha_acute_and_ypogegrammeni","ᾶ":"alpha_circ","ῂ":"eta_grave_and_ypogegrammeni","ῆ":"eta_circ","ῇ":"eta_circ_and_ypogegrammeni","ῖ":"iota_circ","ῥ":"rho_rough","ῦ":"upsilon_circ","ῳ":"omega_ypogegrammeni","ῶ":"omega_circ","ῷ":"omega_circ_and_ypogegrammeni","Ὸ":"Omicron_grave","ᾤ":"omega_smooth_and_acute_and_ypogegrammeni","ᾷ":"alpha_circ_and_ypogegrammeni","ἂ":"alpha_smooth_and_grave","ἷ":"iota_rough_and_circ","Ὄ":"Omicron_smooth_and_acute","ᾖ":"eta_smooth_and_circ_and_ypogegrammeni","Ὁ":"Omicron_rough","ἧ":"eta_rough_and_circ","ῃ":"eta_ypogegrammeni","Ἄ":"Alpha_smooth_and_acute","Ὤ":"Omega_smooth_and_acute","ὦ":"omega_smooth_and_circ","ἠ":"eta_smooth","ἳ":"iota_rough_and_grave","ᾔ":"eta_smooth_and_acute_and_ypogegrammeni","Ἁ":"Alpha_rough","ᾦ":"omega_smooth_and_circ_and_ypogegrammeni","ὠ":"omega_smooth","ᾓ":"eta_rough_and_grave_and_ypogegrammeni","Ὣ":"Omega_rough_and_grave","Ἕ":"Epsilon_rough_and_acute","Ὀ":"Omicron_smooth","Ἥ":"Eta_rough_and_acute","Ἴ":"Iota_smooth_and_acute","ϋ":"upsilon_diar","Ὧ":"Omega_rough_and_circ","ῴ":"omega_acute_and_ypogegrammeni","ἆ":"alpha_smooth_and_circ","ῒ":"iota_diar_and_grave","ῄ":"eta_acute_and_ypogegrammeni","ΰ":"upsilon_diar_and_acute","ῢ":"upsilon_diar_and_grave","Ὑ":"Upsilon_rough","Ὦ":"Omega_smooth_and_circ","ᾧ":"omega_rough_and_circ_and_ypogegrammeni","ᾕ":"eta_rough_and_acute_and_ypogegrammeni","Ὃ":"Omicron_rough_and_grave","Ἅ":"Alpha_rough_and_acute","Ἱ":"Iota_rough","Ῥ":"Rho_rough","Ἵ":"Iota_rough_and_acute","ἓ":"epsilon_rough_and_grave","Ἧ":"Eta_rough_and_circ","Ἶ":"Iota_smooth_and_circ","ᾠ":"omega_smooth_and_ypogegrammeni","Ἆ":"Alpha_smooth_and_circ","ῗ":"iota_diar_and_circ","Ἂ":"Alpha_smooth_and_grave","Ὥ":"Omega_rough_and_acute","ᾑ":"eta_rough_and_ypogegrammeni","ᾰ":"alpha_vrachy","ῐ":"iota_vrachy","ῠ":"upsilon_vrachy","ᾱ":"alpha_macron","ῑ":"iota_macron","ῡ":"upsilon_macron","Ᾰ":"Alpha_vrachy","Ῐ":"Iota_vrachy","Ῠ":"Upsilon_vrachy","Ᾱ":"Alpha_macron","Ῑ":"Iota_macron","Ῡ":"Upsilon_macron","א":"alef","ב":"bet","ג":"gimel","ד":"dalet","ה":"he","ו":"vav","ז":"zayin","ח":"het","ט":"tet","י":"yod","ל":"lamed","מ":"mem","נ":"nun","ס":"samekh","ע":"ayin","פ":"pe","צ":"tsadi","ק":"qof","ר":"resh","ש":"shin","ת":"tav","ם":"final_mem","ן":"final_nun","ף":"final_pe","ץ":"final_tsadi"}
  JSON
  return JSON.parse(json)
end

def char_to_short_name_helper(c)
  # Don't call this directly. Call char_to_short_name() or char_to_short_name_slow().
  long = char_to_name(c).gsub(/LAMDA/,'LAMBDA')
  if long=='HYPHEN-MINUS' then long='hyphen' end
  if long=~/LATIN SMALL LETTER (.)$/ then return $1.downcase end
  if long=~/LATIN CAPITAL LETTER (.)$/ then return $1.upcase end
  if long=~/GREEK SMALL LETTER (.*)/ then return clean_up_accent_name(lc_underbar($1)) end
  if long=~/GREEK CAPITAL LETTER (.*)/ then return clean_up_accent_name(lc_underbar($1).capitalize) end
  if long=~/HEBREW LETTER (.*)/ then return lc_underbar($1) end
  return lc_underbar(long)
end

def lc_underbar(s)
  return s.downcase.gsub(/ /,'_')
end

def clean_up_accent_name(x)
  # input is, e.g., RHO_with_dasia
  if !(x=~/(.*)_with_(.*)/) then return x end
  bare,y = $1,$2.downcase
  stuff = []
  stuff.push(bare)
  h = accent_long_to_short_hash
  y.split(/_/).each { |a|
    aa = accent_long_to_short_name(a)
    if aa.nil? then aa=a end
    stuff.push(aa)
  }
  return stuff.join("_")
end

def accent_long_to_short_name(x)
  return accent_long_to_short_hash()[x]
end

def accent_short_to_long_name(x)
  return accent_long_to_short_hash().invert()[x]
end

def accent_long_to_short_hash()
  # unicode names use obscure greek names for accents
  return {"psili"=>"smooth","dasia"=>"rough","tonos"=>"acute","oxia"=>"acute","varia"=>"grave","perispomeni"=>"circ","dialytika"=>"diar"}
end

def short_name_to_long_name(name_raw)
  name = name_raw.clone.gsub(/_/,' ')
  if name.length==1 then return char_to_name(name) end # Latin
  if is_name_of_hebrew_letter(name) then return "HEBREW LETTER #{name}".upcase end
  if is_name_of_greek_letter(name) then
    # example: iota diar -> GREEK SMALL LETTER IOTA WITH DIALYTIKA
    accent_long_to_short_hash().invert().keys.each { |short_accent|
      name.gsub!(/#{short_accent}/i) {accent_short_to_long_name(short_accent).upcase}
    }
    nn = name.gsub(/LAMBDA/i,'LAMDA') # accept either lamda or lambda as the spelling, but convert to the spelling used in the standard
    if nn=~/^(\w+) (.*)/ then nn="#{$1} WITH #{$2}" end
    if nn=~/^[a-z]/ then
      return "GREEK SMALL LETTER #{nn.upcase}"
    else
      return "GREEK CAPITAL LETTER #{nn.upcase}"
    end
  end
  return name.upcase
end

def is_name_of_greek_letter(s)
  # Note that it's only anchored at the front, so stuff like iota_grave will work.
  return s=~/^(Alpha|Beta|Gamma|Delta|Epsilon|Zeta|Eta|Theta|Iota|Kappa|Lambda|Mu|Nu|Xi|Omicron|Pi|Rho|Sigma|Tau|Upsilon|Phi|Chi|Psi|Omega)/i
end

def is_name_of_hebrew_letter(s)
  return s=~/^(Alef|Bet|Gimel|Dalet|He|Vav|Zayin|Het|Tet|Yod|Final_Kaf|Kaf|Lamed|Final_Mem|Mem|Final_Nun|Nun|Samekh|Ayin|Final_Pe|Pe|Final_Tsadi|Tsadi|Qof|Resh|Shin|Tav)/i
end

def char_unicode_property(c,property)
  # https://en.wikipedia.org/wiki/Unicode_character_property
  # Shells out to the linux command-line utility called	"unicode," which is installed as the debian packaged of	the same name.
  # list of properties: https://github.com/garabik/unicode/blob/master/README
  #   useful ones include opt_unicode_block_desc, category, name
  # This is only going to work on Unix, and is also rather slow.
  # A platform-independent way to do this, without linking to C code, might be to use python's unicodedata module, but that would still be slow.
  # Probably better to write out a memoization table and then cut and paste it back into the code.
  if c=='"' then c='\\"' end
  result	= `unicode --string "#{c}" --format "{#{property}}"`
  if $?!=0 then	die($?) end
  return result
end

def clean_up_greek(s,thorough:false,silent:true)
  # s is any string, can contain any script or mix of scripts, can be more than one word.
  # Use the thorough option for external sources like raw Perseus xml files. This option is slow.
  s = standardize_greek_punctuation(s) # Standardize elision character and middle dot/ano teleia.
  if thorough then s=clean_up_grotty_greek(s,silent:silent) end
  return s
end

def standardize_greek_punctuation(s)
  # Works on any string, doesn't have to be a single word. Standardize elision character and middle dot/ano teleia.
  # Perseus writes ρ with breathing mark instead of ρ᾽ when there's elision:
  s = s.gsub(/(?<=[[:alpha:]])[ῤῥ](?![[:alpha:]])/,'ρ')
  # Wikisource has ῤῥ in the middle of words, e.g., χείμαῤῥοι, which OCT and Perseus don't have:
  s = s.gsub(/(?<=[[:alpha:]])ῤῥ(?=[[:alpha:]])/,'ρρ')
  # Standardize the elision character:
  s = s.gsub(/[᾽’'](?![[:alpha:]])/,'᾽')
  # ... There are other possibilities (see comments in contains_greek_elision), but these should already have been taken care of in flatten.rb.
  s = s.gsub(/#{[183].pack('U')}/,[903].pack('U')) # ano teleia has two forms, B7=183 and 387=903; GFS Porson and Olga only have the latter code point
  return s
end

def contains_greek_elision(s)
  if s=~/[᾽’]/ then return true else return false end
  # the above are koronis (8125=14bd hex) and apostrophe (8217=2019 hex)
  # see http://www.opoudjis.net/unicode/gkdiacritics.html
  # Perseus sometimes has 787=313 hex, which is combining comma above, the non-spacing version of koronis. This seems
  # to me to be a mistake on their part.
  # https://github.com/PerseusDL/treebank_data/issues/31
  # One could also have 700=2bc hex, spacing smooth breathing, which seems like an error, or 39=27 hex, the ascii apostrophe.
end

def clean_up_grotty_greek(s,silent:true)
  # Designed for external data sources that can have all kinds of nasty crap in them. Slow, thorough, silent, and brutal.
  a = s.split(/(\s+)/) # returns a string in which even indices are words, odd indices are whitespace
  b = []
  0.upto(a.length-1) { |i|
    w = a[i]
    if i%2==0 then
      unless w=~/[a-zA-Z]/ then # for speed and reliability; if it contains Latin letters, it shouldn't be a greek word
        w=clean_up_grotty_greek_one_word(w,silent:silent)
      end
    end
    b.push(w)
  }
  return b.join('')
end

def clean_up_grotty_greek_one_word(s,silent:true)
  # This works on a single word.
  s = s.sub(/σ$/,'ς').unicode_normalize(:nfc).sub(/&?απο[σς];/,"᾽")
  s = s.unicode_normalize(:nfc)
  s = clean_up_combining_characters(s)
  s2 = clean_up_beta_code(s)
  if s2!=s then
    $stderr.print "cleaning up what appears to be beta code, #{s} -> #{s2}\n" unless silent
    s = s2
  end
  greek_koronis = [8125].pack('U')
  if s[0]==greek_koronis then
    s = s[1..-1] # this happens in perseus for the lemma ἀθήνη, which they have encoded as 787 7936 952 ..., i.e., the
    #             breathing mark is there twice, once as a combining comma above and once as part of the composed character ἀ
    #             https://github.com/PerseusDL/treebank_data/issues/37
  end
  if s=~/[^[:alpha:]᾽[0-9]\?;]/ then raise "word #{s} contains unexpected characters; unicode=#{s.chars.map { |x| x.ord}}\n" end
  return s
end

def clean_up_combining_characters(s)
  combining_comma_above = [787].pack('U')
  greek_koronis = [8125].pack('U')
  s = s.sub(/#{combining_comma_above}/,greek_koronis)
  # ... mistaken use of combining comma above rather than the spacing version
  #     https://github.com/PerseusDL/treebank_data/issues/31
  # seeming one-off errors in perseus:
  s2 = s
  s2 = s2.sub(/#{[8158, 7973].pack('U')}/,"ἥ") # dasia and oxia combining char with eta
  s2 = s2.sub(/#{[8142, 7940].pack('U')}/,"ἄ") # psili and oxia combining char with alpha
  s2 = s2.sub(/#{[8142, 7988].pack('U')}/,"ἴ")
  s2 = s2.sub(/ἄἄ/,'ἄ') # why is this necessary...??
  s2 = s2.sub(/ἥἥ/,'ἥ') # why is this necessary...??
  s2 = s2.sub(/#{[769].pack('U')}([μτ])/) {$1} # accent on a mu or tau, obvious error
  s2 = s2.sub(/#{[769].pack('U')}ε/) {'έ'}
  s2 = s2.sub(/#{[180].pack('U')}([κ])/) {$1} # accent on a kappa, obvious error
  s2 = s2.sub(/#{[834].pack('U')}/,'') # what the heck is this?  
  s2 = s2.sub(/ʽ([ἁἑἱὁὑἡὡ])/) {$1} # redundant rough breathing mark
  # another repeating error:
  s2 = s2.sub(/(?<=[[:alpha:]][[:alpha:]])([ἀἐἰὀὐἠὠ])(?![[:alpha:]])/) { $1.tr("ἀἐἰὀὐἠὠ","αειουηω")+"᾽" }
  # ... smooth breathing on the last character of a long word; this is a mistake in representation of elision
  #     https://github.com/PerseusDL/treebank_data/issues/31
  if s2!=s then
    $stderr.print "cleaning up what appears to be an error in a combining character, #{s} -> #{s2}, unicode #{s.chars.map { |x| x.ord}} -> #{s2.chars.map { |x| x.ord}}\n"
    s = s2
  end
  return s
end

def clean_up_beta_code(s)
  # This was for when I mistakenly used old beta code version of project perseus.
  # Even with perseus 2.1, some stuff seems to come through that looks like beta code, e.g., ἀργει~ος.
  # https://github.com/PerseusDL/treebank_data/issues/30
  s = s.sub(/\((.)/) { $1.tr("αειουηω","ἁἑἱὁὑἡὡ") }
  s = s.sub(/\)(.)/) { $1.tr("αειουηω","ἀἐἰὀὐἠὠ") } 
  s = s.sub(/(.)~/) { $1.tr("αιυηω","ᾶῖῦῆῶ") } 
  s = s.sub(/\|/,'ϊ') 
  s = s.sub(/\/(.)/) { $1.tr("αειουηω","άέίόύήώ") }
  s = s.sub(/&θυοτ;/,'')
  s = s.sub(/θεοισ=ν/,'θεοῖσιν')
  s = s.sub(/ὀ=νοψ1/,'οἴνοπα1')
  s = s.sub(/π=ας/,'πᾶς')
  return s
end

def escape_double_quotes(s)
  return s.gsub(/"/,'\\"') # escape double quotes
end

def reverse_if_rtl(s)
  if s=='' then return s end
  if char_is_rtl(s[0]) then return reverse_string(s) else return s end
end

def reverse_string(s)
  r = 0
  s.chars.each { |c| r = c+r }
  return r
end

def console(*x)
  $stderr.print *x
end
