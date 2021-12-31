require "json"
require "set"
require "./lib/string_util.rb"
require "./lib/file_util.rb"

in_file = "core/homer.json"
glosses = json_from_file_or_die(in_file)

print "% This file is generated automatically by doing a make core_tex. Don't edit it by hand.\n"
alpha_sort(glosses.keys).each { |lemma|
  print "\\vocab{#{lemma}}{#{glosses[lemma]}}\\\\\n"
}
