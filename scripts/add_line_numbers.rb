#!/bin/ruby

n = 0
$stdin.each_line { |line|
  if line=~/\A\s*\Z/ then print "\n"; next end
  n += 1
  line = line.sub(/\s+$/,'')
  if n%5==0 then line = line+"    #{n}" end
  print line,"\n"
}
