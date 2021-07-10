def guess_whether_third_declension(word,lemma,pos)
  # example: word="κύνεσσι", lemma="κύων", pos="n-p---md-"
  # Project perseus 9-character POS	tags are defined at https://github.com/cltk/greek_treebank_perseus (scroll down).
  if pos[0]!='n' then return false end # has to be a noun
  if word=~/[^[:alpha:]]$/ then return false end # don't try to guess for forms with elision, such as ἄλγε᾽
  number = pos[2] # s, p, d
  gender = pos[6] # 
  c = pos[7] # ngdavl
  # I don't know how the following work, so just give up and return false:
  if number=='d' || c=='l' || c=='v' then return false end
  if guess_whether_third_declension_helper(gender,remove_accents(lemma)) then return true end
  w = remove_accents(word)
  if number=='s' then
    if c=='n' then
      # ---- nominative singular ----
      guess_whether_third_declension_helper(gender,w)
    end
    if c=='g' then
      # ---- genitive singular ----
      return true if w=~/[εου]ς$/ # short vowel followed by ς is a characteristic of 3rd decl; -ας may be ambiguous?
    end
    if c=='d' then
      # ---- dative singular ----
      return true if w=~/ι$/
    end
    if c=='a' then
      # ---- accusative singular ----
      return true if !(w=~/[ηαο]ν$/)
    end
  end
  if number=='p' then
    if c=='n' then
      # ---- nominative plural ----
      return true if !(w=~/(αι|οι|α)$/) # -α is ambiguous
    end
    if c=='g' then
      # ---- genitive plural ----
      return false # can't tell from this form
    end
    if c=='d' then
      # ---- dative plural ----
      return true if w=~/εσσιν?$/
    end
    if c=='a' then
      # ---- accusative plural ----
      return true if !(w=~/(ας|ους|α)$/) #  -ας and -α are ambiguous
    end
  end
  return false
end

def guess_whether_third_declension_helper(gender,w)
  # Given the singular nominative form w (which is the lexical form), try to guess whether it's 3rd declension.
  # List of words that are feminine and end if -ος:
  return false if
          ["νυος","νησος","φηγος","αμπελος","διαλεκτος","διαμετρος","αυλειος","συγκλητος","ερημος","ηπειρος","οδος","κελευθος","αμαξιτος","ατραπος",
           "βασανος","βιβλος","γερανος","γναθος","γυψος","δελτος","δοκος","δροσος","καμνος","καρδοπος","κβωτος","κοπρος","ληνος","λιθος","νοσος",
           "πλινθος","ραβδος","σορος","σποδος","ταφρος","χηλος","ψαμμος","ψηφος"].include?(w)
  return true if gender=='m' && !(w=~/ος$/)
  return true if gender=='f' && !(w=~/(α|η)$/)
  return true if gender=='n' && !(w=~/(ον)$/)
  return false
end
