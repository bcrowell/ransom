BOOK = iliad
POS = $(BOOK).pos
GENERIC = "pos_file":"$(POS)"
#COMPILE = xelatex $(BOOK) | ruby filter_latex_messages.rb
# ... If I do this, then error messages freeze things.
COMPILE = xelatex $(BOOK)

.PHONY: clean default check check_glosses core update_github_pages reconfigure_git

default:
	@make --no-print-directory --assume-new iliad.rbtex $(BOOK).pdf

$(BOOK).pdf: lib/*rb eruby_ransom.rb iliad.rbtex iliad/core.tex
	@rm -f warnings help_gloss/__links.html
	@make figures # renders any figure whose pdf is older than its svg
	@./fruby $(BOOK).rbtex '{$(GENERIC),"clean":true}' >$(BOOK).tex
	@$(COMPILE)
	@./fruby $(BOOK).rbtex '{$(GENERIC),"write_pos":true}' >$(BOOK).tex
	@$(COMPILE)
	@./fruby $(BOOK).rbtex '{$(GENERIC),"render_glosses":true}' >$(BOOK).tex
	@$(COMPILE)
	@sort help_gloss/__links.html | uniq >a.a && mv a.a help_gloss/__links.html
	cp $(BOOK).pdf docs
	# If you want to change the public-facing book, do a make update_github_pages

update_github_pages:
	git commit -a -m "updating before erasing history of docs/$(BOOK).pdf and docs/$(BOOK)_booklet.pdf"
	git filter-repo --path docs/$(BOOK).pdf --invert-paths
	git filter-repo --path docs/$(BOOK)_booklet.pdf --invert-paths
	make reconfigure_git
	cp $(BOOK).pdf docs
	cp $(BOOK)_booklet.pdf docs
	git add docs/$(BOOK).pdf
	git push --force -u origin master

reconfigure_git:
	git remote add origin https://github.com/bcrowell/ransom.git
	git config remote.origin.url git@github.com:bcrowell/ransom.git

booklet: $(BOOK).pdf
	pdfbook2 $(BOOK).pdf
	mv $(BOOK)-book.pdf booklet.pdf
	cp booklet.pdf docs/$(BOOK)_booklet.pdf
	# creates booklet.pdf
	# Instructions for printing: https://tex.stackexchange.com/a/70115/6853
	# Briefly: (1) Print even pages. (2) Flip about an axis "out of the board." (3) Print odd pages.

# The following target creates pdf versions of the svg figures.
# For this to work, the scripts in the scripts directory need to be executable.
# Inkscape 0.47 or later is required.
# To force rendering of all figures, even if they seem up to date, do FORCE=1 make figures

check:
	make check_glosses

check_glosses:
	./scripts/check_glosses.rb

flashcards:
	make check_glosses
	./greek/create_flashcards.rb ~/a.txt Iliad-01 mnemosyne >~/a.tsv

list_principal_parts:
	make check_glosses
	./greek/list_principal_parts.rb

figures:
	@perl -e 'foreach my $$f(<iliad/figs/*.svg>) {system("scripts/render_one_figure.pl $$f $(FORCE)")}'

clean:
	rm -f *~ *.aux *.log *.idx *.toc *.ilg *.bak *.toc $(BOOK).tex

core: core/homer.json
	#

core/homer.json: scripts/make_core.rb
	mkdir -p help_gloss
	mkdir -p core
	ruby scripts/make_core.rb >core/homer.json

core_tex: iliad/core.tex
	#

iliad/core.tex: core/homer.json
	ruby scripts/make_core_tex.rb >iliad/core.tex

test:
	ruby -e "require './greek/writing.rb'; require './greek/verbs.rb'; require './greek/nouns.rb'; require './lib/multistring.rb'; require './lib/clown.r\
b'; require './lib/string_util.rb'; Verb_difficulty.test()"
