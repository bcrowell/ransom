module Verb_difficulty
  def Verb_difficulty.test()
    # ruby -e "require './greek/writing.rb'; require './greek/verbs.rb'; require './greek/nouns.rb'; require './lib/multistring.rb'; require './lib/clown.rb'; require './lib/string_util.rb'; Verb_difficulty.test()"
    tests = [
      ["ἁζόμενοι","ἅζομαι","v-pppemn-",false],
      ["λύει","λύω","v3spia---",false],
      ["ἠτίμασεν","ἀτιμάζω","v3saia---",false],
      ["λίσσετο","λίσσομαι","v3siie---",false],
      ["ᾤχετο","οἴχομαι","v3siie---",false],
      ["λυσόμενός","λύω","v-sfpmmn-",false],
      ["μάχεσθαι","μάχομαι","v--pne---",false],
      ["κιὼν","κίω","v-sapamn-",false],
      ["ἔλυσα","λύω","v1saia---",false],
      ["ἐφιεὶς","ἐφίημι","v-sppamn-",true],
      ["δαμᾷ","δαμάζω","v3sfia---",true],
      ["ἤγερθεν","ἀγείρω","v3paip---",true],
      ["ἔφατ᾽","φημί","v3siie---",true],
      ["ἴθι","εἶμι","v2spma---",true],
      ["ὄμοσσον","ὄμνυμι","v2sama---",true],
      ["οἶσθα","οἶδα","v2sria---",true],
    ]
    results = []
    tests.each { |x|
      word,lemma,pos,i_think_hard = x
      if_hard,score,threshold,debug = Verb_difficulty.guess(word,lemma,pos)
      if if_hard then hard_string='hard' else hard_string='easy' end
      mismatch = (i_think_hard!=if_hard)
      if mismatch then mismatch_string='******* error ??? *******' else mismatch_string='' end
      results.push([score,sprintf("%10s %10s %.2f %s %s %20s %s\n",word,lemma,score,hard_string,mismatch_string,Vform.new(pos),debug)])
    }
    results.sort { |a,b| a[0]<=>b[0] }.each { |r|
    print r[1]
  }
