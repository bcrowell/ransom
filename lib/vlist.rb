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

def Vlist.from_text(t,lemmas_file,freq_file,thresholds:[1,50,700,700],max_entries:58,exclude_glosses:[])
  lemmas = json_from_file_or_die(lemmas_file)
  # typical entry when there's no ambiguity:
  #   "βέβασαν": [    "βαίνω",    "1",    "v3plia---",    1,    false,    null  ],
  freq = json_from_file_or_die(freq_file)
  freq_list = freq.to_a
  freq_list.sort! { |a,b| b[1] <=> a[1]} # descending order by frequency; is probably already sorted, so this will be fast
  # ... a list of pairs like [["δέ", 12136], ["ὁ" , 5836], ...]
  whine = []

  t.gsub!(/\d/,'')
  t.gsub!(/᾽(?=[[:alpha:]])/,"᾽ ") # e.g., ποτ᾽Ἀθήνη
  t = t.unicode_normalize(:nfc)

  freq_rank = {}
  rank = 1
  freq_list.each { |a|
    lemma,count = a
    freq_rank[lemma] = rank
    rank += 1
  }

  threshold_difficult = thresholds[0] # words ranked lower than this may be glossed if they're difficult forms to recognize
  threshold_no_gloss = thresholds[1] # words ranked higher than this are not normally glossed
  threshold = thresholds[2] # words ranked higher than this are listed as common
  threshold2 = thresholds[3] # words ranked lower than this get ransom notes

  result = []
  did_lemma = {}
  warn_ambig = {}
  t.scan(/[^\s—]+/).each { |word_raw|
    word = word_raw.gsub(/[^[:alpha:]᾽']/,'')
    next unless word=~/[[:alpha:]]/
    lemma_entry = Vlist.get_lemma_helper(lemmas,word)
    if lemma_entry.nil? then whine.push("error: no index entry for #{word_raw}, key=#{word}"); next end
    lemma,lemma_number,pos,count,if_ambiguous,ambig = lemma_entry
    if if_ambiguous then 
      warn_ambig[word]= "warning: lemma for #{word_raw} is ambiguous, taking most common one; #{ambig}"
    end
    if lemma.nil? then whine.push("lemma is nil for #{word} in lemmas file"); next end
    next if did_lemma.has_key?(lemma)
    excl = false
    [lemma,word].each { |x| excl = excl || exclude_glosses.include?(remove_accents(x).downcase) }
    # $stderr.print "excl=#{excl}, #{lemma}/#{word}\n" # qwe
    next if excl
    did_lemma[lemma] = 1
    rank = freq_rank[lemma]
    f = freq[lemma]
    is_3rd_decl = guess_whether_third_declension(word_raw,lemma,pos)
    is_epic = Epic_form.is(word_raw)
    difficult_to_recognize = false
    if !alpha_equal(word_raw,lemma) then
      difficult_to_recognize ||= is_3rd_decl
      difficult_to_recognize ||= is_epic
      # Don't try to judge whether it's a difficult aorist to recognize, because we don't have access to the gloss file.
    end
    next unless rank>=threshold_no_gloss || (rank>=threshold_difficult && difficult_to_recognize)
    misc = {}
    misc['difficult_to_recognize'] = difficult_to_recognize
    if is_3rd_decl then misc['is_3rd_decl']=true end
    if is_epic then misc['is_epic']=true end
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
      next unless rank>=threshold_difficult
      next if rank<threshold_no_gloss && !difficult_to_recognize      
      next unless rank<threshold && commonness==0 or rank>=threshold && rank<threshold2 && commonness==1 or rank>=threshold2 && commonness==2
      key1 = remove_accents(word).downcase.sub(/᾽/,'')
      key2 = remove_accents(lemma).downcase
      filename1 = "glosses/#{key1}"
      filename2 = "glosses/#{key2}"
      if FileTest.exist?(filename1) then
        key=key1
      else
        if FileTest.exist?(filename2) then
          key=key2
        else
          key=key1
        end
      end
      filename = "glosses/#{key}"
      if !(FileTest.exist?(filename)) && Options.if_render_glosses && !Ignore_words.patch(word) && !Proper_noun.is(word,lemma) then
        if key1==key2 then foo=key1 else foo="#{key1} or #{key2}" end
        gloss_help.push({
          'filename'=>key2,
          'lemma'=>lemma,
          'url'=> "https://en.wiktionary.org/wiki/#{lemma} https://logeion.uchicago.edu/#{lemma}",
          'wikt'=> WiktionaryGlosses.get_glosses(lemma).join(', ')
        })
        whine.push("no glossary entry for #{filename2} , see gloss help file")
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
  if gloss_help.length>0 then Vlist.give_gloss_help(gloss_help) end
  vl = Vlist.new(result2)
  if whine.length>0 then vl.console_messages = "#{whine.length} warnings written to the file #{whiny_file}\n" end
  return vl
end

def Vlist.get_lemma_helper(lemmas,word)
  if lemmas.has_key?(word) then return lemmas[word] end
  if lemmas.has_key?(word.downcase) then return lemmas[word.downcase] end
  return nil
end

def Vlist.give_gloss_help(gloss_help)
  gloss_help_dir = "help_gloss"
  unless File.directory?(gloss_help_dir) then Dir.mkdir(gloss_help_dir) end
  $stderr.print "====writing gloss help to #{gloss_help_dir} ====\n"
  gloss_help.each { |h|
    File.open(dir_and_file_to_path(gloss_help_dir,h['filename']),"w") { |f|
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
    }
  }
  File.open(dir_and_file_to_path(gloss_help_dir,"__links.html"),"a") { |f|
    gloss_help.each { |h|
      next if h['wikt'].to_s!=''
      f.print "<p>#{remove_accents(h['lemma']).downcase} "
      h['url'].scan(/http[^\s]+/).each { |url|
        f.print "  <a href=\"#{url}\">#{h['lemma']}</a> " unless url=~/wiktionary/
      }
      f.print "</p>\n"
    }
  }
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
    αιθιοψ κρονιδης πηλευς δρυας κορος Ἀτρείων
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
  @@index = %q{
    οτηερ υνκνοων
    η τα τον ο τους αυτους εμος αυτου σος ω ουτος τοιος εγω
    ειμι
    επι ανα μετα απο δια προς συν εις αμα ηδη ινα ευς μην ος οδε τω ετι
    δυω πολλας δη πατηρ πολυ τρις
    κακος ευ παρα περ χειρ
    οτι πως εαν οτε ουδε τοτε οπως ουτε που ωδε δυο
    ειπον μα αλλη αμφω εκεινος κεινος μητε περι
    μη αμφι υπερ
  }.split(/\s+/).map { |x| remove_accents(x.downcase)}.to_set
  def Ignore_words.patch(word)
    w = remove_accents(word).downcase
    return @@index.include?(w)
  end

end

