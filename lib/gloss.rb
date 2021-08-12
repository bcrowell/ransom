# coding: utf-8
class Gloss

def Gloss.get(lexical,word,prefer_short:false)
  # It doesn't matter whether the inputs have accents or not. We immediately strip them off.
  # Return value looks like the following. The item lexical exists only if this is supposed to be an entry for the inflected form.
  # {  "word"=> "ἔθηκε",  "gloss"=> "put, put in a state",  "lexical"=> "τίθημι", "file_under"=>"ἔθηκε" }
  entry_lexical   = Gloss.helper(lexical,prefer_short)
  entry_inflected = Gloss.helper(word,prefer_short)
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

def Gloss.helper(word,prefer_short)
  x = Gloss.get_from_file(word)
  if x.nil? then return nil end
  if x.kind_of?(Array) then
    # words like δαίς/δάϊς that have the same key and therefore live in the same file
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
  if prefer_short && x.has_key?('short') then x['gloss']=x['short'] else x['gloss']=x['medium'] end
  return x
end

def Gloss.validate(key)
  # Returns [err,message].
  path = Gloss.key_to_path(key)
  if !FileTest.exist?(path) then return [true,"file #{path} doesn't exist"] end
  json,err = slurp_file_with_detailed_error_reporting(path)
  if !(err.nil?) then return [true,err] end
  begin
    x = JSON.parse(json)
  rescue
    return [true,"error parsing JSON in file #{path}, json=\n#{json}\n"]
  end
  if x.kind_of?(Array) then a=x else a=[x] end # number of words for this key, normally 1, except for stuff like δαίς/δάϊς
  n = a.length
  # Try to detect duplicate keys.
  allowed_keys = ['word','lexical','short','medium','long','etym','cog','syn','notes','pos','gender','genitive','proper_noun','logdiff']
  allowed_keys.each { |key|
    if json.scan(/\"#{key}\"/).length>n then return [true,"key #{key} occurs more than #{n} times"] end
  }
  a.each { |entry|
    if !(entry.keys.to_set.subset?(allowed_keys.to_set)) then return [true,"illegal key(s): #{entry.keys.to_set-allowed_keys.to_set}"] end
  }
  return [false,nil]
end

def Gloss.get_from_file(word)
  key = Gloss.word_to_key(word)
  x = Gloss.get_from_file_helper(key)
  return x
end

def Gloss.get_from_file_helper(key)
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