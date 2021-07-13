require 'json'

$stdin.each_line { |line|
  line = JSON.generate(JSON.parse(line))
  puts line+"\n"
}
