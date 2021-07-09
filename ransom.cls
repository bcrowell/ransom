\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{ransom}

\LoadClass[12pt]{book}
\RequirePackage[paperheight=9in,paperwidth=6in,bindingoffset=0.3in, left=0.5in, right=0.5in]{geometry} 
% https://tex.stackexchange.com/q/80520/6853
% Bindingoffset refers to the gutter.

\RequirePackage{graphicx} % needed for \resizebox
\RequirePackage{multicol,xcolor,calc,titlesec}
\RequirePackage{parskip} % disables indentation at the beginning of a paragraph
\RequirePackage[absolute,overlay]{textpos}

% https://tex.stackexchange.com/a/37251/6853
\RequirePackage{fontspec}
\defaultfontfeatures{Ligatures=TeX,Scale=MatchLowercase}
\setmainfont{GFS Didot} % is said to be a good Latin font to match with Porson-style fonts; if changing this, change it on the following line as well
\newfontfamily\latinfont{GFS Didot}
\newfontfamily\greekfont{GFS Porson}
%  Also tried GFS Olga, which is also a Porson-style font; has a higher x-height than GFS Porson, and therefore matches better with Latin fonts.
%  But seems to be buggy/immature/weird. Bad/weird kerning on λλ.
\newenvironment{greek}{\greekfont}{}
\newenvironment{latin}{\latinfont}{}
% Both Olga and Porson lack real bold:
\newenvironment{boldgreek}{\fontspec{GFS Olga}[FakeBold=0.1]}{} % discontinuous behavior: 0.0 gives no bolding, 0.0001 gives quite a bit

\titleformat{\chapter}{\Large\bfseries}{}{}{}{}
\titleformat{\section}{\large\bfseries}{}{}{}{}
\titlespacing*{\chapter}{0pt}{-30pt}{10pt}
\newcommand{\mychapter}[1]{{\Large\bfseries #1}}
\newcommand{\myransomchapter}[1]{\begin{graytext}\mychapter{#1}\end{graytext}}

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
\newenvironment{foreignpage}{\begin{greek}\begin{raggedright}\begin{widespacing} \large}{\end{widespacing}\end{raggedright}\end{greek}\pagebreak}
\newenvironment{graytext}{\color{black!25}}{} % xcolor package, https://tex.stackexchange.com/a/17105/6853
\newenvironment{blacktext}{\color{black}}{} % xcolor package, https://tex.stackexchange.com/a/17105/6853


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


