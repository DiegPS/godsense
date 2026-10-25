[CmdletBinding()]
param(
    [switch]$SkipIntegration,
    [switch]$SkipBuild,
    [switch]$ProfileUI,
    [double]$MinimumCoverage = 65
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot

function Invoke-FlutterStep {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string[]]$FlutterArguments
    )

    Write-Host "`n==> $Name" -ForegroundColor Cyan
    & flutter @FlutterArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Step '$Name' failed with exit code $LASTEXITCODE."
    }
}

function Get-ProjectCoverage {
    param([Parameter(Mandatory = $true)][string]$LcovPath)

    if (-not (Test-Path -LiteralPath $LcovPath -PathType Leaf)) {
        throw "Coverage report was not generated at '$LcovPath'."
    }

    $includedSource = $false
    $totalLines = 0
    $coveredLines = 0
    foreach ($line in Get-Content -LiteralPath $LcovPath) {
        if ($line.StartsWith('SF:')) {
            $source = $line.Substring(3).Replace('/', '\')
            $includedSource = $source -match '(^|\\)lib\\' -and
                $source -notmatch '(\.g|\.freezed)\.dart$'
            continue
        }
        if ($includedSource -and $line -match '^DA:\d+,(\d+)') {
            $totalLines++
            if ([int]$Matches[1] -gt 0) {
                $coveredLines++
            }
        }
    }
    if ($totalLines -eq 0) {
        throw 'No application lines were found in the coverage report.'
    }
    return [math]::Round(($coveredLines * 100.0) / $totalLines, 1)
}

Invoke-FlutterStep 'Resolve dependencies' @('pub', 'get')
Invoke-FlutterStep 'Static analysis' @('analyze', '--fatal-infos')
Invoke-FlutterStep 'Unit and widget tests with coverage' @(
    'test',
    '--coverage',
    '--exclude-tags',
    'native-cv',
    '--reporter',
    'compact'
)

$coverage = Get-ProjectCoverage -LcovPath (
    Join-Path $projectRoot 'coverage\lcov.info'
)
Write-Host "Application coverage: $coverage%" -ForegroundColor Green
if ($coverage -lt $MinimumCoverage) {
    throw "Coverage $coverage% is below the local floor of $MinimumCoverage%."
}

$nativeCvTests = @(
    'test/application/native_vision_targets_test.dart',
    'test/cv_corpus_comparator_test.dart',
    'test/infrastructure/native_vision/multi_display_calibration_test.dart',
    'test/native_calibration_parity_test.dart'
)
foreach ($nativeTest in $nativeCvTests) {
    Invoke-FlutterStep "Native DartCV: $nativeTest" @(
        'test',
        $nativeTest,
        '--reporter',
        'compact'
    )
}

if (-not $SkipIntegration) {
    $integrationTests = Get-ChildItem -LiteralPath (
        Join-Path $projectRoot 'integration_test'
    ) -Filter '*_test.dart' -File | Sort-Object Name
    foreach ($testFile in $integrationTests) {
        $relativePath = 'integration_test/' + $testFile.Name
        Invoke-FlutterStep "Integration: $($testFile.Name)" @(
            'test',
            $relativePath,
            '--reporter',
            'compact'
        )
    }
}

if ($ProfileUI) {
    & (Join-Path $PSScriptRoot 'profile_windows.ps1')
}

if (-not $SkipBuild) {
    Invoke-FlutterStep 'Windows release build' @(
        'build',
        'windows',
        '--release'
    )
    $releaseDirectory = Join-Path $projectRoot 'build\windows\x64\runner\Release'
    $smoke = Start-Process -FilePath (Join-Path $releaseDirectory 'godsense.exe') `
        -WorkingDirectory $releaseDirectory -WindowStyle Hidden -PassThru
    try {
        if ($smoke.WaitForExit(8000)) {
            throw "Release exited during startup with code $($smoke.ExitCode)."
        }
        Write-Host 'Windows release startup passed.' -ForegroundColor Green
    } finally {
        if (-not $smoke.HasExited) {
            Stop-Process -Id $smoke.Id
        }
        $smoke.Dispose()
    }
}

Write-Host "`nGodSense local verification passed." -ForegroundColor Green
