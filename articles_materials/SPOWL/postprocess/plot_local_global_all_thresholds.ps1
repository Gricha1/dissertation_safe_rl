param(
    [ValidateRange(1, 100)]
    [int]$SmoothingWindow = 5,

    [ValidatePattern('^[A-Za-z0-9_.-]+$')]
    [string]$OutputBase = 'local_global_all_thresholds',

    [switch]$SkipPng
)

$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot 'spowl\spowl'
$svgOutput = Join-Path $PSScriptRoot "$OutputBase.svg"
$pngOutput = Join-Path $PSScriptRoot "$OutputBase.png"
$window = $SmoothingWindow

$series = @(
    @{ Kind = 'global'; Threshold = 1.0; Suffix = 'cceg_thr_1'; Color = '#F28E2B'; Dash = '' },
    @{ Kind = 'global'; Threshold = 3.0; Suffix = 'cceg_thr_3'; Color = '#59A14F'; Dash = '' },
    @{ Kind = 'global'; Threshold = 5.0; Suffix = 'cceg_thr_5'; Color = '#E15759'; Dash = '' },
    @{ Kind = 'global'; Threshold = 10.0; Suffix = 'cceg_thr_10'; Color = '#9C755F'; Dash = '' },
    @{ Kind = 'global'; Threshold = 25.0; Suffix = 'cceg_thr_25'; Color = '#B07AA1'; Dash = '' },
    @{ Kind = 'local'; Threshold = 0.01; Suffix = 'ccel_thr_0.01'; Color = '#4E79A7'; Dash = '10,7' },
    @{ Kind = 'local'; Threshold = 0.1; Suffix = 'ccel_thr_0.1'; Color = '#76B7B2'; Dash = '10,7' },
    @{ Kind = 'local'; Threshold = 1.0; Suffix = 'ccel_thr_1'; Color = '#EDC948'; Dash = '10,7' },
    @{ Kind = 'spowl'; Threshold = 0.0; Suffix = 'rae_5ens5_avg'; Color = '#111111'; Dash = '' }
)
$environments = @(
    @{ Key = 'PG1'; Label = 'PointGoal1' },
    @{ Key = 'PG2'; Label = 'PointGoal2' }
)
$metrics = @(
    @{ Key = 'eval/mean_reward_return'; Label = 'Reward'; Min1 = -5.0; Max1 = 30.0; Min2 = -5.0; Max2 = 25.0 },
    @{ Key = 'eval/mean_cost_return'; Label = 'Cost'; Min1 = 0.0; Max1 = 150.0; Min2 = 0.0; Max2 = 150.0 },
    @{ Key = 'train/cost_rate'; Label = 'Cost Rate'; Min1 = 0.0; Max1 = 0.10; Min2 = 0.0; Max2 = 0.20 }
)

function Get-MovingAverage([double[]]$values, [int]$size) {
    $result = @()
    for ($i = $size - 1; $i -lt $values.Count; $i++) {
        $sum = 0.0
        for ($j = $i - $size + 1; $j -le $i; $j++) {
            $sum += $values[$j]
        }
        $result += $sum / $size
    }
    return [double[]]$result
}

function Get-Mean([double[]]$values) {
    return ($values | Measure-Object -Average).Average
}

$logs = @{}
foreach ($environment in $environments) {
    foreach ($item in $series) {
        $config = "$($environment.Key)_$($item.Suffix)"
        $runs = @()
        Get-ChildItem -LiteralPath (Join-Path $root $config) -Filter 'seed_*.jsonl' |
            Sort-Object Name |
            ForEach-Object {
                $runs += ,@(Get-Content -LiteralPath $_.FullName -Encoding UTF8 |
                    ForEach-Object { $_ | ConvertFrom-Json })
            }
        $logs["$($environment.Key)-$($item.Kind)-$($item.Threshold)"] = $runs
    }
}

$width = 1700
$height = 1120
$leftMargin = 110
$topMargin = 90
$panelWidth = 455
$panelHeight = 315
$columnGap = 75
$rowGap = 110

function Map-X([double]$step, [double]$left) {
    return $left + ($step / 5000000.0) * $panelWidth
}

function Map-Y([double]$value, [double]$top, [double]$min, [double]$max) {
    return $top + $panelHeight - (($value - $min) / ($max - $min)) * $panelHeight
}

$svg = [System.Text.StringBuilder]::new()
[void]$svg.AppendLine("<svg xmlns='http://www.w3.org/2000/svg' width='$width' height='$height' viewBox='0 0 $width $height'>")
[void]$svg.AppendLine("<rect width='100%' height='100%' fill='white'/>")
[void]$svg.AppendLine("<style>text{font-family:Arial,sans-serif;fill:#222}.title{font-size:34px;font-weight:700}.row{font-size:31px;font-weight:700}.axis{font-size:27px}.tick{font-size:24px}.legend{font-size:32px}.group{font-size:33px;font-weight:700}.grid{stroke:#dedede;stroke-width:1}.frame{stroke:#333;stroke-width:2;fill:none}</style>")

