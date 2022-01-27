#!/bin/ruby

=begin

sample input:

406c55e1844c758e95e2b0e52d665581;;;Forte;;;26.22481pt;7.61436pt;0.14365pt;{"offset":0,"length":6,"para":0,"file":0};
8ba3e6c70338364e4861023461fcc384;;;dominus;;;43.29912pt;7.76909pt;0.14365pt;{"offset":6,"length":8,"para":0,"file":0};
...
406c55e1844c758e95e2b0e52d665581;1;;Forte;3410160;36724906;;;;{}
8ba3e6c70338364e4861023461fcc384;1;;dominus;5446372;36724906;;;;{}
...

=end

require "json"
require "./lib/file_util.rb"

prose_file = ARGV[0]
input_files = ARGV[1..-1]

#$stderr.print "input files: #{prose_file}, #{input_files}\n"

texts = []
input_files.each { |filename|
  texts.push(slurp_file(filename))
}

# Merge output from the two passes of latex:
data = [] # array of hashes, one per word
word_index = {} # key is hash, value is index into data
IO.foreach(prose_file) { |line| 
  # some code here is duplicated from eruby_ransom.rb, WhereAt class
  next if line=~/^\?/
  line.sub!(/\s+$/,'') # trim trailing whitespace, such as a newline
  a = line.split(/;/,-1)
  hash,page,line_garbage,word,x,y,width,height,depth = a
  # line_garbage is always empty, need to infer it myself
  word.gsub!(/__SEMICOLON__/,';')
  if !(line=~/([^;]*;){9}(.*);(.*)/) then raise "bad line, not enough fields: #{line}" end
  extra1_json,extra2_json = [$2,$3]
  if extra1_json!='' then extra1 = JSON.parse(extra1_json) else extra1={} end
  if extra2_json!='' then extra2 = JSON.parse(extra2_json) else extra2={} end
  d = {'word'=>word,'x'=>x,'y'=>y,'width'=>width,'height'=>height,'depth'=>depth,
          'offset'=>extra1['offset'],'length'=>extra1['length'],'para'=>extra1['para'],'file'=>extra1['file']}
  d.keys.each { |k| if d[k].nil? || d[k]=='' then d.delete(k) end }
  ['x','y'].each { |k| if d.has_key?(k) then d[k] = d[k].to_i end}
  ['width','height','depth'].each { |k| if d.has_key?(k) then d[k] = d[k].sub(/pt$/,'').to_f end}
  if !word_index.has_key?(hash) then
    data.push(d)
    word_index[hash] = data.length-1
  else
    i = word_index[hash]
    data[i] = data[i].merge(d)
  end
}

# Walk through the text word by word. When I get to the end of a line or chunk, flush it.
all_chunks = []
current_x = -999 # When x fails to increase, or when y decreases, we've hit a line break.
                 # Note tricky case where you have paragraph indentation, the final line of a para is short, and the x increases across the break.
current_y = nil # When y increases by ~3x10^7, we've hit a page break. Initial nil value is to be construed as infinity.
current_para = 0
chunk = [] # accumulates lines until it's time to flush it
line = [] # accumulates words until it's time to flush it
data.push(nil) # marker for final flushing
data.each { |d|
  if_final_flush = d.nil?
  if if_final_flush then d={} end
  x,y,page,para = d['x'],d['y'],d['page'],d['para']
  if_line_break = (if_final_flush || x<=current_x || (!current_y.nil? && y<current_y))
  if_page_break = (!if_final_flush && (!current_y.nil? && y>current_y))
  if_para_break = (if_final_flush || para>current_para)
  #if d['word']=~/(stelas|numero|Deinde)/ then debug=true else debug=false end
  #if debug then print "...#{d['word']}, line,page,para=#{if_line_break},#{if_page_break},#{if_para_break} line=#{line}\n" end
  if if_line_break then chunk.push(line.map { |x| x['word'] }.join(' ')); line=[] end
  line.push(d) unless if_final_flush
  current_x = x
  current_para = para
  if if_page_break || if_para_break || if_final_flush then
    flags = []
    if if_para_break then flags.push('para') end
    if if_page_break then flags.push('page') end
    dressed_chunk = {'flags'=>flags,'lines'=>chunk}
    all_chunks.push(dressed_chunk)
    chunk = []
  end
  current_y = y
}

print "[\n"
print all_chunks.map { |c| JSON.generate(c) }.join(",\n")
print "\n"
print "]\n"
