\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{ransom}

\LoadClass[12pt]{book}
\RequirePackage[paperheight=9in,paperwidth=6in,bindingoffset=0.3in, left=0.5in, right=0.5in]{geometry} 
% https://tex.stackexchange.com/q/80520/6853
% Bindingoffset refers to the gutter.

% https://tex.stackexchange.com/a/37251/6853
\RequirePackage{fontspec}
\defaultfontfeatures{Ligatures=TeX,Scale=MatchLowercase}

\newcommand{\rightheaderwhatvocab}{Minivocab} % gets redefined by, e.g., greekransom.sty
\newcommand{\rightheaderwhatglosses}{Ransom notes}
\RequirePackage{greekransom}

\RequirePackage{graphicx} % needed for \resizebox
\RequirePackage{multicol,xcolor,calc,titlesec,fancyhdr}
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
\newcommand{\myransomchapter}[1]{\begin{graytext}\mychapter{#1}\end{graytext}}
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
\newcommand{\vocab}[2]{\begin{boldgreek}#1\end{boldgreek} \hardspace{1em} #2}
\newcommand{\vocabinflection}[3]{\vocab{#1}{\from{}{\greekfont #2}}, #3}
\newcommand{\common}{\textit{common}}
\newcommand{\uncommon}{\bigseparator\vspace{2mm}\textit{uncommon}}

\newenvironment{vocabpage}{\cleardoublepage\begin{raggedright}\begin{multicols}{2}}{\end{multicols}\end{raggedright}}
\newenvironment{vocabcommon}{\common\\}{}
\newenvironment{vocabuncommon}{\uncommon\\}{}
\newenvironment{widespacing}{\linespread{1.5}}{}
\newenvironment{foreignpage}{%
  \begin{greek}\begin{raggedright}\begin{widespacing} \large%
}{%
  \end{widespacing}\end{raggedright}\end{greek}\pagebreak%
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
  \vspace{-0.5\baselineskip}% % ...affects the space below, not above -- why?; but cutting this causes the hspace to have no effect
  \hspace{0.27\textwidth}%
  \noindent\makebox[\linewidth]{\resizebox{0.3333\linewidth}{1pt}{$\bullet$}}\bigskip%
  \vspace{-0.5\baselineskip}
}
% ... https://tex.stackexchange.com/a/130763/6853
\newcommand{\smallseparator}{%
  \vspace{-0.7\baselineskip}%
  \hspace{-0.01\textwidth}\noindent\makebox[\linewidth]{\resizebox{0.15\linewidth}{1pt}{$\bullet$}}%
  \vspace{-0.2\baselineskip}
}
%     Used mainly between vocab and translation, but also in some spots as a scene separator.


