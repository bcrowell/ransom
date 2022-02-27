class BBCode
  def BBCode.tag(tag,contents)
    return "[#{tag}]#{contents}[/#{tag}]"
  end
  def BBCode.bold(s)
    return BBCode.tag('b',s)
  end
  def BBCode.italic(s)
    return BBCode.tag('i',s)
  end
  def BBCode.underline(s)
    return BBCode.tag('u',s)
  end
  def BBCode.pre(s) # preformatted text
    return BBCode.tag('pre',s)
  end
end
