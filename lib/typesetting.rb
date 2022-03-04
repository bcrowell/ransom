class Typesetting

def Typesetting.width_to_fit_para_in_n_lines(string,n,font_size_pt,preamble,para_preface)
  # used in setting column widths for interlinear
  # preamble is, e.g., \setmainfont{GFS Didot}
  # para_preface is, e.g., '\footnotesize{}'
  # returns a result in mm
  cache_filename = "cache_typesetting"
  key = Digest::MD5.hexdigest(string)+",#{n},#{font_size_pt},#{preamble},#{para_preface}"
  result = nil
  if File.exists?(cache_filename+".dir") then
    SDBM.open(cache_filename) { |db| if db.has_key?(key) then result=db[key].to_f end }
  end
  if !(result.nil?) then return result end # return cached result
  $stderr.print "...typesetting data not found in cache for #{string}, recalculating\n" if n==1
  result = Typesetting.width_to_fit_para_in_n_lines_no_caching(string,n,font_size_pt,preamble,para_preface)
  SDBM.open(cache_filename) { |db| db[key]=result.to_s }
  return result
end

def Typesetting.width_to_fit_para_in_n_lines_no_caching(string,n,font_size_pt,preamble,para_preface)
  # Don't use this directly, use width_to_fit_para_in_n_lines(). See that function for comments explaining what it does.
  # https://tex.stackexchange.com/questions/231329/equally-distribute-text-among-a-given-amount-of-lines-automatically-adjusting-t/231333#231333
  single_word = %q(
    \sbox2{__STRING__}
    \immediate\write\outputfile{\the\wd2}
  )
  multi_word = %q(
    \dimen0=1pt

    \loop
    \sbox2{\parbox[b]{\dimen0}{__STRING__}}
    \ifdim\ht2>__N__\baselineskip
    \advance\dimen0 10pt
    \repeat

    \advance\dimen0 -10pt
    \loop
    \sbox2{\parbox[b]{\dimen0}{__STRING__}}
    \ifdim\ht2>__N__\baselineskip
    \advance\dimen0 1pt
    \repeat

    \advance\dimen0 -1pt
    \loop
    \sbox2{\parbox[b]{\dimen0}{__STRING__}}
    \ifdim\ht2>__N__\baselineskip
    \advance\dimen0 0.1pt
    \repeat

    \immediate\write\outputfile{\the\wd2}
  )
  code = %q(
    \documentclass[__FONT_SIZE__pt]{article}
    \RequirePackage{fontspec}
    __PREAMBLE__
    \begin{document}

    \newwrite\outputfile
    \immediate\openout\outputfile=__OUTFILE__

    __CASE__

    \closeout\outputfile

    \end{document}
)
  temp_file_1 = "temp-"+Process.pid.to_s+"-"+Digest::MD5.hexdigest(string)+"-1.foo"
  temp_file_2 = "temp-"+Process.pid.to_s+"-"+Digest::MD5.hexdigest(string)+"-2"
  if string=~/\s/ then which_case=multi_word else which_case=single_word end
  code.gsub!(/__CASE__/,which_case)
  code.gsub!(/__PREAMBLE__/,preamble)
  code.gsub!(/__FONT_SIZE__/,font_size_pt.to_s)
  code.gsub!(/__OUTFILE__/,temp_file_1)
  code.gsub!(/__STRING__/,"{#{para_preface}#{string}}")
  code.gsub!(/__N__/,n.to_s)
  begin
    File.open(temp_file_2+'.tex',"w") { |f| f.print code }
    `xelatex #{temp_file_2} >/dev/null 2>&1`
    result=nil
    File.open(temp_file_1,"r") { |f| result=f.gets(nil) }
  ensure
    FileUtils.rm_f([temp_file_1,temp_file_2+'.tex',temp_file_2+'.pdf',temp_file_2+'.aux',temp_file_2+'.log'])
  end
  result =~ /(.*)pt/
  result = $1.to_f
  pt_per_mm =  2.8346456692913
  return (result/pt_per_mm+0.01).round(2)
end


end

