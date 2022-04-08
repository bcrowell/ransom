=begin
class CunliffeGlosses -- accesses Cunliffe entries from a file on disk

Interface is similar to the one for WiktionaryGlosses.

Example for testing:
ruby -e "require './lib/cunliffe.rb'; require './lib/string_util.rb'; a=CunliffeGlosses.new(); print a.get_glosses('ἄβλητος')"
=end


class CunliffeGlosses
def initialize()
  # The caller should check whether the return has .invalid, and if so, replace the returned object with nil, which is
  # what other code expects when it's called with a CunliffeGlosses argument that doesn't actually work.
  # As presently implemented, this is pretty slow to start up.
  filename = "cunliffe/cunliffe.txt"
  if not File.exists?(filename) then
    $stderr.print %Q{
      Warning: file #{filename} not found, so we won't be able to give automatic suggestions of glosses from Cunliffe.
      This has no effect on production of the pdf files. It just makes it more work to create glosses for new pages.
      }
    @invalid = true
  else  
    # $stderr.print "Reading #{filename}...\n"
    @glosses = {}
    accum = ''
    w = nil
    IO.foreach(filename) { |line|
      if line=~/\*{20,}/ then # in the archive.org scan, entries are separated by lines of asterisks
        if !w.nil? then
          accum.sub!(/\n{2,}/,"\n")
          @glosses[w] = accum
        end
        accum = ''
        w = nil
      else
        next if accum=='' && line=~/^\s*$/ # skip blank line at top of entry
        if accum=='' then
          if line=~/^[\*†]*([[:alpha:]]+)/ then
            w = $1
          else
            raise "In CunliffeGlosses.initialize(), unable to parse head word from this line:\n#{line}\n"
            next
          end
        else
          accum += "\n"
        end
        accum += line
      end
    }
    # $stderr.print "...done\n"
    @invalid = false
  end
end

attr_reader :invalid

def get_glosses(lexical,decruft:true)
  # Input is a lemmatized form, whose accents are significant, but not its case or macrons and breves.
  # Output is an array of strings, possibly empty.
  key = remove_macrons_and_breves(lexical).downcase
  return [] if !(@glosses.has_key?(key))
  result = [@glosses[key]]
  if decruft then result = result.map { |x| self.decruft(x) } end
  return result
end

def decruft(gloss)
  gloss = clean_up_greek(gloss)
  gloss.sub!(/\A[\*†]*/,'')
  gloss.gsub!(/[αβγδεζηθικλμνξοπρστυφχψωΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ][0-9]{1,3}(, \d{1,3})?/,'_')
  # typical listing of occurrences: Cf. Ε223 = Θ107, Θ342 = Λ178, Λ121, 404, Μ136, Ο345: χ299.
  gloss.gsub!(/_ = /,'_')
  gloss.gsub!(/_: /,'_')
  gloss.gsub!(/_[\.,]/,'_')
  gloss.gsub!(/Cf\. _/,'_')
  gloss.gsub!(/_/,'')
  gloss.gsub!(/^   \n/,"\n")
  gloss.gsub!(/\s+\n/,"\n")
  gloss.gsub!(/^ {3,}/,"__INDENT__")
  gloss.gsub!(/ {2,}/,"  ")
  gloss.gsub!(/__INDENT__/,"   ")
  gloss = remove_macrons_and_breves(gloss)
  return gloss
end

end




