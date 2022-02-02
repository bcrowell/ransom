require 'json'
require "../lib/file_util.rb"

freq = {}
ARGV.each { |filename|
  x = json_from_file_or_die(filename)
  x.keys.each { |k|
    if freq.has_key?(k) then
      freq[k] += x[k]
    else
      freq[k] = x[k]
    end
  }
}
data = []
freq.keys.sort { |a,b| freq[b]<=>freq[a] }.each { |lemma|
  data.push("\"#{lemma}\" : #{freq[lemma]}")
}
print "{\n"+data.join(",\n")+"\n}\n"


