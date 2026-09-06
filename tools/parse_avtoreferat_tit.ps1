$doc = Get-Content "c:\Grisha\mipt\asp\disser\dissertation\diplom_final\tools\_avtoreferat_tit\word\document.xml" -Raw -Encoding UTF8
$parts = [regex]::Split($doc, '(?=<w:p )')
$out = @()
$idx = 0
foreach ($part in $parts) {
    if ($part -notmatch '<w:p ') { continue }
    $text = ([regex]::Matches($part, '<w:t[^>]*>([^<]*)</w:t>') | ForEach-Object { $_.Groups[1].Value }) -join ''
    if ([string]::IsNullOrWhiteSpace($text)) { $idx++; continue }
    $jc = if ($part -match 'w:jc w:val="(\w+)"') { $Matches[1] } else { $null }
    $left = if ($part -match 'w:ind w:left="([^"]+)"') { $Matches[1] } else { $null }
    $first = if ($part -match 'w:firstLine="([^"]+)"') { $Matches[1] } else { $null }
    $hanging = if ($part -match 'w:hanging="([^"]+)"') { $Matches[1] } else { $null }
    $before = if ($part -match 'w:spacing[^>]*w:before="([^"]+)"') { $Matches[1] } else { $null }
    $after = if ($part -match 'w:spacing[^>]*w:after="([^"]+)"') { $Matches[1] } else { $null }
    $line = if ($part -match 'w:line="([^"]+)"') { $Matches[1] } else { $null }
    $p_sz = if ($part -match '<w:pPr>[\s\S]*?<w:sz w:val="(\d+)"') { $Matches[1] } else { $null }
    $p_b = $part -match '<w:pPr>[\s\S]*?<w:b w:val="1"'
    $has_tab = $part -match '<w:tab/>'
    $runs = @()
    foreach ($m in [regex]::Matches($part, '<w:r[\s\S]*?</w:r>')) {
        $rt = ([regex]::Matches($m.Value, '<w:t[^>]*>([^<]*)</w:t>') | ForEach-Object { $_.Groups[1].Value }) -join ''
        if (-not $rt) { continue }
        $rb = $m.Value -match '<w:rPr>[\s\S]*?<w:b w:val="1"'
        $ri = $m.Value -match '<w:rPr>[\s\S]*?<w:i w:val="1"'
        $rsz = if ($m.Value -match '<w:sz w:val="(\d+)"') { $Matches[1] } else { $null }
        $runs += [pscustomobject]@{ t = $rt; b = $rb; i = $ri; sz = $rsz }
    }
    $out += [pscustomobject]@{
        i = $idx; text = $text; jc = $jc; left = $left; first = $first; hanging = $hanging
        before = $before; after = $after; line = $line; p_sz = $p_sz; p_b = $p_b; has_tab = $has_tab; runs = $runs
    }
    $idx++
}
$out | ConvertTo-Json -Depth 5 | Set-Content "c:\Grisha\mipt\asp\disser\dissertation\diplom_final\tools\_avtoreferat_tit\paras_full.json" -Encoding UTF8
$out | ForEach-Object {
    "P$($_.i.ToString('00')) jc=$($_.jc) L=$($_.left) F=$($_.first) H=$($_.hanging) bef=$($_.before) aft=$($_.after) line=$($_.line) psz=$($_.p_sz) tab=$($_.has_tab)"
    "  $($_.text)"
    foreach ($r in $_.runs) { "    [$($r.t)] b=$($r.b) i=$($r.i) sz=$($r.sz)" }
} | Set-Content "c:\Grisha\mipt\asp\disser\dissertation\diplom_final\tools\_avtoreferat_tit\parse_output.txt" -Encoding UTF8
Write-Output "done $($out.Count) paras"
