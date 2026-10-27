param([string[]]$Poses, [string]$PaletteJson, [string]$OutPng, [int]$CropX, [int]$Width)
# Builds a 256x128 rig sheet from several 96x96 pose PNGs: each pose is cropped to columns [CropX, CropX+Width)
# (full 96 rows) and placed side by side at x = i*Width. Colours are snapped through the palette json exactly
# like make-sprite-pngs.ps1. Prints the sprite X offset the rig cells need (-48 + CropX).
Add-Type -AssemblyName System.Drawing
$pal = Get-Content $PaletteJson -Raw | ConvertFrom-Json
$merge = @{}; foreach ($p in $pal.merge.PSObject.Properties) { $merge[$p.Name] = $p.Value }
$lookup = @{}; foreach ($e in $pal.entries) { $lookup[$e.src] = $e.rgb }
function Hex2Color($h) { return [System.Drawing.Color]::FromArgb(255, [Convert]::ToInt32($h.Substring(0,2),16), [Convert]::ToInt32($h.Substring(2,2),16), [Convert]::ToInt32($h.Substring(4,2),16)) }
if ($Poses.Count * $Width -gt 256) { throw "poses do not fit: $($Poses.Count) x $Width > 256" }
$rig = New-Object System.Drawing.Bitmap(256, 128, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$unmatched = 0; $clipped = 0
for ($i = 0; $i -lt $Poses.Count; $i++) {
    $src = [System.Drawing.Bitmap]::FromFile($Poses[$i])
    for ($y = 0; $y -lt 96; $y++) { for ($x = 0; $x -lt 96; $x++) {
        $c = $src.GetPixel($x, $y); if ($c.A -eq 0) { continue }
        if ($x -lt $CropX -or $x -ge $CropX + $Width) { $clipped++; continue }
        $h = "{0:X2}{1:X2}{2:X2}" -f $c.R, $c.G, $c.B; if ($merge[$h]) { $h = $merge[$h] }
        if (-not $lookup[$h]) { $unmatched++; continue }
        $rig.SetPixel($i * $Width + ($x - $CropX), $y, (Hex2Color $lookup[$h]))
    } }
    $src.Dispose()
}
$rig.Save($OutPng, [System.Drawing.Imaging.ImageFormat]::Png); $rig.Dispose()
"$OutPng`: $($Poses.Count) poses x $Width px, sprite X offset $(-48 + $CropX), unmatched $unmatched, clipped (outside crop) $clipped"
