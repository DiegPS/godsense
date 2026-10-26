[CmdletBinding()]
param([switch]$IgnoreInstalledModels)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
# This entrypoint imports only pure Dart catalog data. Bypass pub/hooks so
# preparing downloads cannot touch a DLL used by an ongoing Windows test.
$json = & dart --disable-dart-dev --packages=.dart_tool/package_config.json tool/voice_model_manifest.dart
if ($LASTEXITCODE -ne 0) { throw 'Could not read the native voice fixture catalog.' }
$manifest = $json | ConvertFrom-Json
$root = [IO.Path]::GetFullPath((Join-Path $projectRoot 'build/testing/model-downloads'))
$total = ($manifest.downloads | Measure-Object bytes -Sum).Sum
if ($total -gt 2GB -or (Get-PSDrive C).Free -lt ($total * 3 + 20GB)) { throw 'Insufficient space or unexpected fixture size.' }
foreach ($model in $manifest) {
    $existing = Join-Path (Join-Path $env:APPDATA 'com.godsense/godsense/tts/models') $model.key
    if (-not $IgnoreInstalledModels -and (Test-Path -LiteralPath (Join-Path $existing '.godsense-integrity.json'))) { continue }
    foreach ($item in $model.downloads) {
        $destination = [IO.Path]::GetFullPath((Join-Path (Join-Path $root $model.key) $item.file))
        if (-not $destination.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture path escaped its cache.' }
        if (([uri]$item.url).Scheme -ne 'https') { throw 'Fixture downloads require HTTPS.' }
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        if ((Test-Path -LiteralPath $destination) -and
            (Get-Item -LiteralPath $destination).Length -eq $item.bytes -and
            (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant() -eq $item.sha256) { continue }
        Write-Host "Preparing $($model.id): $($item.file)"
        $partial = $destination + '.partial'
        $downloaded = $false
        for ($attempt = 0; $attempt -lt 3 -and -not $downloaded; $attempt++) {
            try {
                Invoke-WebRequest -Uri $item.url -OutFile $partial -TimeoutSec 120
                if ((Get-Item -LiteralPath $partial).Length -ne $item.bytes -or
                    (Get-FileHash -LiteralPath $partial -Algorithm SHA256).Hash.ToLowerInvariant() -ne $item.sha256) { throw 'Fixture size / SHA256 mismatch.' }
                Move-Item -LiteralPath $partial -Destination $destination -Force
                $downloaded = $true
            } catch { if ($attempt -eq 2) { throw } }
        }
    }
}
Write-Host 'All required fixture downloads match their pinned hashes.'
