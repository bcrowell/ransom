#!/bin/ruby

lib_dir = "lib"
require_relative "../lib/file_util"
require_relative "../lib/string_util"
require 'json'

# https://github.com/cltk/greek_treebank_perseus
fields = ["pos","person","number","tense","mood","voice","gender","case","degree"]

# usage:
#   report_inflections.rb καλεω person=3 mood=i voice=a tense=p,i,a number=s,p
# The rightmost key changes most rapidly, as expected intuitively from the way we write decimal notation.

def main
  lemma = ARGV.shift
  selector_strings = ARGV
  print "lemma=#{lemma} selectors=#{selector_strings}\n"
  keys = []
  values = []
  selector_strings.each { |s|
    key,val = s.split(/=/)
    keys.push(key)
    values.push(val.split(/,/))
  }
  nvals = values.map { |x| x.length}
  n = nvals.length
  total_odometer_values = nvals.inject(1, :*)
  print "keys=#{keys}\nvalues=#{values}\nnvals=#{nvals}\ntotal_odometer_values=#{total_odometer_values}\n"
  0.upto(total_odometer_values-1) { |o|
    odo = []
    most_significant_part = o
    (n-1).downto(0) { |i|
      remainder = most_significant_part % nvals[i]
      most_significant_part = most_significant_part / nvals[i]
      odo = [remainder] + odo
    }
    print "odo=#{odo}\n"
  }
end

main
