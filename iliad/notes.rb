class IliadNotes

@@notes = {
  "1.9" => {
    'about_what'    => %q{Λητοῦς καὶ Διὸς υἱός},
    'explain'       => %q{Apollo}
  },
  "1.25" => {
    'about_what'    => %q{ἐπὶ \ldots ἔτελλε},
    'explain'       => %q{ἐπὶ τέλλω: to command (lit.~``accomplish on'')},
    'prevent_gloss' =>['τέλλω']
  },
  "1.28" => {
    'about_what'    => %q{χραίσμῃ},
    'explain'       => %q{singular verb whose subject is ``staff and fillet''},
    'cite'          => "https://www.textkit.com/greek-latin-forum/viewtopic.php?f=22&t=71155"
  },
  "1.34" => {
    'about_what'    => %q{πολυφλοίσβοιο},
    'explain'       => %q{2-2 adjective, archaic form of the genitive},
    'cite'          => "Smyth 230, http://www.perseus.tufts.edu/hopper/text?doc=Perseus%3Atext%3A1999.04.0007%3Apart%3D2%3Achapter%3D13%3Asection%3D15"
  },
  "1.39" => {
    'about_what'    => %q{Σμινθεῦ},
    'explain'       => %q{The meaning of this epithet for Apollo is unknown, and traditional interpretations such as ``mouse'' or ``mouse-killer''
                          are attempts to explain this verse in Homer. },
    'prevent_gloss' =>['Σμινθεῦ'],
    'cite'          =>"https://en.wikipedia.org/wiki/Hamaxitus#Apollo_Smintheus"
  },
}

def IliadNotes.notes
  return @@notes
end

end