end

  # Code that tries to judge the difficulty of recognizing a particular inflected form of a verb.
  def Verb_difficulty.guess(word,lemma,pos)
    f = Vform.new(pos)
    f_lemma = f.make_lemma(lemma)
    # The effect of the following is to strip accents, phoneticize rough breathing as 'h' or null string, and archaicize iota subscripts.
    μι_verb = (lemma=~/μι$/) # won't work if, e.g., lemma is 2nd aorist, but failure is awesome
    w = Writing.phoneticize(word)
    stem_from_word =  Verb_difficulty.strip_ending(w,μι_verb,f)
    l = Writing.phoneticize(lemma)
    stem_from_lemma = Verb_difficulty.strip_ending(l,μι_verb,f_lemma)
    stem_from_lemma_with_sigma = Verb_difficulty.add_sigma_to_aorist_or_future(stem_from_lemma,f)
    # ... e.g., if w is aorist, find the aorist stem from the lemma
    # In the following, ws and ls are multistrings, not strings.
    ws = Verb_difficulty.strip_augment(stem_from_word,f)
    ls = Verb_difficulty.strip_augment(stem_from_lemma,f_lemma)
    ls_with_sigma = Verb_difficulty.strip_augment(stem_from_lemma_with_sigma,f_lemma)
    ls = ls.or(ls_with_sigma)
    dist = ls.distance(ws) # is 0 if identical, or number of chars unexplainable by longest common subsequence
    x = dist.to_f/([stem_from_lemma.length,stem_from_word.length].max) # basically the fraction of chars that are unexplainable
    x = x+dist*0.1
    threshold = 0.27
    return [x>threshold,x,threshold,{
      # debugging info:
      'wstem'=>stem_from_word,
      'lstem'=>[stem_from_lemma,stem_from_lemma_with_sigma],
      'unaug'=>ws.to_s
    }]
  end

  def Verb_difficulty.strip_augment(word,f)
    # This won't work if it has a preposition on the front, which is good because failure is awesome.
    if !(f.past) then
      return MultiString.new(word)
    else
      # past tense, may have augment
      patterns = [
        ["ηι",["αι","ει"]], # phoneticized, so handles stuff like ῃ -> ᾳ
        ["ωι",["οι"]], # ῳ
        ["ηυ",["αυ","ευ"]],
        ["η",["α","ε"]],
        ["ω",["ο"]],
        ["ε",[""]]
      ]
      poss = [word]
      patterns.each { |a,l|
        if word=~/^#{a}/ then
          l.each { |b|
            poss.push(word.sub(/^#{a}/,b))
          }
          break # e.g., if it matches ῃ, don't also try to apply the η rule to it
        end
      }
      return MultiString.new([poss]) # needs a singleton list of lists, not just a list
    end
  end

  def Verb_difficulty.add_sigma_to_aorist_or_future(s,f)
    # s is a string (not a multistring), has already had its ending stripped
    if !(f.aorist || f.future) then return s end
    if s=~/σ$/ then return s end
    if s=~/[μνλρ]$/ then return s end
    if s=~/[ζ]$/ then return s.sub(/.$/,'σ') end
    return s+'σ'
  end

  def Verb_difficulty.strip_ending(s,μι_verb,f)
    # The point of the following is not to be correct in all cases. The goal is actually to strip the ending in the way that a bewildered
    # human would be likely to do. This is the "failure is awesome" philosophy.
    # Input s should be phoneticized, not raw accented Greek.
    if remove_accents(s)!=s then $stderr.print "input to Verb_difficulty.strip_ending not phoneticized: #{s}\n"; exit(-1) end
    pat = nil
    # $stderr.print "                                        #{s} #{pat} #{f}\n" # qwe
    if f.active then
      if f.indicative then
        if !μι_verb then
          if f.present || f.future then pat = "ω|εις|ει|ομεν|ετε|ουσιν?" end
          if f.imperfect then pat = "ον|ες|εν?|ομεν|ετε|ον" end
          if f.aorist then pat = "α|ας|εν?|αμεν|ατε|αν" end # don't try to do root aorist, we *want* those to get scored as high difficulty
        else
          # μι verbs, indicative
          if f.present then pat = "μι|ς|σι|μεν|τε|ασιν?" end
          if f.past then pat = "ν|ς|μεν|τε|σαν" end
        end
      end
      if f.optative then
        if f.present then pat = "μι|ην|ς|ης|η|οι|μεν|τε|εν?" end
        if f.aorist then pat = "μι|ς|μεν|τε|εν?" end
      end
      if f.imperative then pat = "ε|θι|τι|τε" end # no dual forms, failure is awesome
      if f.infinitive then
        if μι_verb then pat = "εν|ειν|μεναι|μεν|αι|ναι" else pat = "εν|ειν|ο?μεναι|ο?μεν|αι" end
      end
      if f.participle then pat = "ων|ους|ασιν|((οντ|αντ)(ος|ι|α|ες|ων|ας))|((ουσ|ασ)(α|ης|ηι|αν|αι|αων|ηις|ας))|((αν)(|τος|τι|τα|ων|α))" end
      # ... spellings like ηι are because s is already phoneticized; don't do athematic stuff like υς because failure is awesome
    else
      # voice = passive, middle, mp
      if f.present || f.future then pat = "o?(μαι|αι|σαι|ται|μεθα|σθε|νται|ομαι|ει|εται|ομεθα|εσθε|ονται)" end
      if f.imperfect || (f.aorist && !f.passive) then 
        if μι_verb then pat = "μην|σο|το|μεθα|σθε|ντο|ατο" else pat = "ομην|εσο|ετο|ομεθα|εσθε|οντο|ατο" end
      end
      if f.aorist && f.passive then pat = "(θη)?(ν|ς||το|μεν|τε|σαν|θεν|ντο)" end # null in 2nd group is to allow bare θη
      if f.imperative then pat = "σο|ου|σθε" end # no dual forms, failure is awesome
      if f.participle then pat = "ο?μεν(ος|ου|οιο|ωι|ον|οι|ων|οις|οισιν?|ους|ης|ας|η|α|ην|αν|αι|ηις|ηισιν?|ας)" end
      # ...2-1-2 endings; -ο- is actually only for thematic verbs
      if f.infinitive then
        if !(f.aorist) then
          if μι_verb then pat = "σθαι" else pat = "εσθαι" end
        else
          if μι_verb then pat = "ναι|μεναι|μεν" else pat = "ομεναι|ομεν" end
        end
      end
    end
    if !(pat.nil?) then s = s.sub(/(#{pat})$/,'') end
    # ... not really a bug if pat is nil; can just indicate that this is something obscure where the human would have trouble
    return s
  end
end

class Vform
  # An instance of this class basically embodies a Project Perseus part-of-speech tag for a verb in a form that is more convenient to
  # manipulate.
  def initialize(perseus_pos)
    # definition of perseus 9-character pos tags: https://github.com/cltk/greek_treebank_perseus
    # First character has to be there as a placeholder, but is ignored.
    # Final three characters are optional, ignored.
    # To get back a complete 9-character perseus tag, use the method get_perseus_tag().
    if !(perseus_pos[0]=~/[vt]/) then $stderr.print caller[0..5].join("\n")+"\nVform initialized with pos=#{perseus_pos}, not a verb or participle\n"; exit(-1) end
    @person = perseus_pos[1].to_i # 1, 2, or 3
    @number = perseus_pos[2] # 's', 'd', or 'p'
    @tense = perseus_pos[3] # paif = present,aorist,imperfect,future; rlt = perfect,pluperfect,future perfect
    @mood = perseus_pos[4] # isonmp = indicative,subjunctive,optative,infinitive,imperative,participle
    @voice = perseus_pos[5] # apme = active,passive,middle,medio-passive
    @participle_stuff = perseus_pos[6..7]
  end

  attr_reader :person,:number,:tense,:mood,:voice

  def make_lemma(lemma)
    # take a Vform describing an inflected form, and a string representing its lemma, and try to make the correct Vform for the lemma
    result = clown(self)
    result.make_lemma!(lemma)
    return result
  end

  def make_lemma!(lemma)
    @person = 1
    @number = 's'
    @mood = 'i'
    if lemma=~/(ω|μι|μαι)$/ then @tense = 'p' end
    if lemma=~/(α|ον)$/ then @tense = 'a' end
    if lemma=~/(ω|μι|ον)$/ then @voice = 'a' end
    if lemma=~/(μαι)$/ then @voice = 'p' end # mark it as passive; better to use middle or mp?
  end

  def get_perseus_tag
    if self.participle() then c0='t'; c67=@participle_stuff else c0='v';c67='--' end
    return c0+@person.to_s+@number+@tense+@mood+@voice+c67+'-'
  end

  def indicative() return (@mood=='i') end
  def optative() return (@mood=='o') end
  def imperative() return (@mood=='m') end
  def active() return (@voice=='a') end
  def passive() return (@voice=='p') end
  def present() return (@tense=='p') end
  def future() return (@tense=='f') end
  def singular() return (@number=='s') end
  def dual() return (@number=='d') end
  def plural() return (@number=='p') end # doesn't include dual
  def perfect() return (@tense=~/[rlt]/) end
  def past() return (@tense=~/[ail]/) end
  def present() return (@tense=='p') end
  def aorist() return (@tense=='a') end
  def imperfect() return (@tense=='i') end
  def infinitive() return (@mood=='n') end
  def participle() return (@mood=='p') end

  def to_s
    result = []
    if !(self.participle || self.infinitive) then result.push(self.person.to_s+({'s'=>'s','p'=>'pl','d'=>'dual'}[self.number])) end
    if !self.present then result.push({'i'=>'impf.','r'=>'perf.','l'=>'plupf.','t'=>'fut. perf.','f'=>'fut.','a'=>'aor.'}[self.tense]) end
    if !self.indicative then result.push({'s'=>'subj.','o'=>'opt.','n'=>'inf.','m'=>'impve.','p'=>'part'}[@mood]) end
    if !self.active then result.push({'p'=>'pass.','m'=>'mid.','e'=>'mp'}[@voice]) end
    if_tex = false # don't put ~ after ., not appropriate for a general-purpose stringification routine
    if self.participle then result.push(describe_declension(self.get_perseus_tag,if_tex)[0]) end
    # part mp nom. pl. nom.
    return result.join(' ')
  end

end

class Verb_conj

# This class was my attempt to do conjugation using code. Didn't work very well, not currently used in ransom.

def Verb_conj.regular(lemma,f,principal_parts:{},do_archaic_forms:false,include_contracted:true)
  # lemma may be fully accented or omit the acute accent
  # f is a Vform object
  # principal_parts is a hash whose keys are strings such as '2' for the second principle part, etc.
  # Returns [conjugated verb,unimplemented,error message,explanation].
  # Conjugated verb is a list, usually a singleton. If the form doesn't exist, e.g., 1st-person imperative, then this is an empty list.
  # If there's an error or the conjugation is unimplemented, then conjugated verb is nil.
  # The unimplemented flag says that the user didn't do anything wrong, but the relevant feature just isn't implemented yet.
  # Explanation is a list of strings explaining any non-obvious rules used.
  # Conjugated verb is supposed to be a string that is what the conjugation *would* be if the verb were 
  # regular. For example, if you want to determine whether a certain form is or is not regular, you can
  # compare the actual form against the one returned by this routine.
  # Irregular verbs are usually irregular only in the formation of their principal parts, not in the
  # conjugation based on those parts. So if a non-empty principal_parts argument is supplied, then
  # this routine should in most cases actually give the correct conjugation in *irregular* cases.
  # This routine doesn't know which verbs are contract verbs, but if include_contracted is true (the
  # default) then it will include contracted forms as possibilities.

  if f.imperative && f.person==1 then return [[],false,nil,"First-person imperative forms don't exist.",nil] end
  lemma = remove_acute_and_grave(lemma)

  if lemma=~/μαι/ then return [nil,true,"Lemmas in -μαι are not implemented.",nil] end

  # -- Thematic/athematic, present stem.
  thematic = nil
  if lemma=~/(.*)ω$/ then thematic=true; present_stem=$1 end
  if lemma=~/(.*)μι$/ then thematic=false; present_stem=$1 end
  if lemma=~/(.*)εῖν$/ then return [nil,true,'Verbs like φαγεῖν, which have no present tense, are not implemented.',nil] end
  if lemma=~/(.*)α$/ then return [nil,true,'Verbs like ἄνωγα, with the perfect used as the present, are not implemented.',nil] end
  if lemma=~/(.*)ον$/ then return [nil,true,'Verbs like τέτμον, with the epic aorist used as the present, are not implemented.',nil] end
  if lemma=~/(.*)ῶ$/ then return [nil,true,'The software does not implement conjugation given an already-contracted lemma like ζῶ.',nil] end
  if remove_accents(lemma)=~/^(δει|χρη)$/  then return [nil,true,'Impersonal verbs like δεῖ and χρή are not implemented.',nil] end
  if thematic.nil? then return [nil,false,"unable to recognize lemma #{lemma} as -ω or -μι",nil] end
  if !thematic then return [nil,true,'Athematic verbs are not implemented.',nil] end

  # -- Stem.
  stem = present_stem
  desired_principal_part = '1'
  optional_doubled_sigma = false # principal parts like -σα can also be -σσα, Pharr, p. 324
  optional_unaugmented_stem = nil # augments are optional in Homer
  if f.aorist then
    desired_principal_part='3'
    stem,optional_doubled_sigma,optional_unaugmented_stem = Verb_conj.aorist_stem(present_stem)
  end
  if principal_parts.has_key?(desired_principal_part) then stem=principal_parts[desired_principal_part] end

  # --
  if !(f.present || f.aorist || f.imperfect) then return [nil,true,'Tenses other than the present, imperfect, and aorist are not implemented.',nil] end
  if !f.indicative then return [nil,true,'Moods other than the indicative are not implemented.',nil] end
  if !f.active then return [nil,true,'Voices other than the active are not implemented.',nil] end

  # -- Movable nu.
  #    https://en.wikipedia.org/wiki/Movable_nu
  movable_nu = f.person==3 && ((f.plural && (f.present || f.future)) || (f.singular && (f.perfect || f.past || (f.present && !thematic))))

  # == Personal ending.
  if f.present || f.future then
    if f.singular then ee='ω ισ ι' end
    if f.dual     then ee='@ τον τον' end
    if f.plural   then ee='μεν τε σι' end
  end
  if f.imperfect then
    if f.singular then ee='ν σ -' end
    if f.dual     then ee='@ τον τον' end # fixme: this may be wrong
    if f.plural   then ee='μεν τε ν' end
  end
  if f.aorist then
    if f.singular then ee='- σ -' end
    if f.dual     then ee='@ τον την' end
    if f.plural   then ee='μεν τε ν' end
  end
  endings = ee.split(/\s+/)[f.person-1].split(/\//).map { |x| if x=~/[@\-]/ then {'@'=>nil,'-'=>''}[x] else x end}
  if f.active && f.dual && f.person==1 then return [[],false,nil,"Active dual first-person forms don't exist."] end
  if endings.nil? then return [[],false,nil,"endings not implemented for #{f.get_perseus_tag}"] end

  # -- Thematic vowel, contraction.
  forms = []
  if thematic then
    endings.each { |e|
      t = thematic_vowel(f,e)
      flags = {'form_before_contraction'=>stem+t+e}
      forms.push([stem,t+e,flags.merge({'contracted'=>false})])
      if include_contracted then
        c = Verb_conj.contract(stem,f,t,e,Verb_conj.n_syll(lemma)==2)
        # if !c.nil? then print "............... t=#{t} e=#{e} c=#{c}\n" end
        if !(c.nil?) then forms.push([c[0],c[1],flags.merge({'contracted'=>true})]) end
      end
    }
  end

  #-- Postprocessing.
  results = []
  forms.each { |x|
    stem,e,flags = x
    0.upto(1) { |doubled_sigma|
      next if doubled_sigma==1 && !optional_doubled_sigma
      0.upto(1) { |unaugmented_stem|
        next if unaugmented_stem==1 && optional_unaugmented_stem.nil?
        0.upto(1) { |do_movable_nu|
          next if do_movable_nu==1 && !movable_nu
          if unaugmented_stem==0 then s=stem.dup else s=optional_unaugmented_stem.dup end
          if doubled_sigma==1 then s=s+'σ' end
          form = Verb_conj.accentuation_helper(s,e,flags['form_before_contraction'],flags['contracted'])
          if do_movable_nu==1 then form=form+'ν' end
          form = Verb_conj.respell_sigmas(form)
          results.push(form)
        }
      }
    }
  }

  return [results,false,nil,nil]  
end

def Verb_conj.accentuation_helper(stem,e,before_contraction,if_contracted)
  # recessive accent (fixme: not for participles, and see other exceptions, Pharr p. 330)
  if Verb_conj.long_ultima(before_contraction) then accent_syll=2 else accent_syll=3 end # counting back from end, 1-based
  accent_syll = [accent_syll,Verb_conj.n_syll(before_contraction)].min
  n_syll_ending = Verb_conj.n_syll(e)
  did_accentuation = false
  if if_contracted==true then
    # Is this sometimes wrong? https://ancientgreek.pressbooks.com/chapter/17/ has unclear ref to 
    # "the accent rules that apply to vowel contractions, learned earlier."
    e2 = Verb_conj.accentuation_helper2(e,accent_syll-1,type_of_accent:'circ') # contractions all contract two syllables to 1
    form = stem+e2
    did_accentuation = true        
  end
  if !did_accentuation then form = Verb_conj.accentuation_helper2(stem+e,accent_syll) end
  return form  
end

def Verb_conj.accentuation_helper2(w,accent_syll,type_of_accent:'acute')
  accent_syll = [accent_syll,Verb_conj.n_syll(w)].min
  # This is a kludge. What happens is that stem can be unaugmented (because the augment is optional), but
  # before_contraction is augmented.
  return Verb_conj.accentuate(w,accent_syll,type_of_accent:type_of_accent)
end

def Verb_conj.aorist_stem(present_stem)
  augmented_stem,optional_doubled_sigma,optional_unaugmented_stem = [nil,nil,nil]
  0.upto(1) { |do_augment|
    stem,x = Verb_conj.aorist_stem_final_cons_helper(present_stem)
    if do_augment==1 then
      augmented_stem = 'ἐ'+stem
      optional_doubled_sigma = x
    else
      optional_unaugmented_stem = stem.dup
    end
  }
  return [augmented_stem,optional_doubled_sigma,optional_unaugmented_stem]
end

def Verb_conj.aorist_stem_final_cons_helper(stem)
  # returns [stem,optional_doubled_sigma]
  if stem=~/^(.*)([εα])([λρμν])$/ then
    # Pharr, p. 326, # 856
    a,b,c = $1,$2,$3
    if b=='ε' then b='ει' end
    if b=='α' then b='η' end
    return [a+b+c,false]
  end
  if stem=~/^(.*)([πβφκγχτδθ])$/ then
    # Pharr, p. 325, # 850
    a,b = $1,$2
    if b=~/[πβφ]/ then b='ψ' end
    if b=~/[κγχ]/ then b='ξ' end
    if b=~/[τδθ]/ then b='' end
    return [a+b,false]
  end
  return [stem+'σ',true]
end

def Verb_conj.contract(stem,f,t,e,disyllabic)
  # f,t,e = form, thematic vowel, ending
  # returns contracted form as [stem,ending], or nil if there is no contraction
  # https://ancientgreek.pressbooks.com/chapter/17/
  if stem=~/^(.*)(ε|α|ο)$/ then shorter,s=[$1,$2] else return nil end # find final vowel of stem
  ee = t+e
  result = nil
  if f.present && f.indicative && f.active
    if s=='ε' then
      if !(disyllabic && ee=~/^(ο|ω)$/) then
        if ee=~/^(ω|ει|ου)$/ then result = ee end
        if ee=~/^(ο|ε)$/ then result = {'ο'=>'ου','ε'=>'ει'}[ee] end
      end
    end
    if s=='α' then
      if ee=~/^(ω)$/ then result = ee end
      if ee=~/^(ει|ο|ε|ου)$/ then result = {'ει'=>'ᾳ','ο'=>'ω','ε'=>'α','ου'=>'ω'}[ee] end
    end
    if s=='ο' then
      if ee=~/^(ω)$/ then result = ee end
      if ee=~/^(ει|ο|ε|ου)$/ then result = {'ει'=>'οι','ο'=>'ου','ε'=>'ου','ου'=>'ου'}[ee] end
    end
  end
  if result.nil? then return nil end
  return [shorter,result]
end

def Verb_conj.thematic_vowel(f,ending)
  if ending=='ω' then return '' end
  if ending=~/σι/ then return 'ου' end
  if !(f.aorist) then # This handles present, future, thematic 2nd aorist, and imperfect, provided that the correct ending is supplied.
    if ending=~/^[μν]/ then return 'ο' else return 'ε' end
  else
    if f.singular && f.person==3 then return 'ε' else return 'α' end
  end
end

def Verb_conj.respell_sigmas(w)
  return w.gsub(/ς/,'σ').sub(/σ$/,'ς')
end

def Verb_conj.accentuate(w,n,type_of_accent:'acute')
  # n is the syllable to accentuate, counting back from end, 1-based
  # type_of_accent can be 'acute' or 'circ'
  if n==0 then raise "n=0" end
  if w=='' then raise "w is null string" end
  if n>Verb_conj.n_syll(w) then raise "n=#{n}, w=#{w}, n too high" end
  if n==1 then
    remove_accents(w)=~/(.*)([αειουηω])([^αειουηω]*)/
    a,b,c = Verb_conj.three_analogous_pieces(remove_acute_and_grave(w),$1,$2,$3)
    if type_of_accent=='acute' then b=add_acute(b) end
    if type_of_accent=='circ' then b=b.tr('αιυηωᾳ','ᾶῖῦῆῶᾷ') end # this probably covers all cases of interest for contract verbs
    return a+add_acute(b)+c
  else
    a,b,c = Verb_conj.ultima(w)
    return Verb_conj.accentuate(a,n-1)+b+c
  end
end

def Verb_conj.n_syll(w)
  a,b,c = Verb_conj.ultima(w)
  if b=='' then return 0 end
  if a=='' then return 1 end
  #print "abc=#{[a,b,c]}\n"
  return 1+Verb_conj.n_syll(a)
end

def Verb_conj.long_ultima(w)
  a,b,c = Verb_conj.ultima(w)
  if b=~/[ηω]/ then return true end
  return (b.length==2 && !(b=~/(αι|οι)/)) || b.length>=3
end

def Verb_conj.ultima(w)
  a,b,c = Verb_conj.ultima_helper(w)
  return Verb_conj.three_analogous_pieces(w,a,b,c)
end

def Verb_conj.three_analogous_pieces(w,a,b,c)
  return [ substr(w,0,a.length) , substr(w,a.length,b.length), substr(w,a.length+b.length,c.length) ]
end

def Verb_conj.ultima_helper(w)
  # returns [beginning,vowel,cons], removing all accents (including breathing, etc.)
  w = remove_accents(w)
  w=~/([αειουηω]+)([^αειουηω]*)$/
  b,c = [$1,$2]
  if b.nil? then b='' end
  if c.nil? then c='' end
  w=~/(.*)#{b}#{c}/
  a = $1
  if a.nil? then a='' end
  while b.length>1 && !(b=~/^(αι|αυ|ει|ευ|ηυ|οι|ου|υι|ωυ)$/) do # Pharr, p. 268
    a = a+b[0]
    b = b[1..-1]
  end
  return [a,b,c]
end

def Verb_conj.test
  # ruby -e 'require "./lib/string_util.rb"; require "./greek/verbs.rb"; Verb_conj.test'
  unless Verb_conj.ultima('α')[1]=='α' then raise "failed" end
  unless Verb_conj.ultima('αβ')[1]=='α' then raise "failed" end
  unless Verb_conj.ultima('εβαβ')[1]=='α' then raise "failed" end
  unless Verb_conj.ultima('α')[2]=='' then raise "failed" end
  unless Verb_conj.ultima('αβ')[2]=='β' then raise "failed" end
  unless Verb_conj.ultima('εβαβ')[2]=='β' then raise "failed" end
  unless Verb_conj.ultima('α')[0]=='' then raise "failed" end
  unless Verb_conj.n_syll('α')==1 then raise "failed" end
  unless Verb_conj.n_syll('αβ')==1 then raise "failed" end
  unless Verb_conj.n_syll('εβαβ')==2 then raise "failed" end
  unless Verb_conj.n_syll('κλέπτω')==2 then raise "failed" end
  unless Verb_conj.respell_sigmas('σ')=='ς' then raise "failed" end
  unless Verb_conj.respell_sigmas('ς')=='ς' then raise "failed" end
  unless Verb_conj.respell_sigmas('σασ')=='σας' then raise "failed" end
  unless Verb_conj.long_ultima('κτίνω')==true then raise "failed" end
  unless Verb_conj.long_ultima('κτίνετε')==false then raise "failed" end
  unless Verb_conj.long_ultima('κτίνει')==true then raise "failed" end
  unless Verb_conj.long_ultima('ἔκτινα')==false then raise "failed" end
  unless Verb_conj.long_ultima('βαι')==false then raise "failed" end
  unless Verb_conj.accentuate('κλεπτω',2)=='κλέπτω' then raise "failed #{Verb_conj.accentuate('κλεπτω',2)}" end
  unless Verb_conj.accentuate('ἱκω',2)=='ἵκω' then raise "failed #{Verb_conj.accentuate('ἱκω',2)}" end
  Verb_conj.test_helper('κλέπτω','v1spia','κλέπτω')
  Verb_conj.test_helper('κλέπτω','v2spia','κλέπτεις')
  Verb_conj.test_helper('κλέπτω','v3spia','κλέπτει')
  Verb_conj.test_helper('κλέπτω','v1ppia','κλέπτομεν')
  Verb_conj.test_helper('κλέπτω','v2ppia','κλέπτετε')
  Verb_conj.test_helper('κλέπτω','v3ppia','κλέπτουσι')
  Verb_conj.test_helper('κλέπτω','v3ppia','κλέπτουσιν',version:1)
  homer = json_from_file_or_die("greek/homer_conjugations.json",how_to_die:lambda { |err| raise err})
  #Verb_conj.stats(homer,'v1spia---')
  #Verb_conj.stats(homer,'v3spia---')
  Verb_conj.stats(homer,'v1saia---')
end

def Verb_conj.stats(homer,pos)
  f = Vform.new(pos)
  x = homer[pos]
  if x.nil? then x={} end
  x.keys.each { |lemma|
    real_forms = x[lemma]
    regular_forms,unimplemented,error_message,explanation = regular(lemma,f)
    next if unimplemented
    if !(error_message.nil?) then raise error_message end
    if regular_forms.nil? then raise "pos=#{pos}, lemma=#{lemma}, regular_forms=nil" end
    if regular_forms.include?(real_forms[0]) then print "equal, lemma=#{lemma} #{real_forms[0]}\n" else print "unequal, lemma=#{lemma} reg,real = #{regular_forms} #{real_forms} \n" end
  }
end

def Verb_conj.test_helper(verb,which,expect,version:0)
  f = Vform.new(which)
  c = regular(verb,f)[0][version]
  Verb_conj.test_helper2(c,expect)
  print "passed #{verb} #{which} (#{version}) #{expect}\n"
end

def Verb_conj.test_helper2(x,y)
  if x!=y then raise "failed, #{x} != #{y}" end
end

end # Verb_conj
