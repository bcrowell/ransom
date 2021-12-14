require "set"

class MultiString
  # A MultiString object represents a string that can exist in multiple forms, e.g., blinked/blinking.
  # ruby -e "require './multistring.rb'; x=MultiString.new('hello'); y=MultiString.new('louder'); print x.bag_distance(y)"
  # ... outputs 3, because udr in second string are not in first string
  # ruby -e "require './multistring.rb'; x=MultiString.new([['quiet','loud'],['ly']]); y=MultiString.new('louder'); print x.bag_distance(y)"
  # ... outputs 2, because loudly and louder have a bag distance of 2
  def initialize(stuff)
    # stuff can be either a string or a list of lists such as [["blink"],["ed","ing"]]
    if stuff.kind_of?(String) then @data=[[stuff]] else @data=stuff end
  end
  attr_accessor :data
  def complexity
    # The number of different paths through the multistring. This may be greater than the actual number of possible distinct strings.
    result = 1
    @data.each { |seg|
      result = result*seg.length
    }
    return result
  end
  def nth(n)
    # Input n ranges from 0 to complexity-1. Gives the nth string that can result from the multistring.
    indices = []
    @data.each { |seg|
      choices = seg.length
      indices.push(n%choices)
      n = n/choices
    }
    result = ''
    k = 0
    @data.each { |seg|
      result = result + seg[indices[k]]
      k = k+1
    }
    return result
  end
  def bag_distance(t)
    # Calculate a measure of the similarity between this instance and another MultiString t.
    # This measure is the smallest of all distances calculated between possible atomic results of the two multistrings.
    # The distance can be zero even if the strings are not identical. 
    # The idea is basically that each string is considered as a set of characters.
    d = []
    0.upto(self.complexity-1) { |i|
      p = self.nth(i)
      0.upto(t.complexity-1) { |j|
        q = t.nth(j)
        d.push(MultiString.atomic_bag_distance(p,q))
      }
    }
    return d.min
  end
  def MultiString.atomic_bag_distance(p,q)
    # The distance between two atomic strings p and q is the number of characters in p not appearing in q, or vice versa, whichever is greater.
    ps = MultiString.string_to_set_of_chars(p)
    qs = MultiString.string_to_set_of_chars(q)
    return [(ps-qs).length,(qs-ps).length].max
  end
  def MultiString.string_to_set_of_chars(s)
    return s.chars.to_set
  end
end
