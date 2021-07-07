require 'json'
require_relative "lib/file_util"
require_relative "lib/string_util"

def vocab(words)
  # Input is a string consisting of three sections, each separated by a double newline.
  # These sections are common, uncommon, and rare.
  # Within each section, words are separated by whitespace.
  a = words.split(/\n\n/)
  if a.length>3 then die("more than 3 sections in input to vocab") end
  while a.length<3 do a.push([]) end
  common,uncommon,rare = a.map { |x| sort_vocab(x)}
  print "\\begin{vocabpage}\n"
  vocab_helper('common',common)
  vocab_helper('uncommon',uncommon+rare)
  print "\\end{vocabpage}\n"
  return [common,uncommon,rare]
end

def vocab_helper(commonness,files)
  if commonness=='common' then tag='vocabcommon' else tag='vocabuncommon' end
  print "\\begin{#{tag}}\n"
  files.each { |file| vocab1(file) }
  print "\\end{#{tag}}\n"
end

def sort_vocab(s)
  return s.split(/\s+/).select { |x| x=~/[[:alpha:]]/ }.sort
end

def vocab1(file)
  path = "glosses/#{file}"
  if FileTest.exist?(path) then
    entry = json_from_file_or_die(path)
    # {  "word": "ἔθηκε",  "gloss": "put, put in a state",  "lexical": "τίθημι" }
    word,gloss,lexical = entry['word'],entry['gloss'],entry['lexical']
    if entry.has_key?('lexical') then
      s = "\\vocabinflection{#{word}}{#{lexical}}{#{gloss}}"
    else
      s = "\\vocab{#{word}}{#{gloss}}"
    end
    print "#{s}\\\\"
  end
end

def foreign(t)
  foreign_helper(t,false)
end

def ransom(t,v)
  common,uncommon,rare = v
  foreign_helper(t,true,gloss_these:rare)
end

def foreign_helper(t,ransom,gloss_these:[])
  # If gloss_these isn't empty, then we assume it contains a list of rare lemmatized forms.
  print "\\begin{foreignpage}\n"
  if ransom then print "\\begin{graytext}\n" end
  lines = t.split(/\s*\n\s*/).select { |line| line=~/[[:alpha:]]/ }
  gg = gloss_these.map { |x| remove_accents(x)}
  0.upto(lines.length-1) { |i|
    w = words(lines[i])
    ww = w.map { |x| remove_accents(Lemmatize.lemmatize(x)[0]).downcase} # if the lemmatizer fails, it just returns the original word
    gg.each { |x|
      if ww.include?(x) then # lemmatized version of sentence includes this rare lemma that we were asked to gloss
        j = ww.index(x)
        word = w[j] # original inflected form
        code =                 %q(\makebox[0pt]{__})
        code.sub!(/__/,        %q(\parbox[b]{WIDTH}{CONTENTS})  ) # https://en.wikibooks.org/wiki/LaTeX/Boxes
        code.sub!(/WIDTH/,     "0pt"  )
        code.sub!(/CONTENTS/,  %q(\begin{blacktext}__\end{blacktext})  )
        code.sub!(/__/,        x   )
        lines[i] = lines[i].sub(/#{word}/) {"#{code}#{word}"}
      end
    }
  }
  print lines.join("\\\\\n"),"\n\n"
  if ransom then print "\\end{graytext}\n" end
  print "\\end{foreignpage}\n"
end

def words(s)
  # fixme: handle apostrophes
  return s.scan(/[[:alpha:]]+/)
end

class Patch_names
  @@patches = {"Latona"=>"Leto","Ulysses"=>"Odysseus","Jove"=>"Zeus","Atrides"=>"Atreides"}
  def Patch_names.patch(text)
    @@patches.each { |k,v|
      text = text.gsub(/#{k}/,v)
    }
    return text
  end
end

class Lemmatize
  @@lemmas = json_from_file_or_die("lemmas/homer_lemmas.json")
  # typical entry when there's no ambiguity:
  #   "βέβασαν": [    "βαίνω",    "1",    "v3plia---",    1,    false,    null  ],
  def Lemmatize.lemmatize(word)
    # returns [lemma,success]
    if @@lemmas.has_key?(word) then return Lemmatize.lemma_helper(word) end
    if @@lemmas.has_key?(capitalize(word)) then return Lemmatize.lemma_helper(capitalize(word)) end
    return [word,false]
  end

  def Lemmatize.lemma_helper(word)
    lemma,lemma_number,pos,count,if_ambiguous,ambig = @@lemmas[word]
    return [lemma,true]
  end
end

def capitalize(x)
  return x.sub(/^(.)/) {$1.upcase}
end


def die(message)
  #  $stderr.print message,"\n"
  raise message # gives a stack trace
  exit(-1)
end

