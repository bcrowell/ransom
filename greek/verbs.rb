class Vform
  def initialize(perseus_pos)
    # definition of perseus 9-character pos tags: https://github.com/cltk/greek_treebank_perseus
    # first character has to be there as a placeholder, but is ignored
    # final three characters are optional
    @person = perseus_pos[1].to_i # 1, 2, or 3
    @number = perseus_pos[2] # 's', 'd', or 'p'
    @tense = perseus_pos[3] # paif = present,aorist,imperfect,future; rlt = perfect,pluperfect,future perfect
    @mood = perseus_pos[4] # isonmp = indicative,subjunctive,optative,infinitive,imperative,participle
    @voice = perseus_pos[5] # apme = active,passive,middle,medio-passive
  end

  attr_reader :person,:number,:tense,:mood,:voice

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

end

class Verb_conj

def regular_conj(lemma,f,principal_parts:{},do_archaic_forms:false)
  # lemma may be fully accented or omit the acute accent
  # f is a Vform object
  # principal_parts is a hash whose keys are strings such as '2' for the second principle part, etc.
  # This function is supposed to return a string that is what the conjugation *would* be if the verb were 
  # regular. For example, if you want to determine whether a certain form is or is not regular, you can
  # compare the actual form against the one returned by this routine.
  # Irregular verbs are usually irregular only in the formation of their principal parts, not in the
  # conjugation based on those parts. So if a non-empty principal_parts argument is supplied, then
  # this routine should in most cases actually give the correct conjugation in *irregular* cases.
  # Returns [conjugated verb,unimplemented,error message,explanation].
  # Conjugated verb is a list, usually a singleton. If the form doesn't exist, e.g., 1st-person imperative, then this is an empty list.
  # If there's an error or the conjugation is unimplemented, then conjugated verb is nil.
  # The unimplemented flag says that the user didn't do anything wrong, but the relevant feature just isn't implemented yet.
  # Explanation is a list of strings explaining any non-obvious rules used.

  if f.imperative && f.person==1 then return [[],false,nil,"First-person imperative forms don't exist."] end
  lemma = remove_accents(lemma)

  # -- Thematic/athematic,
  thematic = nil
  if lemma=~/(.*)ω$/ then thematic=true; stem=$1 end
  if lemma=~/(.*)μι$/ then thematic=false; stem=$1 end
  if thematic.nil? then return [nil,false,'unable to recognize lemma #{lemma} as -ω or -μι',nil] end
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
  if f.singular then endings=[['ω'],['εισ'],['ει']][f.person-1] end
  if f.dual     then endings=[nil,['τον'],['τον']][f.person-1] end
  if f.plural   then endings=[['μεν'],['τε'],['σι']][f.person-1] end
  if endings.nil? then return [[],false,nil,"Active dual first-person forms don't exist."] end

  # -- Thematic vowel.
  if thematic then
    if !f.aorist then
      endings = endings.map { |x| if x=~/^[μν]/ then 'ο'+x else 'ε'+x end }
    else
      if f.singular && f.person==3 then t='ε' else t='α' end
      endings = endings.map { |x| t+x }
    end
  end

  #-- Postprocessing.
  results = []
  endings.each { |e|
    form = stem+e
    form = Verb_conj.respell_sigmas(form)
    # recessive accent (fixme: not for participles)
    if Verb_conj.long_ultima(form) then accent_syll=2 else accent_syll=3 end # counting back from end, 1-based
    accent_syll = [accent_syll,Verb_conj.n_syll(form)].min
    form = Verb_conj.accentuate(form,accent_syll)
    results.push(form)
    results.push(form+'ν') if movable_nu
  }

  return [results,false,nil,nil]  
end

def Verb_conj.respell_sigmas(w)
  return gsub(/ς/,'σ').sub(/σ$/,'ς')
end

def Verb_conj.accentuate(w,n)
  if n==1 then
    return w.sub(/[αειουηω](?=[^αειουηω]*)$/) { |x| $1.tr('αειουηω','άέίόύήώ') }
  else
    a,b,c = ultima(w)
    return accentuate(a+b,n-1)+c
  end
end

def Verb_conj.n_syll(w)
  if penult(w)=='' then return 1 end
  a,b,c = ultima(w)
  return 1+n_syll(a+b)
end

def Verb_conj.long_ultima(w)
  a,b,c = ultima(form)
  return ( b=~/[ηω]/ || (b.length==2 && !(b=~/(αι|οι)/)) || b.length>=3 )
end

def Verb_conj.antepenult(w)
  a,b,c = ultima(w)
  if a=='' then return '' end
  d,e,f = ultima(a)
  if d=='' then return '' else return ultima(d) end
end

def Verb_conj.penult(w)
  a,b,c = ultima(w)
  if a=='' then return '' else return ultima(a) end
end

def Verb_conj.ultima(w)
  # returns [beginning,vowel,cons]
  # strips all accents
  w = remove_accents(w)
  w=~/([αειουηω]+)([^αειουηω]*)$/
  b,c = [$1,$2]
  w=~/(.*)#{b}#{c}/
  a = $1
  if a.nil? then a='' end
  return [a,b,c]
end

def Verb_conj.test
  unless Verb_conj.ultima('α')[1]=='α' then raise "failed" end
end

end # Verb_conj
