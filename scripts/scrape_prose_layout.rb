#!/bin/ruby

=begin

sample input:

406c55e1844c758e95e2b0e52d665581;;;Forte;;;26.22481pt;7.61436pt;0.14365pt;{"offset":0,"length":6,"para":0,"file":0};
8ba3e6c70338364e4861023461fcc384;;;dominus;;;43.29912pt;7.76909pt;0.14365pt;{"offset":6,"length":8,"para":0,"file":0};
...
406c55e1844c758e95e2b0e52d665581;1;;Forte;3410160;36724906;;;;{}
8ba3e6c70338364e4861023461fcc384;1;;dominus;5446372;36724906;;;;{}
...

=end

require "json"
require "./lib/file_util.rb"

prose_file = ARGV[0]
input_files = ARGV[1..-1]

$stderr.print "input files: #{prose_file}, #{input_files}\n"

texts = []
input_files.each { |filename|
  texts.push(slurp_file(filename))
}

data = [] # array of hashes, one per word
word_index = {} # key is hash, value is index into data
IO.foreach(prose_file) { |line| 
  # some code here is duplicated from eruby_ransom.rb, WhereAt class
  next if line=~/^\?/
  line.sub!(/\s+$/,'') # trim trailing whitespace, such as a newline
  a = line.split(/;/,-1)
  line_hash,page,line_garbage,word,x,y,width,height,depth = a
  # line_garbage is always empty, need to infer it myself
  word.gsub!(/__SEMICOLON__/,';')
  if !(line=~/([^;]*;){9}(.*);$/) then raise "bad line, not enough fields: #{line}" end
  extra = JSON.parse($2)
  print "#{a}, #{extra}\n"
  exit(-1)
}


