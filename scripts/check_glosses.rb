#!/bin/ruby

require 'json'
require 'set'

require_relative "../lib/gloss"
require_relative "../lib/genos"
require_relative "../lib/file_util"
require_relative "../lib/string_util"

count = 0
count_errs = 0

greek_db = GlossDB.from_genos(GreekGenos.new('epic'))
latin_db = GlossDB.from_genos(Genos.new('la'))
[['glosses/*',greek_db],['glosses/_latin/*',latin_db]].each { |x|
  glob,db = x
  Dir.glob(glob).each { |filename|
    next if filename=~/~/
    next if filename=~/README/
    filename=~/(([[:alpha:]]|_)+)$/
    key = $1
    next if key=~/^_/
    count += 1
    if key.nil? then print "error, file #{filename} results in a nil key\n"; next end
    err,message = Gloss.validate(db,key)
    if err then
      print "error in file #{key}\n  ",message,"\n"
      count_errs += 1
    end
  }
}
if count_errs>0 then $stderr.print "Failing after #{count_errs} errors.\n"; exit(-1) end
print "checked #{count} keys\n"
