class Vlist
# a vocabulary list

def initialize(list)
  # List is a list whose elements are lists of common, uncommon, and rare words.
  # Each element of a is a list of items of the form [word,lexical] or [word,lexical,data].
  # The data field is a hash with keys that may include 'is_3rd_decl', 'is_epic', 'pos',
  # and 'difficult_to_recognize'. 
  # The pos field is a 9-character string in the format used by Project Perseus:
  #   https://github.com/cltk/greek_treebank_perseus (scroll down)
  # The lexical and pos tagging may be wrong if the word can occur in more than one way.
  # The difficult_to_recognize flag is not completely accurate at this stage, because we don't look at
  # the gloss files, which has info about whether the verb has an aorist that is difficult to recognize.
  # The Vlist class and its initializers mostly don't know or care about the gloss files, and a
  # Vlist object doesn't contain an English translation or any of the other data from the gloss file.
  # However, as a convenience, the Vlist.from_text() initializer will try to supply missing glosses from
  # wiktionary and write them in a subdirectory.
  @list = list
  list.each { |l| l.sort! { |a,b| alpha_compare(a[1],b[1]) } } # alphabetical order by lexical form
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

def Vlist.from_text(t,treebank,freq_file,genos,db,thresholds:[1,50,700,700],max_entries:58,exclude_glosses:[],core:nil)
  # If there's both a perseus lemma and a Homeric lemma for a certain item on the list, this returns the perseus lemma.
  lemmas = treebank.lemmas
  # typical entry when there's no ambiguity:
  #   "βέβασαν": [    "βαίνω",    "1",    "v3plia---",    1,    false,    null  ],
  if freq_file.nil?
    then freq = {} # Frequencies are not really crucial.
    using_thresholds = false
    if core.nil? then raise "both freq_file and core are nil" end
  else
    freq = json_from_file_or_die(freq_file)
    using_thresholds = true
  end
  freq_list = freq.to_a
  freq_list.sort! { |a,b| b[1] <=> a[1]} # descending order by frequency; is probably already sorted, so this will be fast
  # ... a list of pairs like [["δέ", 12136], ["ὁ" , 5836], ...]; not a problem if it's empty
  whine = []

  t.gsub!(/\d/,'')
  if genos.greek then t.gsub!(/᾽(?=[[:alpha:]])/,"᾽ ") end # e.g., ποτ᾽Ἀθήνη
  t = t.unicode_normalize(:nfc)

  freq_rank = {} # if freq_file was not supplied, then this ranking will be random/undefined
  rank = 1
  freq_list.each { |a|
    lemma,count = a
    freq_rank[lemma] = rank
    rank += 1
  }

  # If no frequency file is supplied, then the following are not actually used; we just gloss every word that's not in the core list.
  threshold_difficult = thresholds[0] # words ranked lower than this may be glossed if they're difficult forms to recognize
  threshold_no_gloss = thresholds[1] # words ranked higher than this are not normally glossed
  threshold = thresholds[2] # words ranked higher than this are listed as common
  threshold2 = thresholds[3] # words ranked lower than this get ransom notes

  result = []
  did_lemma = {}
  warn_ambig = {}
  t.scan(/[^\s—]+/).each { |word_raw|
    word = word_raw.gsub(/[^[:alpha:]᾽']/,'') # word_raw is mostly useless, may e.g. have a comma on the end; may also contain elision mark
    next unless word=~/[[:alpha:]]/
    lemma_entry = treebank.word_to_lemma_entry(word)
    elision = genos.greek && contains_greek_elision(word_raw)
    # ... elision produces so much ambiguity that we aren't going to try to gloss elided forms; if I was going to do improve this, I would
    #     need to stop filtering out elided forms when constructing the csv file, and implement disambiguation based on the line-by-line treebank data
    ουδε_μηδε = genos.greek && ["ουδε","μηδε"].include?(remove_accents(word))
    # ... I don't understand why, but these seem to occur in Perseus treebank only as lemmas, never as inflected forms, although they are in the text.
    do_not_try = (elision || ουδε_μηδε)
    if lemma_entry.nil? && !do_not_try then whine.push("error(vlist): no index entry for #{word}, raw=#{word_raw}"); next end
    lemma,lemma_number,pos,count,if_ambiguous,ambig = lemma_entry
    if if_ambiguous then
      sadness,ii = LemmaUtil.disambiguate_lemmatization(word,ambig)
      if sadness>0 then
        warn_ambig[word]= "warning(vlist): lemma for #{word} is ambiguous, sadness=#{sadness}, taking most common one; #{ambig}"
        lemma,lemma_number,pos,count,if_ambiguous = ambig[ii]
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
    rank = freq_rank[lemma]
    f = freq[lemma]
    misc = {}
    is_verb = (pos=~/^[vt]/)
    difficult_to_recognize = false
    if genos.greek then
      is_3rd_decl = guess_whether_third_declension(word,lemma,pos)
      is_epic = Epic_form.is(word)
      if !alpha_equal(word,lemma) then
        difficult_to_recognize ||= (is_3rd_decl && guess_difficulty_of_recognizing_declension(word,lemma,pos)[0])
        difficult_to_recognize ||= is_epic
        difficult_to_recognize ||= (is_verb && Verb_difficulty.guess(word,lemma,pos)[0])
      end
      if is_3rd_decl then misc['is_3rd_decl']=true end
      if is_epic then misc['is_epic']=true end
    end
    if using_thresholds then
      gloss_this = ( rank>=threshold_no_gloss || (rank>=threshold_difficult && difficult_to_recognize) )
    else
      gloss_this = !(core.include?(lemma))
    end
    next unless gloss_this
    misc['difficult_to_recognize'] = difficult_to_recognize
    entry = word_raw,word,lemma,rank,f,pos,difficult_to_recognize,misc
    # ... word and word_raw are not super useful, in many cases will be just the first example in this passage
    #$stderr.print "entry=#{entry}\n"
    result.push(entry)
  }

  result.sort! { |a,b| b[4] <=> a[4] } # descending order by frequency
  while result.length>max_entries do
    kill_em = nil
    count = 0
    result.each { |entry|
      word_raw,word,lemma,rank,f,pos,difficult_to_recognize,misc = entry
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
      word_raw,word,lemma,rank,f,pos,difficult_to_recognize,misc = entry
      next if Proper_noun.is(word_raw,lemma) # ... use word_raw to preserve capitalization, since some proper nouns have the same letters as other words
      next if Ignore_words.patch(word) || Ignore_words.patch(lemma)
      next unless !rank.nil? && rank>=threshold_difficult
      next if rank<threshold_no_gloss && !difficult_to_recognize      
      next unless rank<threshold && commonness==0 or rank>=threshold && rank<threshold2 && commonness==1 or rank>=threshold2 && commonness==2
      key = remove_accents(lemma).downcase
      filename = "glosses/#{key}"
      if Options.if_render_glosses && Gloss.get(db,lemma).nil? then
        gloss_help.push(Vlist.gloss_help_help_helper(key,lemma))
        whine.push("no glossary entry for #{lemma} , see gloss help file")
      end
      if warn_ambig.has_key?(word) then ambig_warnings.push(warn_ambig[word]) end
      # stuff some more info in the misc element:
      misc['pos'] = pos # lemma and pos may be wrong if the same word can occur in more than one way
      this_part_of_result2.push([word,lemma,misc])
    }
    result2.push(this_part_of_result2)
  }
  whine = whine + ambig_warnings
  if whine.length>0 then
    whiny_file = "warnings"
    File.open(whiny_file,"a") { |f|
      whine.each { |complaint| f.print "#{complaint}\n" }
    }
  end
  if gloss_help.length>0 then
    gloss_help_summary_info = Vlist.give_gloss_help(gloss_help)
    $stderr.print gloss_help_summary_info,"\n" if !gloss_help_summary_info.nil?
  end
  vl = Vlist.new(result2)
  if whine.length>0 then vl.console_messages = "#{whine.length} warnings written to the file #{whiny_file}\n" end

  return vl
end

def Vlist.gloss_help_help_helper(key,lemma)
  h = {
    'filename'=>key,
    'lemma'=>lemma,
    'url'=> "https://en.wiktionary.org/wiki/#{lemma} https://logeion.uchicago.edu/#{lemma}",
    'wikt'=> WiktionaryGlosses.get_glosses(lemma).join(', ')
  }
  debug_gloss = false
  if debug_gloss then
     h['debug']="key=#{key}, raw=#{word_raw}, word=#{word}, lemma=#{lemma}, ignore=#{Ignore_words.patch(word)}, pr=#{Proper_noun.is(word,lemma,require_cap:false)}"
  end
  return h
end

def Vlist.give_gloss_help(gloss_help)
  gloss_help_dir = "help_gloss"
  unless File.directory?(gloss_help_dir) then Dir.mkdir(gloss_help_dir) end
  gloss_help = gloss_help.filter { |h| h['lemma']==h['lemma'].downcase } # filter out things that look like proper nouns
  return nil if gloss_help.length==0
  list_written = []
  gloss_help.each { |h|
    filename = dir_and_file_to_path(gloss_help_dir,h['filename'])
    next if File.exist?(filename)
    list_written.push(h['lemma'])
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
  if n_written==0 then return nil end
  if n_written<=10 then ll=list_written; suffix='' else ll = list_written[0..9]; suffix=" (more...) " end
  return "====wrote gloss help to #{gloss_help_dir} for #{n_written} lemmas that previously had no help: ====\n" \
        + "  " + ll.join(" ") + suffix + "\n"
end

end # class Vlist

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
    Ἀθηναῖος  Γερήνιος Αἰτωλός Ὀιλεύς Νήριτος Λήιτος Ὠκεανός
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
  @@index = %q{
    οτηερ υνκνοων
    η τα τον ο τους αυτους εμος αυτου σος ω ουτος τοιος εγω
    ειμι
    επι ανα μετα απο δια προ προς συν εις αμα ηδη ινα ευς μην ος οδε ετι
    δυω πολλας δη πατηρ πολυ τρις
    κακος ευ παρα περ χειρ
    οτι πως εαν οτε ουδε τοτε οπως ουτε που ωδε δυο
    ειπον μα αλλη αμφω εκεινος κεινος μητε περι
    μη αμφι υπερ σφος ποιος οστις οσος αρα εισω θήν τως ὑπό
  }.split(/\s+/).map { |x| remove_accents(x.downcase)}.to_set
  def Ignore_words.patch(word)
    w = remove_accents(word).downcase
    return @@index.include?(w)
  end

end

