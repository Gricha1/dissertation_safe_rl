$ErrorActionPreference = 'Stop'
$docx = 'c:\Grisha\mipt\asp\disser\dissertation\diplom_final\documents\otzyv_nauchnogo_rukovoditelya.docx'
$pdf = 'c:\Grisha\mipt\asp\disser\dissertation\diplom_final\documents\otzyv_nauchnogo_rukovoditelya.pdf'
if (Test-Path $pdf) { Remove-Item $pdf -Force }

$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0
try {
    $doc = $word.Documents.Open($docx, $false, $true)
    Start-Sleep -Seconds 2
    $doc.ExportAsFixedFormat($pdf, 17, $false, 0, 0, 0, 0, 0, $true, $true, 0, $true, $true, $false)
    $doc.Close($false)
    Write-Output "PDF: $pdf"
}
finally {
    $word.Quit() | Out-Null
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}
