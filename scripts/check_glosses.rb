#!/bin/ruby

require 'json'
require 'set'

require_relative "../lib/gloss"
require_relative "../lib/file_util"
require_relative "../lib/string_util"

count = 0
count_errs = 0
Dir.glob( 'glosses/*').each { |filename|
  next if filename=~/~/
  next if filename=~/README/
  filename=~/([[:alpha:]]+)$/
  key = $1
  count += 1
  err,message = Gloss.validate(key)
  if err then
    print "error in file #{key}\n  ",message,"\n"
    count_errs += 1
  end
}
if count_errs>0 then $stderr.print "Failing after #{count_errs} errors.\n"; exit(-1) end
print "checked #{count} keys\n"
