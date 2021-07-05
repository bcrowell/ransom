import sys,re
from cltk.corpus.greek.beta_to_unicode import Replacer

r = Replacer()

def myfunction(a):
  tag = a[0]
  beta = a[1]
  return tag+"=\""+r.beta_code(beta)+"\""
  

for line in sys.stdin:
  line = re.sub("(form|lemma)=\"([^\"]+)\"",lambda m: myfunction(m.group(1,2)),line)
  line.rstrip('\r\n')
  print(line,end='')
