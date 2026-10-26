[CmdletBinding()]
param(
    [string]$KiloExecutable,
    [string]$OpenCodeExecutable,
    [string]$ModelRoot,
    [string]$NativeLibraryDirectory,
    [switch]$RunFreeInference,
    [switch]$SpeechOnly
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
if (-not $KiloExecutable) {
    $KiloExecutable = Join-Path $env:LOCALAPPDATA 'Volta/tools/image/packages/@kilocode/cli/node_modules/@kilocode/cli/node_modules/@kilocode/cli-windows-x64/bin/kilo.exe'
}
if (-not $OpenCodeExecutable) {
    # Package-manager shims may launch another process that outlives the shim.
    # Exercise the standalone binary, just like GodSense's pinned installer.
    $openCodeCandidates = @(
        (Join-Path $env:USERPROFILE '.bun/install/global/node_modules/opencode-windows-x64/bin/opencode.exe'),
        (Join-Path $env:LOCALAPPDATA 'Volta/tools/image/packages/opencode-ai/node_modules/opencode-ai/node_modules/opencode-windows-x64/bin/opencode.exe')
    )
    $OpenCodeExecutable = $openCodeCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
}
if (-not $ModelRoot) { $ModelRoot = Join-Path $env:APPDATA 'com.godsense/godsense/tts/models' }
if (-not $NativeLibraryDirectory) { $NativeLibraryDirectory = Join-Path $projectRoot 'build/windows/x64/runner/Release' }

$testEnvironment = @{}
$testEnvironment['GODSENSE_NATIVE_COVERAGE_DIR'] = Join-Path $projectRoot 'build/testing'
if (Test-Path -LiteralPath $ModelRoot -PathType Container) { $testEnvironment['GODSENSE_MIGRATED_MODELS_DIR'] = $ModelRoot }
if (Test-Path -LiteralPath $KiloExecutable -PathType Leaf) { $testEnvironment['GODSENSE_TEST_KILO_EXE'] = $KiloExecutable }
if ($OpenCodeExecutable -and (Test-Path -LiteralPath $OpenCodeExecutable -PathType Leaf)) { $testEnvironment['GODSENSE_TEST_OPENCODE_EXE'] = $OpenCodeExecutable }
if ($RunFreeInference) { $testEnvironment['GODSENSE_TEST_KILO_AUTO_FREE'] = 'true' }
if (Test-Path -LiteralPath (Join-Path $NativeLibraryDirectory 'sherpa-onnx-c-api.dll')) { $testEnvironment['GODSENSE_SHERPA_LIBRARY_DIR'] = $NativeLibraryDirectory }
$modelVariables = @{
    'GODSENSE_CANARY_MODEL_DIR' = 'speech-canary-180m-int8-2025-07-07-v1'
    'GODSENSE_SUPERTONIC_MODEL_DIR' = 'supertonic-3-hybrid-2026-05-11-v1'
}
foreach ($modelVariable in $modelVariables.GetEnumerator()) {
    $modelDirectory = Join-Path $ModelRoot $modelVariable.Value
    if (Test-Path -LiteralPath $modelDirectory -PathType Container) { $testEnvironment[$modelVariable.Key] = $modelDirectory }
}
$preparedVoiceManifest = Join-Path $projectRoot 'build/testing/voice-test-models.json'
if (Test-Path -LiteralPath $preparedVoiceManifest -PathType Leaf) {
    $preparedVoices = Get-Content -LiteralPath $preparedVoiceManifest -Raw | ConvertFrom-Json
    foreach ($entry in $preparedVoices.PSObject.Properties) {
        if ($entry.Name -notmatch '^GODSENSE_(SUPERTONIC|PIPER_MX|PIPER_ES|KITTEN|KOKORO|MATCHA|POCKET|ZIPVOICE)_MODEL_DIR$') { throw 'Unexpected prepared model variable.' }
        if (-not $testEnvironment.ContainsKey($entry.Name) -and (Test-Path -LiteralPath $entry.Value -PathType Container)) { $testEnvironment[$entry.Name] = $entry.Value }
    }
}
$canary = $testEnvironment['GODSENSE_CANARY_MODEL_DIR']
if ($canary) {
    foreach ($modelFile in @(@('GODSENSE_SILERO_VAD_MODEL', 'silero_vad.onnx'), @('GODSENSE_GTCRN_MODEL', 'gtcrn_simple.onnx'))) {
        $modelPath = Join-Path $canary $modelFile[1]
        if (Test-Path -LiteralPath $modelPath -PathType Leaf) { $testEnvironment[$modelFile[0]] = $modelPath }
    }
}
$previousEnvironment = @{}
$failures = @()
$tests = @(
    'test/infrastructure/ai/ai_model_catalog_live_test.dart',
    'integration_test/ai_runtime_process_test.dart',
    'integration_test/kilo_streaming_test.dart',
    'integration_test/kilo_real_conversation_e2e_test.dart',
    'integration_test/installed_model_migration_test.dart',
    'integration_test/ui/real_ai_chat_test.dart',
    'test/infrastructure/speech/sherpa_speech_integration_test.dart',
    'test/infrastructure/speech/sherpa_tts_integration_test.dart'
)
if ($SpeechOnly) { $tests = @($tests | Where-Object { $_.StartsWith('test/infrastructure/speech/') }) }
try {
    foreach ($entry in $testEnvironment.GetEnumerator()) {
        $previousEnvironment[$entry.Key] = [Environment]::GetEnvironmentVariable($entry.Key, 'Process')
        [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, 'Process')
    }
    foreach ($test in $tests) {
        Write-Host "Running installed-runtime check: $test"
        if ($test -eq 'test/infrastructure/speech/sherpa_tts_integration_test.dart') {
            $voiceJson = & dart --disable-dart-dev --packages=.dart_tool/package_config.json tool/voice_model_manifest.dart
            if ($LASTEXITCODE -ne 0) { throw 'Could not enumerate native voice test cases.' }
            foreach ($voiceCase in ($voiceJson | ConvertFrom-Json)) {
                Write-Host "Running isolated voice backend: $($voiceCase.id)"
                & flutter test $test --no-pub --plain-name $voiceCase.id --coverage --coverage-path ('build/testing/installed-tts-' + $voiceCase.id + '.info') --reporter expanded
                if ($LASTEXITCODE -ne 0) { $failures += "$test [$($voiceCase.id)]" }
            }
            continue
        }
        & flutter test $test --no-pub --coverage --coverage-path ('build/testing/installed-' + [IO.Path]::GetFileNameWithoutExtension($test) + '.info') --reporter expanded
        if ($LASTEXITCODE -ne 0) { $failures += $test }
    }
} finally {
    foreach ($entry in $previousEnvironment.GetEnumerator()) { [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, 'Process') }
}
if ($failures.Count) { throw ('Installed-runtime checks failed: ' + ($failures -join ', ')) }
Write-Host 'All enabled installed-runtime checks passed. Missing models remain explicitly skipped by their tests.'
