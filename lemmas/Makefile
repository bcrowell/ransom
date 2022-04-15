# https://github.com/PerseusDL/treebank_data
PERSEUS_DIR = /home/bcrowell/a/treebank_data/v2.1
PERSEUS_GREEK_DIR = $(PERSEUS_DIR)/Greek/texts
PERSEUS_LATIN_DIR = $(PERSEUS_DIR)/Latin/texts
ILIAD =   $(PERSEUS_GREEK_DIR)/tlg0012.tlg001.perseus-grc1.tb.xml
ODYSSEY = $(PERSEUS_GREEK_DIR)/tlg0012.tlg002.perseus-grc1.tb.xml
PETRONIUS = $(PERSEUS_LATIN_DIR)/phi0972.phi001.perseus-lat1.xml
CAESAR = $(PERSEUS_LATIN_DIR)/phi0448.phi001.perseus-lat1.tb.xml
CICERO = $(PERSEUS_LATIN_DIR)/phi0474.phi013.perseus-lat1.tb.xml
VERGIL = $(PERSEUS_LATIN_DIR)/phi0690.phi003.perseus-lat1.tb.xml
OVID = $(PERSEUS_LATIN_DIR)/phi0959.phi006.perseus-lat1.tb.xml
TACITUS = $(PERSEUS_LATIN_DIR)/phi1351.phi005.perseus-lat1.tb.xml
# When adding a new target, add an appropriate line to flatten.rb in the following form:
#   if line=~/urn:cts:latinLit:phi0972.phi001.perseus-lat1.tb/ then $text="satyricon"; book_and_chapter=false end

.PHONY: default dbs

default:
	[ -f $(ILIAD) ]
	[ -f $(ODYSSEY) ]
	cat $(ILIAD) $(ODYSSEY) | ruby flatten.rb greek >homer_lemmas.csv
	make dbs
	make cunliffe_to_perseus

dbs:
	ruby to_db.rb homer
	# ...writes homer_lemmas.json ; doesn't write sdbm file because I have that commented out; removes macrons and breves
	#    writes homer_lemmas.line_index.json
	ruby make_freq.rb homer >homer_freq.json

cunliffe_to_perseus:
	./make_cunliffe_to_perseus.rb >cunliffe_to_perseus.json

classical_latin_freq.json:
	ruby merge_freq.rb caesar_freq.json cicero_freq.json ovid_freq.json petronius_freq.json vergil_freq.json >classical_latin_freq.json

petronius:
	[ -f $(PETRONIUS) ]
	ruby flatten.rb latin <$(PETRONIUS) >petronius_lemmas.csv
	ruby to_db.rb petronius
	ruby make_freq.rb petronius >petronius_freq.json

caesar:
	[ -f $(CAESAR) ]
	ruby flatten.rb latin <$(CAESAR) >caesar_lemmas.csv
	ruby to_db.rb caesar
	ruby make_freq.rb caesar >caesar_freq.json

cicero:
	[ -f $(CICERO) ]
	ruby flatten.rb latin <$(CICERO) >cicero_lemmas.csv
	ruby to_db.rb cicero
	ruby make_freq.rb cicero >cicero_freq.json

vergil:
	[ -f $(VERGIL) ]
	ruby flatten.rb latin <$(VERGIL) >vergil_lemmas.csv
	ruby to_db.rb vergil
	ruby make_freq.rb vergil >vergil_freq.json

ovid:
	[ -f $(OVID) ]
	ruby flatten.rb latin <$(OVID) >ovid_lemmas.csv
	ruby to_db.rb ovid
	ruby make_freq.rb ovid >ovid_freq.json

tacitus:
	[ -f $(TACITUS) ]
	ruby flatten.rb latin <$(TACITUS) >tacitus_lemmas.csv
	ruby to_db.rb tacitus
	ruby make_freq.rb tacitus >tacitus_freq.json


