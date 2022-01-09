#!/bin/ruby

load 'lib/string_util.rb'
load 'lib/file_util.rb'
load 'lib/epos.rb'

s = $stdin.gets(nil) # nil means read whole file
if s.nil? then s='' end
s.gsub!(/\r\n/,"\n")
result = []
s.split(/\n\n/).each { |paragraph|
  #result.push(paragraph)
  p2 = Epos.strip_pg_footnotes(paragraph+"\n")
  if false then
    print "============================================================================\n"
    print paragraph,"\n"
    print "--------------------------------\n"
    print p2,"\n"
  end
  result.push(p2)
}
x = result.join("\n\n")
x.gsub!(/\n{2,}/,"\n\n")
print x,"\n"

