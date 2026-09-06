$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$workDir = Join-Path $env:TEMP ("otzyv_docx_" + [guid]::NewGuid().ToString())
$outDocx = Join-Path $root 'documents\otzyv_nauchnogo_rukovoditelya.docx'
$templateDir = Join-Path $PSScriptRoot 'otzyv_template'
$sourceFile = Join-Path $PSScriptRoot 'otzyv_rukovoditelya.txt'

function W([string]$t) {
    return ($t -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;')
}

function RunProps([switch]$IsBold) {
    $bold = if ($IsBold) { '<w:b/><w:bCs/>' } else { '' }
    return "<w:rPr><w:rFonts w:ascii=`"Times New Roman`" w:hAnsi=`"Times New Roman`" w:cs=`"Times New Roman`"/><w:sz w:val=`"28`"/><w:szCs w:val=`"28`"/>$bold</w:rPr>"
}

function ParaBody([string]$text) {
    return @"
<w:p>
  <w:pPr>
    <w:jc w:val="both"/>
    <w:spacing w:after="0" w:line="360" w:lineRule="auto"/>
    <w:ind w:firstLine="709"/>
  </w:pPr>
  <w:r>
    $(RunProps)
    <w:t xml:space="preserve">$(W $text)</w:t>
  </w:r>
</w:p>
"@
}

function ParaCenterBlock([string[]]$lines, [switch]$IsBold) {
    $runs = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($i -gt 0) { [void]$runs.Add('<w:br/>') }
        [void]$runs.Add("<w:t xml:space=`"preserve`">$(W $lines[$i])</w:t>")
    }
    return @"
<w:p>
  <w:pPr>
    <w:jc w:val="center"/>
    <w:spacing w:after="0" w:line="360" w:lineRule="auto"/>
  </w:pPr>
  <w:r>
    $(RunProps -IsBold:$IsBold)
    $($runs -join "`n    ")
  </w:r>
</w:p>
"@
}

function ParaLeft([string]$text) {
    if ([string]::IsNullOrWhiteSpace($text)) {
        return '<w:p><w:pPr><w:spacing w:after="0" w:line="360" w:lineRule="auto"/></w:pPr></w:p>'
    }
    return @"
<w:p>
  <w:pPr>
    <w:spacing w:after="0" w:line="360" w:lineRule="auto"/>
  </w:pPr>
  <w:r>
    $(RunProps)
    <w:t xml:space="preserve">$(W $text)</w:t>
  </w:r>
</w:p>
"@
}

$raw = Get-Content -LiteralPath $sourceFile -Raw -Encoding UTF8
$parts = $raw -split '---', 3
$headerBlock = ($parts[0] -split "`r?`n" | Where-Object { $_ -ne '' })
$bodyBlock = $parts[1]
$footerBlock = ($parts[2] -split "`r?`n")

$body = New-Object System.Collections.Generic.List[string]
[void]$body.Add((ParaCenterBlock $headerBlock -IsBold))

$paragraphs = ($bodyBlock -split "`r?`n`r?`n") | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
foreach ($p in $paragraphs) {
    [void]$body.Add((ParaBody ($p.Trim())))
}

[void]$body.Add((ParaLeft ''))
foreach ($line in $footerBlock) {
    [void]$body.Add((ParaLeft $line))
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
  <dc:title>$(W $headerBlock[0])</dc:title>
</cp:coreProperties>
"@

Copy-Item -Path $templateDir -Destination $workDir -Recurse
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText((Join-Path $workDir 'word\document.xml'), $documentXml, $utf8)
[System.IO.File]::WriteAllText((Join-Path $workDir 'docProps\core.xml'), $coreXml, $utf8)

foreach ($f in @($outDocx)) {
    if (Test-Path $f) { Remove-Item $f -Force }
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($workDir, $outDocx)
Remove-Item $workDir -Recurse -Force
Write-Output $outDocx
