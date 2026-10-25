[CmdletBinding()]
param([switch]$SkipVerification)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
if (-not $SkipVerification) {
    & (Join-Path $PSScriptRoot 'verify_windows.ps1') -ProfileUI
}

$releaseRoot = Join-Path $projectRoot 'build\windows\x64\runner\Release'
foreach ($required in @('godsense.exe', 'flutter_windows.dll', 'dartcv.dll', 'data\app.so')) {
    if (-not (Test-Path -LiteralPath (Join-Path $releaseRoot $required))) {
        throw "Release output is incomplete: $required is missing."
    }
}
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path -LiteralPath $vswhere)) {
    throw 'Visual Studio discovery tool was not found.'
}
$visualStudio = & $vswhere -latest -products '*' -property installationPath
$redistRoot = Join-Path $visualStudio 'VC\Redist\MSVC'
$crt = Get-ChildItem -LiteralPath $redistRoot -Directory |
    Where-Object { $_.Name -match '^\d+\.' } |
    Sort-Object { [version]$_.Name } -Descending |
    ForEach-Object { Join-Path $_.FullName 'x64\Microsoft.VC143.CRT' } |
    Where-Object { Test-Path -LiteralPath $_ -PathType Container } |
    Select-Object -First 1
if ($null -eq $crt) {
    throw 'The x64 Visual C++ redistributable DLLs were not found.'
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$candidateName = 'GodSense-windows-x64-candidate-' + $stamp
$distributionRoot = Join-Path $projectRoot 'build\distribution'
[void](New-Item -ItemType Directory -Path $distributionRoot -Force)
$staging = Join-Path $distributionRoot $candidateName
[void](New-Item -ItemType Directory -Path $staging)
foreach ($item in Get-ChildItem -LiteralPath $releaseRoot) {
    if ($item.Extension -eq '.pdb') { continue }
    Copy-Item -LiteralPath $item.FullName -Destination $staging -Recurse
}
# Application-local deployment follows Flutter's Windows distribution guide.
# Include all CRT companion DLLs from the same version, never from System32.
foreach ($dll in Get-ChildItem -LiteralPath $crt -Filter '*.dll' -File) {
    Copy-Item -LiteralPath $dll.FullName -Destination $staging
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs\distribution\README-Windows.txt') `
    -Destination (Join-Path $staging 'README.txt')

$commit = (& git rev-parse HEAD).Trim()
$dirty = [bool](& git status --porcelain)
$files = @(Get-ChildItem -LiteralPath $staging -File -Recurse | ForEach-Object {
    @{
        path = $_.FullName.Substring($staging.Length + 1).Replace('\', '/')
        bytes = $_.Length
        sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
})
$manifest = @{
    product = 'GodSense'
    channel = 'local-candidate'
    architecture = 'x64'
    commit = $commit
    source_dirty = $dirty
    created_at = [DateTime]::UtcNow.ToString('o')
    files = $files
}
[IO.File]::WriteAllText((Join-Path $staging 'build-manifest.json'),
    ($manifest | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = Join-Path $distributionRoot ($candidateName + '.zip')
$archiveStream = [IO.File]::Open($archive, [IO.FileMode]::CreateNew)
$zip = [IO.Compression.ZipArchive]::new(
    $archiveStream, [IO.Compression.ZipArchiveMode]::Create, $false)
try {
    # Windows PowerShell's CreateFromDirectory uses backslashes in ZIP entry
    # names. Write standard forward-slash paths for portable extraction.
    foreach ($file in Get-ChildItem -LiteralPath $staging -File -Recurse) {
        $entryName = $file.FullName.Substring($staging.Length + 1).Replace('\', '/')
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zip, $file.FullName, $entryName, [IO.Compression.CompressionLevel]::Optimal)
    }
} finally {
    $zip.Dispose()
    $archiveStream.Dispose()
}
$inspection = [IO.Compression.ZipFile]::OpenRead($archive)
try {
    foreach ($required in @('godsense.exe', 'data/app.so', 'data/icudtl.dat', 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
        if ($null -eq $inspection.GetEntry($required)) {
            throw "The ZIP is incomplete: $required is missing."
        }
    }
} finally {
    $inspection.Dispose()
}
$digest = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText(($archive + '.sha256'),
    ($digest + '  ' + [IO.Path]::GetFileName($archive) + [Environment]::NewLine))
Write-Host "Windows candidate: $archive" -ForegroundColor Green
Write-Host "SHA256: $digest"
