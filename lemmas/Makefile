PERSEUS_DIR = /home/bcrowell/a/treebank_data/v2.1/Greek/texts
ILIAD =   $(PERSEUS_DIR)/tlg0012.tlg001.perseus-grc1.tb.xml
ODYSSEY = $(PERSEUS_DIR)/tlg0012.tlg002.perseus-grc1.tb.xml

default:
	cat $(ILIAD) $(ODYSSEY) | ruby flatten.rb >homer_lemmas.csv
	ruby to_db.rb <homer_lemmas.csv
	# ...writes homer_lemmas.json ; doesn't write sdbm file because I have that commented out; removes macrons and breves
	ruby make_freq.rb >homer_freq.json
