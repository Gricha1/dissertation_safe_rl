$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$docsDir = Join-Path $root 'Documents'
$src = Get-ChildItem -LiteralPath $docsDir -Filter '*2026.docx' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $src) { throw 'Individual plan DOCX not found in Documents' }

$soffice = @(
    "${env:ProgramFiles}\LibreOffice\program\soffice.exe",
    "${env:ProgramFiles(x86)}\LibreOffice\program\soffice.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $soffice) { throw 'LibreOffice not found (soffice.exe)' }

$outName = -join @(
    [char]0x0413, [char]0x043E, [char]0x0440, [char]0x0431, [char]0x043E, [char]0x0432, '_',
    [char]0x0418, [char]0x043D, [char]0x0434, [char]0x0438, [char]0x0432, [char]0x0438, [char]0x0434, [char]0x0443, [char]0x0430, [char]0x043B, [char]0x044C, [char]0x043D, [char]0x044B, [char]0x0439, '_',
    [char]0x043F, [char]0x043B, [char]0x0430, [char]0x043D, '_',
    [char]0x0430, [char]0x0441, [char]0x043F, [char]0x0438, [char]0x0440, [char]0x0430, [char]0x043D, [char]0x0442, '_2026.pdf'
)
$finalPdf = Join-Path $docsDir $outName

$workDir = Join-Path $env:TEMP ("individual_plan_pdf_" + [guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $workDir -Force | Out-Null
try {
    $loDir = Split-Path $soffice -Parent
    Push-Location $loDir
    try {
        $proc = Start-Process -FilePath $soffice -ArgumentList @(
            '--headless', '--nologo', '--nofirststartwizard',
            '--convert-to', 'pdf', '--outdir', $workDir, $src.FullName
        ) -Wait -PassThru -NoNewWindow -WorkingDirectory $loDir
    }
    finally {
        Pop-Location
    }
    if ($proc.ExitCode -ne 0) { throw "LibreOffice failed with exit code $($proc.ExitCode)" }

    $built = Get-ChildItem -LiteralPath $workDir -Filter '*.pdf' | Select-Object -First 1
    if (-not $built) { throw 'PDF was not created' }

    Copy-Item -LiteralPath $built.FullName -Destination $finalPdf -Force
    $info = Get-Item -LiteralPath $finalPdf
    Write-Output "OK: $($info.FullName)"
    Write-Output "size: $($info.Length)"
}
finally {
    if (Test-Path $workDir) { Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue }
}
