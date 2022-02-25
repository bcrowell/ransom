\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{ransom}

\LoadClass[12pt]{book}

\newcommand{\genericgeometryoptions}{bindingoffset=0.3in, inner=0.5in, outer=0.5in}
\newcommand{\foreignprosebottommargin}{1.5in}
\newcommand{\foreignversebottommargin}{0.3in}
\newcommand{\othertextbottommargin}{0.5in}
% When doing poetry, I want to set the length of each page so that it ends close to a sentence break and also so that there is a reasonable
% bottom margin. But if for any reason I need a page to go a little long, I want it to extend as far as possible, rather than spilling
% over and making a two-page spread out of what was supposed to be a single page.
% But for prose, I let latex pour the text onto pages, so on foreign-prose pages I want the margin to be set to something much larger.
% In general, I want lots of whitespace on foreign-text pages, both between lines and in margins. This is partly just to limit the
% amount of text on the page to something that can be glossed reasonably. I also want space to be able to write notes in pencil,
% and I don't want to be intimidated by huge walls of text.
\newcommand{\foreignproseoutermargin}{1.2in}
% ... Extra margin on outside of foreign prose pages, for line numbers. This doesn't have to be as big as for verse, because
%     there is no such thing as a line that is too long and needs to push into the margin.
\RequirePackage[xetex,paperheight=9in,paperwidth=6in,\genericgeometryoptions, bottom=\othertextbottommargin]{geometry} 
% https://tex.stackexchange.com/q/80520/6853
% Bindingoffset refers to the gutter.

\RequirePackage{commonransom}
\RequirePackage{greekransom}

\newcommand{\formatlikechapter}[1]{{\Large\textbf{#1}}}
\newcommand{\formatlikesection}[1]{{\large\textbf{#1}}}
\newcommand{\formatlikesubsection}[1]{\textbf{#1}}
\newcommand{\formatlikesubsubsection}[1]{\textit{#1}}
\titleformat{\chapter}{\normalfont\Large\bfseries}{\thechapter}{1em}{}
\titleformat{\section}{\normalfont\large\bfseries}{\thesection}{1em}{}
\titlespacing*{\chapter}{0pt}{-30pt}{10pt}
\newcommand{\mychapter}[1]{\formatlikechapter{#1}}
\setlength\headheight{15pt} % https://tex.stackexchange.com/questions/327285/what-does-this-warning-mean-fancyhdr-and-headheight

%--- fancyhdr ---
% https://www.overleaf.com/learn/latex/Headers_and_footers
\newcommand{\leftheaderinfo}{}
\newcommand{\rightheaderinfo}{}
\newcommand{\leftheaderwhat}{}
\newcommand{\rightheaderwhat}{}
\pagestyle{fancy}
\fancyhf{}
\fancyhead[CE]{ΙΛΙΑΣ \leftheaderinfo} % or Ἰλιάς
\fancyhead[LE]{\thepage}
\fancyhead[LO]{\rightheaderwhat}
\fancyhead[CO]{ΙΛΙΑΣ \rightheaderinfo}
\fancyhead[RO]{\thepage}
\renewcommand{\headrulewidth}{0pt}

\newcommand{\vocaballheader}{\textit{vocabulary}}
\newcommand{\formsheader}[1]{\textit{#1}}
\newenvironment{vocabpage}{\cleardoublepage\begin{raggedright}\setlength{\parskip}{0pt}\begin{multicols}{2}}{\end{multicols}\end{raggedright}}
\newenvironment{conjugations}{\formsheader{conjugations}\\}{}
\newenvironment{declensions}{\formsheader{declensions}\\}{}
\newenvironment{vocaball}{\vocaballheader\\}{}
\newenvironment{widespacing}{\linespread{1.5}\selectfont}{}
% ... \selectfont is needed or else \linespread won't take effect until the next change of font
\newenvironment{foreignprose}%
     {\sloppy\newgeometry{bottom=\foreignprosebottommargin,outer=\foreignproseoutermargin}\begin{widespacing}}%
     {\end{widespacing}\restoregeometry}
\newenvironment{foreignverse}{%
  \expandafter\newgeometry\expandafter{\genericgeometryoptions,bottom=\foreignversebottommargin}
  % ... re the expandafter stuff, see https://tex.stackexchange.com/q/631609
  % ... If I don't reiterate the generic values here, then they seem to get reset to the default valuee. The symptom is that
  %     long lines push out into margin where they didn't before, e.g., Iliad 1.10, as a side-effect of an unintended
  %     reduction of the inner margin
  %     https://tex.stackexchange.com/questions/631609/changing-some-options-in-newgeometry-while-retaining-all-others-by-default
  \begin{raggedright}\begin{widespacing} \large%
}{%
  \end{widespacing}\end{raggedright}\restoregeometry\pagebreak%
}

\newcommand{\linenumber}[1]{\begin{mediumgraytext}{\footnotesize{}#1}\end{mediumgraytext}}
\newcommand{\leftpageverseline}[2]{\noindent\rlap{#1}\hskip 20mm minus 20mm \hbox{#2}\\}
% ... https://tex.stackexchange.com/a/605040/6853
%     The "minus 20mm" allows the text to push all the way to the left margin if necessary; to avoid making this
%     run into the line number, I have logic in verse_lines_to_latex that counts characters and omits the line
%     number on exceptionally long lines (more than max_len_for_num characters).
%     If changing the 20mm, should also change max_len_for_num in the ruby code.




