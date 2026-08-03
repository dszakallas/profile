\ProvidesClass{cv}[2017/01/08 CV class]
\LoadClass{article}
\NeedsTeXFormat{LaTeX2e}

%----------------------------------------------------------------------------------------
%	 REQUIRED PACKAGES
%----------------------------------------------------------------------------------------

\RequirePackage[T1]{fontenc}
\RequirePackage{tikz}
\RequirePackage{xcolor}
\RequirePackage[absolute,overlay]{textpos}
\RequirePackage{ragged2e}
\RequirePackage{etoolbox}
\RequirePackage{ifmtarg}
\RequirePackage{ifthen}
\RequirePackage{pgffor}
\RequirePackage{parskip}
\RequirePackage{xspace}
\RequirePackage{graphicx}
\RequirePackage{fontawesome5}
\RequirePackage{charter}

\DeclareOption*{\PassOptionsToClass{\CurrentOption}{article}}
\ProcessOptions\relax

%----------------------------------------------------------------------------------------
%	 VARIABLES
%----------------------------------------------------------------------------------------

\newcommand{\ie}{i.e.,\xspace}
\newcommand{\Ie}{I.e.,\xspace}
\newcommand{\eg}{e.g.,\xspace}
\newcommand{\Eg}{E.g.,\xspace}
\newcommand{\etal}{et al.\@\xspace}
\newcommand{\etc}{etc.\@\xspace}
\newcommand{\vs}{vs.\@\xspace}
\newcommand{\viz}{viz.\@\xspace} % videlicet
\newcommand{\cf}{cf.\@\xspace} % confer
\newcommand{\Cf}{Cf.\@\xspace}
\newcommand{\wrt}{w.r.t.\@\xspace} % with respect to
\newcommand{\cpp}{C\texttt{++}}

%----------------------------------------------------------------------------------------
%	 COLOURS
%----------------------------------------------------------------------------------------

\definecolor{white}{RGB}{255,255,255}
\definecolor{gray}{HTML}{4D4D4D}
\definecolor{sidecolor}{HTML}{E7E7E7}
\definecolor{mainblue}{HTML}{0E5484}
\definecolor{maingray}{HTML}{B9B9B9}
\definecolor{chiphard}{HTML}{333333}
\definecolor{chipsoft}{HTML}{0E5484}

%----------------------------------------------------------------------------------------
%	 CHIPS / TAGS
%----------------------------------------------------------------------------------------

