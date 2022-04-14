=begin
class CunliffeGlosses -- accesses Cunliffe entries from a file on disk

Interface is similar to the one for WiktionaryGlosses.

Example for testing:
ruby -e "require './lib/cunliffe.rb'; require './lib/string_util.rb'; a=CunliffeGlosses.new(); print a.get_glosses('ἄβλητος')"
=end


class CunliffeGlosses
def initialize(filename:"cunliffe/cunliffe.txt")
  # The caller should check whether the return has .invalid, and if so, replace the returned object with nil, which is
  # what other code expects when it's called with a CunliffeGlosses argument that doesn't actually work.
  # As presently implemented, this is pretty slow to start up.
  if not File.exists?(filename) then
    $stderr.print %Q{
      Warning: file #{filename} not found, so we won't be able to give automatic suggestions of glosses from Cunliffe.
      This has no effect on production of the pdf files. It just makes it more work to create glosses for new pages.
      }
    @invalid = true
    return
  end
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
          w = remove_macrons_and_breves(clean_up_greek($1)).downcase
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
  @lemma_keys = {}
  @glosses.keys.each { |head_word|
    g = self.simplify(@glosses[head_word])
    next if self.is_cross_ref(g)
    @lemma_keys[head_word] = 1
  }
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

def all_lemmas()
  return @lemma_keys.keys
end

def extract_line_refs(lexical)
  # Given a lemma like ἀγχόθι, returns an array like ['Ξ412','Ψ762','ν103','ν347'].
  # Testing: ruby -e "require './lib/cunliffe.rb'; require './lib/string_util.rb'; a=CunliffeGlosses.new(); print a.extract_line_refs('ἀγχόθι')"
  alphabet = 'αβγδεζηθικλμνξοπρστυφχψωΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ'
  result = []
  self.get_glosses(lexical,decruft:false).each { |gloss|
    gloss = gloss.gsub(/\s+/,' ')
    gloss = gloss.gsub(/ = /,', ')
    # First make implicit letters explicit, e.g., in ἄγω, we have this: η9, 248.
    replacements = []
    gloss.scan(/(([#{alphabet}])\d{1,3}(, \d{1,3})+)/) {
      whole,letter = [$1,$2]
      changed = whole.dup.gsub(/ (\d{1,3})/) {" #{letter}#{$1}"}
      replacements.push([whole,changed])
    }
    replacements.each { |x|
      a,b = x
      gloss = gloss.gsub(/#{a}/,b)
    }
    # Get list of all line refs.
    result |= gloss.scan(/[#{alphabet}]\d{1,3}/) # union of sets
  }
  return result.sort { |a,b| self.compare_line_refs(a,b)}
end

def compare_line_refs(a,b)
  aa = self.cunliffe_line_ref_to_ints(a)
  bb = self.cunliffe_line_ref_to_ints(b)
  if aa.nil? || bb.nil? then return 0 end
  return aa<=>bb
end

def csv_line_ref_to_ints(x)
  # x = ['iliad',1,2]
  # It doesn't matter whether x[1] and x[2] are strings or ints. They'll be ints in output.
  # returns [0,1,2]
  book = x[0]
  if book=='iliad' then book=0 else book=1 end
  return [book,x[1].to_i,x[2].to_i]
end

def csv_line_ref_to_cunliffe(x)
  # x = ['iliad',1,2]
  # It doesn't matter whether x[1] and x[2] are strings or ints.
  # returns a Cunliffe-style line reference such as Α2
  return ints_line_ref_to_cunliffe(csv_line_ref_to_ints(x))
end

def ints_line_ref_to_cunliffe(x)
  alphabet = 'αβγδεζηθικλμνξοπρστυφχψωΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ'
  book,ch,line = x
  if book==0 then ch=alphabet[ch+24-1] else ch=alphabet[ch-1] end
  return "#{ch}#{line}"
end

def cunliffe_line_ref_to_ints(a)
  # returns [book,ch,line], where book=0 for iliad, 1 for odyssey
  alphabet = 'αβγδεζηθικλμνξοπρστυφχψωΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ'
  if a=~/(.)(\d+)/ then
    letter,line = [$1,$2.to_i]
    ch = alphabet.index(letter)
    if ch<24 then book=1 else book=0; ch-=24; end
    return [book,ch+1,line]
  else
    return nil
  end
end

def is_cross_ref(gloss)
  # example: κατέσσυτο, 3 sing. aor. mid. κατασεύω.
  # example that's not a cross ref: δάκρυ, τό [cf. δάκρυον]. ... note comma
  # Input should have already been put through simplify().
  # Testing:
  #  true: ... ruby -e "require './lib/cunliffe.rb'; require './lib/string_util.rb'; a=CunliffeGlosses.new(); g=a.get_glosses('κατέσσυτο',decruft:false)[0]; g=a.simplify(g); print a.is_cross_ref(g)"
  #  false: ... ruby -e "require './lib/cunliffe.rb'; require './lib/string_util.rb'; a=CunliffeGlosses.new(); g=a.get_glosses('κατευνάω',decruft:false)[0]; g=a.simplify(g); print a.is_cross_ref(g)"
  number_of_lines = gloss.scan(/\n/).length
  if gloss=~/\A[[:alpha:]]+,/ then comma_after_head_word=true else comma_after_head_word=false end
  if comma_after_head_word then
    if gloss=~/\A[[:alpha:]]+, ([[:alpha:]]+)/ then
      # don't count the comma if it's an entry like "δάκρυ, τό" or "ἄκρον, ου, τό"
      second_word = $1
      unless second_word=~/[0-9a-z]/ then comma_after_head_word=false end
    end
  end
  return (number_of_lines==1) && comma_after_head_word
end

def simplify(gloss)
  # Result is one line per paragraph.
  # testing: ruby -e "require './lib/cunliffe.rb'; require './lib/string_util.rb'; a=CunliffeGlosses.new(); g=a.get_glosses('κατευνάω',decruft:false)[0]; g=a.simplify(g); print g"
  gloss = clean_up_greek(gloss)
  gloss = remove_macrons_and_breves(gloss)
  gloss.sub!(/\A[\*†]*/,'')
  gloss.gsub!(/^   \n/,"\n")
  gloss.gsub!(/\s+\n/,"\n")
  gloss.gsub!(/^ {3,}/,"__INDENT__")
  gloss.gsub!(/ {2,}/,"  ")
  gloss.gsub!(/__INDENT__/,"   ")
  gloss.gsub!(/\n   /,' ')
  return gloss
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




