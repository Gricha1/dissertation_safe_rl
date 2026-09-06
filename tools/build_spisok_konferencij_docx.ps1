$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$docName = -join @(
    [char]0x0430, [char]0x043F, [char]0x0440, [char]0x043E, [char]0x0431, [char]0x0430, [char]0x0446, [char]0x0438, [char]0x044F,
    '.docx'
)
$outDocx = Join-Path $root ('Documents\' + $docName)
$workDir = Join-Path $env:TEMP ("konferencii_docx_" + [guid]::NewGuid().ToString())
$templateDir = Join-Path $PSScriptRoot 'otzyv_template'
$dataPath = Join-Path $PSScriptRoot 'konferencii_list.json'
$data = Get-Content -LiteralPath $dataPath -Raw -Encoding UTF8 | ConvertFrom-Json
$talkIntro = -join @(
    ' ',
    [char]0x0441, ' ',
    [char]0x0434, [char]0x043E, [char]0x043A, [char]0x043B, [char]0x0430, [char]0x0434, [char]0x043E, [char]0x043C, ' ',
    [char]0x00AB
)
$talkOutro = -join @([char]0x00BB, '.')

function W([string]$t) {
    return ($t -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;')
}

function RunProps([switch]$IsBold, [switch]$IsItalic, [switch]$IsUnderline) {
    $parts = @(
        '<w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman"/>',
        '<w:sz w:val="28"/>',
        '<w:szCs w:val="28"/>'
    )
    if ($IsBold) { $parts += '<w:b/><w:bCs/>' }
    if ($IsItalic) { $parts += '<w:i/><w:iCs/>' }
    if ($IsUnderline) { $parts += '<w:u w:val="single"/>' }
    return "<w:rPr>$($parts -join '')</w:rPr>"
}

function ParaTitle([string]$text) {
    return @"
<w:p>
  <w:pPr>
    <w:jc w:val="center"/>
    <w:spacing w:after="0" w:line="360" w:lineRule="auto"/>
  </w:pPr>
  <w:r>
    $(RunProps -IsBold)
    <w:t xml:space="preserve">$(W $text)</w:t>
  </w:r>
</w:p>
"@
}

function ParaConference([int]$num, [string]$prefix, [string]$talkTitle, [string]$intro) {
    return @"
<w:p>
  <w:pPr>
    <w:jc w:val="both"/>
    <w:spacing w:after="0" w:line="360" w:lineRule="auto"/>
    <w:ind w:firstLine="709"/>
  </w:pPr>
  <w:r>
    $(RunProps)
    <w:t xml:space="preserve">$(W "$num. $prefix$intro")</w:t>
  </w:r>
  <w:r>
    $(RunProps -IsUnderline)
    <w:t xml:space="preserve">$(W $talkTitle)</w:t>
  </w:r>
  <w:r>
    $(RunProps)
    <w:t xml:space="preserve">$(W $talkOutro)</w:t>
  </w:r>
</w:p>
"@
}

function ParaSubheading([string]$text) {
    return @"
<w:p>
  <w:pPr>
    <w:jc w:val="both"/>
    <w:spacing w:before="0" w:after="0" w:line="360" w:lineRule="auto"/>
    <w:ind w:firstLine="709"/>
  </w:pPr>
  <w:r>
    $(RunProps -IsItalic)
    <w:t xml:space="preserve">$(W $text)</w:t>
  </w:r>
</w:p>
"@
}

function ParaSimple([int]$num, [string]$text) {
    return @"
<w:p>
  <w:pPr>
    <w:jc w:val="both"/>
    <w:spacing w:after="0" w:line="360" w:lineRule="auto"/>
    <w:ind w:firstLine="709"/>
  </w:pPr>
  <w:r>
    $(RunProps)
    <w:t xml:space="preserve">$(W "$num. $text")</w:t>
  </w:r>
</w:p>
"@
}

$body = New-Object System.Collections.Generic.List[string]
[void]$body.Add((ParaTitle $data.title))
[void]$body.Add('<w:p><w:pPr><w:spacing w:after="0" w:line="360" w:lineRule="auto"/></w:pPr></w:p>')

$num = 1
foreach ($entry in $data.entries) {
    if ($entry.PSObject.Properties.Name -contains 'simple' -and $entry.simple) {
        [void]$body.Add((ParaSimple $num $entry.text))
    } else {
        $intro = if ($entry.PSObject.Properties.Name -contains 'poster' -and $entry.poster) {
            ' с постерным докладом «'
        } else {
            $talkIntro
        }
        [void]$body.Add((ParaConference $num $entry.prefix $entry.talk $intro))
    }
    $num++
}

$documentXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
            xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:body>
$($body -join "`n")
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1134" w:right="850" w:bottom="1134" w:left="1701" w:header="708" w:footer="708" w:gutter="0"/>
    </w:sectPr>
  </w:body>
</w:document>
"@

$coreXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
  xmlns:dc="http://purl.org/dc/elements/1.1/">
  <dc:title>$(W $data.title)</dc:title>
</cp:coreProperties>
"@

Copy-Item -Path $templateDir -Destination $workDir -Recurse
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText((Join-Path $workDir 'word\document.xml'), $documentXml, $utf8)
[System.IO.File]::WriteAllText((Join-Path $workDir 'docProps\core.xml'), $coreXml, $utf8)

foreach ($f in @($outDocx)) {
    if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force }
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($workDir, $outDocx)
Remove-Item $workDir -Recurse -Force
Write-Output $outDocx
