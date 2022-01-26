\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{ransom}

\LoadClass[12pt]{book}

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
\RequirePackage[xetex,paperheight=9in,paperwidth=6in,bindingoffset=0.3in, inner=0.5in, outer=0.5in, bottom=\othertextbottommargin]{geometry} 
% https://tex.stackexchange.com/q/80520/6853
% Bindingoffset refers to the gutter.

\RequirePackage{silence}

% https://tex.stackexchange.com/a/37251/6853
\RequirePackage{fontspec}
\defaultfontfeatures{Ligatures=TeX,Scale=MatchLowercase}

\newcommand{\rightheaderwhatvocab}{Minivocab} % gets redefined by, e.g., greekransom.sty
\newcommand{\rightheaderwhatglosses}{Ransom notes}
\RequirePackage{greekransom}

\RequirePackage{graphicx} % needed for \resizebox
\RequirePackage{multicol,xcolor,calc,titlesec,fancyhdr,hyphenat,ifthen}
\RequirePackage{parskip} % disables indentation at the beginning of a paragraph
\RequirePackage[absolute,overlay]{textpos}

\newcommand{\formatlikechapter}[1]{{\Large\textbf{#1}}}
\newcommand{\formatlikesection}[1]{{\large\textbf{#1}}}
\newcommand{\formatlikesubsection}[1]{\textbf{#1}}
\newcommand{\formatlikesubsubsection}[1]{\textit{#1}}
\titleformat{\chapter}{\Large\bfseries}{}{}{}{}
\titleformat{\section}{\large\bfseries}{}{}{}{}
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

% A symbol to be used like κύνεσσιν < κύων, to show A is an inflected form of B.
%%%% \newcommand{\from}{$\prec$\hardspace{0.2em}} % or \textless
\newcommand{\from}{\raisebox{.25ex}{{\tiny{$\prec$}}}\hardspace{0.2em}}

\newcommand{\hardspace}[1]{\unskip\hspace{#1}\ignorespaces} % https://tex.stackexchange.com/a/89096/6853
\newcommand{\vocabbasic}[2]{\begin{boldgreek}#1\end{boldgreek} \hardspace{1em} #2}
\newcommand{\vocabwithcogbasic}[3]{\begin{boldgreek}#1\end{boldgreek} \hardspace{1em} #2 $\sim$\emph{#3}}
\newcommand{\vocab}[2]{\glosstrailingrightpara{\vocabbasic{#1}{#2}}}
\newcommand{\vocabwithcog}[3]{\glosstrailingrightpara{\vocabwithcogbasic{#1}{#2}{#3}}}
\newcommand{\vocabnospace}[2]{\begin{boldgreek}#1\end{boldgreek} #2}
\newcommand{\vocabinflection}[3]{\glosstrailingrightpara{\vocabnospace{#1}{\from{}{\greekfont #2}}, #3}}
\newcommand{\vocabnouninflection}[3]{\vocabinflection{#1}{#2}{#3}}
\newcommand{\vocabverbinflection}[3]{\vocabinflection{#1}{#2}{#3}}
\newcommand{\vocabinflectiononly}[2]{\vocab{#1}{\from{}{\greekfont #2}}}
\newcommand{\vocaballheader}{\textit{vocabulary}}
\newcommand{\formsheader}[1]{\textit{#1}}

%------------------------------------------------------------------
% Code for typesetting glossary entries. When an entry is one line, left-justify it. When it's more than
% one line, justify it, but right-justify the final line -- currently disabled, see below.
% https://tex.stackexchange.com/a/630789/261851
% Macro to typeset a paragraph so that if it's a single line, it's left-justified, but if it's multiple lines,
% it's justified except for the last line, which is right-justified.
\newcommand{\xglosstrailingrightpara}[1]{\CalcNumber{#1}{\columnwidth}{\NLines}\ifthenelse{\NLines>1}{\glossmultiline{#1\par}}{#1\par}}
% ... x in front is so it's disabled
\newcommand{\glosstrailingrightpara}[1]{#1\par}
% ... go back to doing it the normal-looking way instead

% https://tex.stackexchange.com/a/406722
% For a single paragraph of text, determines how many lines it will take to typeset.
% #1=text, #2=width, #3=variable to store result in
\def\CalcNumber#1#2#3{%
  \setbox0\vbox{\hsize=#2 \noindent#1\par\xdef#3{\the\prevgraf}}}

% https://tex.stackexchange.com/a/43239/261851
% Typeset a paragraph so that the text is justified, and the final line is right-aligned:
\newcommand{\lastlinerightaligned}[1]{\begingroup \leftskip=0pt plus .5fil\rightskip=0pt plus -.5fil\parfillskip=0pt plus .5fil{}#1\par \endgroup}

\newcommand{\glossmultiline}[1]{\lastlinerightaligned{\nohyphens{#1}}}


%------------------------------------------------------------------

\newenvironment{vocabpage}{\cleardoublepage\begin{raggedright}\setlength{\parskip}{0pt}\begin{multicols}{2}}{\end{multicols}\end{raggedright}}
\newenvironment{conjugations}{\formsheader{conjugations}\\}{}
\newenvironment{declensions}{\formsheader{declensions}\\}{}
\newenvironment{vocaball}{\vocaballheader\\}{}
\newenvironment{widespacing}{\linespread{1.5}\selectfont}{}
% ... \selectfont is needed or else \linespread won't take effect until the next change of font
\newenvironment{foreignprose}{\sloppy\newgeometry{bottom=\foreignprosebottommargin,outer=\foreignproseoutermargin}\begin{widespacing}}{\end{widespacing}\restoregeometry}
\newenvironment{foreignverse}{%
  \newgeometry{bottom=\foreignversebottommargin}%
  \begin{raggedright}\begin{widespacing} \large%
}{%
  \end{widespacing}\end{raggedright}\restoregeometry\pagebreak%
}

% xcolor package, https://tex.stackexchange.com/a/17105/6853
\newenvironment{graytext}{\color{black!25}}{}
\newenvironment{mediumgraytext}{\color{black!50}}{} % used for line numbers
\newenvironment{blacktext}{\color{black}}{}
\newenvironment{whitetext}{\color{white}}{}

\newcommand{\linenumber}[1]{\begin{mediumgraytext}{\footnotesize{}#1}\end{mediumgraytext}}
\newcommand{\leftpageverseline}[2]{\noindent\rlap{#1}\hskip 20mm minus 20mm \hbox{#2}\\}
% ... https://tex.stackexchange.com/a/605040/6853
%     The "minus 20mm" allows the text to push all the way to the left margin if necessary; to avoid making this
%     run into the line number, I have logic in verse_lines_to_latex that counts characters and omits the line
%     number on exceptionally long lines (more than max_len_for_num characters).
%     If changing the 20mm, should also change max_len_for_num in the ruby code.

% The following need to be in their own separate paragraphs.
\newcommand{\bigseparator}{
  \par
  %\vspace{-0.5\baselineskip}% % ...affects the space below, not above -- why?; but cutting this causes the hspace to have no effect
  %\hspace{0.27\textwidth}%
  \noindent\makebox[\linewidth]{\resizebox{0.3333\linewidth}{1pt}{$\bullet$}}
  %\bigskip%
  \vspace{-1.25\baselineskip}
  \par
}
% ... https://tex.stackexchange.com/a/130763/6853
\newcommand{\smallseparator}{%
  \vspace{-0.7\baselineskip}%
  \hspace{-0.01\textwidth}\noindent\makebox[\linewidth]{\resizebox{0.15\linewidth}{1pt}{$\bullet$}}%
  \vspace{-0.2\baselineskip}
}
%     Used mainly between vocab and translation, but also in some spots as a scene separator.


% https://texblog.org/2011/04/19/highlight-table-rowscolumns-with-color/
\RequirePackage{color,colortbl}
\definecolor{TableColorA}{rgb}{1,0.725,0.725}
\definecolor{TableColorB}{rgb}{0.875,0.875,1}

\usepackage[para]{footmisc}
% https://tex.stackexchange.com/questions/28736/footnotes-on-the-same-line
