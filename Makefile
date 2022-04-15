BOOK = iliad
POS = $(BOOK).pos
GENERIC = "pos_file":"$(POS)"
.PHONY: clean default check check_glosses core update_github_pages reconfigure_git book_no_post post flush_epos_cache test_epos dbs

default:
	@make --no-print-directory --assume-new iliad.rbtex iliad-i.pdf

iliad-i.pdf: export FORMAT=whole
iliad-i.pdf: export OVERWRITE=1
iliad-i.pdf: export VOL=i
iliad-i.pdf: lib/*rb eruby_ransom.rb iliad.rbtex iliad/core.tex lemmas/homer_lemmas.line_index.json
	make book_no_post
	@sort help_gloss/__links.html | uniq >a.a && mv a.a help_gloss/__links.html

iliad-ii.pdf: export FORMAT=whole
iliad-ii.pdf: export OVERWRITE=1
iliad-ii.pdf: export VOL=ii
iliad-ii.pdf: lib/*rb eruby_ransom.rb iliad.rbtex iliad/core.tex lemmas/homer_lemmas.line_index.json
	make book_no_post
	@sort help_gloss/__links.html | uniq >a.a && mv a.a help_gloss/__links.html

post: iliad-i.pdf iliad-ii.pdf
	cp iliad-i.pdf ~/Lightandmatter/iliad
	cp iliad-ii.pdf ~/Lightandmatter/iliad

booklet.pdf: lib/*rb eruby_ransom.rb iliad.rbtex iliad/core.tex
	make booklet

booklet: export FORMAT=booklet_short
booklet: lib/*rb eruby_ransom.rb iliad.rbtex iliad/core.tex
	make book_no_post
	pdfbook2 temp.pdf && rm -f temp.pdf
	mv temp-book.pdf booklet.pdf
	# creates booklet.pdf
	# Instructions for printing: https://tex.stackexchange.com/a/70115/6853
	# Briefly: (1) Print even pages. (2) Flip about an axis "out of the board." (3) Print odd pages.

book_no_post: lib/*rb greek/*rb eruby_ransom.rb iliad.rbtex iliad/core.tex
	# makes temp.pdf, which may be either the whole book or some portion, such as the first half of book 1
	@rm -f warnings help_gloss/__links.html
	@make figures # renders any figure whose pdf is older than its svg
	@./fruby $(BOOK).rbtex '{$(GENERIC),"vol":"$(VOL)","clean":true,"if_warn":true}' >temp.tex
	xelatex temp
	mv temp.aux $(BOOK)-$(VOL).aux
	[ "$(OVERWRITE)" = "1" ] && mv temp.pdf $(BOOK)-$(VOL).pdf ; true
	@./fruby $(BOOK).rbtex '{$(GENERIC),"vol":"$(VOL)","write_pos":true,"check_aux":"$(BOOK)-$(VOL).aux"}' >temp.tex
	xelatex temp
	[ "$(OVERWRITE)" = "1" ] && mv temp.pdf $(BOOK)-$(VOL).pdf ; true
	@./fruby $(BOOK).rbtex '{$(GENERIC),"vol":"$(VOL)","render_glosses":true}' >temp.tex
	xelatex temp
	[ "$(OVERWRITE)" = "1" ] && mv temp.pdf $(BOOK)-$(VOL).pdf ; true

usage: usage.rbtex lib/*rb greek/*rb iliad/core.tex
	@./fruby usage.rbtex '{}' >temp_usage.tex
	xelatex temp_usage
	mv temp_usage.pdf usage.pdf
	xelatex temp_usage
	mv temp_usage.pdf usage.pdf

usage_bbcode: usage.rbtex lib/*rb greek/*rb iliad/core.tex
	@./fruby usage.rbtex '{"format":"bbcode"}' >usage.bbcode
	perl -0777 -i -pe "s/\n{3,}/\n\n/gs" usage.bbcode

dry_run: export DRY_RUN=1
dry_run: export FORMAT=whole
dry_run: lib/*rb eruby_ransom.rb iliad.rbtex iliad/core.tex
	@echo "checking that Epos globs are valid, doing sanity checks on their results..."
	./fruby $(BOOK).rbtex '{$(GENERIC),"clean":true,"if_warn":true}' >$(BOOK).tex

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
	rm -f glosses/*~ glosses/_latin/*~ help_gloss/*~
	rm -f lemmas/explain.txt lemmas/unmatched.txt


lemmas/homer_lemmas.line_index.json: lemmas/homer_lemmas.csv
	make dbs

dbs:
	make -C lemmas dbs

core: core/homer.json
	#

core/homer.json: scripts/make_core.rb
	mkdir -p help_gloss
	mkdir -p core
	ruby scripts/make_core.rb >core/homer.json

core_tex: iliad/core.tex
	#

iliad/core.tex: export FORMAT = tex
iliad/core.tex: core/homer.json
	ruby scripts/make_core_tex.rb >iliad/core.tex

core.txt: export FORMAT = txt
core.txt: core/homer.json
	ruby scripts/make_core_tex.rb >core.txt

latin_core:
	ruby scripts/make_dickinson_latin_core.rb >core/latin.json

test:
	ruby -e "require './greek/adjectives.rb'; require './lib/multistring.rb'; require './lib/string_util.rb'; Adjective.test()"
	ruby -e "require './greek/writing.rb'; require './greek/verbs.rb'; require './greek/nouns.rb'; require './lib/multistring.rb'; require './lib/clown.r\
b'; require './lib/string_util.rb'; Verb_difficulty.test()"

flush_epos_cache:
	rm -f text/*.cache.* text/*.cache.*/

test_epos:
	ruby -e "require './lib/epos.rb'; require './lib/file_util.rb'; require 'json'; require './lib/string_util.rb'; require './lib/clown.rb'; Epos.run_tests()"

demo: export FORMAT=whole
demo: export OVERWRITE=1
demo: lib/*rb eruby_ransom.rb demo.rbtex
	@rm -f warnings help_gloss/__links.html
	@./fruby demo.rbtex '{"pos_file":"demo.prose","write_pos":true,"clean":true,"prose_trial_run":true}' >temp_demo.tex
	cp temp_demo.tex c.tex
	xelatex temp_demo
	./scripts/scrape_prose_layout.rb <demo.prose >demo.para
	@./fruby demo.rbtex '{"pos_file":"demo.pos","clean":true,"if_warn":true}' >temp_demo.tex
	cp temp_demo.tex d.tex
	xelatex temp_demo
	[ "$(OVERWRITE)" = "1" ] && mv temp_demo.pdf demo.pdf ; true
	@./fruby demo.rbtex '{"pos_file":"demo.pos","write_pos":true}' >temp_demo.tex
	cp temp_demo.tex e.tex
	xelatex temp_demo
	[ "$(OVERWRITE)" = "1" ] && mv temp_demo.pdf demo.pdf ; true
	@./fruby demo.rbtex '{"pos_file":"demo.pos","render_glosses":true}' >temp_demo.tex
	xelatex temp_demo
	[ "$(OVERWRITE)" = "1" ] && mv temp_demo.pdf demo.pdf ; true
