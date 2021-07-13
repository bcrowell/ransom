require 'json'

def main()

$stdin.each_line { |line|
  x = JSON.parse(line)
  x.delete("lang")
  x.delete("wikipedia")
  x.delete("topics")
  x.delete("sounds")
  x.delete("categories")

  line = JSON.generate(x)
  puts line+"\n"
}

end # main

def clown(x)
  # Call it something besides clone because otherwise it's hard to grep for use of clone, which I
  # should *never* use.
  return Marshal.load(Marshal.dump(x))
end

def shallow_copy(x)
  # The purpose of having this here is so that I can easily tell when looking through my code that I haven't
  # thoughtlessly done shallow copying using clone.
  return x.clone
end

main
