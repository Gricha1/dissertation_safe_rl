$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot 'spowl\spowl'
$output = Join-Path $PSScriptRoot 'local_global_tradeoff.svg'

function Get-Mean([double[]]$values) {
    return ($values | Measure-Object -Average).Average
}

function Get-Std([double[]]$values) {
    $mean = Get-Mean $values
    $sum = 0.0
    foreach ($value in $values) {
        $sum += [math]::Pow($value - $mean, 2)
    }
    return [math]::Sqrt($sum / ($values.Count - 1))
}

function Escape-Xml([string]$text) {
    return [System.Security.SecurityElement]::Escape($text)
}

$rows = @()
Get-ChildItem -LiteralPath $root -Directory |
    Where-Object { $_.Name -match '^(PG[12])_(cceg|ccel)_thr_(.+)$' } |
    ForEach-Object {
        $environment = $Matches[1]
        $kind = $Matches[2]
        $threshold = [double]$Matches[3]

        Get-ChildItem -LiteralPath $_.FullName -Filter 'seed_*.jsonl' |
            Sort-Object Name |
            ForEach-Object {
                $seed = [int]([regex]::Match($_.BaseName, '\d+$').Value)
                $data = @(Get-Content -LiteralPath $_.FullName -Encoding UTF8 |
                    ForEach-Object { $_ | ConvertFrom-Json })
                $tail = @($data | Select-Object -Last 10)

                $rows += [pscustomobject]@{
                    Environment = $environment
                    Kind = $kind
                    Threshold = $threshold
                    Seed = $seed
                    Reward = [double](($tail |
                        Measure-Object -Property 'eval/mean_reward_return' -Average).Average)
                    CostRate = [double]$data[-1].'train/cost_rate'
                }
            }
    }

$summary = @()
$rows | Group-Object Environment, Kind, Threshold | ForEach-Object {
    $group = $_.Group
    $summary += [pscustomobject]@{
        Environment = $group[0].Environment
        Kind = $group[0].Kind
        Threshold = $group[0].Threshold
        Reward = Get-Mean ([double[]]$group.Reward)
        RewardStd = Get-Std ([double[]]$group.Reward)
        CostRate = Get-Mean ([double[]]$group.CostRate)
        CostRateStd = Get-Std ([double[]]$group.CostRate)
    }
}

$width = 1500
$height = 700
$plotTop = 100
$plotHeight = 470
$panelWidth = 570
$panelLeft = @(100, 825)
$environments = @('PG1', 'PG2')
$titles = @{
    PG1 = 'PointGoal1'
    PG2 = 'PointGoal2'
}
$ranges = @{
    PG1 = @{ XMin = 0.015; XMax = 0.035; YMin = -3.0; YMax = 30.0 }
    PG2 = @{ XMin = 0.020; XMax = 0.075; YMin = -1.0; YMax = 15.0 }
}
$styles = @{
    cceg = @{ Color = '#2468B4'; Label = 'Global estimate' }
    ccel = @{ Color = '#E36A2E'; Label = 'Local estimate' }
}

function Map-X($value, $left, $range) {
    return $left + (($value - $range.XMin) / ($range.XMax - $range.XMin)) * $panelWidth
}

function Map-Y($value, $range) {
    return $plotTop + $plotHeight -
        (($value - $range.YMin) / ($range.YMax - $range.YMin)) * $plotHeight
}

$svg = [System.Text.StringBuilder]::new()
[void]$svg.AppendLine("<svg xmlns='http://www.w3.org/2000/svg' width='$width' height='$height' viewBox='0 0 $width $height'>")
[void]$svg.AppendLine("<rect width='100%' height='100%' fill='white'/>")
[void]$svg.AppendLine("<style>text{font-family:Arial,sans-serif;fill:#222}.title{font-size:29px;font-weight:700}.axis{font-size:21px}.tick{font-size:17px}.legend{font-size:20px}.label{font-size:17px;font-weight:700}.grid{stroke:#dedede;stroke-width:1}.frame{stroke:#333;stroke-width:2;fill:none}</style>")

