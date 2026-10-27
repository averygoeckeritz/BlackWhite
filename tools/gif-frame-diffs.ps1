param([string]$Gif)
# Prints, for every frame of a GIF, how many pixels differ from frame 0 (position or colour).
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile($Gif)
$fd = New-Object System.Drawing.Imaging.FrameDimension($img.FrameDimensionsList[0])
$n = $img.GetFrameCount($fd)
function Frame($i) { $img.SelectActiveFrame($fd, $i) | Out-Null; $b = New-Object System.Drawing.Bitmap($img.Width, $img.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb); $g = [System.Drawing.Graphics]::FromImage($b); $g.Clear([System.Drawing.Color]::Transparent); $g.DrawImage($img, 0, 0, $img.Width, $img.Height); $g.Dispose(); return $b }
$f0 = Frame 0
$px0 = New-Object 'int[,]' $img.Width, $img.Height
for ($y = 0; $y -lt $img.Height; $y++) { for ($x = 0; $x -lt $img.Width; $x++) { $c = $f0.GetPixel($x, $y); $px0[$x, $y] = $(if ($c.A -eq 0) { -1 } else { $c.ToArgb() }) } }
for ($i = 1; $i -lt $n; $i++) {
    $f = Frame $i; $diff = 0
    for ($y = 0; $y -lt $img.Height; $y++) { for ($x = 0; $x -lt $img.Width; $x++) { $c = $f.GetPixel($x, $y); $v = $(if ($c.A -eq 0) { -1 } else { $c.ToArgb() }); if ($v -ne $px0[$x, $y]) { $diff++ } } }
    "frame {0,2}: {1,5} pixels differ from frame 0" -f $i, $diff
    $f.Dispose()
}
$f0.Dispose(); $img.Dispose()
