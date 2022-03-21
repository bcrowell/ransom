class LemmaUtil

# This is Greek-specific for multiple reasons:
#   - Uses Perseus pos tags.
#   - Uses linguistic facts about Greek.

def LemmaUtil.make_inflected_form_flavored_like_lemma(word,is_proper_noun:false)
  # Sometimes we give a gloss in which we explain an inflection. In these cases, we're sort of giving a dictionary entry for
  # a form that isn't the dictionary form. Try to make this look normal. It may be capitalized because it was the first word
  # in a sentence, and it may have a grave accent or multiple accents because of enclitics.
  # The Greek-specific code shouldn't do any harm on Latin words.
  word = word.downcase
  word = to_single_accent(word)
  # ... If the word has both an acute and a grave, remove the grave. If it has only a grave, change it to an acute.
  return word
end

def LemmaUtil.disambiguate_lemmatization(word,ambig)
  # On input, ambig is a list of structures like ["αἴξ", "", "n-p---mg-", 14], sorted from most to least frequent.
  # The idea here is that often a single word like αἰγῶν has more than one lemma/pos analysis in Perseus, but often
  # this has no consequences for looking up the right dictionary entry.
  # E.g., ambig=[["αἴξ", "", "n-p---mg-", 14], ["αἴξ", "", "n-p---fg-", 7]] because αἴξ has common gender.
  # This routine tries to determine whether it's one of those cases or not, doing the best it can without actually
  # knowing the POS analysis of word.
  # If this routine fails, then we can try instead using treebank.get_lemma_and_pos_by_line(), which is slower, normally more precise, but
  # may not work if the treebank's text doesn't match the text we're using.
  # Returns [sadness,i].
  # If disambiguation worked, sadness<=0. If it didn't, then sadness>0.
  # The i index is basically useless, is always 0. I intended it to be the best index into ambig to use, but this routine
  # actually has no data that would allow it to determine that, so it always returns 0, which is the most frequent lemma.
  # Other typical examples:
  #  ἀπάνευθε -- [["ἀπάνευθε", "", "r--------", 20], ["ἀπάνευθε", "", "d--------", 15]]
  #    This happens because prepositions in the Homeric dialect haven't finished evolving from adverbs to prepositions.
  #  ἕζετ᾽ -- [["ἕζομαι", "", "v3spie---", 7], ["ἕζομαι", "", "v3saim---", 6], ["ἕζομαι", "", "v3siie---", 4]]
  #    Elision makes the conjugation ambiguous, but doesn't affect the lemmatization.

  differences = {}
  0.upto(ambig.length-2) { |i|
    if ambig[i][0]!=ambig[i+1][0] then differences['spelling_of_lemma']=1 end
    tag1,tag2 = ambig[i][2],ambig[i+1][2] # 9-character perseus pos tags
    pos1,pos2 = tag1[0],tag2[0] # first character, the part of speech, e.g., n for noun
    if tag1!=tag2 then differences['inflection']=1 end
    if pos1!=pos2 then
      done = false
      combo = [pos1,pos2].sort.join('') # e.g., 'nv' if one lemma is a noun and the other a verb
      if combo=='dr' then differences['minor_pos']=1; done=true end # this is language- and dialect-specific; but see remark re ἀπάνευθε above
      if !done then differences['major_pos']=1; done=true end # e.g., one's a verb and one's a noun
    end
  }
  sadnesses = {'spelling_of_lemma'=>10,'major_pos'=>5,'minor_pos'=>2,'inflection'=>0}
  sadnesses.keys.sort_by { |k| -sadnesses[k] }.each { |k| # return a score based on the highest-scoring difference
    if differences.has_key?(k) then return [sadnesses[k],0] end
  }
  return [0,0]  
end

end
