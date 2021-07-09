BOOK = iliad
POS = $(BOOK).pos
GENERIC = "pos_file":"$(POS)"
COMPILE = xelatex $(BOOK) | ruby filter_latex_messages.rb

default:
	@fruby $(BOOK).rbtex '{$(GENERIC),"clean":true}' >$(BOOK).tex
	@$(COMPILE)
	@fruby $(BOOK).rbtex '{$(GENERIC),"write_pos":true}' >$(BOOK).tex
	@$(COMPILE)
	@fruby $(BOOK).rbtex '{$(GENERIC),"render_glosses":true}' >$(BOOK).tex
	@$(COMPILE)



clean:
	rm -f *~ *.aux *.log *.idx *.toc *.ilg *.bak *.toc $(BOOK).tex

