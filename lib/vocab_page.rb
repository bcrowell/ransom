class VocabPage

def VocabPage.helper(bilingual,genos,db,wikt,core,treebank,freq,notes,vocab_by_chapter,start_chapter,ch)
  # Doesn't get called if if_prose_trial_run is set.
  core = core.map { |x| remove_accents(x).downcase }
  vl = Vlist.from_text(bilingual.foreign_text,treebank,freq,genos,db,wikt,core:core, \
               exclude_glosses:list_exclude_glosses(bilingual.foreign_hr1,bilingual.foreign_hr2,notes))
  if !ch.nil? then
    if !(start_chapter.nil?) then vocab_by_chapter[ch] = [] end
    if vocab_by_chapter[ch].nil? then vocab_by_chapter[ch]=[] end
    vocab_by_chapter[ch] = alpha_sort((vocab_by_chapter[ch]+vl.all_lexicals).uniq)
  else
    vocab_by_chapter = []
  end
  return core,vl,vocab_by_chapter
end

def VocabPage.make(db,vl,core)
  # Input is a Vlist object.
  # The three sections are interpreted as common, uncommon, and rare.
  # Returns {'tex'=>...,'file_lists'=>...}, containing latex code for vocab page and the three file lists for later reuse.
  if Options.if_render_glosses then $stderr.print vl.console_messages end
  tex = ''
  tex +=  "\\begin{vocabpage}\n"
  tex +=  VocabPage.make_helper(db,'uncommon',vl,0,2,core) # I used to have common (0) as one section and uncommon (1 and 2) as another. No longer separating them.
  tex +=  "\\end{vocabpage}\n"
  v = vl.list.map { |l| l.map{ |entry| entry[1] } }
  result = {'tex'=>tex,'file_lists'=>v}
end

def VocabPage.make_helper(db,commonness,vl,lo,hi,core)
  debug_this_page = false
  l = []
  lo.upto(hi) { |i|
    vl.list[i].each { |entry|
      word,lexical,data = entry
      if data.nil? then data={} end
      pos = data['pos']
      is_verb = (pos=~/^[vt]/)
      is_comparative = (pos=~/[cs]$/)
      g = Gloss.get(db,lexical)
      next if g.nil?
      difficult_to_recognize = data['difficult_to_recognize']
      debug = false
      debug_this_page ||= debug
      Debug.print(debug) {"... 100 #{word} #{lexical} #{difficult_to_recognize}\n"}
      difficult_to_recognize ||= (is_verb && Verb_difficulty.guess(word,lexical,pos)[0])
      Debug.print(debug && is_verb) {"... 200 #{word} #{lexical} #{difficult_to_recognize} #{Verb_difficulty.guess(word,lexical,pos)[0]}"}
      data['difficult_to_recognize'] = difficult_to_recognize
      data['core'] = core.include?(remove_accents(lexical).downcase)
      entry_type = nil
      file_under_lexical = true
      if !data['core'] then entry_type='gloss' end
      if data['core'] && difficult_to_recognize then
        file_under_lexical = false
        entry_type = 'gloss' # applies to irregular comparatives
        if is_verb then entry_type='conjugation' end
        if !is_verb && !is_comparative then entry_type='declension' end
      end
      if file_under_lexical then file_under=lexical else file_under=word end
      if !entry_type.nil? then l.push([entry_type,[lexical,word,lexical,data,file_under]]) end
    }
  }
  Debug.print(debug_this_page) {"... 300 #{l}"}
  secs = []
  ['gloss','conjugation','declension'].each { |type|
    envir = {'gloss'=>'vocaball','conjugation'=>'conjugations','declension'=>'declensions'}[type]
    ll = l.select { |entry| entry[0]==type }.map { |entry| entry[1] }
    if ll.length>0 then
      this_sec = ''
      this_sec += "\\begin{#{envir}}\n"
      ll.sort { |a,b| alpha_compare(a[4],b[4])}.each { |entry|
        s = nil
        if type=='gloss' then s=VocabPage.entry(db,entry) end
        if type=='conjugation' || type=='declension' then s=VocabPage.inflection(entry) end
        if !(s.nil?) then
          this_sec += clean_up_unicode("#{s}\n")
        else
          die("unrecognized vocab type: #{type}")
        end
      }
      this_sec += "\\end{#{envir}}\n"
      secs.push(this_sec)
    end
  }
  if secs.length!=0 then
    return secs.join("\n\\bigseparator\\vspace{2mm}\n")
  else
    return "\n\nThere is no vocabulary for this page.\n\n"
  end
end

def VocabPage.entry(db,stuff)
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
  explained = gloss+VocabPage.explainer_in_gloss(flags)
  if !has_mnemonic_cog then
    if explain_inflection then
      s = "\\vocabinflection{#{inflected}}{#{preferred_lex}}{#{explained}}"
    else
      s = "\\vocab{#{preferred_lex}}{#{explained}}"
    end
  else
    if explain_inflection then
      s = "\\vocabinflection{#{inflected}}{#{preferred_lex}}{#{explained}}"
    else
      s = "\\vocabwithcog{#{preferred_lex}}{#{explained}}{#{entry['mnemonic_cog']}}"
    end
  end
  return s
end

def VocabPage.explainer_in_gloss(flags)
  is_3rd_decl,is_dual,is_irregular_comparative = [flags['is_3rd_decl']==true,flags['is_dual']==true,flags['is_irregular_comparative']==true]
  explainer = ''
  explainer = ', dual' if is_dual
  explainer = ', comparative' if is_irregular_comparative
  return explainer  
end

def VocabPage.inflection(stuff)
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
