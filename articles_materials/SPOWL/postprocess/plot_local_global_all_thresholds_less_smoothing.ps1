$ErrorActionPreference = 'Stop'

# Window 2 keeps light smoothing while showing early dynamics more clearly
# than the main plot, which uses window 5.
& (Join-Path $PSScriptRoot 'plot_local_global_all_thresholds.ps1') `
    -SmoothingWindow 2 `
    -OutputBase 'local_global_all_thresholds_less_smoothing'
