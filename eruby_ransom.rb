  require 'json'
  require_relative "lib/file_util"
  require_relative "lib/string_util"

  def vocab(commonness,files)
    if commonness=='common' then tag='vocabcommon' else tag='vocabuncommon' end
    print "\\begin{#{tag}}\n"
    files.split(/\s+/).select { |x| x=~/[[:alpha:]]/ }.sort.each { |file| vocab1(file) }
    print "\\end{#{tag}}\n"
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
    print "\\begin{foreignpage}\n"
    lines = t.split(/\s*\n\s*/).select { |line| line=~/[[:alpha:]]/ }
    print lines.join("\\\\\n"),"\n\n"
    print "\\end{foreignpage}\n"
  end
