=begin
This script can create output in both .tex and .txt formats.
There are two separate makefile targets for these purposes.
=end


require "json"
require "set"
require "./lib/string_util.rb"
require "./lib/file_util.rb"

format = ENV['FORMAT']
if format.nil? then $stderr.print "FORMAT environment variable not set\n"; exit(-1) end
if !(['tex','txt'].include?(format)) then $stderr.print "FORMAT environment variable set to illegal value #{format}\n"; exit(-1) end

in_file = "core/homer.json"
glosses = json_from_file_or_die(in_file)

if format=='tex' then
  print "% This file is generated automatically by doing a make core_tex. Don't edit it by hand.\n"
end
alpha_sort(glosses.keys).each { |lemma|
  if format=='tex' then
    print "\\vocab{#{lemma}}{#{glosses[lemma]}}\\\\\n"
  else
    print "#{lemma} #{glosses[lemma]}\n"
  end
}
