# coding: utf-8
class Gloss

=begin
Format of glossary files:

Sometimes two words have the same key, e.g.,
δαίς and δάϊς. Then the data structure inside
the file is an array containing the two entries.

mandatory keys:

word
  Normally this is  just the filename with accents added in. However, sometimes Project Perseus indexes a word under a form
  like ξένος, while Homer uses some other form like ξείνος. In a case like that, we would have a file named
  χενος, containing "word":"ξείνος" and "perseus":"ξένος" (see below). The word would appear
  in the book as ξείνος.
  Sometimes Homer has more than one form of the word, e.g., ὄπισθεν and ὄπιθεν. In this situation, the
  gloss file only has to list whatever form is used by Perseus. When the alternate spelling occurs, it's
  tagged in the Perseus treebank as a case of the lemma with the correct spelling, so we don't need to
  do anything special.

medium
  A medium-length definition of the word.

optional:

perseus
  In cases where the preferred Homeric form of the word differs from Project Perseus's lemma, the filename
  is based on the Perseus lemma, and we can also have this tag giving the accented form of
  the Perseus lemma. If this information is missing, the main thing that goes wrong is that when
  we generate the list of core vocabulary, we get an error. Having this data could conceivably
  also be helpful if there is some danger of ambiguity in looking up the
  word based on its Perseus lemma.

vowel_length
  E.g., for νέκυς, this is νέκυ_ς. That is: for any doubtful vowel that is
  phonemically long, we put an underbar after it. To convert from standard macronized
  style to this style, use Gloss.macronized_to_underbar_style().

pos ["verb","noun","adj","adv",...]
short
long

etym
cog
syn
notes

gender ["m","f","n","m or f"]
genitive [for nouns]
princ [for verbs]: future and aorist, e.g., for ἔρχομαι, "ἐλεύσομαι,ἤλυθον"; for verbs that have both a 1st and a 2nd aorist: βήσω,ἔβησα/ἔβην [the slash always means this 1st/2nd aorist thing, not some other variation of form]; can be parsed in software using Gloss.split_princ()

"proper_noun":1 -- indicates that it's a proper noun

logdiff [+1 means consider it as difficult as a word whose freq
     rank is 10x greater]
"aorist_difficult_to_recognize" -- deprecated, never set to 1; harmless if set to 0

mnem -- a mnemonic; may be idiosyncratic and only of interest to me; I use these only when there is no cognate that helps
=end

def Gloss.all_lemmas(file_glob:'glosses/*')
  lemmas = []
  Dir.glob(file_glob).sort.each { |filename|
    next if (filename=~/~/ || filename=~/README/ )
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
      lemmas.push(x['word']) if x['word']!=''
    }
  }
  return alpha_sort(lemmas)
end

def Gloss.get(word,prefer_length:1)
  # The input can be accented or unaccented. Accentuation will be used only for disambiguation, which is seldom necessary.
  # Giving the inflected form could in theory disambiguate certain cases where there are two lemmas spelled the same, but
  # I haven't implemented anything like that yet.
  # Return value looks like the following.
  # {  "word"=> "ἔθηκε",  "gloss"=> "put, put in a state" }
  x = Gloss.get_from_file(word)
  if x.nil? then return nil end
  if !(x.kind_of?(Array)) then x=[x] end
  # We can have words like δαίς/δάϊς that have the same key and therefore live in
  # the same file. Even if that's not the case, convert x to an array for convenience.
  entries_found = []
  ['perseus','word'].each { |tag|
    x.each { |entry|
      if entry[tag]==word then
        entries_found.push([tag,entry])
      end
    }
  }
  if entries_found.length>0 then
    e = entries_found[0][1]
  else
    return nil
  end
  ambiguous = (entries_found.length>=2 && entries_found[0][0]!=entries_found[1][0])
  if ambiguous then
    $stderr.print "********* WARNING: ambiguous glosses found for lemma #{lemma}: #{entries_found}\n"
  end
  # {  "word": "ἔθηκε",  "medium": "put, put in a state" }
  e['gloss']=e['medium']
  if prefer_length==0 && e.has_key?('short') then e['gloss']=e['short'] end
  if prefer_length==2 && e.has_key?('long') then e['gloss']=e['long'] end
  return e
