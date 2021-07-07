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
  entry = get_gloss(file)
  # {  "word": "ἔθηκε",  "gloss": "put, put in a state",  "lexical": "τίθημι" }
  return if entry.nil?
  word,gloss,lexical = entry['word'],entry['gloss'],entry['lexical']
  if entry.has_key?('lexical') then
    s = "\\vocabinflection{#{word}}{#{lexical}}{#{gloss}}"
  else
    s = "\\vocab{#{word}}{#{gloss}}"
  end
  print "#{s}\\\\"
end

def get_gloss(key)
  path = "glosses/#{key}"
  if FileTest.exist?(path) then
    return json_from_file_or_die(path)
    # {  "word": "ἔθηκε",  "gloss": "put, put in a state",  "lexical": "τίθημι" }
  else
    return nil
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
  if gloss_these.length>0 then
    gg = gloss_these.map { |x| remove_accents(x)}
    0.upto(lines.length-1) { |i|
      w = words(lines[i])
      ww = w.map { |x| remove_accents(Lemmatize.lemmatize(x)[0]).downcase} # if the lemmatizer fails, it just returns the original word
      gg.each { |x|
        if ww.include?(x) then # lemmatized version of sentence includes this rare lemma that we were asked to gloss
          j = ww.index(x)
          word = w[j] # original inflected form
          key = to_key(x)
          entry = get_gloss(key)
          if !(entry.nil?) then gloss=entry['gloss'] else gloss="??" end
          code = nil
          if Options.if_write_pos then
            code = %q{
              \savebox{\myboxregister}{WORD}%
              \smash{\pdfsavepos\usebox{\myboxregister}}%
              \write\posoutputfile{\thepage,LINE,KEY,\the\pdflastxpos,\the\pdflastypos,\the\wd\myboxregister,\the\ht\myboxregister,\the\dp\myboxregister}%
            }
            code.gsub!(/WORD/,word)
            code.gsub!(/LINE/,i.to_s)
            code.gsub!(/KEY/,key)
            code = "#{code}#{word}"
          end
          if Options.if_render_glosses then
            code =                 %q(\smash{\makebox[0pt]{__}})
            code.sub!(/__/,        %q(\parbox[b]{WIDTH}{CONTENTS})  ) # https://en.wikibooks.org/wiki/LaTeX/Boxes
            code.sub!(/WIDTH/,     "0pt"  )
            code.sub!(/CONTENTS/,  %q(\begin{blacktext}\begin{latin}__\end{latin}\end{blacktext})  )
            code.sub!(/__/,        gloss  )
            code = "#{code}#{word}"
          end
          if !(code.nil?) then lines[i] = lines[i].sub(/#{word}/,code) end
        end
      }
    }
  end
  print lines.join("\\\\\n"),"\n\n"
  if ransom then print "\\end{graytext}\n" end
  print "\\end{foreignpage}\n"
end

def to_key(word)
  return remove_accents(word).downcase
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

class Options
  if ARGV.length<1 then die("no command-line argument supplied") end
  @@the_options = JSON.parse(ARGV[0])
  def Options.if_write_pos() return Options.has_flag('write_pos') end
  def Options.if_render_glosses() return Options.has_flag('render_glosses') end
  def Options.if_clean() return Options.has_flag('clean') end
  def Options.pos_file() return @@the_options['pos_file'] end
  def Options.has_flag(flag)
    return @@the_options.has_key?(flag) && @@the_options[flag]
  end
end

class Init
  # Code that gets run when the eruby script starts, but after code that's higher up in the file.
  require 'fileutils'
  if Options.if_clean then FileUtils.rm_f(Options.pos_file) end # Currently I open the file to write, not append, so this isn't necessary.
  if Options.if_write_pos then
    print %Q{
      \\newsavebox\\myboxregister
      \\newwrite\\posoutputfile
      \\openout\\posoutputfile=#{Options.pos_file}
    }
  end
end

END {
  if Options.if_write_pos then
    print %q{
      \closeout\posoutputfile
    }
  end
  print %q{
    \end{document}
  }
}

def capitalize(x)
  return x.sub(/^(.)/) {$1.upcase}
end


def die(message)
  #  $stderr.print message,"\n"
  raise message # gives a stack trace
  exit(-1)
end

