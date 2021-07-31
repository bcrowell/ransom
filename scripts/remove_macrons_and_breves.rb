#!/bin/ruby

load '../lib/string_util.rb'

$stdin.each_line { |line|
  puts remove_macrons_and_breves(line)
}