for ($row = 0; $row -lt $environments.Count; $row++) {
    $environment = $environments[$row]
    $top = $topMargin + $row * ($panelHeight + $rowGap)
    [void]$svg.AppendLine("<text class='row' transform='translate(30 $($top + $panelHeight / 2)) rotate(-90)' text-anchor='middle'>$($environment.Label)</text>")

    for ($column = 0; $column -lt $metrics.Count; $column++) {
        $metric = $metrics[$column]
        $left = $leftMargin + $column * ($panelWidth + $columnGap)
        $min = if ($row -eq 0) { $metric.Min1 } else { $metric.Min2 }
        $max = if ($row -eq 0) { $metric.Max1 } else { $metric.Max2 }

        if ($row -eq 0) {
            [void]$svg.AppendLine("<text class='title' x='$($left + $panelWidth / 2)' y='44' text-anchor='middle'>$($metric.Label)</text>")
        }

        for ($i = 0; $i -le 5; $i++) {
            $x = $left + $i * $panelWidth / 5
            [void]$svg.AppendLine("<line class='grid' x1='$x' y1='$top' x2='$x' y2='$($top + $panelHeight)'/>")
            if ($row -eq 1) {
                [void]$svg.AppendLine("<text class='tick' x='$x' y='$($top + $panelHeight + 27)' text-anchor='middle'>$i</text>")
            }
        }

        for ($i = 0; $i -le 5; $i++) {
            $y = $top + $i * $panelHeight / 5
            $value = $max - $i * ($max - $min) / 5
            $format = if ($metric.Key -eq 'train/cost_rate') { '0.000' } else { '0.0' }
            [void]$svg.AppendLine("<line class='grid' x1='$left' y1='$y' x2='$($left + $panelWidth)' y2='$y'/>")
            [void]$svg.AppendLine("<text class='tick' x='$($left - 12)' y='$($y + 6)' text-anchor='end'>$($value.ToString($format))</text>")
        }
        if ($row -eq 1) {
            [void]$svg.AppendLine("<text class='axis' x='$($left + $panelWidth / 2)' y='$($top + $panelHeight + 61)' text-anchor='middle'>Environment steps (x 10^6)</text>")
        }

        $clipId = "panel-$row-$column"
        [void]$svg.AppendLine("<defs><clipPath id='$clipId'><rect x='$left' y='$top' width='$panelWidth' height='$panelHeight'/></clipPath></defs>")
        [void]$svg.AppendLine("<g clip-path='url(#$clipId)'>")
        foreach ($item in $series) {
            $runs = $logs["$($environment.Key)-$($item.Kind)-$($item.Threshold)"]
            $smoothedRuns = @()
            foreach ($run in $runs) {
                $values = [double[]]@($run | ForEach-Object { [double]$_.$($metric.Key) })
                $smoothedRuns += ,(Get-MovingAverage $values $window)
            }

            $means = @()
            for ($i = 0; $i -lt $smoothedRuns[0].Count; $i++) {
                $slice = [double[]]@($smoothedRuns | ForEach-Object { $_[$i] })
                $means += Get-Mean $slice
            }

            $points = @()
            for ($i = 0; $i -lt $means.Count; $i++) {
                $step = ($i + $window) * 50000
                $points += "$(Map-X $step $left),$(Map-Y $means[$i] $top $min $max)"
            }
            $dash = if ($item.Dash) { "stroke-dasharray='$($item.Dash)'" } else { '' }
            $lineWidth = if ($item.Kind -eq 'spowl') { 5.0 } else { 3.4 }
            [void]$svg.AppendLine("<polyline points='$($points -join ' ')' fill='none' stroke='$($item.Color)' stroke-width='$lineWidth' $dash/>")
        }
        [void]$svg.AppendLine("</g>")
        [void]$svg.AppendLine("<rect class='frame' x='$left' y='$top' width='$panelWidth' height='$panelHeight'/>")
    }
}

$legendTop = 990
[void]$svg.AppendLine("<text class='group' x='120' y='$legendTop'>Global estimate:</text>")
$x = 400
foreach ($item in @($series | Where-Object { $_.Kind -eq 'global' })) {
    [void]$svg.AppendLine("<line x1='$x' y1='$($legendTop - 7)' x2='$($x + 38)' y2='$($legendTop - 7)' stroke='$($item.Color)' stroke-width='4'/><text class='legend' x='$($x + 47)' y='$legendTop'>d=$($item.Threshold.ToString('0.##'))</text>")
    $x += 150
}
[void]$svg.AppendLine("<line x1='1170' y1='$($legendTop - 7)' x2='1215' y2='$($legendTop - 7)' stroke='#111111' stroke-width='5'/><text class='legend' x='1228' y='$legendTop'>SPOWL (adaptive d)</text>")

[void]$svg.AppendLine("<text class='group' x='120' y='$($legendTop + 53)'>Local estimate:</text>")
$x = 400
foreach ($item in @($series | Where-Object { $_.Kind -eq 'local' })) {
    [void]$svg.AppendLine("<line x1='$x' y1='$($legendTop + 46)' x2='$($x + 38)' y2='$($legendTop + 46)' stroke='$($item.Color)' stroke-width='4' stroke-dasharray='$($item.Dash)'/><text class='legend' x='$($x + 47)' y='$($legendTop + 53)'>d=$($item.Threshold.ToString('0.##'))</text>")
    $x += 190
}

[void]$svg.AppendLine("</svg>")
[System.IO.File]::WriteAllText($svgOutput, $svg.ToString(), [System.Text.UTF8Encoding]::new($false))
Write-Output "SVG: $svgOutput"

if (-not $SkipPng) {
    $edgeCandidates = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),
        (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe')
    )
    $edge = $edgeCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
    if (-not $edge) {
        throw 'Microsoft Edge was not found. Run with -SkipPng to create SVG only.'
    }

    $svgUri = [System.Uri]::new($svgOutput).AbsoluteUri
    & $edge `
        --headless `
        --disable-gpu `
        --hide-scrollbars `
        --window-size="$width,$height" `
        --screenshot="$pngOutput" `
        $svgUri | Out-Null

    if (-not (Test-Path -LiteralPath $pngOutput)) {
        throw "Failed to create PNG: $pngOutput"
    }
    Write-Output "PNG: $pngOutput"
}
