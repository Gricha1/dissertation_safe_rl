param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('aggregation', 'ensemble')]
    [string]$Mode,

    [ValidateRange(1, 100)]
    [int]$SmoothingWindow = 5,

    [switch]$SkipPng
)

$ErrorActionPreference = 'Stop'
$culture = [System.Globalization.CultureInfo]::InvariantCulture
$root = Join-Path $PSScriptRoot 'spowl\spowl'

function F([double]$value, [string]$format = '0.###') {
    return $value.ToString($format, $culture)
}

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

if ($Mode -eq 'aggregation') {
    $outputBase = 'spowl_aggregation_comparison'
    $environments = @(
        @{ Key = 'PG1'; Label = 'PointGoal1'; RewardMin = -5.0; RewardMax = 30.0; CostMax = 100.0; RateMax = 0.10 },
        @{ Key = 'PG2'; Label = 'PointGoal2'; RewardMin = -5.0; RewardMax = 30.0; CostMax = 250.0; RateMax = 0.25 }
    )
    $series = @(
        @{ Label = 'Minimum'; Suffix = 'cvaltarg_min'; Color = '#4E79A7'; Dash = '' },
        @{ Label = 'Maximum'; Suffix = 'cvaltarg_max'; Color = '#F28E2B'; Dash = '' },
        @{ Label = 'Average (SPOWL)'; Suffix = 'rae_5ens5_avg'; Color = '#111111'; Dash = '' }
    )
}
else {
    $outputBase = 'spowl_ensemble_ablation'
    $environments = @(
        @{ Key = 'PP1'; Label = 'PointPush1'; RewardMin = -3.0; RewardMax = 25.0; CostMax = 120.0; RateMax = 0.09 },
        @{ Key = 'PG2'; Label = 'PointGoal2'; RewardMin = -3.0; RewardMax = 25.0; CostMax = 250.0; RateMax = 0.23 },
        @{ Key = 'DG1'; Label = 'DoggoGoal1'; RewardMin = -3.0; RewardMax = 25.0; CostMax = 210.0; RateMax = 0.08 }
    )
    $series = @(
        @{ Label = '1x5'; Suffix = 'rae_1ens5'; Color = '#4E79A7'; Dash = '' },
        @{ Label = '2x5 max'; Suffix = 'rae_2ens5'; Color = '#F28E2B'; Dash = '' },
        @{ Label = '2x5 avg'; Suffix = 'rae_2ens5_avg'; Color = '#59A14F'; Dash = '' },
        @{ Label = '5x5 max'; Suffix = 'rae_5ens5'; Color = '#E15759'; Dash = '' },
        @{ Label = '5x5 avg (SPOWL)'; Suffix = 'rae_5ens5_avg'; Color = '#111111'; Dash = '' },
        @{ Label = '1x1'; Suffix = 'rae_1ens1_avg'; Color = '#9C755F'; Dash = '12,7' },
        @{ Label = '3x3 avg'; Suffix = 'rae_3ens3_avg'; Color = '#E377C2'; Dash = '12,7' },
        @{ Label = '10x10 avg'; Suffix = 'rae_10ens10_avg'; Color = '#17BECF'; Dash = '12,7' }
    )
}

$metrics = @(
    @{ Key = 'eval/mean_reward_return'; Label = 'Reward' },
    @{ Key = 'eval/mean_cost_return'; Label = 'Cost' },
    @{ Key = 'train/cost_rate'; Label = 'Cost Rate' }
)

$logs = @{}
foreach ($environment in $environments) {
    foreach ($item in $series) {
        $config = "$($environment.Key)_$($item.Suffix)"
        $path = Join-Path $root $config
        $runs = @()
        Get-ChildItem -LiteralPath $path -Filter 'seed_*.jsonl' |
            Sort-Object Name |
            ForEach-Object {
                $runs += ,@(Get-Content -LiteralPath $_.FullName -Encoding UTF8 |
                    ForEach-Object { $_ | ConvertFrom-Json })
            }
        if ($runs.Count -eq 0) {
            throw "No runs found in $path"
        }
        $logs["$($environment.Key)-$($item.Suffix)"] = $runs
    }
}

$width = 1700
$leftMargin = 110
$topMargin = 90
$panelWidth = 455
$panelHeight = 315
$columnGap = 75
$rowGap = 105
$legendRows = if ($Mode -eq 'ensemble') { 2 } else { 1 }
$legendTop = $topMargin + $environments.Count * $panelHeight + ($environments.Count - 1) * $rowGap + 125
$height = $legendTop + 55 * $legendRows + 45

function Map-X([double]$step, [double]$left) {
    return $left + ($step / 5000000.0) * $panelWidth
}

function Map-Y([double]$value, [double]$top, [double]$min, [double]$max) {
    return $top + $panelHeight - (($value - $min) / ($max - $min)) * $panelHeight
}

$svgOutput = Join-Path $PSScriptRoot "$outputBase.svg"
$pngOutput = Join-Path $PSScriptRoot "$outputBase.png"
$svg = [System.Text.StringBuilder]::new()
[void]$svg.AppendLine("<svg xmlns='http://www.w3.org/2000/svg' width='$width' height='$height' viewBox='0 0 $width $height'>")
[void]$svg.AppendLine("<rect width='100%' height='100%' fill='white'/>")
[void]$svg.AppendLine("<style>text{font-family:Arial,sans-serif;fill:#222}.title{font-size:34px;font-weight:700}.row{font-size:31px;font-weight:700}.axis{font-size:27px}.tick{font-size:24px}.legend{font-size:32px}.grid{stroke:#dedede;stroke-width:1}.frame{stroke:#333;stroke-width:2;fill:none}</style>")

