=begin
This script can create output in both .tex and .txt formats.
There are two separate makefile targets for these purposes.
=end


require "json"
require "set"
require "./lib/string_util.rb"
require "./lib/file_util.rb"
require "./lib/clown.rb"
require "./lib/format_gloss.rb"
require "./lib/latex.rb"
require "./lib/bilingual.rb"
require "./lib/genos.rb"
require "./lib/epos.rb"

format = ENV['FORMAT']
if format.nil? then $stderr.print "FORMAT environment variable not set\n"; exit(-1) end
if !(['tex','txt'].include?(format)) then $stderr.print "FORMAT environment variable set to illegal value #{format}\n"; exit(-1) end

in_file = "core/homer.json"
glosses = json_from_file_or_die(in_file)

bilingual = BareBilingual.new(Genos.new('grc'),Genos.new('en'))

if format=='tex' then
  print "% This file is generated automatically by doing a make core_tex. Don't edit it by hand.\n"
end
alpha_sort(glosses.keys).each { |lemma|
  g = glosses[lemma][0]
  mnemonic_cog = glosses[lemma][1] # is usually nil
  if format=='tex' then
    items = {'b'=>lemma,'g'=>g}
    if !mnemonic_cog.nil? then items['c']=mnemonic_cog end
    print FormatGloss.assemble(bilingual,items)+"\\par\n"
  else
    print "#{lemma} #{g} #{mnemonic_cog}\n"
  end
}
