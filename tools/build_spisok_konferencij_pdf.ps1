#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$docs = Join-Path $root 'Documents'
$dataPath = Join-Path $PSScriptRoot 'konferencii_list.json'
$data = Get-Content -LiteralPath $dataPath -Raw -Encoding UTF8 | ConvertFrom-Json

function Escape-Latex([string]$s) {
    $s = $s -replace '\\', '\textbackslash{}'
    $s = $s -replace '&', '\&'
    $s = $s -replace '%', '\%'
    $s = $s -replace '\$', '\$'
    $s = $s -replace '#', '\#'
    $s = $s -replace '_', '\_'
    $s = $s -replace '\{', '\{'
    $s = $s -replace '\}', '\}'
    $s = $s -replace '\^', '\textasciicircum{}'
    $s = $s -replace '~', '\textasciitilde{}'
    return $s
}

function Item-Latex([string]$prefix, [string]$talk, [bool]$poster = $false) {
    if ($poster) {
        $intro = -join @(
            ' ',
            [char]0x0441, ' ',
            [char]0x043F, [char]0x043E, [char]0x0441, [char]0x0442, [char]0x0435, [char]0x0440, [char]0x043D, [char]0x044B, [char]0x043C, ' ',
            [char]0x0434, [char]0x043E, [char]0x043A, [char]0x043B, [char]0x0430, [char]0x0434, [char]0x043E, [char]0x043C, ' ',
            [char]0x00AB
        )
    } else {
        $intro = -join @(
            ' ',
            [char]0x0441, ' ',
            [char]0x0434, [char]0x043E, [char]0x043A, [char]0x043B, [char]0x0430, [char]0x0434, [char]0x043E, [char]0x043C, ' ',
            [char]0x00AB
        )
    }
    $outro = [char]0x00BB
    return "  \item $(Escape-Latex $prefix)$intro\uline{$(Escape-Latex $talk)}$outro."
}

function Entry-Poster([object]$entry) {
    return ($entry.PSObject.Properties.Name -contains 'poster') -and [bool]$entry.poster
}

function Simple-Item-Latex([string]$text) {
    return "  \item $(Escape-Latex $text)"
}

function Entry-Simple([object]$entry) {
    return ($entry.PSObject.Properties.Name -contains 'simple') -and [bool]$entry.simple
}

$items = New-Object System.Collections.Generic.List[string]
foreach ($entry in $data.entries) {
    if (Entry-Simple $entry) {
        [void]$items.Add((Simple-Item-Latex $entry.text))
    } else {
        [void]$items.Add((Item-Latex $entry.prefix $entry.talk (Entry-Poster $entry)))
    }
}

$tex = @"
\documentclass[a4paper,14pt]{extarticle}
\usepackage{fontspec}
\usepackage{polyglossia}
\setdefaultlanguage{russian}
\setotherlanguage{english}
\setmainfont{Tempora}
\usepackage{microtype}
\setlength{\emergencystretch}{2em}
\usepackage[normalem]{ulem}
\usepackage{geometry}
\geometry{left=3cm,right=1.5cm,top=2cm,bottom=2cm}
\usepackage{setspace}
\onehalfspacing
\usepackage{indentfirst}
\usepackage{enumitem}
\pagestyle{empty}
\setlength{\parindent}{1.25cm}
\setlength{\parskip}{0pt}

\begin{document}

\begin{center}
{\bfseries $(Escape-Latex $data.title)}
\end{center}

\vspace{0.5\baselineskip}

\begin{enumerate}[leftmargin=0pt, itemindent=0pt, labelsep=0.5em, align=left, itemsep=0pt, parsep=0pt, listparindent=1.25cm]
$($items -join "`n")
\end{enumerate}

\end{document}
"@

$work = Join-Path $docs '_spisok_konferencij_build'
New-Item -ItemType Directory -Path $work -Force | Out-Null
$texPath = Join-Path $work 'spisok_konferencij.tex'
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($texPath, $tex, $utf8)

Push-Location $work
try {
    xelatex -interaction=nonstopmode spisok_konferencij.tex | Out-Null
    xelatex -interaction=nonstopmode spisok_konferencij.tex | Out-Null
}
finally {
    Pop-Location
}

$pdfName = -join @(
    [char]0x0430, [char]0x043F, [char]0x0440, [char]0x043E, [char]0x0431, [char]0x0430, [char]0x0446, [char]0x0438, [char]0x044F,
    '.pdf'
)
$outPdf = Join-Path $docs $pdfName
Copy-Item -LiteralPath (Join-Path $work 'spisok_konferencij.pdf') -Destination $outPdf -Force
Write-Output $outPdf
Write-Output "size: $((Get-Item -LiteralPath $outPdf).Length)"
