class FormatGloss

def FormatGloss.with_english(db,stuff)
  file_under,word,lexical,data = stuff
  entry = Gloss.get(db,lexical)
  return if entry.nil?
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
  # Count chars, and if it looks too long to fit on a line, switch to the short gloss:
  if explain_inflection then
    text = [word.downcase,preferred_lex,gloss]
  else
    text = [preferred_lex,gloss]
  end
  total_chars = text.map { |t| t.length}.sum+text.length-1 # final terms count blanks
  if total_chars>35 && entry.has_key?('short') then gloss=entry['short'] end
  has_mnemonic_cog = entry.has_key?('mnemonic_cog')
  # Generate latex:
  inflected = LemmaUtil.make_inflected_form_flavored_like_lemma(word)
  # FIXME: The explainer doesn't actually get printed for θᾶσσον ≺ ταχύς in Ilid 2.440.
  explained = gloss+FormatGloss.explainer_in_gloss(inflected,flags,data['pos'])
  items = {}
  if explain_inflection then items['b']=inflected; items['l']=preferred_lex else items['b']=preferred_lex end
  items['g'] = explained
  if has_mnemonic_cog then items['c']=entry['mnemonic_cog'] end
  return FormatGloss.assemble(items)+"\\\\\n"
end

def FormatGloss.explainer_in_gloss(word,flags,pos)
  is_3rd_decl,is_dual,is_irregular_comparative = [flags['is_3rd_decl']==true,flags['is_dual']==true,flags['is_irregular_comparative']==true]
  explainer = nil
  explainer = 'dual' if is_dual
  explainer = describe_declension(pos,true)[1] if is_3rd_decl
  # ... here the is_3rd_decl flag just means it's a hard declension, could be stuff like -φιν
  explainer = 'comparative' if is_irregular_comparative
  if explainer.nil? then return '' else return ", #{explainer}" end
end

def FormatGloss.inflection(stuff)
  file_under,word,lexical,data = stuff
  lemma_flavored = LemmaUtil.make_inflected_form_flavored_like_lemma(word)
  pos = data['pos']
  items = nil
  if pos[0]=='n' then items={'b'=>lemma_flavored,'l'=>lexical,'p'=>describe_declension(pos,true)[0]} end
  if pos[0]=~/[vt]/ then
    # File.open("debug.txt",'a') { |f| f.print "          #{word} #{lexical} #{pos} \n" }
    items = {'b'=>word.downcase,'l'=>lexical,
                 'p'=>Vform.new(pos).to_s_fancy(tex:true,relative_to_lemma:lexical,omit_easy_number_and_person:true,omit_voice:true)}
  end
  if items.nil? then items={'b'=>word.downcase,'l'=>lexical} end
  return FormatGloss.assemble(items)+"\\\\\n"
end

def FormatGloss.assemble(items,force_no_space:false)
  # items is a hash whose keys are one-letter codes
  # b=head word, h=hard space, g=gloss, f=from symbol, l=lemma, c=cognate, p=POS tag
  format = 'b '
  format = format+'h ' if !(force_no_space || items.has_key?('l'))
  format = format+'f' if items.has_key?('l')
  ['l','g','p','c'].each { |code|
    next unless items.has_key?(code)
    format = format+code
    format = format+',' if code=='l'
    format = format+' '
  }
  format = format.sub(/ $/,'') # trim trailing space
  format = format.sub(/,$/,'') # trim trailing comma
  return FormatGloss.assemble_helper(format,items)
end

def FormatGloss.assemble_helper(format,items)
  # format is, e.g., 'b h g' for boldfaced lemma, hard space, and gloss
  # items is a hash whose keys are the one-letter codes
  codes_0 = ['h','f'] # codes that take no arguments
  codes_1 = ['b','g','l','c','p'] # codes that take one argument
  (codes_0+codes_1).each { |code|
    format = format.gsub(/#{code}/,"__#{code}__")
  }
  result = format
  while result=~/(__[a-z]__)/ do
    x = $1
    x =~ /__(.)__/
    code = $1
    if codes_1.include?(code) then s=items[code] else s='' end
    result = result.sub(/#{x}/,FormatGloss.mark_up_element(code,s))
  end
  return result
end

def FormatGloss.mark_up_element(type,s)
  if type=='b' then return Latex.macro('boldforeign',s) end
  if type=='h' then return Latex.macro('hardspace','1em') end
  if type=='g' then return s end # gloss
  if type=='f' then return Latex.macro('from','') end
  if type=='l' then return "{\\greekfont #{s}}" end # FIXME: shouldn't assume Greek
  if type=='c' then return Latex.macro('cog',s) end # cognate
  if type=='p' then return Latex.macro('textsc',s.gsub(/\./,'')) end # part of speech
  raise "unknown type=#{type}, string=#{s}"
end

end
