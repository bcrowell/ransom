class Debug
  def Debug.print(debug,&block)
    return unless debug
    File.open("debug.txt","a") { |f| f.print block.call,"\n" }
  end
end
