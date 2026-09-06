$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Compress-Docx($sourceDir, $destFile) {
    if (Test-Path $destFile) { Remove-Item $destFile -Force }
    $zip = [System.IO.Compression.ZipFile]::Open($destFile, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        Get-ChildItem $sourceDir -Recurse -File | ForEach-Object {
            $rel = $_.FullName.Substring($sourceDir.Length + 1).Replace('\', '/')
            $entry = $zip.CreateEntry($rel, [System.IO.Compression.CompressionLevel]::Optimal)
            $stream = $entry.Open()
            try {
                $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
                $stream.Write($bytes, 0, $bytes.Length)
            } finally { $stream.Close() }
        }
    } finally { $zip.Dispose() }
}

$root = 'c:\Grisha\mipt\asp\disser\dissertation\diplom_final'
$work = Join-Path $root 'tools\_ip_edit'
$sourceDocx = Join-Path $work 'plan_kafedra_fixed.docx'
if (-not (Test-Path $sourceDocx)) {
    $sourceDocx = (Get-ChildItem (Join-Path $root 'Documents') -Filter '*2026.docx' | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}

$unz = Join-Path $work 'unzipped_qr'
if (Test-Path $unz) { Remove-Item $unz -Recurse -Force }
New-Item -ItemType Directory -Path $unz | Out-Null
Copy-Item $sourceDocx (Join-Path $work 'qr_src.zip') -Force
Expand-Archive (Join-Path $work 'qr_src.zip') -DestinationPath $unz -Force

$xmlPath = Join-Path $unz 'word\document.xml'
$xml = [System.IO.File]::ReadAllText($xmlPath, [System.Text.Encoding]::UTF8)

$qrIdx = $xml.IndexOf('image1.gif')
if ($qrIdx -lt 0) { throw 'QR image not found' }
$tblStart = $xml.LastIndexOf('<w:tbl>', $qrIdx)
$tblEnd = $xml.IndexOf('</w:tbl>', $qrIdx) + 8
if ($tblStart -lt 0 -or $tblEnd -le $tblStart) { throw 'QR table bounds not found' }

$tableXml = $xml.Substring($tblStart, $tblEnd - $tblStart)
$xml = $xml.Remove($tblStart, $tblEnd - $tblStart)

$pageBreak = '<w:p w:rsidR="00000000" w:rsidDel="00000000" w:rsidP="00000000" w:rsidRDefault="00000000" w:rsidRPr="00000000" w14:paraId="000000QR"><w:pPr><w:rPr/></w:pPr><w:r w:rsidDel="00000000" w:rsidR="00000000" w:rsidRPr="00000000"><w:rPr/><w:br w:type="page"/></w:r></w:p>'

$pamParaStart = $xml.IndexOf('w14:paraId="00000037"')
if ($pamParaStart -lt 0) { throw 'PAMYATKA paragraph not found' }
$pamParaStart = $xml.LastIndexOf('<w:p ', $pamParaStart)
if ($pamParaStart -lt 0) { throw 'PAMYATKA paragraph start not found' }

$xml = $xml.Insert($pamParaStart, $pageBreak + $tableXml)

# Remove empty spacer paragraphs between signature and former table location
foreach ($id in @('00000028', '00000029', '0000002A', '0000002B')) {
    $xml = [regex]::Replace($xml, '<w:p\b[^>]*w14:paraId="' + $id + '"[\s\S]*?</w:p>', '', 1)
}

[System.IO.File]::WriteAllText($xmlPath, $xml, [System.Text.UTF8Encoding]::new($false))

$editedDocx = Join-Path $work 'plan_qr_moved.docx'
Compress-Docx $unz $editedDocx

$soffice = 'C:\Program Files\LibreOffice\program\soffice.exe'
$loDir = Split-Path $soffice -Parent
$outDir = Join-Path $work 'lo_out5'
if (Test-Path $outDir) { Remove-Item $outDir -Recurse -Force }
New-Item -ItemType Directory -Path $outDir | Out-Null
Push-Location $loDir
$p = Start-Process -FilePath $soffice -ArgumentList @('--headless', '--convert-to', 'pdf', '--outdir', $outDir, $editedDocx) -Wait -PassThru -NoNewWindow -WorkingDirectory $loDir
Pop-Location
if ($p.ExitCode -ne 0) { throw "LibreOffice exit $($p.ExitCode)" }
$builtPdf = Get-ChildItem $outDir -Filter '*.pdf' | Select-Object -First 1

$docs = Join-Path $root 'Documents'
$targetDocx = [System.IO.File]::ReadAllText((Join-Path $work 'docx_path.txt'), [System.Text.Encoding]::UTF8).Trim()
$outName = -join @(
    [char]0x0413, [char]0x043E, [char]0x0440, [char]0x0431, [char]0x043E, [char]0x0432, '_',
    [char]0x0418, [char]0x043D, [char]0x0434, [char]0x0438, [char]0x0432, [char]0x0438, [char]0x0434, [char]0x0443, [char]0x0430, [char]0x043B, [char]0x044C, [char]0x043D, [char]0x044B, [char]0x0439, '_',
    [char]0x043F, [char]0x043B, [char]0x0430, [char]0x043D, '_',
    [char]0x0430, [char]0x0441, [char]0x043F, [char]0x0438, [char]0x0440, [char]0x0430, [char]0x043D, [char]0x0442, '_2026.pdf'
)
$finalPdf = Join-Path $docs $outName

foreach ($pair in @(
    @{ src = $editedDocx; dst = $targetDocx },
    @{ src = $editedDocx; dst = (Join-Path $docs 'gorbov_individual_plan_2026.docx') },
    @{ src = $builtPdf.FullName; dst = $finalPdf },
    @{ src = $builtPdf.FullName; dst = (Join-Path $docs 'gorbov_individual_plan_2026.pdf') }
)) {
    try {
        Copy-Item -LiteralPath $pair.src -Destination $pair.dst -Force
        Write-Output "copied -> $($pair.dst)"
    } catch {
        Write-Output "locked -> $($pair.dst)"
    }
}
