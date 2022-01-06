require 'json'

def main()

kill_tags = "lang wikipedia topics sounds categories forms inflection inflection_templates etymology_text lang_code etymology_templates".split(/\s+/)
kill_senses_subtags = "tags id categories examples related".split(/\s+/)
$stdin.each_line { |line|
  x = JSON.parse(line)
  kill_tags.each { |tag|
    x.delete(tag)
  }
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
