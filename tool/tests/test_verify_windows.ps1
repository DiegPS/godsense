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
    Copy-Item -LiteralPath (Join-Path (Split-Path -Parent $PSScriptRoot) 'testing_targets.ps1') -Destination (Join-Path $temporaryRoot 'tool/testing_targets.ps1')
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
    . (Join-Path (Split-Path -Parent $PSScriptRoot) 'testing_targets.ps1')
    $runtimeTargets = @(Get-GodSenseInstalledRuntimeTests | Where-Object { $_.StartsWith('integration_test/') })
    $otherTargets = @('integration_test/new_future_test.dart', 'integration_test/ui/general_fixture_test.dart')
    foreach ($target in ($runtimeTargets + $otherTargets)) {
        $absolute = Join-Path $temporaryRoot $target
        New-Item -ItemType Directory -Path (Split-Path -Parent $absolute) -Force | Out-Null
        Set-Content -LiteralPath $absolute -Value '// Disposable target fixture.'
    }
    $failAnalysis = $false
    $lowCoverage = $false
    foreach ($defer in @($false, $true)) {
        $calls.Clear()
        & $scriptPath -SkipBuild -InstalledRuntimesSeparately:$defer *> $null
        $executed = @($calls | Where-Object { $_ -match '^test integration_test/' })
        $expected = if ($defer) { $otherTargets } else { $runtimeTargets + $otherTargets }
        if ($executed.Count -ne $expected.Count) { throw "Incorrect integration count: deferred=$defer" }
        foreach ($target in $expected) {
            if (-not ($executed | Where-Object { $_.StartsWith('test ' + $target + ' ') })) {
                throw "Expected integration was not executed: $target"
            }
        }
        foreach ($target in $runtimeTargets) {
            $found = @($executed | Where-Object { $_.StartsWith('test ' + $target + ' ') }).Count
            if ($found -ne [int](-not $defer)) { throw "Runtime deferral regression: $target" }
        }
        Write-Host "Passed integration inventory scenario: deferred=$defer"
    }

    # Match the inventory to the real bundle imports before trusting deferral.
    $groupedTargets = @(Get-GodSenseGroupedWindowsTests)
    $bundleName = 'integration_test/ui/windows_journeys_test.dart'
    $realBundle = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) $bundleName
    $importedTargets = @(
        [regex]::Matches((Get-Content -LiteralPath $realBundle -Raw), "import '(?:\./)?([^'/:]+_test\.dart)'") |
            ForEach-Object { 'integration_test/ui/' + $_.Groups[1].Value }
    )
    if ($importedTargets.Count -ne $groupedTargets.Count -or
        @(Compare-Object $groupedTargets $importedTargets).Count) {
        throw 'Windows bundle imports differ from the grouped integration inventory.'
    }
    foreach ($target in ($groupedTargets + $bundleName)) {
        $absolute = Join-Path $temporaryRoot $target
        New-Item -ItemType Directory -Path (Split-Path -Parent $absolute) -Force | Out-Null
        Set-Content -LiteralPath $absolute -Value '// Disposable grouped target fixture.'
    }
    foreach ($defer in @($false, $true)) {
        $calls.Clear()
        & $scriptPath -SkipBuild -InstalledRuntimesSeparately:$defer *> $null
        $executed = @($calls | Where-Object { $_ -match '^test integration_test/' })
        $expected = if ($defer) { $otherTargets + $bundleName } else { $runtimeTargets + $otherTargets + $bundleName }
        if ($executed.Count -ne $expected.Count) { throw "Incorrect bundled integration count: deferred=$defer" }
        foreach ($target in $expected) {
            if (@($executed | Where-Object { $_.StartsWith('test ' + $target + ' ') }).Count -ne 1) {
                throw "Expected integration must run exactly once with bundle: $target"
            }
        }
        foreach ($target in $groupedTargets) {
            if ($executed | Where-Object { $_.StartsWith('test ' + $target + ' ') }) {
                throw "Grouped suite was unnecessarily executed twice: $target"
            }
        }
        $bundleCall = $executed | Where-Object { $_.StartsWith('test ' + $bundleName + ' ') }
        if ($bundleCall -notmatch '-d windows --coverage --coverage-path build/testing/ui-windows_journeys_test.info') {
            throw 'Bundled UI suite lost its native Windows target or coverage output.'
        }
        Write-Host "Passed bundled integration inventory scenario: deferred=$defer"
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
