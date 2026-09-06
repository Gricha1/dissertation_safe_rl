$docx = $args[0]
$outFile = $args[1]
$doc = Get-Content $docx -Raw -Encoding UTF8
$parts = [regex]::Split($doc, '(?=<w:p )') | Where-Object { $_ -match '<w:p ' }
$idx = 0
$paras = @()
foreach ($part in $parts) {
    $text = ([regex]::Matches($part, '<w:t[^>]*>([^<]*)</w:t>') | ForEach-Object { $_.Groups[1].Value }) -join ''
    $jc = if ($part -match 'w:jc w:val="(\w+)"') { $Matches[1] } else { $null }
    $sz = if ($part -match '<w:pPr>[\s\S]*?<w:sz w:val="(\d+)"') { [int]$Matches[1]/2 } elseif ($part -match '<w:sz w:val="(\d+)"') { [int]$Matches[1]/2 } else { $null }
    $bold = $false
    foreach ($m in [regex]::Matches($part, '<w:r[\s\S]*?</w:r>')) {
        $rt = ([regex]::Matches($m.Value, '<w:t[^>]*>([^<]*)</w:t>') | ForEach-Object { $_.Groups[1].Value }) -join ''
        if (-not $rt) { continue }
        $rb = $m.Value -match '<w:rPr>[\s\S]*?<w:b w:val="1"'
        $ri = $m.Value -match '<w:rPr>[\s\S]*?<w:i w:val="1"'
        $rsz = if ($m.Value -match '<w:sz w:val="(\d+)"') { [int]$Matches[1]/2 } else { $null }
        $paras += [pscustomobject]@{ i=$idx; text=$text; run=$rt; b=$rb; i=$ri; sz=$rsz; jc=$jc; empty=[string]::IsNullOrWhiteSpace($text) }
    }
    if ([string]::IsNullOrWhiteSpace($text)) {
        $esz = if ($part -match '<w:sz w:val="(\d+)"') { [int]$Matches[1]/2 } else { 12 }
        $paras += [pscustomobject]@{ i=$idx; text=''; run=''; b=$false; i=$false; sz=$esz; jc=$jc; empty=$true }
    }
    $idx++
}
$lines = @()
$content = $paras | Where-Object { -not $_.empty } | Select-Object -Unique i, text, jc, sz -First 50
foreach ($c in ($paras | Where-Object { -not $_.empty } | Group-Object i)) {
    $g = $c.Group[0]
    $runs = ($c.Group | ForEach-Object { "{0}(b={1},i={2},sz={3})" -f $_.run,$_.b,$_.i,$_.sz }) -join ' | '
    $lines += "P$($g.i) jc=$($g.jc) sz=$($g.sz): $($g.text)"
    if ($runs.Trim()) { $lines += "  $runs" }
}
$lines | Set-Content $outFile -Encoding UTF8
