param([string]$Rom, [string]$FrontPng, [string]$OutPng, [int]$Species = 601, [int]$PaletteId = 0, [switch]$Apply)
# Builds a 32x64 party icon (two 32x32 frames, the second one pixel lower) from a 96x96 front sprite by scaling
# it to 32x32 and snapping every opaque pixel to the nearest colour of icon palette $PaletteId (index 0 stays
# transparent). With -Apply it writes the icon in place into a/0/0/7 file 8 + id*2 (uncompressed 4bpp NCGR).
Add-Type -AssemblyName System.Drawing
$fs = [IO.File]::Open($Rom, 'Open', 'ReadWrite'); $br = New-Object IO.BinaryReader($fs); $bw = New-Object IO.BinaryWriter($fs)
function U32($o) { $fs.Position = $o; return $br.ReadUInt32() }
function U16($o) { $fs.Position = $o; return $br.ReadUInt16() }
$fntOff = U32 0x40; $fatOff = U32 0x48
$files = @{}
function Walk($dirId, $path) {
    $e = $fntOff + ($dirId -band 0xFFF) * 8; $subOff = U32 $e; $firstId = U16 ($e + 4)
    $p = $fntOff + $subOff; $id = $firstId
    while ($true) {
        $fs.Position = $p; $len = $br.ReadByte(); if ($len -eq 0) { break }
        $isDir = ($len -band 0x80) -ne 0; $n = $len -band 0x7F
        $name = [Text.Encoding]::ASCII.GetString($br.ReadBytes($n)); $p += 1 + $n
        if ($isDir) { $sub = U16 $p; $p += 2; Walk $sub "$path$name/" } else { $files["$path$name"] = $id; $id++ }
    }
}
Walk 0xF000 ""
$id = $files["a/0/0/7"]; $base = U32 ($fatOff + $id * 8)
$btnfOff = $base + 0x10 + (U32 ($base + 0x14)); $btnfSize = U32 ($btnfOff + 4); $gmif = $btnfOff + $btnfSize + 8
function EntryStart($i) { return $gmif + (U32 ($base + 0x1C + $i*8)) }
$p0 = EntryStart 0; $pal = @()
for ($j = 0; $j -lt 16; $j++) { $v = U16 ($p0 + 40 + 32*$PaletteId + $j*2); $pal += [System.Drawing.Color]::FromArgb(255, [int][Math]::Floor(($v -band 0x1F)*8.25), [int][Math]::Floor((($v -shr 5) -band 0x1F)*8.25), [int][Math]::Floor((($v -shr 10) -band 0x1F)*8.25)) }
# scale 96 -> 32 with smoothing, then snap to the palette
$src = [System.Drawing.Bitmap]::FromFile($FrontPng)
$small = New-Object System.Drawing.Bitmap(32, 32, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($small); $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic; $g.Clear([System.Drawing.Color]::Transparent); $g.DrawImage($src, 0, 0, 32, 32); $g.Dispose()
$idx = New-Object 'int[,]' 32, 32
$icon = New-Object System.Drawing.Bitmap(32, 64, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
for ($y = 0; $y -lt 32; $y++) { for ($x = 0; $x -lt 32; $x++) {
    $c = $small.GetPixel($x, $y)
    if ($c.A -lt 128) { $idx[$x,$y] = 0; continue }
    $best = 1; $bd = [double]::MaxValue
    for ($j = 1; $j -lt 16; $j++) { $d = [Math]::Pow($c.R - $pal[$j].R, 2) + [Math]::Pow($c.G - $pal[$j].G, 2) + [Math]::Pow($c.B - $pal[$j].B, 2); if ($d -lt $bd) { $bd = $d; $best = $j } }
    $idx[$x,$y] = $best; $icon.SetPixel($x, $y, $pal[$best]); if ($y + 1 -lt 32) { $icon.SetPixel($x, 32 + $y + 1, $pal[$best]) }
} }
$icon.Save($OutPng, [System.Drawing.Imaging.ImageFormat]::Png); "written $OutPng (palette $PaletteId)"
if ($Apply) {
    $st = EntryStart (8 + $Species*2); $fs.Position = $st; if ([Text.Encoding]::ASCII.GetString($br.ReadBytes(4)) -ne 'RGCN') { throw 'icon entry is not RGCN' }
    for ($tile = 0; $tile -lt 32; $tile++) { $tx = $tile % 4; $ty = [Math]::Floor($tile / 4)
        for ($yT = 0; $yT -lt 8; $yT++) { for ($xT = 0; $xT -lt 8; $xT += 2) {
            $px = $tx*8 + $xT; $py = $ty*8 + $yT
            $px2 = $px + 1; $py2 = $py - 33
            $lo = $(if ($py -lt 32) { $idx[$px, $py] } elseif ($py -ge 33) { $idx[$px, $py2] } else { 0 })
            $hi = $(if ($py -lt 32) { $idx[$px2, $py] } elseif ($py -ge 33) { $idx[$px2, $py2] } else { 0 })
            $fs.Position = $st + 48 + $tile*32 + $yT*4 + ($xT / 2); $bw.Write([byte](($hi -shl 4) -bor $lo))
        } } }
    $bw.Flush(); "APPLIED icon into a/0/0/7 file $(8 + $Species*2)"
}
$fs.Close(); $src.Dispose(); $small.Dispose(); $icon.Dispose()
