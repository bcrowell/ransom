class Spew
  # A class intended to hold output text. Basically just a container for two pieces of data: a string, and an indication of
  # what the intended output format is.
  # Format can be: tex, txt, html, bbcode
  def initialize(format,s)
    @format = format
    @s = s
  end

  def like(s)
    return Spew.new(@format,s) # makes a new Spew object with the same format but a different string
  end

  def to_s
    s = @s
    s = s.gsub(/<([^>]*)>/) {self.like($1).underline}
    unless @format=='tex' then s=s.gsub(/\\ldots/,'...') end
    return s
  end

  def bold
    new_s = @s.dup
    if @format=='tex'    then new_s = Latex.macro('textbf',self.to_s) end
    if @format=='bbcode' then new_s = BBCode.bold(self.to_s) end
    return self.like(new_s)
  end

  def italic
    new_s = @s.dup
    if @format=='tex'    then new_s = Latex.macro('textit',self.to_s) end
    if @format=='bbcode' then new_s = BBCode.italic(self.to_s) end
    return self.like(new_s)
  end

  def underline
    new_s = @s.dup
    if @format=='tex'    then new_s = Latex.macro('underline',self.to_s) end
    if @format=='bbcode' then new_s = BBCode.underline(self.to_s) end
    return self.like(new_s)
  end

  def pre # preformatted text
    new_s = @s.dup
    if @format=='tex'    then new_s = Latex.envir('verbatim',self.to_s) end
    if @format=='bbcode' then new_s = BBCode.pre(self.to_s) end
    return self.like(new_s)
  end

end
