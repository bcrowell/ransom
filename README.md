ransom
======

A presentation of foreign-language texts in which the text is on a left page and
glosses are shown in corresponding geometrical positions on the right page.

Although the software is designed to be fairly general, my initial use case
is [a presentation of the Iliad](https://bcrowell.github.io/ransom/).

## Card decks for Mnemosyne

The front of each card is an inflected word from the appropriate book of the Iliad,
and the back is the word's English translation and its grammatical
information. For example, if the front is ἔχωμεν, then the back is
ἔχω, to have, present 1 pl. subjunctive. The deck includes all words from
that book except for those that are extremely common (such as articles)
or extremely uncommon (an inflected form occurring only once or twice
in all of Homer). Most cards have additional information on the back,
such as etymology, cognates, genitives of nouns, and the first few
principal parts of verbs.

The information about etymology and cognates is
meant to help with memorization. In a small number of cases, I've included my own
idiosyncratic mnemonics, but usually it's more effective to make up your own.

Because verbs can have so many inflected forms, most of the cards are
of verbs. I actually find this to be helpful, since parsing verb forms
is hard and requires much more practice than parsing nouns and other parts
of speech.

The cards are tagged for Mnemosyne with tags of the form Homer,Greek,Iliad-01,
where 01 is the chapter.

The license of the decks is CC-BY-SA, and many entries are taken from
Wiktionary, which has the same license. Source code is at
https://github.com/bcrowell/ransom .
