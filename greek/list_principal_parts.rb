#!/bin/ruby
# coding: utf-8

require 'json'
require 'set'

require_relative "../lib/gloss"
require_relative "../lib/file_util"
require_relative "../lib/string_util"

Gloss.all_lemmas().each { |lemma|
  g = Gloss.get(lemma)
  # {"word"=>"χαίρω", "princ"=>"χαιρήσω,ἐχηράμην", "medium"=>"rejoice", "long"=>"to rejoice; to enjoy (+dat/part)", "cog"=>"χάρμα", "notes"=>"The future means to make glad. Other tenses mean to be made glad, in both active and mp. In Homer, forms with reduplication such as κεχάροντο are about as common as those without.", "syn"=>"γηθέω", "gloss"=>"rejoice", "file_under"=>"χαίρω"}
  next if g.nil?
  next unless g.has_key?('princ')
  forms = [g['word']]
  forms = forms + g['princ'].split(/[,\/]/)
  english = g['medium']
  print forms.join(' '),"\n  #{english}\n"
  if g.has_key?('long') then print "  ",g['long'],"\n" end
}
print "\n"

