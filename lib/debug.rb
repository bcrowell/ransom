class Debug
  def Debug.print(debug,&block)
    return unless debug
    File.open("debug.txt","a") { |f| f.print block.call,"\n" }
  end
end

class SpecialPurposeDebugger
  # This is currently used for coaxing the software into explaining why words are included in or omitted from vocabulary lists. To turn it
  # on, uncomment the line in iliad.rbtex that overwrites the inactive vocab_debugger with an active one.
  def initialize(if_active,file:nil,if_overwrite:false,purpose:nil)
    @if_active = if_active
    @file = file # can be nil
    self.d(purpose,if_overwrite:if_overwrite)
  end

  def d(message,if_overwrite:false)
    return unless @if_active && !@file.nil? && !message.nil?
    if if_overwrite then mode="w" else mode="a" end
    File.open(@file,mode) { |f| f.print message,"\n" }
  end
end
