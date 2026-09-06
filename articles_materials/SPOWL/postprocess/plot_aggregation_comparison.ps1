$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'plot_spowl_ablation_grid.ps1') -Mode aggregation @args
