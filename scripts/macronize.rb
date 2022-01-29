#!/bin/ruby
# coding: utf-8

require 'json'
lib_dir = "lib"
require_relative "../lib/string_util"
require_relative "../lib/wiktionary"
require_relative "../lib/genos"

=begin

usage:
  macronize.rb χαλινος

=end

def main
  lemma = ARGV[0]
  if lemma.nil? then print "no lemma given\n"; exit(-1) end
  wikt = WiktionaryGlosses.new(Genos.new('grc'))
  found,macronized,err = wikt.macronized(lemma)
  if found then
    print macronized,"\n"
  else
    $stderr.print err,"\n"
    exit(-1)
  end
end


main