for ($panel = 0; $panel -lt 2; $panel++) {
    $environment = $environments[$panel]
    $left = $panelLeft[$panel]
    $range = $ranges[$environment]

    [void]$svg.AppendLine("<text class='title' x='$($left + $panelWidth / 2)' y='48' text-anchor='middle'>$($titles[$environment])</text>")

    for ($i = 0; $i -le 5; $i++) {
        $x = $left + $i * $panelWidth / 5
        $value = $range.XMin + $i * ($range.XMax - $range.XMin) / 5
        [void]$svg.AppendLine("<line class='grid' x1='$x' y1='$plotTop' x2='$x' y2='$($plotTop + $plotHeight)'/>")
        [void]$svg.AppendLine("<text class='tick' x='$x' y='$($plotTop + $plotHeight + 29)' text-anchor='middle'>$($value.ToString('0.000'))</text>")
    }

    for ($i = 0; $i -le 5; $i++) {
        $y = $plotTop + $i * $plotHeight / 5
        $value = $range.YMax - $i * ($range.YMax - $range.YMin) / 5
        [void]$svg.AppendLine("<line class='grid' x1='$left' y1='$y' x2='$($left + $panelWidth)' y2='$y'/>")
        [void]$svg.AppendLine("<text class='tick' x='$($left - 14)' y='$($y + 6)' text-anchor='end'>$($value.ToString('0.0'))</text>")
    }

    [void]$svg.AppendLine("<rect class='frame' x='$left' y='$plotTop' width='$panelWidth' height='$plotHeight'/>")
    [void]$svg.AppendLine("<text class='axis' x='$($left + $panelWidth / 2)' y='645' text-anchor='middle'>Training cost rate (rho)  -  lower is better</text>")

    foreach ($kind in @('cceg', 'ccel')) {
        $color = $styles[$kind].Color
        $means = @($summary |
            Where-Object { $_.Environment -eq $environment -and $_.Kind -eq $kind } |
            Sort-Object Threshold)

        $points = @()
        foreach ($point in $means) {
            $x = Map-X $point.CostRate $left $range
            $y = Map-Y $point.Reward $range
            $points += "$x,$y"
        }
        [void]$svg.AppendLine("<polyline points='$($points -join ' ')' fill='none' stroke='$color' stroke-width='3' opacity='0.75'/>")

        foreach ($row in @($rows |
            Where-Object { $_.Environment -eq $environment -and $_.Kind -eq $kind })) {
            $x = Map-X $row.CostRate $left $range
            $y = Map-Y $row.Reward $range
            [void]$svg.AppendLine("<circle cx='$x' cy='$y' r='5' fill='$color' opacity='0.28'/>")
        }

        foreach ($point in $means) {
            $x = Map-X $point.CostRate $left $range
            $y = Map-Y $point.Reward $range
            $x1 = Map-X ($point.CostRate - $point.CostRateStd) $left $range
            $x2 = Map-X ($point.CostRate + $point.CostRateStd) $left $range
            $y1 = Map-Y ($point.Reward + $point.RewardStd) $range
            $y2 = Map-Y ($point.Reward - $point.RewardStd) $range

            [void]$svg.AppendLine("<line x1='$x1' y1='$y' x2='$x2' y2='$y' stroke='$color' stroke-width='2'/>")
            [void]$svg.AppendLine("<line x1='$x1' y1='$($y - 5)' x2='$x1' y2='$($y + 5)' stroke='$color' stroke-width='2'/>")
            [void]$svg.AppendLine("<line x1='$x2' y1='$($y - 5)' x2='$x2' y2='$($y + 5)' stroke='$color' stroke-width='2'/>")
            [void]$svg.AppendLine("<line x1='$x' y1='$y1' x2='$x' y2='$y2' stroke='$color' stroke-width='2'/>")
            [void]$svg.AppendLine("<line x1='$($x - 5)' y1='$y1' x2='$($x + 5)' y2='$y1' stroke='$color' stroke-width='2'/>")
            [void]$svg.AppendLine("<line x1='$($x - 5)' y1='$y2' x2='$($x + 5)' y2='$y2' stroke='$color' stroke-width='2'/>")
            [void]$svg.AppendLine("<circle cx='$x' cy='$y' r='9' fill='$color' stroke='white' stroke-width='2'/>")

            $labelX = $x + 12
            $labelY = $y - 10
            [void]$svg.AppendLine("<text class='label' x='$labelX' y='$labelY' fill='$color'>d=$($point.Threshold.ToString('0.##'))</text>")
        }
    }

    $arrowX1 = $left + 155
    $arrowY1 = $plotTop + 135
    $arrowX2 = $left + 65
    $arrowY2 = $plotTop + 55
    [void]$svg.AppendLine("<defs><marker id='arrow$panel' markerWidth='10' markerHeight='10' refX='8' refY='3' orient='auto'><path d='M0,0 L0,6 L9,3 z' fill='#555'/></marker></defs>")
    [void]$svg.AppendLine("<line x1='$arrowX1' y1='$arrowY1' x2='$arrowX2' y2='$arrowY2' stroke='#555' stroke-width='2.5' marker-end='url(#arrow$panel)'/>")
    [void]$svg.AppendLine("<text class='tick' x='$($arrowX1 + 8)' y='$($arrowY1 + 8)'>better</text>")
}

[void]$svg.AppendLine("<text class='axis' transform='translate(31 350) rotate(-90)' text-anchor='middle'>Mean reward over final 10 evaluations  -  higher is better</text>")

$legendY = 685
[void]$svg.AppendLine("<circle cx='505' cy='$legendY' r='8' fill='$($styles.cceg.Color)'/><text class='legend' x='523' y='$($legendY + 7)'>$($styles.cceg.Label)</text>")
[void]$svg.AppendLine("<circle cx='805' cy='$legendY' r='8' fill='$($styles.ccel.Color)'/><text class='legend' x='823' y='$($legendY + 7)'>$($styles.ccel.Label)</text>")
[void]$svg.AppendLine("</svg>")

[System.IO.File]::WriteAllText($output, $svg.ToString(), [System.Text.UTF8Encoding]::new($false))
Write-Output $output
