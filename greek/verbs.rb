class Vform
  def initialize(perseus_pos)
    # definition of perseus 9-character pos tags: https://github.com/cltk/greek_treebank_perseus
    # First character has to be there as a placeholder, but is ignored.
    # Final three characters are optional, ignored.
    # To get back a complete 9-character perseus tag, use the method get_perseus_tag().
    @person = perseus_pos[1].to_i # 1, 2, or 3
    @number = perseus_pos[2] # 's', 'd', or 'p'
    @tense = perseus_pos[3] # paif = present,aorist,imperfect,future; rlt = perfect,pluperfect,future perfect
    @mood = perseus_pos[4] # isonmp = indicative,subjunctive,optative,infinitive,imperative,participle
    @voice = perseus_pos[5] # apme = active,passive,middle,medio-passive
  end

  attr_reader :person,:number,:tense,:mood,:voice

  def get_perseus_tag
    if self.participle() then c0='t' else c0='v' end
    return c0+@person.to_s+@number+@tense+@mood+@voice+'---'
  end

  def indicative() return (@mood=='i') end
  def imperative() return (@mood=='m') end
  def active() return (@voice=='a') end
  def present() return (@tense=='p') end
  def future() return (@tense=='f') end
  def singular() return (@number=='s') end
  def dual() return (@number=='d') end
  def plural() return (@number=='p') end # doesn't include dual
  def perfect() return (@tense=~/[rlt]/) end
  def past() return (@tense=~/[ail]/) end
  def present() return (@tense=='p') end
  def aorist() return (@tense=='a') end
  def participle() return (@mood=='p') end

end

class Verb_conj

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
  # This routine doesn't know which verbs are contract verbs, so it defines those as irregular.

  if f.imperative && f.person==1 then return [[],false,nil,"First-person imperative forms don't exist.",nil] end
  lemma = remove_acute_and_grave(lemma)

  if lemma=~/μαι/ then return [nil,true,"Lemmas in -μαι are not implemented.",nil] end

  # -- Thematic/athematic,
  thematic = nil
  if lemma=~/(.*)ω$/ then thematic=true; stem=$1 end
  if lemma=~/(.*)μι$/ then thematic=false; stem=$1 end
  if lemma=~/(.*)α$/ then return [nil,true,'Verbs like ἄνωγα, with the perfect used as the present, are not implemented.',nil] end
  if lemma=~/(.*)ον$/ then return [nil,true,'Verbs like τέτμον, with the epic aorist used as the present, are not implemented.',nil] end
  if lemma=~/(.*)ῶ$/ then return [nil,true,'The software does not implement conjugation given an already-contracted lemma like ζῶ.',nil] end
  if remove_accents(lemma)=~/^(δει|χρη)$/  then return [nil,true,'Impersonal verbs like δεῖ and χρή are not implemented.',nil] end
  if thematic.nil? then return [nil,false,"unable to recognize lemma #{lemma} as -ω or -μι",nil] end
  if !thematic then return [nil,true,'Athematic verbs are not implemented.',nil] end

  # --
  if !f.present then return [nil,true,'Tenses other than the present are not implemented.',nil] end
  if !f.indicative then return [nil,true,'Moods other than the indicative are not implemented.',nil] end
  if !f.active then return [nil,true,'Voices other than the active are not implemented.',nil] end

  # -- Movable nu.
  #    https://en.wikipedia.org/wiki/Movable_nu
  movable_nu = f.person==3 && ((f.plural && (f.present || f.future)) || (f.singular && (f.perfect || f.past || (f.present && !thematic))))

  # == Personal ending.
  # -- Active primary.
  if f.singular then ee='ω ισ ι' end
  if f.dual     then ee='@ τον τον' end
  if f.plural   then ee='μεν τε σι' end
  endings = ee.split(/\s+/)[f.person-1].split(/\//).map { |x| if x=='@' then nil else x end}
  if endings.nil? then return [[],false,nil,"Active dual first-person forms don't exist."] end

  # -- Thematic vowel.
  forms = []
  if thematic then
    endings.each { |e|
      t = thematic_vowel(f,e)
      forms.push([stem,t+e,{'contracted'=>false}])
      if include_contracted then
        c = Verb_conj.contract(stem,f,t,e,Verb_conj.n_syll(lemma)==2)
        if !c.nil? then print "............... t=#{t} e=#{e} c=#{c}\n" end # qwe
        if !(c.nil?) then forms.push([c[0],c[1],{'contracted'=>true}]) end
      end
    }
  end

  #-- Postprocessing.
  results = []
  forms.each { |x|
    stem,e,flags = x
    form = stem+e # gets redone later if there's a contraction
    form = Verb_conj.respell_sigmas(form)
    # recessive accent (fixme: not for participles, and see other exceptions, Pharr p. 330)
    if Verb_conj.long_ultima(form) then accent_syll=2 else accent_syll=3 end # counting back from end, 1-based
    accent_syll = [accent_syll,Verb_conj.n_syll(form)].min
    n_syll_ending = Verb_conj.n_syll(e)
    $stderr.print "---- x=#{x} #{flags['contracted']}\n" if stem=~/ταρ/ # qwe
    did_accentuation = false
    if flags['contracted']==true then
      # Is this sometimes wrong? https://ancientgreek.pressbooks.com/chapter/17/ has unclear ref to 
      # "the accent rules that apply to vowel contractions, learned earlier."
      $stderr.print "---- contraction\n" # qwe
      e2 = Verb_conj.accentuate(e,accent_syll-1,type_of_accent:'circ') # contractions all contract two syllables to 1
      form = stem+e2
      did_accentuation = true        
    end
    if !did_accentuation then form = Verb_conj.accentuate(form,accent_syll) end
    results.push(form)
    results.push(form+'ν') if movable_nu
  }

  return [results,false,nil,nil]  
end

def Verb_conj.contract(stem,f,t,e,disyllabic)
  # f,t,e = form, thematic vowel, ending
  # returns contracted form as [stem,ending], or nil if there is no contraction
  # https://ancientgreek.pressbooks.com/chapter/17/
  if stem=~/^(.*)(ε|α|ο)$/ then shorter,s=[$1,$2] else return nil end # find final vowel of stem
  ee = t+e
  result = nil
  if f.present && f.indicative && f.active
    if s=='ε' && !disyllabic then
      if ee=~/^(ω|ει|ου)$/ then result = ee end
      if ee=~/^(ο|ε)$/ then result = {'ο'=>'ου','ε'=>'ει'}[ee] end
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
  if !f.aorist then
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
  $stderr.print [a,b,c],"\n" # qwe
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
  Verb_conj.stats(homer,'v3spia---')
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
