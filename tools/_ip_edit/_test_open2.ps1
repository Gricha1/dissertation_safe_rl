$ErrorActionPreference = "Stop"
$w = New-Object -ComObject Word.Application
$w.Visible = $false; $w.DisplayAlerts = 0
$d = $w.Documents.Open("c:\\Grisha\\mipt\\asp\\disser\\dissertation\\diplom_final\\Documents\\gorbov_individual_plan_2026.docx", $false, $true)
"open ok"
$d.Close($false)
$w.Quit()
