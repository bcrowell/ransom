BOOK = iliad
POS = $(BOOK).pos
GENERIC = "pos_file":"$(POS)"

default:
	fruby $(BOOK).rbtex '{$(GENERIC),"clean":true}' >$(BOOK).tex
	xelatex $(BOOK)
	fruby $(BOOK).rbtex '{$(GENERIC),"write_pos":true}' >$(BOOK).tex
	xelatex $(BOOK)
	fruby $(BOOK).rbtex '{$(GENERIC),"render_glosses":true}' >$(BOOK).tex
	xelatex $(BOOK)



clean:
	rm -f *~ *.aux *.log *.idx *.toc *.ilg *.bak *.toc $(BOOK).tex

