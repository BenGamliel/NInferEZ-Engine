param([Parameter(Mandatory=$true)][string[]]$Path)
$ErrorActionPreference = 'Stop'

foreach ($item in $Path) {
    $resolved = (Resolve-Path -LiteralPath $item).Path
    $bytes = [IO.File]::ReadAllBytes($resolved)
    $signature = [byte[]]@(137,80,78,71,13,10,26,10)
    if ($bytes.Length -lt 20 -or [Convert]::ToHexString($bytes[0..7]) -ne [Convert]::ToHexString($signature)) { throw 'Expected a PNG asset.' }
    $output = [IO.MemoryStream]::new()
    try {
        $output.Write($signature,0,8)
        $position = 8
        $removed = 0
        $imageEnd = $false
        while ($position -lt $bytes.Length) {
            if ($position+12 -gt $bytes.Length) { throw 'Incomplete PNG chunk header.' }
            $length = [long]$bytes[$position]*16777216 + [long]$bytes[$position+1]*65536 + [long]$bytes[$position+2]*256 + $bytes[$position+3]
            if ($length -gt [int]::MaxValue -or $position+$length+12 -gt $bytes.Length) { throw 'Invalid PNG chunk size.' }
            $kind = [Text.Encoding]::ASCII.GetString($bytes,$position+4,4)
            # Text/provenance metadata is not part of the image pixel or color-profile data.
            if ($kind -in @('caBX','tEXt','zTXt','iTXt')) { $removed++ }
            else { $output.Write($bytes,$position,[int]$length+12) }
            $position += [int]$length+12
            if ($kind -eq 'IEND') { $imageEnd = $true; break }
        }
        if (!$imageEnd -or $position -ne $bytes.Length) { throw 'Unexpected PNG ending.' }
        if ($removed -gt 0) {
            # Replace the directory entry, not shared hardlink content in another build.
            $temporary = $resolved + '.metadata-clean-' + [Guid]::NewGuid().ToString('N')
            [IO.File]::WriteAllBytes($temporary,$output.ToArray())
            Move-Item -LiteralPath $temporary -Destination $resolved -Force
        }
        Write-Host "PNG metadata cleaned; image/color chunks preserved; removed $removed optional chunks."
    } finally { $output.Dispose() }
}
