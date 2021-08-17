$stderr.print %q{
This program generates ruby code to strip accents from characters in Latin and Greek scripts.
Progress will be printed to stderr, the final result to stdout.
}

all_characters = %q{
         ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝàáâãäåæçèéêëìíîïñòóôõöøùúûüýÿ
         ΆΈΊΌΐάέήίϊόύώỏἀἁἃἄἅἈἐἑἒἔἕἘἙἜἡἢἣἤἥἦἨἩἫἬἮἰἱἲἴἵἶἸὀὁὂὃὄὅὊὍὐὑὓὔὕὖὗὝὡὢὣὤὥὧὨὩὰὲὴὶὸὺὼᾐᾗᾳᾴᾶῂῆῇῖῥῦῳῶῷῸᾤᾷἂἷ
         ὌᾖὉἧἷἂῃἌὬὉἷὉἷῃὦἌἠἳᾔἉᾦἠἳᾔὠᾓὫἝὈἭἼϋὯῴἆῒῄΰῢἆὙὮᾧὮᾕὋἍἹῬἽᾕἓἯἾᾠἎῗἾῗἯἊὭἍᾑᾰῐῠᾱῑῡᾸῘῨᾹῙῩ
}.gsub(/\s/,'')
# The first line is a list of accented Latin characters. The second and third lines are polytonic Greek.
# The Greek on this list includes every character occurring in the Project Gutenberg editions of Homer, except for some that seem to be
# mistakes (smooth rho, phi and theta in symbol font). Duplications and characters out of order in this list have no effect at run time.
# Also includes vowels with macron and vrachy, which occur in Project Perseus texts sometimes.

# The following code shells out to the linux command-line utility called "unicode," which is installed as the debian package
# of the same name.
# Documentation: https://github.com/garabik/unicode/blob/master/README

def char_to_name(c)
  return `unicode --string "#{c}" --format "{name}"`.downcase
end

def name_to_char(name)
   name.gsub!(/\s+$/,'')
   list = `unicode "#{name}" --format "{pchar}" --max 0` # returns a string of possibilities, not just exact matches
   # Usually, but not always, the unaccented character is the first on the list.
   list.chars.each { |c|
     if char_to_name(c)==name then return c end
   }
   #$stderr.print "Warning: unable to convert name #{name} to a character, list=#{list}."
   return nil
end

from = ''
to = ''
(all_characters+"aeiouyαειουηω").chars.sort.uniq.each { |c|
  name = char_to_name(c)
  next if name=~/tilde/
  name.sub!(/(grave|varia)/,'acute')
  unless name=~/(acute|tonos|oxia)/ then name = name+" with acute" end
  name.sub!(/and ypogegrammeni/,'with ypogegrammeni')
  1.upto(3) { |i|
    name.sub!(/with ([a-z]+) with ([a-z]+)/) { "with #{$1} and #{$2}" }
    name.sub!(/and ([a-z]+) with ([a-z]+)/) { "with #{$1} and #{$2}" }
  }
  with_accent = name_to_char(name)
  if with_accent.nil? then name2 = name.sub(/acute/,'tonos'); with_accent = name_to_char(name2) end
  if with_accent.nil? then name3 = name.sub(/acute/,'oxia'); with_accent = name_to_char(name3) end
  if c=='ὼ' and with_accent.nil? then raise "c=#{c}, name=#{name}\n" end
  next if with_accent.nil?
  from = from+c.unicode_normalize(:nfc)
  to = to+with_accent.unicode_normalize(:nfc)
  $stderr.print c
}
$stderr.print "\n"
print %Q{
# Code generated by code at https://stackoverflow.com/a/68338690/1142217
# See notes there on how to add characters to the list.
def add_acute(s)
  return s.unicode_normalize(:nfc).tr("#{from}","#{to}")
end
}
