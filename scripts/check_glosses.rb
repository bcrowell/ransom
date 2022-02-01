#!/bin/ruby

require 'json'
require 'set'

require_relative "../lib/gloss"
require_relative "../lib/genos"
require_relative "../lib/file_util"
require_relative "../lib/string_util"

count = 0
count_errs = 0
db = GlossDB.from_genos(GreekGenos.new('epic'))
Dir.glob(['glosses/*','glosses/_latin/*']).each { |filename|
  next if filename=~/~/
  next if filename=~/README/
  filename=~/(([[:alpha:]]|_)+)$/
  key = $1
  next if key=~/^_/
  count += 1
  err,message = Gloss.validate(db,key)
  if err then
    print "error in file #{key}\n  ",message,"\n"
    count_errs += 1
  end
}
if count_errs>0 then $stderr.print "Failing after #{count_errs} errors.\n"; exit(-1) end
print "checked #{count} keys\n"