\newcommand{\hardchip}[1]{%
  \tikz[baseline=-0.5ex]{\node[draw=none, fill=chiphard, text=white, rounded corners=1.5pt, inner xsep=2.5pt, inner ysep=1pt, minimum height=8.5pt, text height=4.8pt, text depth=1.2pt, font=\fontsize{6pt}{7pt}\selectfont] {#1};}%
}

\newcommand{\softchip}[1]{%
  \tikz[baseline=-0.5ex]{\node[draw=none, fill=chipsoft, text=white, rounded corners=1.5pt, inner xsep=2.5pt, inner ysep=1pt, minimum height=8.5pt, text height=4.8pt, text depth=1.2pt, font=\fontsize{6pt}{7pt}\selectfont] {#1};}%
}

%----------------------------------------------------------------------------------------
%	 MISC CONFIGURATIONS
%----------------------------------------------------------------------------------------
\renewcommand{\familydefault}{\rmdefault}

\pagestyle{empty} % Disable headers and footers

\setlength{\parindent}{0pt} % Disable paragraph indentation

%----------------------------------------------------------------------------------------
%	 SIDEBAR DEFINITIONS
%----------------------------------------------------------------------------------------

\setlength{\TPHorizModule}{1cm} % Left margin
\setlength{\TPVertModule}{1cm} % Top margin

\newlength\imagewidth
\newlength\imagescale
\pgfmathsetlength{\imagewidth}{5cm}
\pgfmathsetlength{\imagescale}{\imagewidth/600}

\newlength{\TotalSectionLength} % Define a new length to hold the remaining line width after the section title is printed
\newlength{\SectionTitleLength} % Define a new length to hold the width of the section title
\newcommand{\profilesection}[1]{%
	\setlength\TotalSectionLength{\linewidth}% Set the total line width
	\settowidth{\SectionTitleLength}{\Large\bfseries #1 }% Calculate the width of the section title
	\addtolength\TotalSectionLength{-\SectionTitleLength}% Subtract the section title width from the total width
	\addtolength\TotalSectionLength{-2.22221pt}% Modifier to remove overfull box warning
	\vspace{4pt}% Whitespace before the section title
	{\color{black!80} \Large\bfseries #1 \rule[0.2\baselineskip]{\TotalSectionLength}{0.8pt}}% Print the title and auto-width rule
}

% Define custom commands for CV info
\newcommand{\cvdate}[1]{\def\@cvdate{#1}}
\newcommand{\cvmail}[1]{\def\@cvmail{#1}}
\newcommand{\cvnumberphone}[1]{\def\@cvnumberphone{#1}}
\newcommand{\cvaddress}[1]{\def\@cvaddress{#1}}
\newcommand{\cvsite}[1]{\def\@cvsite{#1}}
\newcommand{\cvgithub}[1]{\def\@cvgithub{#1}}
\newcommand{\cvlinkedin}[1]{\def\@cvlinkedin{#1}}
\newcommand{\aboutme}[1]{\def\@aboutme{#1}}
\newcommand{\profilepic}[1]{\def\@profilepic{#1}}
\newcommand{\cvname}[1]{\def\@cvname{#1}}
\newcommand{\cvjobtitle}[1]{\def\@cvjobtitle{#1}}
\newcommand{\citizenship}[1]{\def\@citizenship{#1}}
\newcommand{\languages}[1]{\def\@languages{#1}}

% Initialize empty
\let\@cvdate\@empty
\let\@cvmail\@empty
\let\@cvnumberphone\@empty
\let\@cvaddress\@empty
\let\@cvsite\@empty
\let\@cvgithub\@empty
\let\@cvlinkedin\@empty
\let\@aboutme\@empty
\let\@profilepic\@empty
\let\@cvname\@empty
\let\@cvjobtitle\@empty
\let\@citizenship\@empty
\let\@languages\@empty

% Command for printing the contact information icons
\newcommand*\icon[1]{\tikz[baseline=(char.base)]{\node[shape=circle,draw=mainblue,inner sep=2pt, fill=mainblue,text=white] (char) {\makebox[1em][c]{\small #1}};}}

% Command for printing a skill group with stacked bars
\newcommand{\skillgroup}[2]{%
	\par\vspace{2pt}%
	{\textbf{\small #1}}\par\vspace{1.5pt}%
	\noindent\begin{tikzpicture}[x=\linewidth, y=1cm, baseline=(current bounding box.south)]
		\foreach [count=\i] \x/\y in {#2}{
			\pgfmathsetmacro{\ypos}{-(\i-1)*0.33}
			\pgfmathsetmacro{\fillw}{min(\y/10.0, 1.0)}
			% Background track
			\fill[black!30] (0, \ypos) rectangle (1, \ypos - 0.31);
			% Filled progress
			\fill[mainblue] (0, \ypos) rectangle (\fillw, \ypos - 0.31);
			% Dividing hairline between stacked bars
			\draw[white, line width=0.3pt] (0, \ypos) -- (1, \ypos);
			% Skill title
			\node[anchor=west, inner sep=0pt, font=\fontsize{6pt}{6.5pt}\sffamily\bfseries, text=white] at (0.02, \ypos - 0.155) {\x};
			% Years on the right
			\node[anchor=east, inner sep=0pt, font=\fontsize{5.5pt}{6pt}\sffamily\bfseries, text=white!95] at (0.98, \ypos - 0.155) {\y\ y};
		}
	\end{tikzpicture}\par\vspace{1pt}%
}

\newcommand\skills[1]{\def\@skills{#1}}
\let\@skills\@empty

%----------------------------------------------------------------------------------------
%	 SIDEBAR LAYOUT
%----------------------------------------------------------------------------------------

\newcommand{\makeprofile}{%
	\begin{textblock}{6.2}(0.25, 0.3)%
		\ifx\@profilepic\@empty\else
			\begin{center}
				\begin{tikzpicture}[x=\imagescale,y=-\imagescale]
					\clip (600/2, 567/2) circle (567/2);
					\node[anchor=north west, inner sep=0pt, outer sep=0pt] at (0,0) {\includegraphics[width=\imagewidth]{\@profilepic}};
				\end{tikzpicture}
			\end{center}
		\fi

		{\Huge\color{mainblue}\@cvname}\par
		\vspace{2pt}
		{\Large\color{black!80}\@cvjobtitle}\par
		\vspace{4pt}
		\renewcommand{\arraystretch}{1.2}
		\begin{tabular}{@{}l@{\hspace{0.2cm}}l @{\hspace{0.35cm}} l@{\hspace{0.2cm}}l@{}}
			\ifx\@cvdate\@empty\else\icon{\faCalendar*} & \multicolumn{3}{l}{\@cvdate}\\ \fi
			\ifx\@cvaddress\@empty\else\icon{\faMapMarker*} & \multicolumn{3}{l}{\@cvaddress}\\ \fi
			\ifx\@cvnumberphone\@empty\else\icon{\faPhone*} & \multicolumn{3}{l}{\href{tel:\@cvnumberphone}{\@cvnumberphone}}\\ \fi
			\ifx\@cvmail\@empty\else\icon{\faEnvelope} & \multicolumn{3}{l}{\href{mailto:\@cvmail}{\@cvmail}}\\ \fi
			\ifx\@cvgithub\@empty\else\icon{\faGithub} & \href{https://github.com/\@cvgithub}{\@cvgithub}\fi & \ifx\@cvsite\@empty\else\icon{\faGlobe} & \href{https://\@cvsite}{\@cvsite}\fi \\
			\ifx\@cvlinkedin\@empty\else\icon{\faLinkedinIn} & \href{https://www.linkedin.com/in/\@cvlinkedin}{\@cvlinkedin}\fi & & \\
		\end{tabular}\par
		\ifx\@aboutme\@empty\else
			\profilesection{About}
			\begin{flushleft}
				\@aboutme
			\end{flushleft}
		\fi
		\ifx\@skills\@empty\else
			\profilesection{Skills}
			\@skills
		\fi
		\ifx\@citizenship\@empty\ifx\@languages\@empty\else
			\profilesection{Misc}
			\begin{flushleft}
				\textbf{\small Languages}\\ \small\@languages
			\end{flushleft}
		\fi\else
			\profilesection{Misc}
			\begin{flushleft}
				\textbf{\small Citizenship}\\ \small\@citizenship\par\vspace{2pt}
				\ifx\@languages\@empty\else
					\textbf{\small Languages}\\ \small\@languages
				\fi
			\end{flushleft}
		\fi
	\end{textblock}%
}

%----------------------------------------------------------------------------------------
%	 COLOURED SECTION TITLE BOX
%----------------------------------------------------------------------------------------

% Command to create the rounded boxes around the first three letters of section titles
\newcommand*\round[2]{%
	\tikz[baseline=(char.base)]\node[anchor=north west, draw,rectangle, rounded corners, inner sep=2pt, minimum width=\textwidth, minimum height=5.4mm, text height=3.2mm, fill=#2,#2,text=white](char){\scshape #1};%
}

\newcommand{\sectioncolor}[1]{%
	{%
		\round{#1}{mainblue}%
	}%
}

\renewcommand{\section}[1]{%
	\par\vspace{0pt}%
	{%
		\color{gray}%
		\Large\sectioncolor{#1}%
	}%
	\par\vspace{1pt}%
}

\renewcommand{\subsection}[1]{%
	\par\vspace{2pt}{%
		\bfseries\color{mainblue}\fontsize{9.5pt}{11pt}\selectfont #1%
	}%
	\par\vspace{1pt}%
}

%----------------------------------------------------------------------------------------
%	 LONG LIST ENVIRONMENT
%----------------------------------------------------------------------------------------

\setlength{\tabcolsep}{0pt}

% New environment for the long list
\newenvironment{twenty}{%
	\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}ll}
}{%
	\end{tabular*}
}

\newcommand{\twentyitem}[4]{%
  \parbox[t]{\textwidth}{%
    {\textbf{#1}\ifstrempty{#2}{}{, #2}} \hfill #3 \\%
    #4%
  }\\[0.5pt]%
}

\newcommand{\twentyseparator}{%
  \parbox[t]{\textwidth}{%
    \vspace{-4pt}%
    {\color{black!15}\rule{\linewidth}{0.4pt}}%
    \vspace{-2pt}%
  }\\[-1pt]%
}

\newcommand{\twentyitemtight}[4]{%
  \parbox[t]{\textwidth}{%
    {\textbf{#1}\ifstrempty{#2}{}{, #2}} \hfill #3 \\%
    #4%
  }\\[1pt]%
}

%----------------------------------------------------------------------------------------
%	 SMALL LIST ENVIRONMENT
%----------------------------------------------------------------------------------------

\setlength{\tabcolsep}{0pt}

% New environment for the small list
\newenvironment{twentyshort}{%
	\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}ll}
}{%
	\end{tabular*}
}

\newcommand{\twentyitemshort}[2]{%
	\parbox[t]{0.29\textwidth}{#1}&%
	\parbox[t]{0.70\textwidth}{%
		#2\vspace{0.5pt}%
	}\\
}

%----------------------------------------------------------------------------------------
%	 MARGINS AND LINKS
%----------------------------------------------------------------------------------------

\RequirePackage[left=7.0cm,top=0.3cm,right=0.5cm,bottom=0.2cm,nohead,nofoot]{geometry}

\RequirePackage{hyperref}
\hypersetup{hidelinks,pdfborder={0 0 0}}
