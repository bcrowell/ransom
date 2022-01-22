# https://github.com/PerseusDL/treebank_data
PERSEUS_DIR = /home/bcrowell/a/treebank_data/v2.1
PERSEUS_GREEK_DIR = $(PERSEUS_DIR)/Greek/texts
PERSEUS_LATIN_DIR = $(PERSEUS_DIR)/Latin/texts
ILIAD =   $(PERSEUS_GREEK_DIR)/tlg0012.tlg001.perseus-grc1.tb.xml
ODYSSEY = $(PERSEUS_GREEK_DIR)/tlg0012.tlg002.perseus-grc1.tb.xml
PETRONIUS = $(PERSEUS_LATIN_DIR)/phi0972.phi001.perseus-lat1.xml
# When adding a new target, add an appropriate line to flatten.rb in the following form:
#   if line=~/urn:cts:latinLit:phi0972.phi001.perseus-lat1.tb/ then $text="satyricon"; book_and_chapter=false end


default:
	[ -f $(ILIAD) ]
	[ -f $(ODYSSEY) ]
	cat $(ILIAD) $(ODYSSEY) | ruby flatten.rb greek >homer_lemmas.csv
	ruby to_db.rb homer <homer_lemmas.csv
	# ...writes homer_lemmas.json ; doesn't write sdbm file because I have that commented out; removes macrons and breves
	ruby make_freq.rb homer >homer_freq.json

petronius:
	[ -f $(PETRONIUS) ]
	ruby flatten.rb latin <$(PETRONIUS) >petronius_lemmas.csv
	ruby to_db.rb petronius <petronius_lemmas.csv
	ruby make_freq.rb petronius >petronius_freq.json


