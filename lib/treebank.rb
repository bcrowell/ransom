# This class provides a wrapper for the Project Perseus treebank data.
# Currently this is mainly just a way of avoiding having the path to the json file hardcoded in lots of scripts.
# Could also be expanded to give convenient access to the line-by-line data in the .csv file.

class TreeBank
  def initialize(corpus)
    if corpus!='homer' then $stderr.print "warning: unrecognized corpus #{corpus}\n" end
    data_dir = "#{Dir.home}/Documents/programming/ransom/lemmas"
    @lemmas_file = "#{data_dir}/#{corpus}_lemmas.json"
    @lemmas = json_from_file_or_die(@lemmas_file)
  end
  attr_reader :lemmas,:lemmas_file
end