for ($row = 0; $row -lt $environments.Count; $row++) {
    $environment = $environments[$row]
    $top = $topMargin + $row * ($panelHeight + $rowGap)
    [void]$svg.AppendLine("<text class='row' transform='translate(30 $($top + $panelHeight / 2)) rotate(-90)' text-anchor='middle'>$($environment.Label)</text>")

    for ($column = 0; $column -lt $metrics.Count; $column++) {
        $metric = $metrics[$column]
        $left = $leftMargin + $column * ($panelWidth + $columnGap)
        if ($metric.Key -eq 'eval/mean_reward_return') {
            $min = $environment.RewardMin
            $max = $environment.RewardMax
        }
        elseif ($metric.Key -eq 'eval/mean_cost_return') {
            $min = 0.0
            $max = $environment.CostMax
        }
        else {
            $min = 0.0
            $max = $environment.RateMax
        }

        if ($row -eq 0) {
            [void]$svg.AppendLine("<text class='title' x='$($left + $panelWidth / 2)' y='44' text-anchor='middle'>$($metric.Label)</text>")
        }

        for ($i = 0; $i -le 5; $i++) {
            $x = $left + $i * $panelWidth / 5
            [void]$svg.AppendLine("<line class='grid' x1='$(F $x)' y1='$(F $top)' x2='$(F $x)' y2='$(F ($top + $panelHeight))'/>")
            if ($row -eq $environments.Count - 1) {
                [void]$svg.AppendLine("<text class='tick' x='$(F $x)' y='$(F ($top + $panelHeight + 27))' text-anchor='middle'>$i</text>")
            }
        }

        for ($i = 0; $i -le 5; $i++) {
            $y = $top + $i * $panelHeight / 5
            $value = $max - $i * ($max - $min) / 5
            $format = if ($metric.Key -eq 'train/cost_rate') { '0.000' } else { '0.0' }
            [void]$svg.AppendLine("<line class='grid' x1='$(F $left)' y1='$(F $y)' x2='$(F ($left + $panelWidth))' y2='$(F $y)'/>")
            [void]$svg.AppendLine("<text class='tick' x='$(F ($left - 12))' y='$(F ($y + 6))' text-anchor='end'>$(F $value $format)</text>")
        }

        if ($row -eq $environments.Count - 1) {
            [void]$svg.AppendLine("<text class='axis' x='$(F ($left + $panelWidth / 2))' y='$(F ($top + $panelHeight + 61))' text-anchor='middle'>Environment steps (x 10^6)</text>")
        }

        $clipId = "panel-$row-$column"
        [void]$svg.AppendLine("<defs><clipPath id='$clipId'><rect x='$(F $left)' y='$(F $top)' width='$panelWidth' height='$panelHeight'/></clipPath></defs>")
        [void]$svg.AppendLine("<g clip-path='url(#$clipId)'>")
        foreach ($item in $series) {
            $runs = $logs["$($environment.Key)-$($item.Suffix)"]
            $smoothedRuns = @()
            foreach ($run in $runs) {
                $values = [double[]]@($run | ForEach-Object { [double]$_.$($metric.Key) })
                $smoothedRuns += ,(Get-MovingAverage $values $SmoothingWindow)
            }

            $means = @()
            for ($i = 0; $i -lt $smoothedRuns[0].Count; $i++) {
                $slice = [double[]]@($smoothedRuns | ForEach-Object { $_[$i] })
                $means += Get-Mean $slice
            }

            $points = @()
            for ($i = 0; $i -lt $means.Count; $i++) {
                $step = ($i + $SmoothingWindow) * 50000
                $points += "$(F (Map-X $step $left)),$(F (Map-Y $means[$i] $top $min $max))"
            }
            $dash = if ($item.Dash) { "stroke-dasharray='$($item.Dash)'" } else { '' }
            $lineWidth = if ($item.Label -like '*SPOWL*') { 5.0 } else { 3.5 }
            [void]$svg.AppendLine("<polyline points='$($points -join ' ')' fill='none' stroke='$($item.Color)' stroke-width='$lineWidth' $dash/>")
        }
        [void]$svg.AppendLine("</g>")
        [void]$svg.AppendLine("<rect class='frame' x='$(F $left)' y='$(F $top)' width='$panelWidth' height='$panelHeight'/>")
    }
}

if ($Mode -eq 'aggregation') {
    $x = 430
    foreach ($item in $series) {
        [void]$svg.AppendLine("<line x1='$x' y1='$($legendTop - 7)' x2='$($x + 48)' y2='$($legendTop - 7)' stroke='$($item.Color)' stroke-width='5'/><text class='legend' x='$($x + 60)' y='$legendTop'>$($item.Label)</text>")
        $x += 330
    }
}
else {
    for ($legendRow = 0; $legendRow -lt 2; $legendRow++) {
        $x = 120
        $y = $legendTop + $legendRow * 55
        $items = @($series | Select-Object -Skip ($legendRow * 4) -First 4)
        foreach ($item in $items) {
            $dash = if ($item.Dash) { "stroke-dasharray='$($item.Dash)'" } else { '' }
            [void]$svg.AppendLine("<line x1='$x' y1='$($y - 7)' x2='$($x + 45)' y2='$($y - 7)' stroke='$($item.Color)' stroke-width='5' $dash/><text class='legend' x='$($x + 57)' y='$y'>$($item.Label)</text>")
            $x += 375
        }
    }
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
    & $edge --headless --disable-gpu --hide-scrollbars --window-size="$width,$height" --screenshot="$pngOutput" $svgUri | Out-Null
    if (-not (Test-Path -LiteralPath $pngOutput)) {
        throw "Failed to create PNG: $pngOutput"
    }
    Write-Output "PNG: $pngOutput"
}
