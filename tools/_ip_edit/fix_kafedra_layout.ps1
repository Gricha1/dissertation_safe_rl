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
$sourceDocx = Join-Path $work 'plan_obosnovanie.docx'
if (-not (Test-Path $sourceDocx)) {
    $sourceDocx = (Get-ChildItem (Join-Path $root 'Documents') -Filter '*2026.docx' | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}

$unz = Join-Path $work 'unzipped_kafedra'
if (Test-Path $unz) { Remove-Item $unz -Recurse -Force }
New-Item -ItemType Directory -Path $unz | Out-Null
Copy-Item $sourceDocx (Join-Path $work 'kafedra_src.zip') -Force
Expand-Archive (Join-Path $work 'kafedra_src.zip') -DestinationPath $unz -Force

$xmlPath = Join-Path $unz 'word\document.xml'
$xml = [System.IO.File]::ReadAllText($xmlPath, [System.Text.Encoding]::UTF8)

$full = [System.IO.File]::ReadAllText((Join-Path $work 'kafedra_name.txt'), [System.Text.Encoding]::UTF8).Trim()
$line1 = [System.IO.File]::ReadAllText((Join-Path $work 'kafedra_line1.txt'), [System.Text.Encoding]::UTF8)
$line2 = [System.IO.File]::ReadAllText((Join-Path $work 'kafedra_line2.txt'), [System.Text.Encoding]::UTF8).Trim()

if ($full -ne ($line1.Trim() + ' ' + $line2)) {
    throw 'Unexpected kafedra name split'
}

$xml = $xml.Replace($full, $line1)

$para5Pattern = '(?s)(<w:p\b[^>]*w14:paraId="00000005"[^>]*>.*?<w:t xml:space="preserve">)\s*(</w:t><w:tab/></w:r></w:p>)'
$newXml = [regex]::Replace($xml, $para5Pattern, ('${1}' + $line2 + '${2}'), 1)
if ($newXml -eq $xml) { throw 'Second line paragraph not updated' }
$xml = $newXml

[System.IO.File]::WriteAllText($xmlPath, $xml, [System.Text.UTF8Encoding]::new($false))

$editedDocx = Join-Path $work 'plan_kafedra_fixed.docx'
Compress-Docx $unz $editedDocx

$soffice = 'C:\Program Files\LibreOffice\program\soffice.exe'
$loDir = Split-Path $soffice -Parent
$outDir = Join-Path $work 'lo_out4'
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
