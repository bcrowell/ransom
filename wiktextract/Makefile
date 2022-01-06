default:
	curl -o kaikki.json https://kaikki.org/dictionary/Ancient%20Greek/kaikki.org-dictionary-AncientGreek.json
	ruby 100_clean_unicode.rb <kaikki.json >temp.json
	ruby 200_remove_stuff.rb <temp.json >temp2.json
	du -sh *.json
	# echo "If everything looks OK, you can do this: mv temp2.json grc_en.json && rm -f kaikki.json temp.json"


