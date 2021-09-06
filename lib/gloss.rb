# coding: utf-8
class Gloss

=begin
Format of glossary files:

Sometimes two words have the same key, e.g.,
δαίς and δάϊς. Then the data structure inside
the file is an array containing the two entries.

mandatory keys:

word
medium

optional:

lexical
  E.g., for the word ἕλωμαι, lexical is αἱρέω.

pos ["verb","noun","adj","adv",...]
short
long

etym
cog
syn
notes

gender ["m","f","n","m or f"]
genitive [for nouns]
princ [for verbs]: future and aorist, e.g., for ἔρχομαι, "ἐλεύσομαι,ἤλυθον"; for verbs that have both a 1st and a 2nd aorist: βήσω,ἔβησα/ἔβην [the slash always means this 1st/2nd aorist thing, not some other variation of form]

proper_noun

logdiff [+1 means consider it as difficult as a word whose freq
     rank is 10x greater]
=end

def Gloss.all_lemmas(file_glob:'glosses/*')
  lemmas = []
  Dir.glob(file_glob).sort.each { |filename|
    next if filename=~/~/
    next if filename=~/README/
    filename=~/([[:alpha:]]+)$/
    key = $1
    err,message = Gloss.validate(key)
    if err then print "error in file #{key}\n  ",message,"\n" end
    # In the following, we don't need to do error checking because any errors would have been caught by Gloss.validate().
    path = Gloss.key_to_path(key)
    json,err = slurp_file_with_detailed_error_reporting(path)
    x = JSON.parse(json)
    if x.kind_of?(Array) then a=x else a=[x] end
    a.each { |x|
      lemmas.push(x['word'])
    }
  }
  return alpha_sort(lemmas)
end

def Gloss.get(lexical,word,prefer_length:1)
  # It doesn't matter whether the inputs have accents or not. We immediately strip them off.
  # Return value looks like the following. The item lexical exists only if this is supposed to be an entry for the inflected form.
  # {  "word"=> "ἔθηκε",  "gloss"=> "put, put in a state",  "lexical"=> "τίθημι", "file_under"=>"ἔθηκε" }
  entry_lexical   = Gloss.helper(lexical,prefer_length)
  entry_inflected = Gloss.helper(word,prefer_length)
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

def Gloss.helper(word,prefer_length)
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
  x['gloss']=x['medium']
  if prefer_length==0 && x.has_key?('short') then x['gloss']=x['short'] end
  if prefer_length==2 && x.has_key?('long') then x['gloss']=x['long'] end
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
  mandatory_keys = ['word','medium']
  allowed_keys = ['word','lexical','short','medium','long','etym','cog','syn','notes','pos','gender','genitive','princ','proper_noun','logdiff']
  # Try to detect duplicate keys.
  allowed_keys.each { |key|
    if json.scan(/\"#{key}\"\s*:/).length>n then return [true,"key #{key} occurs more than #{n} times"] end
  }
  a.each { |entry|
    eks = entry.keys.to_set
    if !(eks.subset?(allowed_keys.to_set)) then return [true,"illegal key(s): #{eks-allowed_keys.to_set}"] end
    if !(mandatory_keys.to_set.subset?(eks)) then return [true,"required key(s) not present: #{mandatory_keys.to_set-eks}"] end
    if entry.has_key?('gender') then
      allowed_genders = ['m','f','n','m or f']
      if !(allowed_genders.to_set.include?(entry['gender'])) then return [true,"illegal value for gender, #{entry['gender']}, should be one of #{allowed_genders}"] end
    end
    entry.keys.each { |key|
      value = entry[key]
      if value!=remove_macrons_and_breves(value) then return [true,"value contains macron or breve, #{value}"] end
    }
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
