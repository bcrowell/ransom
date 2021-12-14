class MultiString
  # A MultiString object represents a string that can exist in multiple forms, e.g., blinked/blinking.
  def initialize(stuff)
    # stuff can be either a string or a list of lists such as [["blink"],["ed","ing"]]
    if stuff.kind_of?(String) then @data=[[stuff]] else @data=stuff end
  end
  attr_accessor :data
  def complexity
    # The number of different paths through the multistring. This may be greater than the actual number of possible distinct strings.
  end
  def distance(t)
    # Calculate a measure of the similarity between the instance and another MultiString t.
  end
end
