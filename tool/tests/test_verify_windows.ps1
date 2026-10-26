$ErrorActionPreference = 'Stop'
$originalLocation = Get-Location
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ('godsense-verification-test-' + [Guid]::NewGuid().ToString('N'))
$calls = [Collections.Generic.List[string]]::new()
$failAnalysis = $false
$lowCoverage = $false

# Invoke the actual verification script in a disposable miniature workspace.
# No Flutter process is started and no application coverage file is overwritten.
function flutter {
    $calls.Add(($args -join ' '))
    $global:LASTEXITCODE = 0
    if ($args[0] -eq 'analyze' -and $failAnalysis) { $global:LASTEXITCODE = 1 }
    if ($args[0] -eq 'test') {
        $hit = if ($lowCoverage) { 0 } else { 1 }
        "SF:lib/synthetic.dart`nDA:1,$hit`nend_of_record" | Set-Content -LiteralPath 'coverage/lcov.info'
    }
}

try {
    New-Item -ItemType Directory -Path (Join-Path $temporaryRoot 'tool'), (Join-Path $temporaryRoot 'coverage') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path (Split-Path -Parent $PSScriptRoot) 'verify_windows.ps1') -Destination (Join-Path $temporaryRoot 'tool/verify_windows.ps1')
    $scriptPath = Join-Path $temporaryRoot 'tool/verify_windows.ps1'
    foreach ($scenario in @(
        @{ name = 'success'; fail = $false; low = $false; keepGoing = $true; expectedCalls = 7; expectedFailure = $false },
        @{ name = 'fail-fast'; fail = $true; low = $false; keepGoing = $false; expectedCalls = 2; expectedFailure = $true },
        @{ name = 'continue-after-analysis-error'; fail = $true; low = $false; keepGoing = $true; expectedCalls = 7; expectedFailure = $true },
        @{ name = 'continue-after-low-coverage'; fail = $false; low = $true; keepGoing = $true; expectedCalls = 7; expectedFailure = $true }
    )) {
        $calls.Clear()
        $failAnalysis = $scenario.fail
        $lowCoverage = $scenario.low
        $caught = $false
        try { & $scriptPath -SkipBuild -SkipIntegration -ContinueOnFailure:$scenario.keepGoing *> $null }
        catch { $caught = $true }
        if ($caught -ne $scenario.expectedFailure -or $calls.Count -ne $scenario.expectedCalls) {
            throw "Verification runner regression: $($scenario.name), failed=$caught, calls=$($calls.Count), expected=$($scenario.expectedCalls)."
        }
        Write-Host "Passed verification runner scenario: $($scenario.name)"
    }
} finally {
    Set-Location -LiteralPath $originalLocation.Path
    $resolved = [IO.Path]::GetFullPath($temporaryRoot)
    $temporaryParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if (-not $resolved.StartsWith($temporaryParent, [StringComparison]::OrdinalIgnoreCase) -or
        -not ([IO.Path]::GetFileName($resolved)).StartsWith('godsense-verification-test-')) {
        throw 'Refusing to remove an unexpected verification fixture path.'
    }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
