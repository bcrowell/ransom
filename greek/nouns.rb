def describe_declension(pos,tex)
  # tex = boolean, do we want latex-compatible output?
  # returns [long,short]
  number = {'s'=>'s.','d'=>'dual','p'=>'pl.'}[pos[2]]
  the_case = {'n'=>'nom.','g'=>'gen.','d'=>'dat.','a'=>'acc.','v'=>'voc.','l'=>'loc.'}[pos[7]]
  short = the_case
  long = "#{the_case} #{number}"
  if tex then long.gsub!(/\. /,".~") end
  return [long,short]
end

def test_decl_diff()
  # ruby -e "require './greek/nouns.rb'; require './lib/multistring.rb'; require './lib/string_util.rb'; test_decl_diff()"
  tests = [
    ['κύνεσσι','κύων','pmd'], 
    ['νῆας','ναῦς','pfa'], 
    ['θύγατρα','θυγάτηρ','sfa'],
    ['βασιλῆϊ','βασιλεύς','smd'],
    ['ἀνδρῶν','ἀνήρ','pmg'],
    ['παῖδα','παῖς','nsa'],
    ['νυκτὶ','νύξ','sfd'],
    ['νεκύων','νέκυς','pmg'],
    ['πόδας','πούς','pma'],
    ['φρεσὶ','φρήν','pfd'],
  ]
  results = []
  tests.each { |x|
    word,lemma,number_gender_case = x
    number,gender,c = number_gender_case.chars
    pos = "n-#{number}---#{gender}#{c}-"
    d = guess_difficulty_of_recognizing_declension(word,lemma,pos)
    results.push([d,"#{number_gender_case}  #{word}   #{lemma}   #{d}\n"])
  }
  results.sort { |a,b| a[0]<=>b[0] }.each { |r|
    print r[1]
  }
end

def guess_difficulty_of_recognizing_declension(word,lemma,pos)
  # Returns a floating-point number from 0 to about 1.0 (possibly a little higher in some cases).
  # For testing and calibration, see test_decl_diff() above.
  is_3rd_decl = guess_whether_third_declension(word,lemma,pos)
  w = remove_accents(word).downcase
  l = remove_accents(lemma).downcase
  # Figure out what declension it *looks like*, not necessarily what declension it is.
  decl = 2
  if !(l=~/ος/) then decl=1 end
  if is_3rd_decl then decl=3 end
  # Find stem based on lemma. We don't even want this to be super accurate, just want to catch the ones that are
  # obvious the the *human* as inflectional endings on the lemma
  if decl==1 then lemma_endings=['η','α'] end
  if decl==2 then lemma_endings=['ος','ον'] end
  if decl==3 then lemma_endings=['α','ος','υς','ις','ος','ας'] end
  e = lemma_endings.join('|')
  stem_from_lemma = l.sub(/(#{e})$/,'')
  # Pick off anything the *reader* would see as an inflectional ending.
  infl_endings = lemma_endings+['ης','ας','ους','οιο','ω','ι','ην','αν','ον','ν','αι','οι','ων','αων','ης','οις','εσσι','εσσιν','σι','σιν','ις','υς']
  e2 = infl_endings.join('|')
  stem_from_word = w.sub(/(#{e2})$/,'')
  ls = MultiString.new(stem_from_lemma)
  ws = MultiString.new(stem_from_word)
  dist = ls.distance(ws) # is 0 if identical, or number of chars unexplainable by longest common subsequence
  x = dist.to_f/([stem_from_lemma.length,stem_from_word.length].max) # basically the fraction of chars that are unexplainable
  if is_3rd_decl then x=x+0.2 end
  if is_feminine_ending_in_os(l) then x=x+0.2 end
  return x
end

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
  return false if is_feminine_ending_in_os(w)
  return true if gender=='m' && !(w=~/ος$/)
  return true if gender=='f' && !(w=~/(α|η)$/)
  return true if gender=='n' && !(w=~/(ον)$/)
  return false
end

def is_feminine_ending_in_os(w)
  # Given the unaccented singular nominative form w (which is the lexical form), determine whether this is one of the
  # exceptional feminine forms ending in -ος.
  # https://latin.stackexchange.com/a/13261/3597
  return  ["νυος","νησος","φηγος","αμπελος","διαλεκτος","διαμετρος","αυλειος","συγκλητος","ερημος","ηπειρος","οδος","κελευθος","αμαξιτος","ατραπος",
           "βασανος","βιβλος","γερανος","γναθος","γυψος","δελτος","δοκος","δροσος","καμνος","καρδοπος","κβωτος","κοπρος","ληνος","λιθος","νοσος",
           "πλινθος","ραβδος","σορος","σποδος","ταφρος","χηλος","ψαμμος","ψηφος"].include?(w)

end
