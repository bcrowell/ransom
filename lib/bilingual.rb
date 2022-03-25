=begin
This class holds information about a passage from a bilingual text, including things
like what languages and dialects they are.
=end

class BareBilingual
  # Sometimes functions like FormatGloss.assemble require a Bilingual object so they know what languages they're dealing with,
  # but they don't need any actual bilingual text. This class supplies an object that fulfills that purpose.
  def initialize(foreign_genos,translation_genos)
    @foreign =     Epos.new(nil,nil,nil,genos:foreign_genos)
    @translation = Epos.new(nil,nil,nil,genos:translation_genos)
  end

  attr_reader :foreign,:translation
end

class Bilingual
  def initialize(g1,g2,t1,t2,foreign,translation,max_chars:5000,length_ratio_tol_factor:1.38)
    # Foreign and translation are Epos objects, which should have non-nil genos with is_verse set correctly.
    # G1, g2, t1, and t2 are references for input to Epos initializer. If a text is verse, then these should be
    # of the form [book,line]. If prose, then they should be either word globs or hard refs.
    # sanity checks:
    #   max_chars -- maximum length of translated text
    #   length_ratio_expected -- expected value of length of translation divided by length of foreign text
    #   length_ratio_tol_factor -- tolerance factor for the above ratio
    length_ratio_expected = translation.genos.verbosity()/foreign.genos.verbosity()
    Bilingual.type_check_refs_helper(g1,g2,t1,t2,foreign,translation)
    @foreign = foreign
    @translation = translation
    if foreign.genos.is_verse then
      @foreign_linerefs = [g1,g2]
      @foreign_chapter_number = g1[0]
      @foreign_first_line_number = g1[1]
      @foreign_hr1,@foreign_hr2 = foreign.line_to_hard_ref(g1[0],g1[1]),foreign.line_to_hard_ref(g2[0],g2[1])
    else
      if g1.kind_of?(String) then
        @foreign_hr1,@foreign_hr2 = foreign.word_glob_to_hard_ref(g1)[0],foreign.word_glob_to_hard_ref(g2)[0]
      else
        @foreign_hr1,@foreign_hr2 = [g1,g2] # they're already hard refs
      end
    end
    @foreign_ch1,@foreign_ch2 = @foreign_hr1[0],@foreign_hr2[0]
    @foreign_text = foreign.extract(@foreign_hr1,@foreign_hr2)
    # The extracted text may begin with a paragraph break, which is represented by a double newline. But Epos.extract on verse won't keep this on
    # the front. So:
    before_me = foreign.lookbehind(@foreign_hr1,50)
    before_me = before_me.gsub(/[ \t]/,'')
    if before_me=~/(\n+)\Z/ then @foreign_text=$1+@foreign_text end
    if t1.kind_of?(String) then # translation is referred to by word glob
      # Let word globs contain, e.g., Hera rather than Juno:
      t1 = Patch_names.antipatch(t1)
      t2 = Patch_names.antipatch(t2)
      translation_hr1_with_errs = translation.word_glob_to_hard_ref(t1)
      translation_hr2_with_errs = translation.word_glob_to_hard_ref(t2)
      translation_hr1,translation_hr2 = translation_hr1_with_errs[0],translation_hr2_with_errs[0]
      if translation_hr1_with_errs[1] then raise "ambiguous word glob: #{t1}, #{translation_hr1_with_errs[2]}" end
      if translation_hr2_with_errs[1] then raise "ambiguous word glob: #{t2}, #{translation_hr2_with_errs[2]}"end
      if translation_hr1.nil? then raise "bad word glob, #{t1}" end
      if translation_hr2.nil? then raise "bad word glob, #{t2}" end
    else
      translation_hr1,translation_hr2 = [t1,t2]
    end
    @translation_text = translation.extract(translation_hr1,translation_hr2)
    @translation_text = Patch_names.patch(@translation_text) # change, e.g., Juno to Hera

    # A hash that is intended to be unique to this particular spread. For example, Homer sometimes repeats entire passages,
    # but this hash should still be different for the different passages. This is needed by foreign_verse in eruby_ransom.rb.
    @hash = Digest::MD5.hexdigest([translation_hr1,translation_hr2,@foreign_hr1,@foreign_hr2].to_s)

    max_chars = 5000
    if @translation_text.length>max_chars || @translation_text.length==0 then
      message = "page of translated text has #{@translation_text.length} characters, failing sanity check"
      self.raise_failed_sanity_check(message,t1,t2,translation_hr1,translation_hr2)
    end
    l_t,l_f = @translation_text.length,@foreign_text.length
    length_ratio = l_t.to_f/l_f.to_f
    lo,hi = length_ratio_expected/length_ratio_tol_factor,length_ratio_expected*length_ratio_tol_factor
    if length_ratio<lo || length_ratio>hi then
      message = "length ratio=trans/foreign=#{length_ratio}, outside of expected range of #{lo}-#{hi}"
      self.raise_failed_sanity_check(message,t1,t2,translation_hr1,translation_hr2)
    end
  end
  def Bilingual.type_check_refs_helper(foreign1,foreign2,t1,t2,foreign,translation)
    Bilingual.type_check_refs_helper2(foreign1,foreign2,foreign)
    Bilingual.type_check_refs_helper2(t1,t2,translation)
  end
  def Bilingual.type_check_refs_helper2(ref1,ref2,epos)
    if epos.is_verse then
      if !(ref1.kind_of?(Array) && ref2.kind_of?(Array)) then raise "epos says verse, but refs are not arrays" end
    else
      if ref1.kind_of?(String) && ref2.kind_of?(String) then return end
      if ref1.kind_of?(Array) && ref2.kind_of?(Array) then return end
      raise "epos says prose, but refs are not strings or arrays"
    end
  end
  def label
    # a string that can be used as part of latex labels, to identify this four-page spread
    l = @foreign_first_line_number
    if l.nil? then l=@foreign_hr1[1] end # use character offset rather than line number
    return "#{@foreign_ch1+1}-#{l}"
  end
  def raise_failed_sanity_check(basic_message,t1,t2,translation_hr1,translation_hr2)
    debug_file = "epos_debug.txt"
    message = "Epos text selection fails sanity check\n" \
         + basic_message + "\n" \
         + "  '#{t1}-'\n  '#{t2}'\n  #{translation_hr1}-#{translation_hr2}\n"
    File.open(debug_file,"w") { |f|
      f.print message,"\n-------------------\n",self.foreign_text,"\n-------------------\n",self.translation_text,"\n"
    }
    raise message + "\n  See #{debug_file}"
  end
  attr_reader :foreign_hr1,:foreign_hr2,:foreign_ch1,:foreign_ch2,:foreign_text,:translation_text,:foreign_first_line_number,:foreign_chapter_number,
          :foreign_linerefs,:foreign,:translation,:hash
end
