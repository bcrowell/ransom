#!/bin/ruby

load 'lib/string_util.rb'

$stdin.each_line { |line|
  puts remove_accents(line)
}
