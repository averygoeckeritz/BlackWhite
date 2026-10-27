param([string]$Rom, [string]$SheetPng, [string]$OutPng, [int]$Species = 601, [switch]$Apply)
# Converts a two-frame menu icon sheet (64x32, or 128x64 at double size, frames side by side) into the game's
# 32x64 icon (frames stacked), snapping colours to whichever of the three shared icon palettes fits best, and
# with -Apply writes the icon into a/0/0/7 file 8 + id*2 and the chosen palette id into arm9 (0x8C578 + id, +2 if id > 680).
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
$p0 = EntryStart 0; $pals = @()
for ($i = 0; $i -lt 3; $i++) { $pal = @(); for ($j = 0; $j -lt 16; $j++) { $v = U16 ($p0 + 40 + 32*$i + $j*2); $pal += [System.Drawing.Color]::FromArgb(255, [int][Math]::Floor(($v -band 0x1F)*8.25), [int][Math]::Floor((($v -shr 5) -band 0x1F)*8.25), [int][Math]::Floor((($v -shr 10) -band 0x1F)*8.25)) }; $pals += ,$pal }
# load sheet, downscale by nearest neighbour if double size
$src = [System.Drawing.Bitmap]::FromFile($SheetPng)
$scale = [int]($src.Width / 64); if ($src.Width -ne 64 * $scale -or $src.Height -ne 32 * $scale) { throw "sheet must be 64x32 or a whole multiple of it (got $($src.Width)x$($src.Height))" }
$sheet = New-Object System.Drawing.Bitmap(64, 32, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
for ($y = 0; $y -lt 32; $y++) { for ($x = 0; $x -lt 64; $x++) { $sheet.SetPixel($x, $y, $src.GetPixel($x * $scale, $y * $scale)) } }
# pick the palette with the least total colour error
$bestPal = 0; $bestErr = [double]::MaxValue
for ($pi = 0; $pi -lt 3; $pi++) {
    $err = 0.0; $pal = $pals[$pi]
    for ($y = 0; $y -lt 32; $y++) { for ($x = 0; $x -lt 64; $x++) { $c = $sheet.GetPixel($x, $y); if ($c.A -lt 128) { continue }
        $bd = [double]::MaxValue; for ($j = 1; $j -lt 16; $j++) { $d = [Math]::Pow($c.R - $pal[$j].R, 2) + [Math]::Pow($c.G - $pal[$j].G, 2) + [Math]::Pow($c.B - $pal[$j].B, 2); if ($d -lt $bd) { $bd = $d } }; $err += [Math]::Sqrt($bd) } }
    "palette $pi`: total colour error $([Math]::Round($err))"
    if ($err -lt $bestErr) { $bestErr = $err; $bestPal = $pi }
}
"using palette $bestPal"
$pal = $pals[$bestPal]
$idx = New-Object 'int[,]' 32, 64
$icon = New-Object System.Drawing.Bitmap(32, 64, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
for ($frame = 0; $frame -lt 2; $frame++) { for ($y = 0; $y -lt 32; $y++) { for ($x = 0; $x -lt 32; $x++) {
    $c = $sheet.GetPixel($frame * 32 + $x, $y); $oy = $frame * 32 + $y
    if ($c.A -lt 128) { $idx[$x, $oy] = 0; continue }
    $best = 1; $bd = [double]::MaxValue
    for ($j = 1; $j -lt 16; $j++) { $d = [Math]::Pow($c.R - $pal[$j].R, 2) + [Math]::Pow($c.G - $pal[$j].G, 2) + [Math]::Pow($c.B - $pal[$j].B, 2); if ($d -lt $bd) { $bd = $d; $best = $j } }
    $idx[$x, $oy] = $best; $icon.SetPixel($x, $oy, $pal[$best])
} } }
$icon.Save($OutPng, [System.Drawing.Imaging.ImageFormat]::Png); "written $OutPng"
if ($Apply) {
    $st = EntryStart (8 + $Species*2); $fs.Position = $st; if ([Text.Encoding]::ASCII.GetString($br.ReadBytes(4)) -ne 'RGCN') { throw 'icon entry is not RGCN' }
    for ($tile = 0; $tile -lt 32; $tile++) { $tx = $tile % 4; $ty = [Math]::Floor($tile / 4)
        for ($yT = 0; $yT -lt 8; $yT++) { for ($xT = 0; $xT -lt 8; $xT += 2) {
            $px = $tx*8 + $xT; $py = $ty*8 + $yT; $px2 = $px + 1
            $lo = $idx[$px, $py]; $hi = $idx[$px2, $py]
            $fs.Position = $st + 48 + $tile*32 + $yT*4 + ($xT / 2); $bw.Write([byte](($hi -shl 4) -bor $lo))
        } } }
    $arm9Off = U32 0x20; $pidOff = $arm9Off + 0x8C578 + $Species + $(if ($Species -gt 680) { 2 } else { 0 }); $fs.Position = $pidOff; $pb = $br.ReadByte()
    $newPb = ($pb -band 0xF0) -bor $bestPal; $fs.Position = $pidOff; $bw.Write([byte]$newPb)
    $bw.Flush(); "APPLIED icon (palette byte 0x$($pb.ToString('X2')) -> 0x$($newPb.ToString('X2')))"
}
$fs.Close(); $src.Dispose(); $sheet.Dispose(); $icon.Dispose()
