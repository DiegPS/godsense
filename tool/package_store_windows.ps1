[CmdletBinding()]
param(
    [string]$CandidateDirectory,
    [string]$PackageVersion,
    [switch]$SkipVerification
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'MSIX packaging requires Windows and the Windows SDK.'
}
$identity = Get-Content -LiteralPath 'windows/packaging/store-identity.json' -Raw -Encoding UTF8 | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($PackageVersion)) {
    $versionLine = Get-Content -LiteralPath 'pubspec.yaml' -Encoding UTF8 |
        Where-Object { $_ -match '^version:\s*(\d+\.\d+\.\d+)(?:\+\d+)?\s*$' } |
        Select-Object -First 1
    if ($null -eq $versionLine) { throw 'Cannot determine the version from pubspec.yaml.' }
    [void]($versionLine -match '^version:\s*(\d+\.\d+\.\d+)')
    $PackageVersion = $Matches[1] + '.0'
}
if ($PackageVersion -notmatch '^\d+\.\d+\.\d+\.0$') {
    throw 'Store versions require four numeric parts and a final zero, for example 1.0.0.0.'
}
$parsedVersion = [version]$PackageVersion
if ($parsedVersion.Major -lt 1 -or $parsedVersion.Major -gt 65535 -or
    $parsedVersion.Minor -gt 65535 -or $parsedVersion.Build -gt 65535) {
    throw 'Store version components must fit the MSIX version limits.'
}

$sdkRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
$sdk = Get-ChildItem -LiteralPath $sdkRoot -Directory |
    Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.\d+$' } |
    Sort-Object { [version]$_.Name } -Descending |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'x64\makeappx.exe') } |
    Select-Object -First 1
if ($null -eq $sdk) { throw 'MakeAppx.exe was not found in the Windows SDK.' }
$makeAppx = Join-Path $sdk.FullName 'x64\makeappx.exe'

