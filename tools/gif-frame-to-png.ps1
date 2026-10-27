param([string]$Gif, [string]$Out, [int]$Frame = 0)
# Saves one frame of an animated GIF as a 32-bit PNG (transparency kept) and reports its colours.
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile($Gif)
$fd = New-Object System.Drawing.Imaging.FrameDimension($img.FrameDimensionsList[0])
$img.SelectActiveFrame($fd, $Frame) | Out-Null
$bmp = New-Object System.Drawing.Bitmap($img.Width, $img.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp); $g.Clear([System.Drawing.Color]::Transparent); $g.DrawImage($img, 0, 0, $img.Width, $img.Height); $g.Dispose()
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$cols = @{}; for ($y=0;$y -lt $bmp.Height;$y++){for($x=0;$x -lt $bmp.Width;$x++){ $c=$bmp.GetPixel($x,$y); if ($c.A -ne 0) { $k = "{0:X2}{1:X2}{2:X2}" -f $c.R,$c.G,$c.B; $cols[$k] = 1 + $(if ($cols.ContainsKey($k)) { $cols[$k] } else { 0 }) } }}
"$Out`: $($bmp.Width)x$($bmp.Height), frame $Frame, $($cols.Count) opaque colours: " + (($cols.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { $_.Key }) -join ' ')
$bmp.Dispose(); $img.Dispose()
