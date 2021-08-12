class Gloss

def Gloss.get(lexical,word,prefer_short:false)
  # It doesn't matter whether the inputs have accents or not. We immediately strip them off.
  # Return value looks like the following. The item lexical exists only if this is supposed to be an entry for the inflected form.
  # {  "word"=> "ἔθηκε",  "medium"=> "put, put in a state",  "lexical"=> "τίθημι", "file_under"=>"ἔθηκε" }
  entry_lexical   = Gloss.helper(lexical,Gloss.word_to_key(lexical),prefer_short)
  entry_inflected = Gloss.helper(word,Gloss.word_to_key(word),prefer_short)
  if entry_inflected.nil? then
    entry = entry_lexical
    file_under = lexical
  else
    entry = entry_inflected
    file_under = word
  end
  if !(entry.nil?) then entry = entry.merge({'file_under'=>file_under}) end
  return entry
end

def Gloss.helper(word,key,prefer_short)
  x = Gloss.get_from_file(key)
  if x.nil? then return nil end
  if x.kind_of?(Array) then
    # words like δαίς/δάϊς that have the same key
    found = false
    entry_found = nil
    x.each { |entry|
      if entry['word']==word then
        found = true
        entry_found = entry
      end
    }
    if found then
      x = entry_found
    else
      return nil
    end
  end
  # {  "word": "ἔθηκε",  "medium": "put, put in a state",  "lexical": "τίθημι" }
  if prefer_short && x.has_key?('short') then x['medium']=x['short'] end
  return x
end

def Gloss.get_from_file(key)
  path = Gloss.key_to_path(key)
  if FileTest.exist?(path) then return json_from_file_or_die(path) else return nil end
end

def Gloss.key_to_path(key)
  return "glosses/#{key}"
end

def Gloss.word_to_key(s)
  return remove_accents(s).downcase.sub(/᾽/,'')
end


end