end

def Gloss.validate(key)
  # Returns [err,message].
  if key!=remove_accents(key).downcase then return [true,"filename #{key} contains accents or uppercase, should be #{remove_accents(key).downcase}"] end
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
  allowed_keys = ['word','short','medium','long','etym','cog','syn','notes','pos','gender','genitive','princ','proper_noun','logdiff','mnem','vowel_length','aorist_difficult_to_recognize','perseus']
  # Try to detect duplicate keys.
  allowed_keys.each { |key|
    if json.scan(/\"#{key}\"\s*:/).length>n then return [true,"key #{key} occurs more than #{n} times"] end
  }
  a.each { |entry|
    eks = entry.keys.to_set
    if !(eks.subset?(allowed_keys.to_set)) then return [true,"illegal key(s): #{eks-allowed_keys.to_set}"] end
    if !(mandatory_keys.to_set.subset?(eks)) then return [true,"required key(s) not present: #{mandatory_keys.to_set-eks}"] end
    eks.select! { |key| entry[key]!='' } # delete keys with null-string values
    if !(mandatory_keys.to_set.subset?(eks)) then return [true,"required key(s) are null strings: #{mandatory_keys.to_set-eks}"] end
    if entry.has_key?('gender') then
      allowed_genders = ['m','f','n','m or f']
      if !(allowed_genders.to_set.include?(entry['gender'])) then return [true,"illegal value for gender, #{entry['gender']}, should be one of #{allowed_genders}"] end
    end
    if entry.has_key?('princ') then
      princ = entry['princ']
      if !(princ=~/,/) then return [true,"no comma in princ=#{princ}"] end
      future,aorist = Gloss.split_princ(princ)
      if future.length>1 then return [true,"more then one future form in princ=#{princ}"] end
      if future.length==1 && !(future[0]=~/(ω|μαι)$/) then return [true,"future #{future[0]} doesn't end in -ω or -μαι, princ=#{princ}"] end
      if aorist.length>0 then
        aorist.each { |a|
          if !(a=~/(α|ον|ην|ων|υν)/) then return [true,"aorist #{a} doesn't end in -α, -ον, -[ηωυ]ν princ=#{princ}"] end
        }
      end
    end
    if entry.has_key?('vowel_length') then
      macronized = entry['vowel_length'] # in a style like λύρα_, with underbars for doubtful vowels that are long
      if macronized.gsub(/_/,'')!=entry['word'] then return [true,"macronized form #{macronized} doesn't make sense for word #{entry['word']}"] end
      if macronized=~/(([^αιυ])_)/ then return [true,"macronized form #{macronized} contains #{$1}, but #{$2} isn't a doubtful vowel"] end
    else
      if entry['word']=~/υμι$/ then return [true,"no vowel_length entry for #{entry['word']}, should probably have one ending in υ_μι"] end
    end
    entry.keys.each { |key|
      value = entry[key]
      if value!=remove_macrons_and_breves(value) then return [true,"value contains macron or breve, #{value}; macronization should be indicated only in the style like α_, not like ᾱ, and should be present only in the vowel_length field"] end
    }
    #if alpha_compare(entry['word'],key)!=0 then return [true,"filename #{key} doesn't match word #{entry['word']} up to case and accents"] end
    # no, we want this in cases like χενος
  }
  return [false,nil]
end

def Gloss.split_princ(princ)
  # Given the value as defined for the "princ" key, return [[f],[a,...]].
  # If the given form doesn't exist, the list is empty.
  f,a = princ.split(/,/)
  if f=='' then f=[] else f=[f] end
  if a=='' || a.nil? then
    # ... the latter happens when there's no comma, which is a user error and will be flagged in checks
    a=[]
  else
    a = a.split(/\//)
  end
  return [f,a]
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

def Gloss.macronized_to_underbar_style(s)
  x = s.gsub(/([ᾱῑῡ])/) { "#{remove_macrons_and_breves($1)}_" }
  return remove_macrons_and_breves(x)
end

end
