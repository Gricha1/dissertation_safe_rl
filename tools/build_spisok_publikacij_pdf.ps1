#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$docs = Join-Path $root 'Documents'
$dataPath = Join-Path $PSScriptRoot 'publikacii_list.json'
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

function Escape-Url([string]$s) {
    $s = $s -replace '%', '\%'
    $s = $s -replace '#', '\#'
    return $s
}

function Heading-Latex([string]$text) {
    return '  \item[] \textit{' + (Escape-Latex $text) + '}'
}

function Item-Latex([object]$entry) {
    $line = '  \item ' + (Escape-Latex $entry.text)
    if ($entry.PSObject.Properties.Name -contains 'url' -and $entry.url) {
        $line += " \\`n\url{" + (Escape-Url $entry.url) + '}'
    }
    return $line
}

$body = New-Object System.Collections.Generic.List[string]
[void]$body.Add((Heading-Latex $data.journal_heading))
foreach ($entry in $data.entries) {
    [void]$body.Add((Item-Latex $entry))
}
[void]$body.Add((Heading-Latex $data.conf_heading))
foreach ($entry in $data.conf_entries) {
    [void]$body.Add((Item-Latex $entry))
}
[void]$body.Add((Heading-Latex $data.other_heading))
foreach ($entry in $data.other_entries) {
    [void]$body.Add((Item-Latex $entry))
}

$tex = @'
\documentclass[a4paper,14pt]{extarticle}
\usepackage{fontspec}
\usepackage{polyglossia}
\setdefaultlanguage{russian}
\setotherlanguage{english}
\setmainfont{Tempora}
\usepackage{microtype}
\setlength{\emergencystretch}{2em}
\usepackage{xurl}
\usepackage[unicode=true,colorlinks=true,urlcolor=blue,linkcolor=blue]{hyperref}
\urlstyle{same}
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
{\bfseries 
'@ + (Escape-Latex $data.title) + @'
}
\end{center}

\vspace{0.5\baselineskip}

\begin{enumerate}[leftmargin=0pt, itemindent=0pt, labelsep=0.5em, align=left, itemsep=0.25\baselineskip, parsep=0pt, listparindent=1.25cm]
'@ + ($body -join "`n") + @'

\end{enumerate}

\end{document}
'@

$work = Join-Path $docs '_spisok_publikacij_build'
New-Item -ItemType Directory -Path $work -Force | Out-Null
$texPath = Join-Path $work 'spisok_publikacij.tex'
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($texPath, $tex, $utf8)

Push-Location $work
try {
    xelatex -interaction=nonstopmode spisok_publikacij.tex | Out-Null
    xelatex -interaction=nonstopmode spisok_publikacij.tex | Out-Null
}
finally {
    Pop-Location
}

$pdfName = -join @(
    [char]0x0441, [char]0x043F, [char]0x0438, [char]0x0441, [char]0x043E, [char]0x043A,
    ' ',
    [char]0x043F, [char]0x0443, [char]0x0431, [char]0x043B, [char]0x0438, [char]0x043A, [char]0x0430, [char]0x0446, [char]0x0438, [char]0x0439,
    '.pdf'
)
$outPdf = Join-Path $docs $pdfName
Copy-Item -LiteralPath (Join-Path $work 'spisok_publikacij.pdf') -Destination $outPdf -Force
Write-Output $outPdf
Write-Output "size: $((Get-Item -LiteralPath $outPdf).Length)"
