default:
	fruby iliad.rbtex >iliad.tex
	xelatex iliad

clean:
	rm -f *~ *.aux *.log *.idx *.toc *.ilg *.bak *.toc iliad.tex

