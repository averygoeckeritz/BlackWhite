param([string]$StaticDir, [string]$PaletteJson, [string]$OutDir, [int]$RigX = 0, [int]$RigY = 0)
# Writes PNGs whose opaque pixels use exactly the editor's expanded palette colours:
#   front.png / back.png (96x96) and front-rig.png / back-rig.png (256x128 with the sprite at RigX,RigY).
Add-Type -AssemblyName System.Drawing
$pal = Get-Content $PaletteJson -Raw | ConvertFrom-Json
$merge = @{}; foreach ($p in $pal.merge.PSObject.Properties) { $merge[$p.Name] = $p.Value }
$lookup = @{}; foreach ($e in $pal.entries) { $lookup[$e.src] = $e.rgb }
function Hex2Color($h) { return [System.Drawing.Color]::FromArgb(255, [Convert]::ToInt32($h.Substring(0,2),16), [Convert]::ToInt32($h.Substring(2,2),16), [Convert]::ToInt32($h.Substring(4,2),16)) }
New-Item -ItemType Directory -Force $OutDir | Out-Null
foreach ($name in "front","back") {
    $src = [System.Drawing.Bitmap]::FromFile("$StaticDir\$name.png")
    $sprite = New-Object System.Drawing.Bitmap(96, 96, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $rig = New-Object System.Drawing.Bitmap(256, 128, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $unmatched = 0
    for ($y = 0; $y -lt 96; $y++) { for ($x = 0; $x -lt 96; $x++) {
        $c = $src.GetPixel($x, $y)
        if ($c.A -eq 0) { continue }
        $h = "{0:X2}{1:X2}{2:X2}" -f $c.R, $c.G, $c.B
        if ($merge[$h]) { $h = $merge[$h] }
        if (-not $lookup[$h]) { $unmatched++; continue }
        $col = Hex2Color $lookup[$h]
        $sprite.SetPixel($x, $y, $col); $rig.SetPixel($RigX + $x, $RigY + $y, $col)
    } }
    $sprite.Save("$OutDir\$name.png", [System.Drawing.Imaging.ImageFormat]::Png)
    # optional second pose ($name-b.png) goes on the rig sheet at (RigX + 96, RigY)
    $bPath = "$StaticDir\$name-b.png"; $unmatchedB = 0
    if (Test-Path $bPath) {
        $srcB = [System.Drawing.Bitmap]::FromFile($bPath)
        for ($y = 0; $y -lt 96; $y++) { for ($x = 0; $x -lt 96; $x++) {
            $c = $srcB.GetPixel($x, $y); if ($c.A -eq 0) { continue }
            $h = "{0:X2}{1:X2}{2:X2}" -f $c.R, $c.G, $c.B; if ($merge[$h]) { $h = $merge[$h] }
            if (-not $lookup[$h]) { $unmatchedB++; continue }
            $rig.SetPixel($RigX + 96 + $x, $RigY + $y, (Hex2Color $lookup[$h]))
        } }
        $srcB.Dispose()
    }
    $rig.Save("$OutDir\$name-rig.png", [System.Drawing.Imaging.ImageFormat]::Png)
    "$name`: written $name.png and $name-rig.png, unmatched pixels: $unmatched (second pose: $(if (Test-Path $bPath) { "yes, unmatched $unmatchedB" } else { 'none' }))"
    $src.Dispose(); $sprite.Dispose(); $rig.Dispose()
}
