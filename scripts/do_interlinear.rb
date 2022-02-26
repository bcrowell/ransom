#!/bin/ruby
# coding: utf-8

# usage:
#   do_interlinear.rb txt iliad 1.37
#     ...does book 1, line 37 of the iliad
#   do_interlinear.rb tex iliad 1.37-39
#     ... multiple lines, latex output

raise "usage: do_interlinear.rb txt iliad 1.37-39" unless ARGV.length==3
format = ARGV[0]
text = ARGV[1]
lines = ARGV[2]

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

linerange = LineRange.new("#{text} #{lines}")
text,book,line1,line2 = linerange.to_a
$stderr.print "#{linerange}\n"

author = "homer"
treebank = TreeBank.new(author)
genos = GreekGenos.new('epic',is_verse:true)
db = GlossDB.from_genos(genos)

# Get an Epos object that includes the actual text, with punctuation; currently, this is a different edition than the one used for the treebank.
if text=='iliad' then
  text = Epos.new("text/ιλιας","greek",true,genos:genos)
else
  raise "no text available for #{text}"
end

style = InterlinearStyle.new(format:format,left_margin:[4,'__LINE__'])
result =  Interlinear.assemble_lines_from_treebank(genos,db,treebank,text,linerange,style:style)

if format=='tex' then
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

