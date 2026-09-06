$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot 'spowl\spowl'
$output = Join-Path $PSScriptRoot 'local_global_curves.svg'
$window = 5

$methods = @(
    @{ Key = 'global'; Label = 'Global estimate (d=10)'; Color = '#2468B4'; Suffix = 'cceg_thr_10' },
    @{ Key = 'local'; Label = 'Local estimate (d=1)'; Color = '#E36A2E'; Suffix = 'ccel_thr_1' }
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

function Get-Std([double[]]$values) {
    $mean = Get-Mean $values
    $sum = 0.0
    foreach ($value in $values) {
        $sum += [math]::Pow($value - $mean, 2)
    }
    return [math]::Sqrt($sum / $values.Count)
}

$logs = @{}
foreach ($environment in $environments) {
    foreach ($method in $methods) {
        $config = "$($environment.Key)_$($method.Suffix)"
        $runs = @()
        Get-ChildItem -LiteralPath (Join-Path $root $config) -Filter 'seed_*.jsonl' |
            Sort-Object Name |
            ForEach-Object {
                $runs += ,@(Get-Content -LiteralPath $_.FullName -Encoding UTF8 |
                    ForEach-Object { $_ | ConvertFrom-Json })
            }
        $logs["$($environment.Key)-$($method.Key)"] = $runs
    }
}

$width = 1600
$height = 950
$leftMargin = 105
$topMargin = 95
$panelWidth = 430
$panelHeight = 300
$columnGap = 75
$rowGap = 105

function Map-X([double]$step, [double]$left) {
    return $left + ($step / 5000000.0) * $panelWidth
}

function Map-Y([double]$value, [double]$top, [double]$min, [double]$max) {
    return $top + $panelHeight - (($value - $min) / ($max - $min)) * $panelHeight
}

$svg = [System.Text.StringBuilder]::new()
[void]$svg.AppendLine("<svg xmlns='http://www.w3.org/2000/svg' width='$width' height='$height' viewBox='0 0 $width $height'>")
[void]$svg.AppendLine("<rect width='100%' height='100%' fill='white'/>")
[void]$svg.AppendLine("<style>text{font-family:Arial,sans-serif;fill:#222}.title{font-size:27px;font-weight:700}.row{font-size:25px;font-weight:700}.axis{font-size:19px}.tick{font-size:16px}.legend{font-size:21px}.grid{stroke:#dedede;stroke-width:1}.frame{stroke:#333;stroke-width:2;fill:none}</style>")

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
            [void]$svg.AppendLine("<text class='title' x='$($left + $panelWidth / 2)' y='47' text-anchor='middle'>$($metric.Label)</text>")
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
        [void]$svg.AppendLine("<rect class='frame' x='$left' y='$top' width='$panelWidth' height='$panelHeight'/>")

        if ($row -eq 1) {
            [void]$svg.AppendLine("<text class='axis' x='$($left + $panelWidth / 2)' y='$($top + $panelHeight + 62)' text-anchor='middle'>Environment steps (x 10^6)</text>")
        }

        foreach ($method in $methods) {
            $color = $method.Color
            $runs = $logs["$($environment.Key)-$($method.Key)"]
            $smoothedRuns = @()

            foreach ($run in $runs) {
                $values = [double[]]@($run | ForEach-Object { [double]$_.$($metric.Key) })
                $smoothedRuns += ,(Get-MovingAverage $values $window)
            }

            $means = @()
            $stds = @()
            for ($i = 0; $i -lt $smoothedRuns[0].Count; $i++) {
                $slice = [double[]]@($smoothedRuns | ForEach-Object { $_[$i] })
                $means += Get-Mean $slice
                $stds += Get-Std $slice
            }

            foreach ($run in $smoothedRuns) {
                $seedPoints = @()
                for ($i = 0; $i -lt $run.Count; $i++) {
                    $step = ($i + $window) * 50000
                    $x = Map-X $step $left
                    $y = Map-Y $run[$i] $top $min $max
                    $seedPoints += "$x,$y"
                }
                [void]$svg.AppendLine("<polyline points='$($seedPoints -join ' ')' fill='none' stroke='$color' stroke-width='1.4' opacity='0.22'/>")
            }

            $upper = @()
            $lower = @()
            $meanPoints = @()
            for ($i = 0; $i -lt $means.Count; $i++) {
                $step = ($i + $window) * 50000
                $x = Map-X $step $left
                $upper += "$x,$(Map-Y ($means[$i] + $stds[$i]) $top $min $max)"
                $lower += "$x,$(Map-Y ($means[$i] - $stds[$i]) $top $min $max)"
                $meanPoints += "$x,$(Map-Y $means[$i] $top $min $max)"
            }
            [array]::Reverse($lower)
            [void]$svg.AppendLine("<polygon points='$($upper -join ' ') $($lower -join ' ')' fill='$color' opacity='0.15'/>")
            [void]$svg.AppendLine("<polyline points='$($meanPoints -join ' ')' fill='none' stroke='$color' stroke-width='4'/>")
        }
    }
}

$legendY = 925
[void]$svg.AppendLine("<line x1='505' y1='$legendY' x2='555' y2='$legendY' stroke='$($methods[0].Color)' stroke-width='5'/><text class='legend' x='570' y='$($legendY + 7)'>$($methods[0].Label)</text>")
[void]$svg.AppendLine("<line x1='890' y1='$legendY' x2='940' y2='$legendY' stroke='$($methods[1].Color)' stroke-width='5'/><text class='legend' x='955' y='$($legendY + 7)'>$($methods[1].Label)</text>")
[void]$svg.AppendLine("</svg>")

[System.IO.File]::WriteAllText($output, $svg.ToString(), [System.Text.UTF8Encoding]::new($false))
Write-Output $output
