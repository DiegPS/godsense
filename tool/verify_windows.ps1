[CmdletBinding()]
param(
    [switch]$SkipIntegration,
    [switch]$SkipBuild,
    [switch]$InstalledRuntimesSeparately,
    [switch]$ProfileUI,
    [switch]$ContinueOnFailure,
    [double]$MinimumCoverage = 65
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'testing_targets.ps1')
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
$verificationFailures = [Collections.Generic.List[string]]::new()
$lastFlutterStepPassed = $false

function Register-VerificationFailure {
    param([string]$Message)
    if (-not $ContinueOnFailure) { throw $Message }
    $verificationFailures.Add($Message)
    Write-Warning $Message
}

function Invoke-FlutterStep {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string[]]$FlutterArguments
    )

    Write-Host "`n==> $Name" -ForegroundColor Cyan
    $script:lastFlutterStepPassed = $false
    try {
        & flutter @FlutterArguments
        if ($LASTEXITCODE -ne 0) {
            throw "Step '$Name' failed with exit code $LASTEXITCODE."
        }
        $script:lastFlutterStepPassed = $true
    } catch {
        Register-VerificationFailure $_.Exception.Message
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

try {
    $coverage = Get-ProjectCoverage -LcovPath (
        Join-Path $projectRoot 'coverage\lcov.info'
    )
    Write-Host "Application coverage: $coverage%" -ForegroundColor Green
    if ($coverage -lt $MinimumCoverage) {
        throw "Coverage $coverage% is below the local floor of $MinimumCoverage%."
    }
} catch {
    Register-VerificationFailure $_.Exception.Message
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
        '--coverage',
        '--coverage-path',
        ('build/testing/native-' + [IO.Path]::GetFileNameWithoutExtension($nativeTest) + '.info'),
        '--reporter',
        'compact'
    )
}

if (-not $SkipIntegration) {
    $integrationTests = Get-ChildItem -LiteralPath (
        Join-Path $projectRoot 'integration_test'
    ) -Filter '*_test.dart' -File -Recurse | Sort-Object FullName
    foreach ($testFile in $integrationTests) {
        $relativePath = $testFile.FullName.Substring($projectRoot.Length + 1).Replace('\', '/')
        if ($InstalledRuntimesSeparately -and $relativePath -in (Get-GodSenseInstalledRuntimeTests)) {
            Write-Host "Deferred to installed-runtimes stage: $relativePath"
            continue
        }
        $deviceArguments = @()
        if ($relativePath.StartsWith('integration_test/ui/')) {
            $deviceArguments = @('-d', 'windows', '--coverage', '--coverage-path',
                ('build/testing/ui-' + $testFile.BaseName + '.info'))
        }
        Invoke-FlutterStep -Name "Integration: $($testFile.Name)" -FlutterArguments (@(
            'test',
            $relativePath,
            '--reporter',
            'compact'
        ) + $deviceArguments)
    }
}

if ($ProfileUI) {
    try {
        & (Join-Path $PSScriptRoot 'profile_windows.ps1')
    } catch {
        Register-VerificationFailure $_.Exception.Message
    }
}

if (-not $SkipBuild) {
    Invoke-FlutterStep 'Windows release build' @(
        'build',
        'windows',
        '--release'
    )
    if ($lastFlutterStepPassed) {
        $releaseDirectory = Join-Path $projectRoot 'build\windows\x64\runner\Release'
        $smoke = $null
        try {
            $smoke = Start-Process -FilePath (Join-Path $releaseDirectory 'godsense.exe') `
                -WorkingDirectory $releaseDirectory -WindowStyle Hidden -PassThru
            if ($smoke.WaitForExit(8000)) {
                throw "Release exited during startup with code $($smoke.ExitCode)."
            }
            Write-Host 'Windows release startup passed.' -ForegroundColor Green
        } catch {
            Register-VerificationFailure $_.Exception.Message
        } finally {
            if ($null -ne $smoke) {
                if (-not $smoke.HasExited) { Stop-Process -Id $smoke.Id }
                $smoke.Dispose()
            }
        }
    }
}

if ($verificationFailures.Count) {
    throw ('Windows verification failed: ' + ($verificationFailures -join '; '))
}
Write-Host "`nGodSense local verification passed." -ForegroundColor Green
