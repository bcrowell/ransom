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
        if type=='gloss' then s=FormatGloss.with_english(db,entry) end
        if type=='conjugation' || type=='declension' then s=FormatGloss.inflection(entry) end
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


end
