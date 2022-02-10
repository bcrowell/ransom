# coding: utf-8
class Gloss

=begin
Format of glossary files:

Sometimes two words have the same key, e.g.,
δαίς and δάϊς. Then the data structure inside
the file is an array containing the two entries.

The following comments were written when my code was hard-coded as if we would always prefer Homeric forms over
Project Perseus's Attic lemmas, but actually I've cleaned that up now and GlossDB can be initialized either way.

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

pos - a one-character part-of-speech label defined as in project perseus: v=verb, g=particle, ...

short
long

etym
cog
mnemonic_cog -- a single English cognate that is helpful as a mnemonic; to be shown in glossaries
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

def Gloss.all_lemmas(db,file_glob:nil,prefer_perseus:false)
  if file_glob.nil? then file_glob=db.path+"/*" end
  lemmas = []
  Dir.glob(file_glob).sort.each { |filename|
    next if (filename=~/~/ || filename=~/README/ )
    filename=~/([[:alpha:]]+)$/
    key = $1
    err,message = Gloss.validate(db,key)
    if err then print "error in file #{key}\n  ",message,"\n" end
    # In the following, we don't need to do error checking because any errors would have been caught by Gloss.validate().
    path = db.key_to_path(key)
    json,err = slurp_file_with_detailed_error_reporting(path)
    x = JSON.parse(json)
    if x.kind_of?(Array) then a=x else a=[x] end
    a.each { |x|
      if prefer_perseus && x.has_key?('perseus') then lemmas.push(x['perseus']); next end
      lemmas.push(x['word']) if x['word']!=''
    }
  }
  return alpha_sort(lemmas)
end

def Gloss.get(db,word,prefer_length:1,if_texify_quotes:true,use_index:nil)
  # The input db is a GlossDB object.
  # Input word is normally not lemmatized, which in fact makes for less ambiguity.
  # When the same lemma string has more than one meaning, e.g., μήν=month, indeed, I don't call that an ambiguity at all.
  # When there is going to be an ambiguity and the caller knows it, they can set use_index; but don't use this for different senses of same lemma string.
  # The input word can be accented or unaccented. Accentuation will be used only for disambiguation, which is seldom necessary.
  # Giving the inflected form could in theory disambiguate certain cases where there are two lemmas spelled the same, but
  # I haven't implemented anything like that yet. If the word has a Homeric form that differs from the standard Perseus
  # form, then the gloss that is returned will have both a 'word' field and a 'perseus' field. See Gloss.perseus_to_homeric().
  # Return value looks like the following.
  # {  "word"=> "ἔθηκε",  "gloss"=> "put, put in a state" }
  entries_found = db.search(word)
  if entries_found.length>0 then
    e = entries_found[0][1]
  else
    return nil
  end
  ambiguous = false
  if entries_found.length>=2 then
    0.upto(entries_found.length-1) { |i| 0.upto(entries_found.length-1) { |j| 
      next if i==j
      next if entries_found[i][0]!=entries_found[j][0] # no problem, we'll prefer the one tagged with perseus
      next if entries_found[i][1]==entries_found[j][1] # This is a comparison of hashes for equality, not just a check if they're the same ref.
      ambiguous =true
    }}
  end
  if ambiguous && !use_index.nil? then
    ambiguous = false
    e=entries_found[use_index][1]
  end
  if ambiguous && entries_found.length==2 then
    # Resolve simple 2-way ambiguities like this one for κῆρ:
    #     [["word", {"word"=>"κῆρ", "medium"=>"heart"}], ["word", {"word"=>"κήρ", "short"=>"doom", "medium"=>"doom, death, fate"}]]
    w0,w1 = entries_found[0][1]['word'],entries_found[1][1]['word']
    if w0!=w1 && w1==word then e=entries_found[1][1]; ambiguous=false end
    if w0!=w1 && w0==word then ambiguous=false end
  end
  if ambiguous && entries_found.length>=2 then
    # Use a point system to try to resolve more difficult ambiguities. This gets activated for δαίς/δάϊς/δάις.
    # Higher scores are worse matches.
    entries_found = entries_found.sort_by { |x| Gloss.dissimilarity_of_lemmas(word,x[1]['word']) }
    pts = [0,0]
    0.upto(1) { |j|
      x = entries_found[j]
      pts[j] = 2*Gloss.dissimilarity_of_lemmas(word,x[1]['word'])
      if db.prefer_tag!=db.lemma_tag && x[0]==db.lemma_tag then pts[j] += 1 end
    }
    if pts[0]<pts[1] || entries_found[0][1]['medium']==entries_found[1][1]['medium'] then ambiguous=false; e=entries_found[0][1] end
    # $stderr.print "WARNING: Ambiguity of #{word} resolved in favor of #{entries_found[0][1]['word']}: #{entries_found[0][1]['medium']} over #{entries_found[1][1]['word']}: #{entries_found[1][1]['medium']}\n"
  end
  if ambiguous then
    $stderr.print "********* WARNING: ambiguous glosses found for #{word}: #{entries_found}\n"
  end
  # {  "word": "ἔθηκε",  "medium": "put, put in a state" }
  e['gloss']=e['medium']
  if prefer_length==0 && e.has_key?('short') then e['gloss']=e['short'] end
  if prefer_length==2 && e.has_key?('long') then e['gloss']=e['long'] end
  #debug = (word=='συνίημι' || word=='ξυνίημι')
  #if debug then $stderr.print "................ word=#{word}, e=#{e}\n" end
  e = Gloss.texify_quotes_in_entry(e,if_texify_quotes)
  return e
