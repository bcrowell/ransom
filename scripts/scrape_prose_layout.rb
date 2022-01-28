#!/bin/ruby

=begin

The purpose of this script is to help with typesetting prose
texts. This is hard to do because latex doesn't expect a paragraph
break ever to jump across multiple intervening pages. Also, we
need to do line numbering, but the standard tool for that, the
latex lineno package, won't work for this application, in which
there are multiple interleaved streams of text.

Reads stdin, writes stdout. Input is a .prose file written by latex,
based on code generated by the WhereAt class. Format is documented
there. See below for what samples of input and output look like.

The output file consists of a list of chunks of text, each of which is
either a paragraph or, if interrupted by a page break, part of a
paragraph. In the latter case, the flags will include "page," and in
this case we will need to take special measures later to make sure the
final line is properly justified. The lines of text are given in two
forms: (1) strings with a single space character separating words;
(2) offsets into the original file. Presently I'm using only the second
form, since that's what's needed in order to create an Epos object.

The code should work if there is paragraph intendation, but I haven't
tested that. It will not work with hyphenation.

sample input:

406c55e1844c758e95e2b0e52d665581;;;Forte;;;26.22481pt;7.61436pt;0.14365pt;{"offset":0,"length":6,"para":0,"file":0};
8ba3e6c70338364e4861023461fcc384;;;dominus;;;43.29912pt;7.76909pt;0.14365pt;{"offset":6,"length":8,"para":0,"file":0};
...
406c55e1844c758e95e2b0e52d665581;1;;Forte;3410160;36724906;;;;{}
8ba3e6c70338364e4861023461fcc384;1;;dominus;5446372;36724906;;;;{}
...

sample output:

[
{"flags":["para"],"lines":[["Forte dominus Capuae exierat ad scruta scita expedienda.",0,57],["Nactus ego occasionem persuadeo hospitem nostrum, ut",57,110],["mecum ad quintum miliarium veniat. Erat autem miles,",110,163],["fortis tanquam Orcus. Apoculamus nos circa gallicinia; luna",163,223],["lucebat tanquam meridie. Venimus inter monimenta: homo",223,278],["meus coepit ad stelas facere; sedeo ego cantabundus et stelas",278,340],["numero.",340,348]]},
{"flags":["para"],"lines":[["Deinde ut respexi ad comitem, ille exuit se et omnia",0,53],["vestimenta secundum viam posuit. Mihi anima in naso esse;",53,111],["stabam tanquam mortuus. At ille circumminxit vestimenta",111,167],["sua, et subito lupus factus est. Nolite me iocari putare;",167,225],["ut mentiar, nullius patrimonium tanti facio. Sed, quod",225,280],["coeperam dicere, postquam lupus factus est, ululare coepit",280,339],["et in silvas fugit. Ego primitus nesciebam ubi essem; deinde",339,400],["accessi, ut vestimenta eius tollerem: illa autem lapidea facta",400,463],["sunt. Qui mori timore nisi ego? Gladium tamen strinxi et",463,520],["<in tota via> umbras cecidi, donec ad villam amicae meae",520,577],["pervenirem.",577,589]]},
...
]

=end

require "json"
require "./lib/file_util.rb"

# Merge output from the two passes of latex:
data = [] # array of hashes, one per word
word_index = {} # key is hash, value is index into data
$stdin.each_line { |line| 
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
  if if_line_break then
    text_of_line = line.map { |x| x['word'] }.join(' ')
    chunk.push([text_of_line,line[0]['offset'],line[-1]['offset']+line[-1]['word'].length+1])
    line=[] 
  end
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
