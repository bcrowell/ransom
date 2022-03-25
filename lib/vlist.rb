class Vlist
# a vocabulary list

def initialize(list)
  # List is a list whose elements are lists of common, uncommon, and rare words.
  # Each element of a is a list of items of the form [word,lexical] or [word,lexical,data].
  # The data field is a hash with keys that may include 'is_3rd_decl', 'is_epic', 'is_dual', 'pos',
  # and 'difficult_to_recognize'. 
  # The pos field is a 9-character string in the format used by Project Perseus:
  #   https://github.com/cltk/greek_treebank_perseus (scroll down)
  # The lexical and pos tagging may be wrong if the word can occur in more than one way.
  # The Vlist class and its initializers mostly don't know or care about the gloss files, and a
  # Vlist object doesn't contain an English translation or any of the other data from the gloss file.
  # However, as a convenience, the Vlist.from_text() initializer will try to supply missing glosses from
  # wiktionary and write them in a subdirectory.
  @list = list
  list.each { |l| l.sort! { |a,b| alpha_compare(a[1],b[1]) } }
  # ... alphabetical order by lexical form; this may be altered later if the word will be presented as, e.g., "ἐρρίγῃσι ≺ ῥιγέω";
  #     see logic involving the variable "file_under," which gets decided on and then revised in a couple of different places on the way to
  #     assembling the vocab page
end

attr_reader :list
attr_accessor :console_messages

def to_s
  a = []
  @list.each { |l|
    x = alpha_sort(l.map{ |v| v[1] }).join(" ") # lemmas only
    a.push(x)
  }
  return a.join("\n")
end

def all_lexicals
  result = []
  @list.each { |l|
    result = result + l.map { |a| a[1] }
  }
  return alpha_sort(result)
end

def total_entries
  return self.list.inject(0){|sum,x| sum + x.length }
end

