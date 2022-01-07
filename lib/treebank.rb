# This class provides a wrapper for the Project Perseus treebank data.
# Could also be expanded to give convenient access to the line-by-line data in the .csv file.

class TreeBank
  def initialize(corpus)
    if corpus!='homer' then $stderr.print "warning: unrecognized corpus #{corpus}\n" end
    data_dir = "#{Dir.home}/Documents/programming/ransom/lemmas"
    @lemmas_file = "#{data_dir}/#{corpus}_lemmas.json"
    @lemmas = json_from_file_or_die(@lemmas_file)
  end
  attr_reader :lemmas,:lemmas_file

  def word_to_lemma_entry(word)
    if @lemmas.has_key?(word) then return @lemmas[word] end
    if @lemmas.has_key?(word.downcase) then return @lemmas[word.downcase] end
    return nil
  end

end
