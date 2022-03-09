\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{usage}

\LoadClass[11pt]{book} % if changing the font size, change the option point_size given to InterlinearStyle's initializer as well

\newcommand{\genericgeometryoptions}{bindingoffset=0.3in, inner=0.5in, outer=0.5in}
\RequirePackage[xetex,paperheight=10in,paperwidth=7in,\genericgeometryoptions, bottom=0.5in]{geometry}
% If changing the size, change the option paper_width given to InterlinearStyle's initializer as well.
% https://tex.stackexchange.com/q/80520/6853
% Bindingoffset refers to the gutter.
% 7"x10" is one of lulu's sizes.

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
\fancyhead[CE]{\latinfont\selectfont{}Homeric usage}
\fancyhead[CO]{\latinfont\selectfont{}Homeric usage}
\fancyhead[LE]{\latinfont\selectfont{}\thepage}
\fancyhead[LO]{\latinfont\selectfont{}\rightheaderwhat}
\fancyhead[RO]{\latinfont\selectfont{}\thepage}
\renewcommand{\headrulewidth}{0pt}

\newcommand{\vocaballheader}{\textit{vocabulary}}
\newcommand{\formsheader}[1]{\textit{#1}}
\newenvironment{vocabpage}{\cleardoublepage\begin{raggedright}\setlength{\parskip}{0pt}\begin{multicols}{2}}{\end{multicols}\end{raggedright}}
\newenvironment{conjugations}{\formsheader{conjugations}\\}{}
\newenvironment{declensions}{\formsheader{declensions}\\}{}
\newenvironment{vocaball}{\vocaballheader\\}{}
\newenvironment{widespacing}{\linespread{1.5}\selectfont}{}
% ... \selectfont is needed or else \linespread won't take effect until the next change of font

\newcommand{\linenumber}[1]{\begin{mediumgraytext}{\footnotesize{}#1}\end{mediumgraytext}}
\newcommand{\leftpageverseline}[2]{\noindent\rlap{#1}\hskip 20mm minus 20mm \hbox{#2}\\}
% ... https://tex.stackexchange.com/a/605040/6853
%     The "minus 20mm" allows the text to push all the way to the left margin if necessary; to avoid making this
%     run into the line number, I have logic in verse_lines_to_latex that counts characters and omits the line
%     number on exceptionally long lines (more than max_len_for_num characters).
%     If changing the 20mm, should also change max_len_for_num in the ruby code.

\newcommand{\pagesec}[2]{p.~#1, \S #2}