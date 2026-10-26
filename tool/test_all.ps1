[CmdletBinding()]
param(
    [switch]$RunFreeInference,
    [string]$KiloExecutable,
    [string]$OpenCodeExecutable,
    [double]$TargetCoverage = 100
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
$started = Get-Date
$sdkJson = & flutter --version --machine
if ($LASTEXITCODE -ne 0) { throw 'Cannot identify the Flutter toolchain for this run.' }
$sdk = $sdkJson | ConvertFrom-Json |
    Select-Object frameworkVersion, frameworkRevision, engineRevision, dartSdkVersion
$runDirectory = Join-Path $projectRoot ('build/testing/runs/' + $started.ToString('yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null
$stages = [Collections.Generic.List[object]]::new()
$sourceBefore = @{}
Get-ChildItem -LiteralPath (Join-Path $projectRoot 'lib') -Recurse -File -Filter '*.dart' | ForEach-Object {
    $sourceBefore[$_.FullName] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
}

function Get-VerificationSourceHashes {
    $hashes = @{}
    $paths = @(& git -c core.quotePath=false ls-files --cached --others --exclude-standard -- lib test integration_test tool windows assets pubspec.yaml pubspec.lock analysis_options.yaml .gitignore)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inventory verification inputs.' }
    foreach ($path in $paths) {
        $absolute = Join-Path $projectRoot $path
        if (Test-Path -LiteralPath $absolute -PathType Leaf) {
            $hashes[$path] = (Get-FileHash -LiteralPath $absolute -Algorithm SHA256).Hash
        }
    }
    return $hashes
}
$verificationBefore = Get-VerificationSourceHashes

function Invoke-TestingStage {
    param([string]$Name, [scriptblock]$Command)
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $passed = $false
    $failure = $null
    Write-Host "Running $Name"
    try {
        & $Command *> (Join-Path $runDirectory ($Name + '.log'))
        $passed = $true
    } catch {
        $failure = $_.Exception.Message
        Write-Host "Failed ${Name}: $failure" -ForegroundColor Red
    }
    $stages.Add([ordered]@{ name = $Name; passed = $passed; seconds = $timer.Elapsed.TotalSeconds; error = $failure })
}

# Native Windows builds are deliberately sequential: Flutter shares its runner
# output directory across integration targets, profiling and release builds.
Invoke-TestingStage 'windows-verification' {
    & (Join-Path $PSScriptRoot 'verify_windows.ps1') -ProfileUI -ContinueOnFailure
}
Invoke-TestingStage 'installed-runtimes' {
    & (Join-Path $PSScriptRoot 'test_installed_runtimes.ps1') -RunFreeInference:$RunFreeInference -KiloExecutable $KiloExecutable -OpenCodeExecutable $OpenCodeExecutable
}
Invoke-TestingStage 'coverage-tool-tests' {
    & python -m unittest discover -s tool/tests -v
    if ($LASTEXITCODE -ne 0) { throw 'Coverage tooling regression tests failed.' }
}
Invoke-TestingStage 'verification-tool-tests' {
    & (Join-Path $PSScriptRoot 'tests/test_verify_windows.ps1')
}

$coverageFiles = @(
    (Get-Item -LiteralPath (Join-Path $projectRoot 'coverage/lcov.info') -ErrorAction SilentlyContinue),
    (Get-ChildItem -LiteralPath (Join-Path $projectRoot 'build/testing') -Filter '*.info' -File -ErrorAction SilentlyContinue)
) | ForEach-Object { $_ } | Where-Object { $_ -and $_.LastWriteTime -ge $started }
foreach ($file in $coverageFiles) { Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $runDirectory $file.Name) }

$changedSources = @()
foreach ($entry in $sourceBefore.GetEnumerator()) {
    if (-not (Test-Path -LiteralPath $entry.Key) -or (Get-FileHash -LiteralPath $entry.Key -Algorithm SHA256).Hash -ne $entry.Value) {
        $changedSources += $entry.Key
    }
}
$addedSources = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'lib') -Recurse -File -Filter '*.dart' |
    Where-Object { -not $sourceBefore.ContainsKey($_.FullName) } | ForEach-Object FullName)
$verificationAfter = Get-VerificationSourceHashes
$changedVerificationInputs = @(
    foreach ($path in @($verificationBefore.Keys) + @($verificationAfter.Keys) | Sort-Object -Unique) {
        if ($verificationBefore[$path] -ne $verificationAfter[$path]) { $path }
    }
)
Invoke-TestingStage 'combined-coverage' {
    if ($changedSources.Count -or $addedSources.Count) { throw 'Application sources changed during testing; coverage cannot be certified for this run.' }
    if ($changedVerificationInputs.Count) { throw ('Verification inputs changed during testing; this run cannot be certified: ' + ($changedVerificationInputs -join ', ')) }
    & python tool/coverage_report.py (Join-Path $runDirectory '*.info') --minimum $TargetCoverage --output (Join-Path $runDirectory 'coverage.json')
    if ($LASTEXITCODE -ne 0) { throw "The $TargetCoverage% coverage target has not been reached. See coverage.json for uncovered lines and unmeasured files." }
}

$summary = [ordered]@{
    started_at = $started.ToUniversalTime().ToString('o')
    finished_at = (Get-Date).ToUniversalTime().ToString('o')
    commit = (& git rev-parse HEAD)
    dirty_files = @(& git status --porcelain)
    application_source_sha256 = $sourceBefore
    verification_source_sha256 = $verificationBefore
    changed_verification_inputs = $changedVerificationInputs
    target_coverage = $TargetCoverage
    flutter_sdk = $sdk
    stages = $stages.ToArray()
    passed = @($stages | Where-Object { -not $_.passed }).Count -eq 0
}
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $runDirectory 'summary.json') -Encoding utf8
Write-Host "Testing evidence: $runDirectory"
if (-not $summary.passed) { throw 'Full testing is incomplete or failed. Inspect the stage logs and coverage report; skipped integrations are explicitly listed in those logs.' }
Write-Host 'All testing stages and the coverage target passed.' -ForegroundColor Green
