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
  if !has_mnemonic_cog then
    if explain_inflection then
      s = "\\vocabinflection{#{inflected}}{#{preferred_lex}}{#{explained}}"
    else
      s = "\\vocab{#{preferred_lex}}{#{explained}}"
    end
  else
    if explain_inflection then
      s = "\\vocabinflectionwithcog{#{inflected}}{#{preferred_lex}}{#{explained}}{#{entry['mnemonic_cog']}}"
    else
      s = "\\vocabwithcog{#{preferred_lex}}{#{explained}}{#{entry['mnemonic_cog']}}"
    end
  end
  return s
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
  if pos[0]=='n' then
    return "\\vocabnouninflection{#{lemma_flavored}}{#{lexical}}{#{describe_declension(pos,true)[0]}}"
  end
  if pos[0]=~/[vt]/ then
    # File.open("debug.txt",'a') { |f| f.print "          #{word} #{lexical} #{pos} \n" }
    return "\\vocabverbinflection{#{word.downcase}}{#{lexical}}{#{Vform.new(pos).to_s_fancy(tex:true,relative_to_lemma:lexical,
                   omit_easy_number_and_person:true,omit_voice:true)}}"
  end
  return "\\vocabinflectiononly{#{word.downcase}}{#{lexical}}"
end

end
