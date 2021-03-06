class VocabPage

def VocabPage.helper(bilingual,context,genos,db,dicts,core,treebank,freq,notes,vocab_by_chapter,start_chapter,ch,if_warn:true,reduce_max_entries:0,
                      debugger:SpecialPurposeDebugger.new(false))
  # Doesn't get called if if_prose_trial_run is set.
  vl = Vlist.from_text(bilingual.foreign_text,context,treebank,freq,genos,db,dicts,core:core,if_warn:if_warn,reduce_max_entries:reduce_max_entries, \
               exclude_glosses:list_exclude_glosses(bilingual.foreign_hr1,bilingual.foreign_hr2,notes),
               debugger:debugger)
  if !ch.nil? then
    if !(start_chapter.nil?) then vocab_by_chapter[ch] = [] end
    if vocab_by_chapter[ch].nil? then vocab_by_chapter[ch]=[] end
    vocab_by_chapter[ch] = alpha_sort((vocab_by_chapter[ch]+vl.all_lexicals).uniq)
  else
    vocab_by_chapter = []
  end
  debugger.d("--- #{context} ---\nAt end of VocabPage.helper, lexicals = #{vl.all_lexicals}")
  debugger.d("--- #{context} ---\nAt end of VocabPage.helper, words = #{vl.all_words}")
  return core,vl,vocab_by_chapter
end

def VocabPage.make(bilingual,db,vl,core,debugger:SpecialPurposeDebugger.new(false))
  # Input vl is a Vlist object.
  # The three sections are interpreted as common, uncommon, and rare.
  # Returns {'tex'=>...,'file_lists'=>...}, containing latex code for vocab page and the three file lists for later reuse.
  if Options.if_render_glosses then $stderr.print vl.console_messages end
  tex = ''
  tex +=  "\\begin{vocabpage}\\label{#{bilingual.label}-a}\n"
  tex +=  VocabPage.make_helper(bilingual,db,'uncommon',vl,0,2,core,debugger:debugger) 
  # ... I used to have common (0) as one section and uncommon (1 and 2) as another. No longer separating them.
  tex +=  "\\end{vocabpage}\n"
  v = vl.list.map { |l| l.map{ |entry| entry[1] } }
  result = {'tex'=>tex,'file_lists'=>v}
  return result
end

def VocabPage.make_helper(bilingual,db,commonness,vl,lo,hi,core,debugger:SpecialPurposeDebugger.new(false))
  debug_this_page = false
  l = []
  lo.upto(hi) { |i|
    vl.list[i].each { |entry|
      word,lexical,data = entry
      debugger.d("#{word} is on list in VocabPage.make_helper (1), lexical=#{lexical}, commonness=#{i}")
      if data.nil? then data={} end
      pos = data['pos']
      is_verb = (pos=~/^[vt]/)
      is_comparative = (pos=~/[cs]$/)
      g = Gloss.get(db,lexical)
      if g.nil? then
        debugger.d("#{word}, lexical=#{lexical}, omitted in VocabPage.make_helper, no gloss found")
        next
      end
      difficult_to_recognize = data['difficult_to_recognize']
      debug = (word=='??????????' && pos=='n-s---na-') # qwe
      debug_this_page ||= debug
      Debug.print(debug) {"... 100 #{word} #{lexical} #{difficult_to_recognize}\n"}
      difficult_to_recognize ||= (is_verb && Verb_difficulty.guess(word,lexical,pos)[0])
      Debug.print(debug && is_verb) {"... 200 #{word} #{lexical} #{difficult_to_recognize} #{Verb_difficulty.guess(word,lexical,pos)[0]}"}
      data['difficult_to_recognize'] = difficult_to_recognize
      data['core'] = core.include?(lexical)
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
      if !entry_type.nil? then
        l.push([entry_type,[lexical,word,lexical,data,file_under]])
        debugger.d("#{word} is on list in VocabPage.make_helper (2), lexical=#{lexical}, commonness=#{i}")
      else
        debugger.d("#{word} omitted from VocabPage.make_helper because it's core and not hard to recognize, lexical=#{lexical}, commonness=#{i}")
      end
    }
  }
  secs = []
  ['gloss','conjugation','declension'].each { |type|
    envir = {'gloss'=>'vocaball','conjugation'=>'conjugations','declension'=>'declensions'}[type]
    ll = l.select { |entry| entry[0]==type }.map { |entry| entry[1] }
    if ll.length>0 then
      this_sec = ''
      this_sec += "\\begin{#{envir}}\n"
      entries = []
      ll.each { |entry|
        debugger.d("#{entry[1]}, lemma=#{entry[0]} included under type #{type} in VocabPage.make_helper")
        file_under = entry[4] # may get modified below
        s = nil
        if type=='gloss' then file_under,s=FormatGloss.with_english(bilingual,db,entry) end
        if type=='conjugation' || type=='declension' then s=FormatGloss.inflection(bilingual,entry) end
        if !(s.nil?) then
          s = standardize_greek_punctuation(s)
        else
          die("unrecognized vocab type: #{type}")
        end
        entries.push([file_under,s])
      }
      entries = entries.map { |x| x[0]+"__DELIM__"+x[1] }.uniq.map { |y| y.split(/__DELIM__/)}
      # ... eliminate duplicates, as with "?????????? ??? ????????, DAT S" in Iliad 4.514
      entries.sort { |a,b| alpha_compare(a[0],b[0])}.each { |x|
        this_sec += (x[1]+"\n")
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
