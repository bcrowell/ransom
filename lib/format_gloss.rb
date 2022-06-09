class FormatGloss

def FormatGloss.with_english(bilingual,db,stuff)
  # Returns [file_under,latex_code]. The file_under in stuff[0] is ignored, only we can determine it properly.
  garbage_under,word,lexical,data = stuff
  pos = data['pos']
  entry = Gloss.get(db,lexical)
  return ['',nil] if entry.nil?
  preferred_lex = entry['word']
  # ...If there is a lexical form used in the database (such as Perseus), but we want some other form (such as Homeric), then
  #    preferred_lex will be different from the form inside stuff.
  word2,gloss,lexical2 = entry['word'],entry['gloss'],entry['lexical']
  if is_feminine_ending_in_os(remove_accents(lexical)) then gloss = "(f.) #{gloss}" end
  explain_inflection = false
  flags = {}
  ['is_3rd_decl','is_dual','is_irregular_comparative'].each { |flag|
    if (data.has_key?(flag) && data[flag] && !alpha_equal(word,lexical)) then
      explain_inflection = true
      flags[flag] = true
    end
  }
  is_3rd_decl,is_dual,is_irregular_comparative = [flags['is_3rd_decl']==true,flags['is_dual']==true,flags['is_irregular_comparative']==true]
  explain_inflection ||= data['difficult_to_recognize']
  if word==preferred_lex then explain_inflection=false end
  # Count chars, and if it looks too long to fit on a line, switch to the short gloss:
  if explain_inflection then
    text = [word.downcase,preferred_lex,gloss]
  else
    text = [preferred_lex,gloss]
  end
  total_chars = text.map { |t| t.length}.sum+text.length-1 # final terms count blanks
  if total_chars>35 && entry.has_key?('short') then gloss=entry['short'] end
  has_mnemonic_cog = entry.has_key?('mnemonic_cog')
  has_der = entry.has_key?('der')
  # Generate latex:
  inflected = LemmaUtil.make_inflected_form_flavored_like_lemma(word)
  # FIXME: The explainer doesn't actually get printed for θᾶσσον ≺ ταχύς in Iliad 2.440.
  explained = gloss+FormatGloss.explainer_in_gloss(inflected,flags,pos)
  items = {}
  if explain_inflection then
    items['b']=inflected
    items['l']=preferred_lex
    items['p']=FormatGloss.format_pos(pos,preferred_lex) if pos[0]=~/[vt]/
  else
    items['b']=preferred_lex
  end
  items['g'] = explained
  if has_mnemonic_cog then
    items['c']=entry['mnemonic_cog']
  end
  if has_der then
    items['d']=entry['der']
  end
  file_under = items['b']
  #Debug.print(word=='ἤριπε') {"items=#{items}, explain_inflection=#{explain_inflection}"}
  return [file_under,FormatGloss.assemble(bilingual,items)+"\\\\\n"]
end

def FormatGloss.inflection(bilingual,stuff)
  file_under,word,lexical,data = stuff
  lemma_flavored = LemmaUtil.make_inflected_form_flavored_like_lemma(word)
  pos = data['pos']
  items = nil
  if pos[0]=='n' then items={'b'=>lemma_flavored,'l'=>lexical,'p'=>describe_declension(pos,true)[0]} end
  if pos[0]=~/[vt]/ then
    items = {'b'=>lemma_flavored,'l'=>lexical,'p'=>FormatGloss.format_pos(pos,lexical)}
  end
  if items.nil? then items={'b'=>lemma_flavored,'l'=>lexical} end
  return FormatGloss.assemble(bilingual,items)+"\\\\\n"
end

def FormatGloss.format_pos(pos,lexical)
  return Vform.new(pos).to_s_fancy(tex:true,relative_to_lemma:lexical,omit_easy_number_and_person:true,omit_voice:true)
end

def FormatGloss.explainer_in_gloss(word,flags,pos)
  is_3rd_decl,is_dual,is_irregular_comparative = [flags['is_3rd_decl']==true,flags['is_dual']==true,flags['is_irregular_comparative']==true]
  explainer = nil
  explainer = 'dual' if is_dual
  if is_3rd_decl then
    # ... here the is_3rd_decl flag just means it's a hard declension, could be stuff like -φιν
    if !(pos[7]=='n' && pos[2]=='s') then # no point in giving an explainer if it's nominative singular
      explainer = describe_declension(pos,true)[1]
    end
  end
  explainer = 'comparative' if is_irregular_comparative
  if explainer.nil? then return '' else return ", #{explainer}" end
end

def FormatGloss.assemble(bilingual,items,force_no_space:false)
  # items is a hash whose keys are one-letter codes
  # b=head word, h=hard space, g=gloss, f=from symbol, l=lemma, c=cognate, p=POS tag
  items = clown(items)
  if items.has_key?('l') && items.has_key?('b') && items['b']==items['l'] then items.delete('l') end
  # ... don't do stuff like ἰητήρ ≺ ἰητήρ
  format = 'b '
  format = format+'h ' if !(force_no_space || items.has_key?('l'))
  format = format+'f' if items.has_key?('l')
  ['l','g','p','c','d'].each { |code|
    next if code=='d' && items.has_key?('c') # prefer mnemonic_cog to der
    next unless items.has_key?(code)
    format = format+code
    format = format+',' if code=='l'
    format = format+' '
  }
  format = format.sub(/ $/,'') # trim trailing space
  format = format.sub(/,$/,'') # trim trailing comma
  return FormatGloss.assemble_helper(bilingual,format,items)
end

def FormatGloss.assemble_helper(bilingual,format,items)
  # format is, e.g., 'b h g' for boldfaced lemma, hard space, and gloss
  # items is a hash whose keys are the one-letter codes
  codes_0 = ['h','f'] # codes that take no arguments
  codes_1 = ['b','g','l','c','d','p'] # codes that take one argument
  (codes_0+codes_1).each { |code|
    format = format.gsub(/#{code}/,"__#{code}__")
  }
  result = format
  while result=~/(__[a-z]__)/ do
    x = $1
    x =~ /__(.)__/
    code = $1
    if codes_1.include?(code) then s=items[code] else s='' end
    result = result.sub(/#{x}/,FormatGloss.mark_up_element(bilingual,code,s))
  end
  result = result.sub(/,\s*$/,'') # trim trailing comma, space
  return result
end

def FormatGloss.mark_up_element(bilingual,type,s)
  if s=='' && type!='f' then return '' end
  greek = bilingual.foreign.genos.greek
  if type=='b' then
    if greek then return Latex.envir('boldgreek',s) else return Latex.macro('textbf',s) end
  end
  if type=='h' then return Latex.macro('hardspace','1em') end
  if type=='g' then return s end # gloss
  if type=='f' then return Latex.macro('from','') end
  if type=='l' then
    if greek then return "{\\greekfont{}#{s}}" else return s end
  end
  if type=='c' then return Latex.macro('cog',s) end # cognate
  if type=='d' then return '('+s+')' end # derived from
  if type=='p' then return Latex.macro('textsc',s.gsub(/\./,'')) end # part of speech
  raise "unknown type=#{type}, string=#{s}"
end

end
