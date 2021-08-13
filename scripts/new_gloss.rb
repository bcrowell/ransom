#!/bin/ruby
# coding: utf-8

# usage:
#   Run the file from inside the glosses directory.
#   new_gloss.rb εξουσια
#   new_gloss.rb ἐξουσία

require 'json'
require 'set'

require_relative "../lib/gloss"
require_relative "../lib/file_util"
require_relative "../lib/string_util"

w = ARGV[0]

key = remove_accents(w)

if FileTest.exist?(key) then
  print "File #{key} exists.\n"
  print `cat #{key}`
  exit
end

print "File #{key} does not exist.\n"

print `grep #{w} ../lemmas/homer_lemmas.json | head -3`