if ([string]::IsNullOrWhiteSpace($CandidateDirectory)) {
    $distribution = Join-Path $projectRoot 'build\distribution'
    $previous = @(Get-ChildItem -LiteralPath $distribution -Directory -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName)
    & (Join-Path $PSScriptRoot 'package_windows.ps1') -SkipVerification:$SkipVerification
    $created = @(Get-ChildItem -LiteralPath $distribution -Directory |
        Where-Object { $_.FullName -notin $previous -and $_.Name -like 'GodSense-windows-x64-candidate-*' })
    if ($created.Count -ne 1) { throw 'Could not identify the newly verified candidate directory.' }
    $CandidateDirectory = $created[0].FullName
}
$candidate = (Resolve-Path -LiteralPath $CandidateDirectory).Path.TrimEnd('\')
$buildManifest = Get-Content -LiteralPath (Join-Path $candidate 'build-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($buildManifest.source_dirty -or $buildManifest.architecture -ne 'x64') {
    throw 'The input must be a clean, verified Windows x64 candidate.'
}
$expectedFiles = @{}
foreach ($entry in $buildManifest.files) {
    $path = [IO.Path]::GetFullPath((Join-Path $candidate $entry.path))
    if (-not $path.StartsWith($candidate + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'An input manifest path escapes its candidate directory.'
    }
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.sha256) {
        throw "Input candidate checksum mismatch: $($entry.path)"
    }
    $expectedFiles[$entry.path.Replace('\', '/')] = $true
}
foreach ($file in Get-ChildItem -LiteralPath $candidate -Recurse -Force) {
    if ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Input candidates must not contain links.' }
    if ($file.PSIsContainer) { continue }
    $relative = $file.FullName.Substring($candidate.Length + 1).Replace('\', '/')
    if ($relative -ne 'build-manifest.json' -and -not $expectedFiles.ContainsKey($relative)) {
        throw "Unexpected input file: $relative"
    }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$output = Join-Path $projectRoot ('build\store\' + $stamp + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
if ($output.StartsWith($candidate + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The output must not be inside its input candidate.'
}
$staging = Join-Path $output 'package'
[void](New-Item -ItemType Directory -Path $staging)
Get-ChildItem -LiteralPath $candidate | Copy-Item -Destination $staging -Recurse
$assets = Join-Path $staging 'Assets'
[void](New-Item -ItemType Directory -Path $assets)

# Read the PNG bundled in the verified candidate, so the Store artwork always
# belongs to that binary rather than to a possibly newer repository checkout.
Add-Type -AssemblyName System.Drawing
$original = [Drawing.Bitmap]::new((Join-Path $candidate 'data\flutter_assets\assets\branding\godsense-icon-256.png'))
try {
    foreach ($asset in @(@('StoreLogo.png', 50), @('Square44x44Logo.png', 44), @('Square150x150Logo.png', 150))) {
        $bitmap = [Drawing.Bitmap]::new([int]$asset[1], [int]$asset[1])
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear([Drawing.Color]::Transparent)
            $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.DrawImage($original, 0, 0, [int]$asset[1], [int]$asset[1])
            $bitmap.Save((Join-Path $assets $asset[0]), [Drawing.Imaging.ImageFormat]::Png)
        } finally { $graphics.Dispose(); $bitmap.Dispose() }
    }
} finally { $original.Dispose() }

$manifestText = Get-Content -LiteralPath 'windows/packaging/AppxManifest.template.xml' -Raw -Encoding UTF8
$values = @{
    PACKAGE_NAME = $identity.packageName; PUBLISHER = $identity.publisher
    DISPLAY_NAME = $identity.displayName; PUBLISHER_DISPLAY_NAME = $identity.publisherDisplayName
    VERSION = $PackageVersion; MIN_VERSION = $identity.minimumWindowsVersion; SDK_VERSION = $sdk.Name
}
foreach ($key in $values.Keys) {
    $manifestText = $manifestText.Replace(('__' + $key + '__'), [Security.SecurityElement]::Escape([string]$values[$key]))
}
if ($manifestText -match '__[A-Z_]+__') { throw 'The MSIX manifest contains unresolved placeholders.' }
[IO.File]::WriteAllText((Join-Path $staging 'AppxManifest.xml'), $manifestText, [Text.UTF8Encoding]::new($false))
$packagePath = Join-Path $output ($identity.packageName + '_' + $PackageVersion + '_x64.msix')
& $makeAppx pack /d $staging /p $packagePath /h SHA256 /o
if ($LASTEXITCODE -ne 0) { throw "MSIX validation/packaging failed: $LASTEXITCODE." }
$unpacked = Join-Path $output 'verified'
& $makeAppx unpack /p $packagePath /d $unpacked /o
if ($LASTEXITCODE -ne 0) { throw "MSIX unpack validation failed: $LASTEXITCODE." }
[xml]$checked = Get-Content -LiteralPath (Join-Path $unpacked 'AppxManifest.xml') -Raw -Encoding UTF8
if ($checked.Package.Identity.Name -ne $identity.packageName -or
    $checked.Package.Identity.Publisher -ne $identity.publisher -or
    $checked.Package.Identity.Version -ne $PackageVersion -or
    $checked.Package.Properties.PublisherDisplayName -ne $identity.publisherDisplayName) {
    throw 'The packaged identity does not match Partner Center.'
}
foreach ($entry in $buildManifest.files) {
    if ((Get-FileHash -LiteralPath (Join-Path $unpacked $entry.path) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.sha256) {
        throw "Packaged payload checksum mismatch: $($entry.path)"
    }
}
$digest = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText(($packagePath + '.sha256'), $digest + '  ' + [IO.Path]::GetFileName($packagePath) + [Environment]::NewLine)
$provenance = @{
    identity = $identity; version = $PackageVersion; architecture = 'x64'; sha256 = $digest
    application_commit = $buildManifest.commit; packaging_commit = (& git rev-parse HEAD).Trim()
    packaging_source_dirty = [bool](& git status --porcelain); sdk = $sdk.Name; signed = $false
}
[IO.File]::WriteAllText(($packagePath + '.json'), ($provenance | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
Write-Host "MSIX candidate: $packagePath" -ForegroundColor Green
Write-Host "Store ID: $($identity.storeId); SHA256: $digest"
Write-Host 'Unsigned Store candidate. Installation and Store certification remain separate checks.'