end

def Gloss.texify_quotes_in_entry(e,if_texify_quotes)
  # modifies it in place but also returns a reference to it
  if if_texify_quotes then
    ['gloss','short','medium','long','notes'].each { |key|
      e[key] = texify_quotes(e[key]) if e.has_key?(key)
    }
  end
  return e
end

def Gloss.dissimilarity_of_lemmas(a,b)
  if a==b then return 0 end
  if Gloss.standardize_diaresis(a)==Gloss.standardize_diaresis(b) then return 1 end
  if remove_accents(a)==remove_accents(b) then return 2 end
  return 999
end

def Gloss.standardize_diaresis(s)
  return s.gsub(/άϊ/,'άι').gsub(/έϊ/,'έι')
end

def Gloss.validate(db,key)
  # Returns [err,message].
  if key!=remove_accents(key).downcase then return [true,"filename #{key} contains accents or uppercase, should be #{remove_accents(key).downcase}"] end
  path = db.key_to_path(key)
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
  allowed_keys = ['word','short','medium','long','etym','cog','mnemonic_cog','syn','notes','pos','gender','genitive','princ','proper_noun','logdiff','mnem','vowel_length','aorist_difficult_to_recognize','perseus']
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
      if remove_accents(macronized)=~/(([^αιυ])_)/ then return [true,"macronized form #{macronized} contains #{$1}, but #{$2} isn't a doubtful vowel"] end
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

def Gloss.macronized_to_underbar_style(s)
  x = s.gsub(/([ᾱῑῡ])/) { "#{remove_macrons_and_breves($1)}_" }
  return remove_macrons_and_breves(x)
end

end

class GlossDB
  # An instance of this class encapsulates information about where to obtain glosses for a particular language and dialect.
  # It's cleaner to call from_genos() rather than using this initializer directly.
  # FIXME: Some installation-specific stuff is hardcoded in from_genos() (but at least it's in one place).
  def initialize(path,lemma_tag,prefer_tag)
    # If path is "glosses", then each gloss is in a file in ./glosses.
    # In my initial setup for Homer, each gloss file has a mandatory 'word' tag, which is the Homeric form, and
    # an optional 'perseus' tag, which is the Attic lemma used by Project Perseus. If we prefer the Homeric
    # form, then we call this initializer with lemma_tag='perseus' and prefer_tag='word'. If we prefer
    # the attic form, then we set lemma_tag='perseus' and prefer_tag='perseus'.
    @path = path
    @lemma_tag = lemma_tag
    @prefer_tag = prefer_tag
  end

  attr_reader :prefer_tag,:lemma_tag,:path

  def GlossDB.from_genos(genos)
    # If it's Greek, the period should be set.
    if genos.greek then
      if genos.period==genos.period_name_to_number("epic") then return GlossDB.new("glosses","perseus","word") end
      if genos.period==genos.period_name_to_number("attic") then return GlossDB.new("glosses","perseus","perseus") end
    end
    if genos.latin then
      return GlossDB.new("glosses/_latin","perseus","perseus")
    end
    raise "unsupported genos: #{genos}"
  end

  def get_from_file(word)
    key = word_to_key(word)
    x = get_from_file_helper(key)
    return x
  end

  def get_from_file_helper(key)
    path = key_to_path(key)
    if FileTest.exist?(path) then return json_from_file_or_die(path) else return nil end
  end

  def key_to_path(key)
    return "#{@path}/#{key}"
  end

  def word_to_key(s)
    return remove_accents(s).downcase.sub(/᾽/,'')
  end

  def search(word)
    # Returns a list whose elements are of the form [tag,entry]. For example, if we're looking up a word in Homer,
    # it could have a 'word' field that is the Homeric form, and a different 'perseus' field that is Project Perseus's preferred
    # (Attic) lemma.
    x = self.get_from_file(word)
    if x.nil? then return [] end
    if !(x.kind_of?(Array)) then x=[x] end
    # We can have words like δαίς/δάϊς that have the same key and therefore live in
    # the same file. Even if that's not the case, convert x to an array for convenience.
    # Also handle words where there's a perseus spelling that differs from our preferred Homeric spelling.
    entries_found = []
    ["word",@lemma_tag,@prefer_tag].uniq.each { |tag|
      x.each { |entry|
        if !entry[tag].nil? && alpha_compare(entry[tag],word)==0 then
          entries_found.push([tag,entry])
        end
      }
    }
    return entries_found
  end

end
