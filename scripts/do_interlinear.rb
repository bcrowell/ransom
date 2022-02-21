#!/bin/ruby

# usage:
#   interlinear.rb iliad 1.37
#     ...does book 1, line 37 of the iliad
#   interlinear.rb iliad 1.37-39
#     ... multiple lines

raise "two args required" unless ARGV.length==2
text = ARGV[0]
lines = ARGV[1]
lines=~/(\d+)\.(.*)/
book = $1.to_i
raise "illegal book number: #{book}" unless book>=1 && book<=24
line_range = $2
if line_range=~/(\d+)\-(\d+)/ then
  line1,line2 = [$1.to_i,$2.to_i]
else
  line1 = line_range.to_i
  line2 = line1
end
$stderr.print "#{text} #{book}.#{line1}-#{line2}\n"
raise "illegal line numbers" unless line1>=1 && line2>=line1

require 'json'

require_relative "../lib/file_util"
require_relative "../lib/string_util"
require_relative "../lib/debug"
require_relative "../lib/multistring"
require_relative "../lib/treebank"
require_relative "../lib/epos"
require_relative "../lib/genos"
require_relative "../lib/wiktionary"
require_relative "../lib/vlist"
require_relative "../lib/frequency"
require_relative "../lib/vocab_page"
require_relative "../lib/format_gloss"
require_relative "../lib/bilingual"
require_relative "../lib/illustrations"
require_relative "../lib/notes"
require_relative "../lib/latex"
require_relative "../lib/gloss"
require_relative "../lib/clown"
require_relative "../lib/tagzig"
require_relative "../lib/word"
require_relative "../lib/interlinear"
require_relative "../greek/nouns"
require_relative "../greek/verbs"
require_relative "../greek/adjectives"
require_relative "../greek/lemma_util"
require_relative "../greek/writing"

author = "homer"
treebank = TreeBank.new(author)
genos = GreekGenos.new('epic',is_verse:true)
db = GlossDB.from_genos(genos)


line1.upto(line2) { |line|
  words = treebank.get_line(genos,db,text,book,line)
  print sprintf("%d.%3d",book,line)," ",Interlinear.assemble(words),"\n"
}


