param()
$ErrorActionPreference='Stop'
$sourceRoot=Split-Path -Parent $PSScriptRoot
Add-Type -AssemblyName System.Drawing
if(-not ('ExecutableBranding' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'ExecutableBranding.cs')}
$sizes=[int[]]@(16,24,32,48,64,128,256)
$images=[Collections.Generic.List[byte[]]]::new()
$image=[Drawing.Image]::FromFile((Join-Path $sourceRoot 'assets\NInferEZ-Engine.png'))
try{
    foreach($size in $sizes){
        $bitmap=[Drawing.Bitmap]::new($size,$size,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics=[Drawing.Graphics]::FromImage($bitmap)
        $stream=[IO.MemoryStream]::new()
        try{
            $graphics.Clear([Drawing.Color]::Transparent)
            $graphics.CompositingMode=[Drawing.Drawing2D.CompositingMode]::SourceCopy
            $graphics.CompositingQuality=[Drawing.Drawing2D.CompositingQuality]::HighQuality
            $graphics.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode=[Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.DrawImage($image,[Drawing.Rectangle]::new(0,0,$size,$size))
            $bitmap.Save($stream,[Drawing.Imaging.ImageFormat]::Png)
            $images.Add($stream.ToArray())
        }finally{$stream.Dispose();$graphics.Dispose();$bitmap.Dispose()}
    }
}finally{$image.Dispose()}
[ExecutableBranding]::WriteIcon((Join-Path $sourceRoot 'assets\NInferEZ-Engine.ico'),$images.ToArray(),$sizes)
Write-Host 'Windows engine icon created at 16, 24, 32, 48, 64, 128 and 256 pixels.'
