class IliadNotes

@@notes = [
  ["1.3" , {
    'about_what'    => %q{Ἄϊδι},
    'explain'       => %q{referring to the god, not the place},
    'cite'          => "Anthon, p. 127; Cunliffe, p. 453, suggests the place would be δῶμα ~?; form with diaresis is ionic/poetic"
  }],
  ["1.6" , {
    'about_what'    => %q{δὴ},
    'explain'       => %q{Anthon thinks that here this word means at a specific moment in time. The line as a whole may be describing the point when the muse is asked to start singing, or the time when Zeus formulated his plan.},
    'cite'          => "Anthon, p. 127"
  }],
  # https://latin.stackexchange.com/questions/17341/iliad-1-6-when-they-first-stood-apart-in-strife-can-this-be-read-as-when-th
  ["1.9" , {
    'about_what'    => %q{Λητοῦς καὶ Διὸς υἱός},
    'explain'       => %q{Apollo}
  }],
  ["1.10" , {
    'about_what'    => %q{ἀνὰ},
    'explain'       => %q{+acc, here meaning throughout},
    'cite'          => "Anthon, p. 128"
  }],
  ["1.16" , {
    'about_what'    => %q{Ἀτρεΐδα δὲ μάλιστα δύω, κοσμήτορε λαῶν},
    'explain'       => %q{referring to Agamemnon and Menelaus},
    'cite'          => "Anthon, p. 128"
  }],
  ["1.25" , {
    'about_what'    => %q{ἐπὶ \ldots ἔτελλε},
    'explain'       => %q{ἐπὶ τέλλω: to command (lit.~``accomplish on'')},
    'prevent_gloss' =>['τέλλω']
  }],
  ["1.28" , {
    'about_what'    => %q{νύ},
    'explain'       => %q{=νυν},
    'cite'          => "Anthon, p. 131"
  }],
  ["1.28" , {
    'about_what'    => %q{χραίσμῃ},
    'explain'       => %q{singular verb whose subject is ``staff and fillet''},
    'cite'          => "https://www.textkit.com/greek-latin-forum/viewtopic.php?f=22&t=71155"
  }],
  ["1.32" , {
    'about_what'    => %q{ἴθι},
    'explain'       => %q{imperative of εἶμι, come, go},
    'cite'          => "https://logeion.uchicago.edu/%E1%BC%B4%CE%B8%CE%B9"
  }],
  ["1.34" , {
    'about_what'    => %q{πολυφλοίσβοιο},
    'explain'       => %q{2-2 adjective, archaic form of the genitive},
    'cite'          => "Smyth 230, http://www.perseus.tufts.edu/hopper/text?doc=Perseus%3Atext%3A1999.04.0007%3Apart%3D2%3Achapter%3D13%3Asection%3D15"
  }],
  ["1.34" , {
    'about_what'    => %q{ἠρᾶθ᾽},
    'explain'       => %q{elided from ἠρᾶτο, contracted imperfect of ἀράομαι}
  }],
  ["1.39" , {
    'about_what'    => %q{Σμινθεῦ},
    'explain'       => %q{The meaning of this epithet for Apollo is unknown, and traditional interpretations such as ``mouse-killer''
                          are attempts to explain this verse in Homer. Σμίνθος=mouse, Σμίνθη=place name. The suffix -ευς indicates a person
                          related to a thing.},
    'prevent_gloss' =>['Σμινθεῦ'],
    'cite'          =>"https://en.wikipedia.org/wiki/Hamaxitus#Apollo_Smintheus"
  }],
  ["1.40" , {
    'about_what'    => %q{ἢ εἰ δή ποτέ},
    'explain'       => %q{or if ever, before this time},
    'cite'          => "Anthon, p. 135"
  }],
  ["1.40" , {
    'about_what'    => %q{κατὰ},
    'explain'       => %q{completely},
    'cite'          => "Anthon, p. 135"
  }],
  ["1.56" , {
    'about_what'    => %q{ὅτι ῥα},
    'explain'       => %q{epic form of ὅτι ἄρα, because},
    'cite'          => "Anthon, p. 138"
  }],
  ["1.60" , {
    'about_what'    => %q{εἴ κεν \\ldots γε},
    'explain'       => %q{if perchance \\ldots at least},
    'cite'          => "Anthon, p. 139"
  }],
  ["1.67" , {
    'about_what'    => %q{ἡμῖν ἀπὸ},
    'explain'       => %q{ἀπὸ is an adverb modifying ἡμῖν, not a preposition modifying λοιγὸν},
    'cite'          => "Anthon, p. 141"
  }],
  ["1.82" , {
    'about_what'    => %q{καταπέψῃ},
    'explain'       => %q{Literally, digest. Metaphorically, to keep down one's resentment.},
    'cite'          => "Anthon, p. 142"
  }],
  ["1.100" , {
    'about_what'    => %q{πεπίθοιμεν},
    'explain'       => %q{Epic reduplicated form of πείθω, optative.},
    'cite'          => "https://en.wiktionary.org/wiki/%CF%80%CE%B5%CE%AF%CE%B8%CF%89"
  }],
  ["1.104" , {
    'about_what'    => %q{ἐΐκτην},
    'explain'       => %q{Pluperfect dual of ἔοικα. The perfect and pluperfect of this verb mean ``to be like'' (here) or ``to beseem.''},
    'cite'          => "https://en.wiktionary.org/wiki/%E1%BC%94%CE%BF%CE%B9%CE%BA%CE%B1"
  }],
  ["1.104" , {
    'about_what'    => %q{ἕλωμαι},
    'explain'       => %q{Middle voice of εἷλον, aorist of αἱρέω, to take, seize. The middle suggests that the taking is a personal choice or for oneself. Cognate with ἑλώριον, booty, spoils.},
    'cite'          => "https://en.wiktionary.org/wiki/%E1%BC%94%CE%BF%CE%B9%CE%BA%CE%B1"
  }],
  ["1.141" , {
    'about_what'    => %q{ἅλα δῖαν},
    'explain'       => %q{a set phrase, divine or bright sea}
  }],
  ["1.113" , {
    'about_what'    => %q{προβέβουλα},
    'explain'       => %q{The use of the perfect is common in describing a permanent present mental state, and can also show intensity.}
  }],
  ["1.114" , {
    'about_what'    => %q{κουριδίης ἀλόχου},
    'explain'       => %q{Literally ``wedded bedmate,'' describing Clytemnestra. He compares his wife with his sex slave Chryseis, who is his unwedded bedmate. (The later, opposite sense of ἄλοχος as ``virgin''  is not found in Homer.)}
  }],
  ["1.170" , {
    'about_what'    => %q{οὐδέ σ᾽ ὀΐω},
    'explain'       => %q{But neither do I think that for your sake}
  }],
  ["1.371" , {
    'about_what'    => %q{},
    'explain'       => %q{Nine lines are repeated verbatim from 1.12-25.}
  }],
]

def IliadNotes.notes
  return @@notes
end

end
