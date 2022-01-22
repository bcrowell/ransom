#!/bin/ruby
# coding: utf-8

# writes the tsv formats that anki and mnemosyne can import
# usage:
#   ./greek/create_flashcards.rb vocab_ch_01.txt Iliad-01 anki >a.tsv
#   ./greek/create_flashcards.rb vocab_ch_01.txt Iliad-01 mnemosyne >a.tsv
# First arg is a file containing a list of lemmas that can be included if appropriate, one word per line.
# For this purpose, you can either use the files like vocab_ch_01.txt that are automatically generated when
# you compile the book, or you can do:
#   ./file_to_lemmas.rb ../text/ιλιας/01 >a.txt
# Second arg is a tag for anki. If doing mnemosyne format, then this arg is ignored, but when
# you import the file into mnemosyne, it lets you give a list of tags.

vocab_list_file = ARGV[0]

tag = ARGV[1]

format = ARGV[2]
if !(format=='anki' || format=='mnemosyne') then $stderr.print "format should be anki or mnemosyne\n"; exit(-1) end

def italicize(format,x)
  if format=='anki' then return x else return "<i>#{x}</i>" end
end

require 'json'
require 'set'

require_relative "../lib/gloss"
require_relative "../lib/file_util"
require_relative "../lib/string_util"
require_relative "../lib/treebank"

db = GlossDB.new("glosses")
all_glossed_lemmas = Gloss.all_lemmas(db).to_set

part_of_speech_code_to_word = {
'n'=>'noun',
'v'=>'verb',
't'=>'participle',
'a'=>'adjective',
'd'=>'adverb',
'l'=>'article',
'g'=>'particle',
'c'=>'conjunction',
'r'=>'preposition',
'p'=>'pronoun',
'm'=>'numeral',
'i'=>'interjection',
'e'=>'exclamation',
'u'=>'punctuation'
}

number_code_to_word = {
's'=>'sing.',
'p'=>'pl.',
'd'=>'dual'
}

case_code_to_word = {
'n'=>'nom.',
'g'=>'gen.',
'd'=>'dat.',
'a'=>'acc.',
'v'=>'voc.',
'l'=>'loc.'
}

tense_code_to_word = {
'p'=>'present',
'i'=>'imperfect',
'r'=>'perfect',
'l'=>'pluperfect',
't'=>'future perfect',
'f'=>'future',
'a'=>'aorist'
}

mood_code_to_word = {
'i'=>'indicative',
's'=>'subjunctive',
'o'=>'optative',
'n'=>'infinitive',
'm'=>'imperative',
'p'=>'participle'
}

voice_code_to_word = {
'a'=>'active',
'p'=>'passive',
'm'=>'middle',
'e'=>'medio-passive'
}

threshold_count = 3 # this form must occur this many times to be included

vocab_list = []
IO.foreach(vocab_list_file) {|line|
  vocab_list.push(line.sub(/\s+/,''))
}

x = Treebank.new('homer').lemmas
cards = {}
x.each { |word,data|
  lemma,glub1,pos,count,if_ambiguous,ambig = data
  if if_ambiguous then l=ambig else l=[[lemma,glub1,pos,count].clone] end
  l.each { |entry|
    lemma,glub,pos,count = entry
    next if count<threshold_count # Don't include very uncommon forms.
    part_of_speech,person,number,tense,mood,voice,gender,the_case,degree = pos[0],pos[1],pos[2],pos[3],pos[4],pos[5],pos[6],pos[7],pos[8]
    part_of_speech_word = part_of_speech_code_to_word[part_of_speech]
    next if lemma=='υνκνοων'  || word=~/᾽/
    next unless vocab_list.include?(lemma) # Don't include very common forms.
    word = to_single_accent(word)
    if !(all_glossed_lemmas.include?(lemma)) then next end
    if lemma=='ἦ' then lemma='ἠμί' end # why do I need this? is it because the homophone is too common to include?
    g = Gloss.get(db,lemma,prefer_length:2)
    if g.nil? then $stderr.print "no gloss found for #{lemma}, #{word}\n"; exit(-1) end
    grammatical_info = part_of_speech_word # default for cases like interjections; in most cases this gets overwritten
    number_info = number_code_to_word[number]
    case_info = case_code_to_word[the_case]
    if person=='-' then person='' end # e.g., for infinitives
    if part_of_speech=~/[nap]/ then # noun, adj, or pronoun
      if part_of_speech=='n' then ppp='' else ppp=part_of_speech_word end
      grammatical_info = "#{ppp} #{gender} #{number_info} #{case_info}"
    end
    if part_of_speech=~/[vt]/ then # verb or participle
      if mood=='i' then mood_info='' else mood_info=mood_code_to_word[mood] end
      if voice=='a' then voice_info='' else voice_info=voice_code_to_word[voice] end
      tense_info = tense_code_to_word[tense]
      if part_of_speech=='v' then # verb
        grammatical_info = "#{tense_info} #{person} #{number_info} #{mood_info} #{voice_info}"
      else # participle
        # passive perfect participle m sing. acc.
        if voice=~/[pe]/ then voice_info='passive' end
        grammatical_info = "#{voice_info} #{tense_info} #{mood_info} #{gender} #{number_info} #{case_info}"
      end
    end
    info = "#{lemma},  #{g['gloss']} <p> #{grammatical_info}"
    other_info_items = []
    ['genitive','princ','cog','etym','syn','notes','mnem','proper_noun'].each { |k|
      next unless g.has_key?(k)
      label = {"genitive"=>"gen.","princ"=>"principal parts","cog"=>"cog.","etym"=>"etym.","syn"=>"syn.","notes"=>"notes","mnem"=>"mnemonic"}[k]
      if label.nil? then label='' end
      if label!='' then
        item = "#{italicize(format,label+":")} #{g[k]}"
      else
        item = g[k]
      end
      if k=='proper_noun' then item='Proper noun.' end
      other_info_items.push(item)
    }
    other_info = other_info_items.join(", ")
    if format=='mnemosyne' then
      tsv_line = "#{word}\t#{info}<p>#{other_info}\n" # mnemosyne; 2 cols=> will not be language card (which I don't want, since I don't want back->front)
    else
      tsv_line = "#{word}\t"#{info}. #{other_info}\tGreek,Homer,#{tag}\n" # anki: front, back, tags
    end
    tsv_line.gsub!(/ +,/,',')
    tsv_line.gsub!(/ +\./,'.')
    tsv_line.gsub!(/\.\./,'.')
    tsv_line.gsub!(/ {2,}/,' ')
    cards[lemma+','+word] = tsv_line
  }
}

k = alpha_sort(cards.keys)
k = k.shuffle # anki and mnemosyne make it a hassle or impossible to shuffle

k.each { |key|
  tsv_line = cards[key]
  print tsv_line
}


