#!/bin/ruby

load 'lib/string_util.rb'

$stdin.each_line { |line|
  puts clean_up_greek(line,thorough:true)
}
