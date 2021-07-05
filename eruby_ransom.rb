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
    if entry.has_key?(lexical) then
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
  print "\\begin{foreignpage}\n"
  if ransom then print "\\begin{graytext}\n" end
  lines = t.split(/\s*\n\s*/).select { |line| line=~/[[:alpha:]]/ }
  gg = gloss_these.map { |x| remove_accents(x)}
  0.upto(lines.length-1) { |i|
    w = words(lines[i])
    ww = w.map { |x| remove_accents(x)}
    gg.each { |x|
      if ww.include?(x) then
        j = ww.index(x)
        aaa = w[j].gsub(/[[:alpha:]]/,'*')
        lines[i] = lines[i].sub(/#{w[j]}/,aaa)
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

def die(message)
  #  $stderr.print message,"\n"
  raise message # gives a stack trace
  exit(-1)
end
