[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Add-Type -AssemblyName System.Drawing
$source = [Drawing.Bitmap]::new((Join-Path $projectRoot 'design\branding\godsense-master.png'))
try {
    if ($source.Width -ne $source.Height -or $source.Width -lt 512) {
        throw 'The branding master must be square and at least 512 pixels wide.'
    }
    $output = Join-Path $projectRoot 'assets\branding'
    [void](New-Item -ItemType Directory -Path $output -Force)
    $frames = @()
    foreach ($size in @(16, 20, 24, 32, 40, 48, 64, 128, 256)) {
        $bitmap = [Drawing.Bitmap]::new($size, $size, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        $attributes = [Drawing.Imaging.ImageAttributes]::new()
        $stream = [IO.MemoryStream]::new()
        try {
            $graphics.Clear([Drawing.Color]::Transparent)
            $graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
            $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $attributes.SetWrapMode([Drawing.Drawing2D.WrapMode]::TileFlipXY)
            $graphics.DrawImage($source, [Drawing.Rectangle]::new(0, 0, $size, $size),
                0, 0, $source.Width, $source.Height, [Drawing.GraphicsUnit]::Pixel, $attributes)
            $bitmap.Save($stream, [Drawing.Imaging.ImageFormat]::Png)
            $frames += @{ Size = $size; Bytes = $stream.ToArray() }
            if ($size -in @(64, 256)) {
                [IO.File]::WriteAllBytes((Join-Path $output "godsense-icon-$size.png"), $stream.ToArray())
            }
        } finally {
            $stream.Dispose(); $attributes.Dispose(); $graphics.Dispose(); $bitmap.Dispose()
        }
    }
    $iconPath = Join-Path $projectRoot 'windows\runner\resources\app_icon.ico'
    $file = [IO.File]::Create($iconPath)
    $writer = [IO.BinaryWriter]::new($file)
    try {
        $writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]$frames.Count)
        [uint32]$offset = 6 + 16 * $frames.Count
        foreach ($frame in $frames) {
            [byte]$dimension = if ($frame.Size -eq 256) { 0 } else { $frame.Size }
            $writer.Write($dimension); $writer.Write($dimension)
            $writer.Write([byte]0); $writer.Write([byte]0)
            $writer.Write([uint16]1); $writer.Write([uint16]32)
            $writer.Write([uint32]$frame.Bytes.Length); $writer.Write([uint32]$offset)
            $offset += $frame.Bytes.Length
        }
        foreach ($frame in $frames) { $writer.Write([byte[]]$frame.Bytes) }
    } finally { $writer.Dispose(); $file.Dispose() }

    # Validate embedded PNGs directly: System.Drawing.Icon can select a smaller
    # frame even when explicitly asked for 256 pixels.
    $reader = [IO.BinaryReader]::new([IO.File]::OpenRead($iconPath))
    try {
        if ($reader.ReadUInt16() -ne 0 -or $reader.ReadUInt16() -ne 1 -or
            $reader.ReadUInt16() -ne $frames.Count) { throw 'Invalid ICO header.' }
        foreach ($frame in $frames) {
            $entryStart = $reader.BaseStream.Position
            [void]$reader.ReadBytes(8)
            $length = $reader.ReadUInt32(); $position = $reader.ReadUInt32()
            $reader.BaseStream.Position = $position
            $png = [IO.MemoryStream]::new([byte[]]$reader.ReadBytes($length))
            $decoded = [Drawing.Bitmap]::new($png)
            try {
                if ($decoded.Width -ne $frame.Size -or $decoded.Height -ne $frame.Size) {
                    throw 'Invalid ICO frame dimensions.'
                }
                if ($decoded.GetPixel(0, 0).A -ne 0) { throw 'Icon background must be transparent.' }
            } finally { $decoded.Dispose(); $png.Dispose() }
            $reader.BaseStream.Position = $entryStart + 16
        }
    } finally { $reader.Dispose() }
    Write-Host 'Branding assets generated and all nine ICO frames verified.' -ForegroundColor Green
} finally { $source.Dispose() }
