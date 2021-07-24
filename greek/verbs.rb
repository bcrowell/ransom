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

def Verb_conj.regular(lemma,f,principal_parts:{},do_archaic_forms:false)
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
  lemma = remove_acute_and_grave(lemma)

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
  if f.singular then endings=[['ω'],['ισ'],['ι']][f.person-1] end
  if f.dual     then endings=[nil,['τον'],['τον']][f.person-1] end
  if f.plural   then endings=[['μεν'],['τε'],['σι']][f.person-1] end
  if endings.nil? then return [[],false,nil,"Active dual first-person forms don't exist."] end

  # -- Thematic vowel.
  if thematic then
    endings = endings.map { |x| thematic_vowel(f,x)+x }
  end

  #-- Postprocessing.
  results = []
  endings.each { |e|
    form = stem+e
    form = Verb_conj.respell_sigmas(form)
    # recessive accent (fixme: not for participles, and see other exceptions, Pharr p. 330)
    if Verb_conj.long_ultima(form) then accent_syll=2 else accent_syll=3 end # counting back from end, 1-based
    accent_syll = [accent_syll,Verb_conj.n_syll(form)].min
    form = Verb_conj.accentuate(form,accent_syll)
    results.push(form)
    results.push(form+'ν') if movable_nu
  }

  return [results,false,nil,nil]  
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

def Verb_conj.accentuate(w,n)
  if n==1 then
    remove_accents(w)=~/(.*)([αειουηω])([^αειουηω]*)/
    if $2.nil? then print "w=#{w}, 1=#{$1}, 2=#{$2}, 3=#{$3}, 3.nil?=#{$3.nil?}\n" end # qwe
    a,b,c = Verb_conj.three_analogous_pieces(remove_acute_and_grave(w),$1,$2,$3)
    return a+b.tr('αειουηω','άέίόύήώ')+c
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
  Verb_conj.test_helper('κλέπτω','v1spia','κλέπτω')
  Verb_conj.test_helper('κλέπτω','v2spia','κλέπτεις')
  Verb_conj.test_helper('κλέπτω','v3spia','κλέπτει')
  Verb_conj.test_helper('κλέπτω','v1ppia','κλέπτομεν')
  Verb_conj.test_helper('κλέπτω','v2ppia','κλέπτετε')
  Verb_conj.test_helper('κλέπτω','v3ppia','κλέπτουσι')
  Verb_conj.test_helper('κλέπτω','v3ppia','κλέπτουσιν',version:1)
  homer = json_from_file_or_die("greek/homer_conjugations.json",how_to_die:lambda { |err| raise err})
  Verb_conj.stats(homer,'v1spia---')
end

def Verb_conj.stats(homer,pos)
  f = Vform.new(pos)
  x = homer[pos]
  if x.nil? then x={} end
  x.keys.each { |lemma|
    real_forms = x[lemma]
    regular_forms = regular(lemma,f)[0]
    if real_forms[0]==regular_forms[0] then print "equal, #{real_forms[0]}\n" else print "unequal, #{real_forms[0]} #{regular_forms[0]}\n" end
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
