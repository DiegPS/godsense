[CmdletBinding()]
param(
    [double]$MaximumNavigationMs = 100,
    [double]$MaximumEventLoopGapMs = 250
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
$reportName = 'navigation-' + [Guid]::NewGuid().ToString('N') + '.json'
$reportPath = Join-Path $projectRoot ('build\performance\' + $reportName)

& flutter run -d windows --profile -t tool/profile_windows.dart `
    --dart-define=GODSENSE_PERF_AUTOCLOSE=true `
    "--dart-define=GODSENSE_PERF_REPORT=$reportPath"
if ($LASTEXITCODE -ne 0) {
    throw "Windows profiling failed with exit code $LASTEXITCODE."
}
# Flutter can report exit code zero when the native process crashes. Require a
# fresh completed report, not just the exit code or a successful compilation.
if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
    throw 'The application exited without completing its performance checks.'
}
$report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
foreach ($name in @('cold_navigation', 'warm_navigation', 'navigation_with_capture')) {
    $measurement = $report.$name
    if ($null -eq $measurement -or $measurement.navigation.samples -lt 6) {
        throw "Incomplete navigation measurement: $name."
    }
    if ($measurement.navigation.max_ms -gt $MaximumNavigationMs) {
        throw "$name exceeded the navigation budget: $($measurement.navigation.max_ms) ms."
    }
    if ($measurement.event_loop.max_ms -gt $MaximumEventLoopGapMs) {
        throw "$name stalled the event loop for $($measurement.event_loop.max_ms) ms."
    }
    Write-Host "$name - navigation p95: $($measurement.navigation.p95_ms) ms; build p95: $($measurement.build.p95_ms) ms"
}
if ($report.captures -lt 10 -or $report.capture_errors -ne 0) {
    throw "Capture stress failed: $($report.captures) frames, $($report.capture_errors) errors."
}
Write-Host "Windows UI performance passed. Report: $reportPath" -ForegroundColor Green