def Vlist.from_text(t,context,treebank,freq,genos,db,wikt,thresholds:[1,50,700,700],max_entries:58,reduce_max_entries:0,
             exclude_glosses:[],core:nil,if_texify_quotes:true,
             include_elided_forms:true,if_warn:true)
  # If there's both a perseus lemma and a Homeric lemma for a certain item on the list, this returns the perseus lemma.
  # The frequency list is optional; if not using one, then set freq to nil. The main use of it is that if the
  # glossary would be too long, we delete the most common words to cut it down to an appropriate length. If no frequency
  # list is given, then the choice of which words to cut is random/undefined.
  # The wikt argument is a WiktionaryGlosses object for the appropriate language; if nil, then no gloss help will be generated.
  # The context argument should be a hash with keys 'ch','line', and 'text', where 'line' is the first line number on the page.
  # If the line key is absent, we can't make much use of this.
  lemmas = treebank.lemmas
  # typical entry when there's no ambiguity:
  #   "βέβασαν": [    "βαίνω",    "1",    "v3plia---",    1,    false,    null  ],
  if freq.nil? then
    using_thresholds = false
    if core.nil? then raise "both freq and core are nil" end
  else
    using_thresholds = true
  end
  max_entries -= reduce_max_entries
  whine = []

  t.gsub!(/\d/,'')
  if genos.greek then t.gsub!(/᾽(?=[[:alpha:]])/,"᾽ ") end # e.g., ποτ᾽Ἀθήνη
  t = t.unicode_normalize(:nfc)

  # If no frequency file is supplied, then the following are not actually used; we just gloss every word that's not in the core list.
  threshold_difficult = thresholds[0] # words ranked lower than this may be glossed if they're difficult forms to recognize
  threshold_no_gloss = thresholds[1] # words ranked higher than this are not normally glossed
  threshold = thresholds[2] # words ranked higher than this are listed as common
  threshold2 = thresholds[3] # words ranked lower than this get ransom notes

  # Split into lines, then into words tagged according to what line they're on. The line number data is semi-optional, only needed in order
  # to more reliably disambiguate a few percent of lemmatizations using the treebank. It will be wrong if the page spans chapters.
  a = t.split(/(\s*\n\s*)/) # even indices are lines, odds are delimiters
  lines = []
  0.upto(a.length-1) { |i|
    if i%2==0 && a[i]=~/[[:alpha:]]/ then lines.push(a[i]) end
  }
  words = []
  0.upto(lines.length-1) { |line_number_offset|
    line = lines[line_number_offset]
    word_index = 0
    line.scan(/[^\s—]+/).each { |word_raw|
      word_raw = standardize_greek_punctuation(word_raw)
      word = word_raw.gsub(/[^[:alpha:]᾽'’]/,'') # word_raw is pretty useless, may e.g. have a comma on the end
      next unless word=~/[[:alpha:]]/
      if context.has_key?('line') then
        loc = [context['text'],context['ch'],context['line']+line_number_offset,word_index]
      else
        loc = nil
      end
      words.push([word,loc,word_raw])
      word_index += 1
    }
  }

  result = []
  did_lemma = {}
  warn_ambig = {}
  words.each { |x|
    word,loc,word_raw = x
    lemma_entry = treebank.word_to_lemma_entry(word)
    elision = genos.greek && contains_greek_elision(word_raw)
    ουδε_μηδε = genos.greek && ["ουδε","μηδε"].include?(remove_accents(word))
    # ... These occur in Perseus treebank only as lemmas, never as inflected forms, although they are in the text. This seems to be because
    #     they split them into two words, e.g., at Iliad 1.124...? Confusing, haven't puzzled it out.
    do_not_try = ((elision && !include_elided_forms) || ουδε_μηδε)
    if lemma_entry.nil? && !do_not_try then whine.push("error(vlist): no index entry for #{word}, raw=#{word_raw}"); next end
    lemma,lemma_number,pos,count,if_ambiguous,ambig = lemma_entry
    if if_ambiguous then
      sadness,garbage = LemmaUtil.disambiguate_lemmatization(word,ambig)
      if sadness>=5 && !loc.nil? then # either the lemma is in doubt or there is a big enough ambiguity in the POS that we might care
        a,misc = treebank.get_lemma_and_pos_by_line(word,genos,db,loc)
        if a.length==0 then
          warn_ambig[word] = \
              "warning(vlist): text,ch,line,word=#{loc}, lemma for #{word} is ambiguous, unable to resolve using line-by-line treebank data\n" + \
              "  taking most common one: ambig=#{ambig}\n  #{misc['message']}"
          # This happens either when the Perseus text differs from the one I'm using, or when the Perseus data is missing POS data for a word.
          # As an example of the latter, at Iliad 4.50, treebank 2.1 has blank lemma and POS for βοῶπις. This occurs for several other usages of
          # βοῶπις, and also for some proper nouns and some other cases.
        else
          # typical a=[["πρῶτος", "a-p---na-", 2]], where 3rd element is word index
          lemma2,pos2,garbage = a[0] # FIXME: what is lemma_number, and how do I set it correctly now?
          if lemma2!=lemma || pos2!=pos then
            lemma,pos = [lemma2,pos2]
          end
          if a.length>1 then
            warn_ambig[word] = \
              "warning(vlist): text,ch,line,word=#{loc}, lemma for #{word} is ambiguous,\n" + \
              "  unable to resolve using line-by-line treebank data, multiple matches\n" + \
              "  taking the closest one on the line: #{a}"
          end
        end
      end
    end
    if lemma.nil? then
      if !do_not_try then whine.push("warning(vlist): lemma is nil for #{word} in lemmas file") end
      next
    end
    next if did_lemma.has_key?(lemma)
    excl = false
    [lemma,word].each { |x| excl = excl || exclude_glosses.include?(remove_accents(x).downcase) }
    next if excl
    did_lemma[lemma] = 1
    if freq.nil? then rank=1 else rank=freq.rank(lemma) end
    misc = {}
    is_verb = (pos=~/^[vt]/)
    is_adj =  (pos=~/^[a]/)
    is_comparative = is_adj && (pos=~/[cs]$/)
    difficult_to_recognize = false
    if genos.greek then
      is_3rd_decl = guess_whether_hard_declension(word,lemma,pos)
      is_epic = Epic_form.is(word)
      is_dual = (pos[2]=='d')
      is_irregular_comparative = (is_comparative && Adjective.is_irregular_comparative(word,lemma,pos[8]))
      if !alpha_equal(word,lemma) then
        difficult_to_recognize ||= (is_3rd_decl && guess_difficulty_of_recognizing_declension(word,lemma,pos)[0])
        difficult_to_recognize ||= is_epic
        difficult_to_recognize ||= (is_verb && Verb_difficulty.guess(word,lemma,pos)[0])
        difficult_to_recognize ||= is_irregular_comparative
        difficult_to_recognize ||= is_dual
      end
      if is_3rd_decl then misc['is_3rd_decl']=true end
      if is_epic then misc['is_epic']=true end
      if is_dual then misc['is_dual']=true end
      if is_irregular_comparative then misc['is_irregular_comparative']=true end
    end
    if using_thresholds then
      gloss_this = ( rank.nil? || rank>=threshold_no_gloss || (rank>=threshold_difficult && difficult_to_recognize) )
    else
      gloss_this = !(core.include?(lemma))
    end
    next unless gloss_this
    misc['difficult_to_recognize'] = difficult_to_recognize
    entry = word_raw,word,lemma,rank,pos,difficult_to_recognize,misc
    # ... word and word_raw are not super useful, in many cases will be just the first example in this passage
    #$stderr.print "entry=#{entry}\n"
    result.push(entry)
  }

  # If we have too many words, delete the most common ones.
  result.sort! { |a,b| a[3] <=> b[3] } # descending order by frequency (i.e., increasing order by frequency rank)
  while result.length>max_entries do
    kill_em = nil
    count = 0
    result.each { |entry|
      word_raw,word,lemma,rank,pos,difficult_to_recognize,misc = entry
      if !difficult_to_recognize then kill_em=count; break end
      count += 1
    }
    if kill_em.nil? then break end # couldn't find anything to kill off, don't spin forever
    # killing off ἄμμε, entry=["ἄμμε", "ἄμμε", "ἐγώ", 5, 2870, "p-p---ma-", true, {"is_epic"=>true}]
    result.delete_at(kill_em)
  end  

  gloss_help = []
  result2 = []
  ambig_warnings = []
  0.upto(2) { |commonness|
    this_part_of_result2 = []
    result.sort { |a,b| a[1] <=> b[1] } .each { |entry|
      word_raw,word,lemma,rank,pos,difficult_to_recognize,misc = entry
      next if Proper_noun.is(word_raw,lemma) # ... use word_raw to preserve capitalization, since some proper nouns have the same letters as other words
      next if Ignore_words.patch(word) || Ignore_words.patch(lemma)
      if !freq.nil? then
        skip = false
        skip = skip || !(!rank.nil? && rank>=threshold_difficult)
        skip = skip || (rank<threshold_no_gloss && !difficult_to_recognize)
        skip = skip || !(rank<threshold && commonness==0 or rank>=threshold && rank<threshold2 && commonness==1 or rank>=threshold2 && commonness==2)
      else
        skip = (commonness!=2)
        # Without frequency data, no way to judge, so just arbitrarily put everything in class 2, rare. When we do
        # ransom-note glosses, we normally gloss everything in the rare category.
      end
      next if skip
      key = remove_accents(lemma).downcase
      if !wikt.nil? && Gloss.get(db,lemma).nil? then gloss_help.push(GlossHelp.prep(wikt,key,lemma)) end # it's OK if this was done in a previous pass
      if warn_ambig.has_key?(word) then ambig_warnings.push(warn_ambig[word]) end
      # stuff some more info in the misc element:
      misc['pos'] = pos # lemma and pos may be wrong if the same word can occur in more than one way
      this_part_of_result2.push([word,lemma,misc])
    }
    result2.push(this_part_of_result2)
  }
  if gloss_help.length>0 then
    gloss_help_summary_info,individual_info = GlossHelp.give(gloss_help)
    whine = whine+individual_info
    $stderr.print gloss_help_summary_info,"\n" if !gloss_help_summary_info.nil?
  end
  whine = whine + ambig_warnings
  if whine.length>0 && if_warn then
    whiny_file = "warnings"
    File.open(whiny_file,"a") { |f|
      whine.each { |complaint| f.print "#{complaint}\n" }
    }
  end
  vl = Vlist.new(result2)
  if whine.length>0 && if_warn then vl.console_messages = "#{whine.length} warnings written to the file #{whiny_file}\n" end

  return vl
end

end # class Vlist

class GlossHelp

@@already_done = {}
# ... already done during this invocation of the ruby code, don't do again; there is separate code that avoids wasting the user's attention
#     with messages if the gloss help was already provided in a previous invocation
@@warned_fatal = false

def GlossHelp.prep(wikt,key,lemma)
  if wikt.nil? && !@@warned_fatal then
    $stderr.print "*********** warning: wikt is nil in GlossHelp.prep, no gloss help can be generated\n"
    @@warned_fatal = true
  end
  if wikt.nil? then return {} end
  # wikt is a WiktionaryGlosses object for the appropriate language
  h = {
    'filename'=>key,
    'lemma'=>lemma,
    'url'=> "https://en.wiktionary.org/wiki/#{lemma} https://logeion.uchicago.edu/#{lemma}",
    'wikt'=> wikt.get_glosses(lemma).join(', ')
  }
  debug_gloss = false
  if debug_gloss then
     h['debug']="key=#{key}, raw=#{word_raw}, word=#{word}, lemma=#{lemma}, ignore=#{Ignore_words.patch(word)}, pr=#{Proper_noun.is(word,lemma,require_cap:false)}"
  end
  return h
end

def GlossHelp.give(gloss_help)
  gloss_help_dir = "help_gloss"
  unless File.directory?(gloss_help_dir) then Dir.mkdir(gloss_help_dir) end
  gloss_help = gloss_help.filter { |h| h['lemma']==h['lemma'].downcase } # filter out things that look like proper nouns
  return [nil,[]] if gloss_help.length==0
  individual_info = []
  list_written = []
  gloss_help.each { |h|
    next if @@already_done.has_key?(h['lemma'])
    @@already_done[h['lemma']] = 1
    filename = dir_and_file_to_path(gloss_help_dir,h['filename'])
    next if File.exist?(filename) # already done in a previous invocation
    list_written.push(h['lemma'])
    individual_info.push("no glossary entry for #{h['lemma']} , see gloss help file")
    File.open(filename,"w") { |f|
      x = %Q(
        // #{h['url']}
        // #{h['wikt']}
        {
          \"word\":\"#{h['lemma']}\",
          \"medium\":\"#{h['wikt']}\"
        }
      )
      x.gsub!(/\A\n/,'')
      x.gsub!(/^        /,'')
      f.print x
      if h.has_key?('debug') then f.print "// #{h}\n" end
    }
  }
  File.open("#{gloss_help_dir}/__links.html","a") { |f|
    gloss_help.each { |h|
      next if h['wikt'].to_s!=''
      f.print "<p>#{remove_accents(h['lemma']).downcase} "
      h['url'].scan(/http[^\s]+/).each { |url|
        f.print "  <a href=\"#{url}\">#{h['lemma']}</a> " unless url=~/wiktionary/
      }
      f.print "</p>\n"
    }
  }
  list_written = alpha_sort(list_written)
  n_written = list_written.length
  if n_written==0 then return [nil,[]] end
  if n_written<=10 then ll=list_written; suffix='' else ll = list_written[0..9]; suffix=" (more...) " end
  summary_info = "====wrote gloss help to #{gloss_help_dir} for #{n_written} lemmas that previously had no help: ====\n" \
        + "  " + ll.join(" ") + suffix + "\n"
  return [summary_info,individual_info]
end

end # class GlossHelp

class Epic_form
  @@index = %q{
    αμμε ρα
  }
  def Epic_form.is(word)
    w = remove_accents(word).downcase
    return @@index.include?(w)
  end
end

class Proper_noun
  # Words in the following list can be accented or unaccented, lemmatized or inflected, upper or lowercase. Accents are stripped.
  # If an inflected form is given here, then it will only match that inflected form.
  @@index = %q{
    Λετω ολυμπος Ὀλύμπιος Ἄργος Πρίαμος Ἀγαμέμνων λητους διος πηληιαδεω ατρειδα ατρειδης απολλων αιδι Χρύση Χρύσης αχιλλευς τενεδος
    Δαναοι Ηρα αργειος ζευς θεστοριδης ιλιος καλχας κιλλα καλχας καρδια κλυταιμνηστρη λητω καλχας καρδια μενελαος Μυρμιδών νεστωρ
    οδυσσευς παλλας Πηλείδης Πηλείων πλοῦτος πυλιος Πύλος τενεδος τροια τρως φθια Χρυσηίς αγαμεμνων αιας απολλων αργος βρισηις ατρειδης
    Μυρμιδών αχαιις ατη ατρειδης βρισευς διος εκτωρ αιγαιων αιγειδην εξαδιος ευρυβατης ηετιων θετις θηβη θησευς ιδομενευς καινευς
    καρδια κρονιων μενοιτιαδης μυρμιδονες πατροκλος πειριθοος πολυφημος ποσειδεων ταλθυβιος
    αιθιοψ κρονιδης πηλευς δρυας κορος Ἀτρείων ηφαιστος λημνος ουρανιωνες σιντιες
    Ἀλέξανδρος Ἀφροδίτη Ἑλένη Πάρις Τρῳάς Τρωιός Μῃονίη Φρύγιος Λακεδαίμων Πριαμίδης Λυκάων Ἀίδης Ἀντήνωρ Ἴδη Σκαιαί Ἰδαῖος Πολυδεύκης
    Κρήτηθεν Κρής Κάστωρ Ὀτρεύς Φρύξ Σαγγάριος Μύγδων Πιτθεύς Πάνθοος Οὐκαλέγων Λάμπος Κλυμένη Θυμοίτης Αἴθρη Ἄρης Ἑλικάων Δάρδανος
    Ἀθηναῖος  Γερήνιος Αἰτωλός Ὀιλεύς Νήριτος Λήιτος Ὠκεανός δημοκόων
  }.split(/\s+/).map { |x| remove_accents(x.downcase)}.to_set
  def Proper_noun.is(word,lemma,require_cap:true)
    if require_cap && word[0].downcase==word[0] then return false end
    w,l = remove_accents(word).downcase,remove_accents(lemma).downcase
    return @@index.include?(w) || @@index.include?(l)
  end

end

class Ignore_words
  # Words in the following list can be accented or unaccented, lemmatized or inflected. Case is not significant. Accents are stripped.
  # If an inflected form is given here, then it will only match that inflected form.
  # The words οτηερ and υνκνοων are English "other" and "unknown," processed incorrectly as if they were beta code.
  # Note that τῷ is a lemma in perseus (adverb), and is glossed and not ignored.
  # If it's desired to ignore a word in an accent-sensitive way, then put the word in @@index_accent_sensitive.
  # We do this with ποῦ (an itty-bitty question word), while not ignoring πού, which is mainly a discourse adverb.
  @@index = %q{
    οτηερ υνκνοων
    η τα τον ο τους αυτους εμος αυτου σος ω ουτος τοιος εγω
    ειμι
    επι ανα μετα απο δια προ προς συν εις αμα ηδη ινα ευς μην ος οδε
    δυω πολλας δη πατηρ πολυ τρις
    κακος ευ παρα περ χειρ
    οτι πως εαν οτε ουδε τοτε οπως ουτε ωδε δυο
    ειπον μα αλλη αμφω εκεινος κεινος μητε περι
    μη αμφι υπερ σφος ποιος οστις οσος αρα εισω τως ὑπό
  }.split(/\s+/).map { |x| remove_accents(x.downcase)}.to_set
  @@index_accent_sensitive = %q{
    ποῦ
  }.split(/\s+/).to_set
  def Ignore_words.patch(word)
    w = remove_accents(word).downcase
    return @@index.include?(w) || @@index_accent_sensitive.include?(word)
  end

end

