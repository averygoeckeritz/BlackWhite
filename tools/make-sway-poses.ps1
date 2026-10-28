param([string]$In, [string]$OutPrefix, [int]$Split = 58, [int]$Cut = 40, [string]$Poses = "0:0;1:1;2:2")
# Makes idle poses from ONE still sprite when no animated source exists (used for Hisuian Zoroark's back).
# Rows from $Split down stay planted. Rows above it are squashed down by up to dy px (dy at the top, 0 at
# $Split, distributed evenly with nearest-neighbour row sampling, so there is no seam), and rows above $Cut are
# leaned sideways by up to sx px (sx at the top row, 0 at $Cut), like hair swaying. Every output pixel is copied
# from the source, so the colour set is unchanged. -Poses "dy:sx;dy:sx;..." writes <OutPrefix>-0.png, -1.png, ...
Add-Type -AssemblyName System.Drawing
$src = [System.Drawing.Bitmap]::FromFile((Resolve-Path $In).Path); $w = $src.Width; $h = $src.Height
$px = New-Object 'System.Drawing.Color[,]' $w, $h
for ($y = 0; $y -lt $h; $y++) { for ($x = 0; $x -lt $w; $x++) { $px[$x, $y] = $src.GetPixel($x, $y) } }
$src.Dispose()
$i = 0
foreach ($p in ($Poses -split ';' | Where-Object { $_ })) {
    $kv = $p -split ':'; $dy = [double]$kv[0]; $sx = [double]$kv[1]
    $out = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    for ($y = 0; $y -lt $h; $y++) {
        if ($y -ge $Split) { $s = $y } else { $s = [int][Math]::Round(($y - $dy) / (1 - $dy / $Split)) }
        if ($s -lt 0 -or $s -ge $h) { continue }
        $shift = 0; if ($s -lt $Cut) { $shift = [int][Math]::Round($sx * ($Cut - $s) / $Cut) }
        for ($x = 0; $x -lt $w; $x++) {
            $sxp = $x - $shift; if ($sxp -lt 0 -or $sxp -ge $w) { continue }
            $c = $px[$sxp, $s]; if ($c.A -ne 0) { $out.SetPixel($x, $y, $c) }
        }
    }
    $file = "$OutPrefix-$i.png"; $out.Save((Join-Path (Get-Location) $file), [System.Drawing.Imaging.ImageFormat]::Png); $out.Dispose()
    "pose $i (squash $dy px, sway $sx px) -> $file"; $i++
}
