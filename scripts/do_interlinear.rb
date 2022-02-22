#!/bin/ruby

# usage:
#   do_interlinear.rb txt iliad 1.37
#     ...does book 1, line 37 of the iliad
#   do_interlinear.rb tex iliad 1.37-39
#     ... multiple lines, latex output

raise "three args required" unless ARGV.length==3
format = ARGV[0]
text = ARGV[1]
lines = ARGV[2]
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

all_lines = []

line1.upto(line2) { |line|
  words = treebank.get_line(genos,db,text,book,line)
  all_lines.push(Interlinear.assemble(genos,words,left_margin:[4,line.to_s],format:format))
}

if format=='txt' then
  result = all_lines.join("\n")
end

if format=='tex' then
  result = all_lines.join("\n\n\\vspace{4mm}\n\n") # FIXME -- formatting shouldn't be hardcoded here
  top = %q{
% https://tex.stackexchange.com/a/37251/6853
\RequirePackage{fontspec}
\defaultfontfeatures{Ligatures=TeX,Scale=MatchLowercase}
\setmainfont{GFS Didot} % is said to be a good Latin font to match with Porson-style fonts; if changing this, change it on the following line as well
\newfontfamily\latinfont{GFS Didot}
\newfontfamily\greekfont{GFS Porson}
%  Also tried GFS Olga, which is also a Porson-style font; has a higher x-height than GFS Porson, and therefore matches better with Latin fonts.
\newenvironment{greek}{\greekfont}{}
\newenvironment{latin}{\latinfont}{}
% Both Olga and Porson lack real bold:
\newenvironment{boldgreek}{\fontspec{GFS Olga}[FakeBold=0.1]}{} % discontinuous behavior: 0.0 gives no bolding, 0.0001 gives quite a bit
  }
  result="\\documentclass{article}\n#{top}\\begin{document}\\latinfont\n\n#{result}\n\\end{document}\n"
end

print result


