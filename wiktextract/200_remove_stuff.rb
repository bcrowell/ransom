require 'json'

def main()

kill_tags = "lang wikipedia topics sounds categories forms inflection inflection_templates etymology_text lang_code etymology_templates head_templates".split(/\s+/)
kill_senses_subtags = "tags id categories examples related".split(/\s+/)
$stdin.each_line { |line|
  x = JSON.parse(line)
  kill_tags.each { |tag|
    x.delete(tag)
  }
  if x.has_key?("senses") then
    # Latin wiktionary has a separate entry for every inflected form. Get rid of these, only keep lemmas.
    # {"pos":"noun","head_templates":[{"name":"la-noun-form","args":{"1":"ephēbe","g":"m"},"expansion":"ephēbe m"}],"word":"ephebe","senses":[{"raw_glosses":["vocative singular of ephēbus"],"glosses":["vocative singular of ephēbus"],"form_of":[{"word":"ephēbus"}]}]}
    any_senses_are_lemmas = false
    x["senses"].each { |sense|
      any_senses_are_lemmas = any_senses_are_lemmas || !(sense.has_key?('form_of'))
    }
    next unless any_senses_are_lemmas
  end
  if x['word']=='ephebe' then raise "ephebe not culled, x=#{x}" end
  if x.has_key?("senses") then
    x["senses"].each { |sense|
      kill_senses_subtags.each { |subtag|
        sense.delete(subtag)
      }
    }
  end
  #line = JSON.pretty_generate(x)
  line = JSON.generate(x)
  puts line+"\n"
}

end # main

main
