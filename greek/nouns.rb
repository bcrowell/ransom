def describe_declension(pos,tex)
  # tex = boolean, do we want latex-compatible output?
  # returns [long,short]
  number = {'s'=>'s.','d'=>'dual','p'=>'pl.'}[pos[2]]
  the_case = {'n'=>'nom.','g'=>'gen.','d'=>'dat.','a'=>'acc.','v'=>'voc.','l'=>'loc.'}[pos[7]]
  short = the_case
  long = "#{the_case} #{number}"
  if tex then long.gsub!(/\. /,".~") end
  if tex then
    short = "\\textsc{#{short}}".gsub(/\./,'')
    long = "\\textsc{#{long}}".gsub(/\./,'')
  end
  return [long,short]
end

def test_decl_diff()
  # ruby -e "require './greek/writing.rb'; require './greek/nouns.rb'; require './lib/multistring.rb'; require './lib/string_util.rb'; test_decl_diff()"
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
    ['λαοί','λαός','pmn']
  ]
  results = []
  tests.each { |x|
    word,lemma,number_gender_case = x
    number,gender,c = number_gender_case.chars
    pos = "n-#{number}---#{gender}#{c}-"
    d = guess_difficulty_of_recognizing_declension(word,lemma,pos)[1]
    results.push([d,"#{number_gender_case}  #{word}   #{lemma}   #{d}\n"])
  }
  results.sort { |a,b| a[0]<=>b[0] }.each { |r|
    print r[1]
  }
end

def guess_difficulty_of_recognizing_declension(word,lemma,pos)
  # Returns [if_hard,score,threshold].
  # For testing and calibration, see test_decl_diff() above.
  is_3rd_decl = guess_whether_hard_declension(word,lemma,pos)
  w = Writing.phoneticize(word)
  l = Writing.phoneticize(lemma)
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
  threshold = 0.4
  return [x>threshold,x,threshold]
end

def guess_whether_hard_declension(word,lemma,pos)
  return true if guess_whether_third_declension(word,lemma,pos)
  # archaic -φι(ν) ending:
  if remove_accents(word)=~/φιν?$/ then
    # smyth p 71, sec 280; an archaic ending usually used for instrumental, locative, ablative, genitive, or dative
    # example: Iliad 2.480, ἀγέληφι
    return true if !(pos[7]=~/[nav]/) # I don't see any other way for -φι/-φιν to occur, e.g., can't just occur for a noun that has φ in it.
  end
  return false
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

