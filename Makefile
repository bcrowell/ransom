BOOK = iliad
POS = $(BOOK).pos
GENERIC = "pos_file":"$(POS)"
#COMPILE = xelatex $(BOOK) | ruby filter_latex_messages.rb
COMPILE = xelatex $(BOOK)

default:
	@make figures # renders any figure whose pdf is older than its svg
	@fruby $(BOOK).rbtex '{$(GENERIC),"clean":true}' >$(BOOK).tex
	@$(COMPILE)
	@fruby $(BOOK).rbtex '{$(GENERIC),"write_pos":true}' >$(BOOK).tex
	@$(COMPILE)
	@fruby $(BOOK).rbtex '{$(GENERIC),"render_glosses":true}' >$(BOOK).tex
	@$(COMPILE)

figures:
	# Create pdf versions of the svg figures.
	# For this to work, the scripts in the scripts directory need to be executable.
	# Inkscape 0.47 or later is required.
	# To force rendering of all figures, even if they seem up to date, do FORCE=1 make figures
	perl -e 'foreach my $$f(<figs/*.svg>) {system("scripts/render_one_figure.pl $$f $(FORCE)")}'

clean:
	rm -f *~ *.aux *.log *.idx *.toc *.ilg *.bak *.toc $(BOOK).tex

