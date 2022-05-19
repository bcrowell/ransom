module Preposition
  def Preposition.all_homeric
    # found by doing print treebank.every_lemma_by_pos('r') on Homer
    return ["ἄγχι", "ἀγχίμολον", "ἀγχόθι", "ἄλλοθι", "ἅμα", "ἀμφί", "ἀμφίς", "ἀνά", "ἄνευ", "ἄνευθε", "ἄντα", "ἀντί", "ἀντία", "ἀντιβίην", "ἀντικρύ", "ἀντίον", "ἀντίος", "ἀπάνευθε", "ἀπάτερθε", "ἀπό", "ἀπονόσφι", "ἆσσον", "ἄτερ", "ἄχρι", "διά", "διαπρό", "διέκ", "ἐγγύθεν", "ἐγγύθι", "ἐγγύς", "εἰς", "εἴσω", "ἐκ", "ἑκάς", "ἑκάτερθε", "ἔκτοθεν", "ἔκτοθι", "ἐκτός", "ἔκτοσε", "ἔκτοσθεν", "ἐν", "ἔναντα", "ἐναντίον", "ἔνδοθεν", "ἔνδοθι", "ἔνδον", "ἕνεκα", "ἔνερθε", "ἐντός", "ἔντοσθε", "ἔντοσθεν", "ἐξόπιθεν", "ἔξω", "ἐπί", "ἔσω", "ἰθύς", "καθύπερθε", "καθύπερθεν", "κατά", "καταντικρύ", "κατεναντίον", "κατόπισθεν", "μεσηγύ", "μεσσηγύς", "μέσφα", "μετά", "μετόπισθε", "μέχρι", "μίγδα", "νόσφι", "ὁμῶς", "ὄπισθεν", "ὀπίσσω", "παρά", "παρασταδόν", "παρέξ", "πάροιθε", "πάρος", "πέλας", "πέραν", "περί", "πλήν", "πλησίον", "πλησίος", "πρό", "προπάροιθε", "πρός", "πρόσθεν", "πρόσθεϝ", "σύν", "σχεδόθεν", "σχεδόν", "τῆλε", "τηλόθι", "τηλοῦ", "ὕπαιθα", "ὑπείρ", "ὑπέκ", "ὑπένερθε", "ὑπέρ", "ὕπερθεν", "ὑπό"]
  end

  def Preposition.all_the_ones_used_in_verbs
    return ["ἅμα", "ἀμφί", "ἀνά", "ἄντα", "ἀντί", "ἀντία", "ἀπό", "διά", "εἴσω", "ἐκ", "ἐν", "ἔξω", "ἐπί", "ἔσω", "κατά", "μετά", "νόσφι", "παρά", 
             "παρέξ", "περί", "πρό", "σύν", "τῆλε", "ὑπέκ", "ὑπέρ", "ὑπό"]
    # found by running Verb_util.find_all_families with temporary debugging code; Homeric, but probably not much different in other dialects
  end


  def Preposition.prefix_to_stem(prep,stem)
    # Doesn't attempt to get accent or breathing mark right, won't work if stem is a verb that has an augment.
    # Preposition should be provided in lemmatized form, meaning ἐκ rather than ἐξ, ἐν rather than ἐνί.
    # Returns a MultiString.
    return Preposition.prefix_form(prep,stem)+MultiString.new(stem)
  end

  def Preposition.recognize_prefix(word,genos:GreekGenos.new('epic'))
    a = Preposition.recognize_prefix_helper(word,genos)
    has_preposition,prefix,stem,preposition = a
    if !has_preposition then return a end
    if ['ἀπό','ἐπί','ὑπό'].include?(preposition) && prefix=~/φ$/ then
      stem = add_rough_breathing(stem)
    end
    return [has_preposition,prefix,stem,preposition]
  end

  def Preposition.recognize_prefix_helper(word,genos)
    Preposition.all_the_ones_used_in_verbs.each { |p|
      poss = [p] # list possible forms for this preposition
      poss = ['ἐκ','ἐξ','ἐγ'] if p=='ἐκ'
      poss = ['ἐν','ἐμ','ἐγ','ἐνι'] if p=='ἐν' # e.g., ἐνιπλήξωμεν
      poss = ['ἀπό','ἀφ'] if p=='ἀπό'
      poss = ['ἐπί','ἐφ'] if p=='ἐπί'
      poss = ['ὑπό','ὑφ'] if p=='ὑπό'
      if p=='σύν' then
        poss = ['σύν','σύμ','σύγ','σύλ','σύρ','σύσ','σύ']
        if genos.period<=1 then poss=poss+poss.map { |x| x.sub(/^σ/,'ξ') } end # handle Homeric ξύν
      end
      w = remove_accents(word)
      poss.each { |x|
        xx = remove_accents(x)
        0.upto(1) { |i| # on pass 1, check for elided vowel
          if i==1 && xx=~/(.*)[αειουηω]$/ then xxx=$1 else xxx=xx end
          next unless w=~/^#{xxx}.{1,}/
          prefix = word[0..(xxx.length-1)]
          stem = word[xxx.length..(word.length-1)]
          return [true,prefix,stem,x]
        }
      }
    }
    return [false,'',word,nil]
  end

  def Preposition.prefix_form(prep,stem)
    # Returns a MultiString representing possible forms for the preposition when it occurs on the front of the given stem.
    stem_phoneticized = Writing.phoneticize(stem)
    first_letter = remove_accents(stem_phoneticized[0]).downcase
    if first_letter=~/[hαειουηω]/ then vowel=true else vowel=false end
    if first_letter=~/[γκξχ]/ then velar=true else velar=false end # ξ would actually have been phoneticized by now
    if first_letter=~/[βμπφψ]/ then labial=true else labial=false end # ψ would actually have been phoneticized by now
    if stem.length>=2 && stem[0]=='σ' && stem[1]=~/[αειουηω]/ then stem_s_vowel=true else stem_s_vowel=false end
    if stem.length>=2 && stem[0]=='σ' && !(stem[1]=~/[αειουηω]/) then stem_s_cons=true else stem_s_cons=false end
    if prep=='ἐκ' then
      return MultiString.new('ἐξ') if vowel
      return MultiString.new('ἐγ') if first_letter=~/[βδλμ]/
    end
    if prep=='ἐν' then
      forms = []
      forms.push('ἐμ') if labial
      forms.push('ἐγ') if velar
      if forms.length==0 then forms.push('ἐν') end # default if it's not either of the above two cases
      forms.push('ἐνι') # we do get forms like ἐνιπλήξωμεν
      return MultiString.new([forms]) 
    end
    # I'm not sure if the following rules about π->φ are 100% right, but this seems like what's happening based on dictionary entries.
    if first_letter=='h' then
      return MultiString.new('ἀφ') if prep=='ἀπό'
      return MultiString.new('ἐφ') if prep=='ἐπί'
      return MultiString.new('ὑφ') if prep=='ὑπό'
    end
    if prep=='σύν' then
      # for phonetic rules, see https://en.wiktionary.org/wiki/%CF%83%CF%85%CE%BD-#Ancient_Greek
      forms = ['σύν']
      if labial then forms.push('σύμ') end # e.g., συμμαχέω, συμφέρω
      if velar then forms.push('σύγ') end
      if first_letter=='λ' then forms.push('σύλ') end # e.g., συλλέγω
      if first_letter=='ρ' then forms.push('σύρ') end
      if stem_s_vowel then forms.push('σύσ') end
      if first_letter=='ζ' || stem_s_cons then forms.push('σύ') end
      forms = forms + forms.map { |x| x.sub(/^σ/,'ξ') } # handle Homeric ξύν
      return MultiString.new([forms]) 
    end
    prep_phoneticized = Writing.phoneticize(prep)
    last_letter_of_prep = remove_accents(prep_phoneticized[-1]).downcase
    if vowel && last_letter_of_prep=~/[αειουηω]/ then
      # last letter of preposition is usually (always?) elided
      # examples: ἀπάρχω ἀντέχω ἀπόρνυμι ἀνερείπομαι
      prep =~ /(.*)./
      with_elision = $1
      return MultiString.new([[prep,with_elision]])
    end
    # Fall through to default:
    return MultiString.new(prep)
  end
end