class Pronouns
  @@memoize_all = nil
  @@memoize_all_ho = nil
  @@memoize_all_as_hash = nil
  def Pronouns.is_one(p)
    return Pronouns.all_as_hash.has_key?(p)
  end
  def Pronouns.all_as_hash
    if @@memoize_all_as_hash.nil? then @@memoize_all_as_hash=Pronouns.all.to_h { |w| [w,1] } end
    return @@memoize_all_as_hash
  end
  def Pronouns.all
    # Returns an array containing every pronoun that occurs in homer (there are 242, counting accentuations).
    # Production of this is kind of a mess. My current version of find_all_pronouns.rb is supposed to get rid of lots of kinds of redundancies, but
    # the design of this code is that this list is supposed to include redundancies. So this is a merge of an older version of the list plus the
    # output of the newer script, which includes possessives. Articles are not really distinct from pronouns
    # in Homer, so they're included. Some of these differ only because there is a form with an acute and a form with a grave; to get a list
    # where these are identified, use Pronouns.all_no_grave.
    # ruby -e "require './greek/writing.rb'; require './greek/nouns.rb'; 
    #             require './lib/multistring.rb'; require './lib/string_util.rb'; print Pronouns.all"
    if @@memoize_all.nil? then
      x = %q{
ἅ αἱ αἳ αἵ αἵδε ἁμάς ἁμήν ἁμῆς ἄμμε ἄμμες ἄμμι ἄμμιν ἁμόν ἃς ἅς ἄσσα ἅσσά ἅσσα ἑ ἓ ἕ ἐγώ ἐγὼ ἔγωγέ ἔγωγε ἐγών ἐγὼν ἑέ ἑὲ ἕης ἑθέν ἑθεν ἕθεν εἷο ἐμά ἐμαί ἐμάς ἐμέ ἐμὲ ἐμέθεν ἐμεῖο ἐμέο ἐμεῦ ἐμῇ ἐμήν ἐμῆς ἐμῇς ἐμῇσιν ἐμοί ἐμοὶ ἔμοιγε ἐμοῖο ἐμοῖς ἐμοῖσιν ἐμόν ἐμός ἐμοῦ ἐμούς ἐμῷ ἐμῶν ἑο ἕο ἑοῖ εὑ ἡ ἣ ἥ ἥδέ ἥδε ἧμας ἡμέας ἡμεῖς ἡμείων ἡμέτεραι ἡμετέρας ἡμετεράων ἡμέτερε ἡμετέρῃ ἡμετέρην ἡμετέρης ἡμετέρῃς ἡμετέρῃσιν ἡμέτεροι ἡμετέροιο ἡμετέροις ἡμετέροισιν ἡμέτερον ἡμέτερος ἡμετέρου ἡμετέρῳ ἡμετέρων ἡμέτεῤ ἡμέων ἡμῖν ἥμιν ἧμιν ἣν ἥν ἧς ᾗς κεῖνος μέ με μευ μίν μιν μοί μοι νώ νὼ νῶΐ νῶι νῶϊ νῶιν νῶϊν ὁ ὃ ὅ ὅδε οἱ οἳ οἵ οἷ οἵδε οἷσί οἷσι οἷσίν οἷσιν ὃν ὅν ὅου ὃς ὅς ὅστις ὁτέοισιν ὅτευ ὅτεῳ ὅτεῴ ὅτεων ὅτεών ὅτινα ὅτινας ὅτίς ὅτις ὅττεο ὅττεό ὅττευ οὗ οὑμός οὓς οὕς σά σάς σέ σε σὲ σέθεν σεῖο σέο σεο σευ σεῦ σέων σή σῇ σήν σῆς σῇς σῇσιν σοί σοι σοὶ σοῖο σοῖς σοῖσιν σόν σός σοῦ σούς σύ σὺ σφας σφε σφέας σφεας σφείων σφέων σφεων σφι σφιν σφίσι σφισι σφίσιν σφισιν σφώ σφὼ σφωε σφῶΐ σφῶϊ σφωιν σφωϊν σφῶϊν σφῶν σφῷν σῷ σῶν τά τάδε ταί ταὶ τάς τὰς τάσδε τάων τεῇ τεήν τεῆς τεῇς τεΐν τεῒν τέο τεο τεοῖο τεοῖσιν τεόν τεός τευ τεῦ τεώ τεῳ τεῷ τέων τῇ τῇδέ τῇδε τήν τὴν τήνδε τῆς τῇς τῆσδέ τῆσδε τῇσι τῇσίν τῇσιν τί τι τίνα τινά τινα τινὰ τινάς τινας τινε τίνες τινές τινες τινι τίς τις τό τὸ τόδε τοί τοι τοὶ τοιάδε τοιαίδε τοιήδε τοῖιν τοῖϊν τοῖο τοιοίδε τοιόνδε τοιόσδε τοιούσδε τοῖς τοῖσδε τοίσδεσι τοίσδεσσι τοῖσδεσσι τοίσδεσσιν τοῖσί τοῖσι τοῖσίν τοῖσιν τόν τόνδε τοσόνδέ τοσόνδε τοσσάδε τοσσόνδε τοῦ τοῦδέ τοῦδε τούς τοὺς τούσδε τύνη τώ τὼ τῳ τῷ τώδε τῷδε τῶν τῶνδε ὑμά ὑμέας ὑμεῖς ὑμείων ὑμετέρῃ ὑμετέρης ὑμετέρῃσιν ὑμετέροισιν ὑμέτερον ὑμέτερος ὑμετέρου ὑμετέρους ὑμετέρων ὑμέων ὑμήν ὑμῆς ὑμῖν ὕμιν ὔμμε ὔμμες ὔμμι ὔμμιν χἠμεῖς ὣ ὥ ᾧ ὧν
}
      @@memoize_all = alpha_sort(x.scan(/[[:alpha:]]+/)).uniq
    end
    return @@memoize_all
  end
  def Pronouns.all_no_grave
    return Pronouns.all.map { |w| to_single_accent(w) }.uniq
  end
  def Pronouns.all_ho
    # Return a list of all forms of the noun/adjective/relative pronoun ὁ/ὅ, "ho," in Homer.
    # The following is based on my report_inflections.rb script. These are the acute-accented forms, but we'll also return the unaccented ones.
    # m: ὅ τοῖο/τοῦ τῷ/οἱ τόν ... οἵ/τοί τῶν τοῖσ(ιν) τούς
    # f: ἥ τῆς τῇ τήν ... αἵ/ταί τάων/τῶν τῇσ(ιν) τάς
    # n: τό τοῖο/τοῦ τῷ τό/ὅττι ... τά τῶν τοῖσ(ιν) τά
    if @@memoize_all_ho.nil? then
      x = %q{ ὅ τοῖο τοῦ τῷ οἱ τόν       οἵ τοί τῶν τοῖσ τοῖσι τοῖσιν τούς
              ἥ τῆς τῇ τήν               αἵ ταί τάων τῶν τῇσ τῇσι τῇσιν τάς
              τό τοῖο τοῦ τῷ τό ὅττι     τά τῶν τοῖσ τοῖσι τοῖσιν τά }
      x = alpha_sort(x.scan(/[[:alpha:]]+/)).uniq
      unaccented = x.map { |w| remove_accents(w) }
      @@memoize_all_ho = Pronouns.all.select { |p| unaccented.include?(remove_accents(p)) }
    end
    return @@memoize_all_ho
  end
end
