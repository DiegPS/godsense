[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
$patch = '16.21.1'
$cache = Join-Path $projectRoot 'build\store-art-assets'
[void](New-Item -ItemType Directory -Force -Path $cache)
$sources = @()
foreach ($champion in @('Ahri','Azir','Orianna','Ashe','LeeSin','Garen','Jinx','Leona','Thresh','Lissandra','Darius','Vi','MasterYi','Zed','Yasuo','Katarina')) {
    $url = "https://ddragon.leagueoflegends.com/cdn/$patch/img/champion/$champion.png"
    $file = Join-Path $cache "$champion.png"
    if (-not (Test-Path -LiteralPath $file)) { Invoke-WebRequest -Uri $url -OutFile $file }
    $sources += @{ url = $url; sha256 = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() }
}
foreach ($item in @(3031,3072,3006,3089,3020,6655,3340,3363)) {
    $url = "https://ddragon.leagueoflegends.com/cdn/$patch/img/item/$item.png"
    $file = Join-Path $cache "$item.png"
    if (-not (Test-Path -LiteralPath $file)) { Invoke-WebRequest -Uri $url -OutFile $file }
    $sources += @{ url = $url; sha256 = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() }
}
$mapUrl = "https://ddragon.leagueoflegends.com/cdn/$patch/img/map/map11.png"
$mapFile = Join-Path $cache 'map11.png'
if (-not (Test-Path -LiteralPath $mapFile)) { Invoke-WebRequest -Uri $mapUrl -OutFile $mapFile }
$sources += @{ url = $mapUrl; sha256 = (Get-FileHash -LiteralPath $mapFile -Algorithm SHA256).Hash.ToLowerInvariant() }
& flutter test test/support/store_screenshots_export.dart --reporter expanded
if ($LASTEXITCODE -ne 0) { throw 'Store screenshot rendering failed.' }
Add-Type -AssemblyName System.Drawing
$output = Join-Path $projectRoot 'design\store'
$images = @(Get-ChildItem -LiteralPath (Join-Path $output 'screenshots') -Filter '*.png' | Sort-Object Name | ForEach-Object {
    $image = [Drawing.Image]::FromFile($_.FullName)
    try {
        if ($image.Width -ne 1600 -or $image.Height -ne 1000) { throw "Unexpected screenshot size: $($_.Name)" }
        @{ file = $_.Name; width = $image.Width; height = $image.Height; bytes = $_.Length;
           sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
    } finally { $image.Dispose() }
})
if ($images.Count -ne 6) { throw 'Expected exactly six Store screenshots.' }
$manifest = @{
    renderer_sha256 = (Get-FileHash test/support/store_screenshots_export.dart -Algorithm SHA256).Hash.ToLowerInvariant()
    classification = 'synthetic-demo'; subject = 'Hide on bush#DEMO'
    personal_data_loaded = $false; art_patch = $patch; images = $images; public_art = $sources
}
[IO.File]::WriteAllText((Join-Path $output 'manifest.json'), ($manifest | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
Write-Host 'Six Store screenshots verified: 1600x1000, synthetic data only.' -ForegroundColor Green
