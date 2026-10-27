param([string]$Rom, [int]$Species = 601, [string]$OutDir, [string]$CompareDir)
# Decodes a species' front/back static sprites (96x96, unscrambled from the 64x144 tile sheet) and front/back rig
# sheets (256x128) from a/0/0/4 with the species palette (and shiny palette), writes PNGs, and optionally compares
# the normal-palette images with front.png/back.png/front-rig.png/back-rig.png in $CompareDir.
Add-Type -AssemblyName System.Drawing
$fs = [IO.File]::OpenRead($Rom); $br = New-Object IO.BinaryReader($fs)
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
$id = $files["a/0/0/4"]; $base = U32 ($fatOff + $id * 8)
$btnfOff = $base + 0x10 + (U32 ($base + 0x14)); $btnfSize = U32 ($btnfOff + 4); $gmif = $btnfOff + $btnfSize + 8
function Entry($i) { $s = U32 ($base + 0x1C + $i*8); $e = U32 ($base + 0x1C + $i*8 + 4); $fs.Position = $gmif + $s; return $br.ReadBytes($e - $s) }
function Lz11([byte[]]$d) {
    if ($d.Length -eq 0) { return $d }
    if ($d[0] -ne 0x11) { throw "not LZ11" }
    $size = [int]$d[1] -bor ([int]$d[2] -shl 8) -bor ([int]$d[3] -shl 16); $out = New-Object byte[] $size; $src = 4; $dst = 0
    while ($dst -lt $size) { $flags = [int]$d[$src]; $src++
        for ($bit = 7; $bit -ge 0 -and $dst -lt $size; $bit--) {
            if ((($flags -shr $bit) -band 1) -eq 0) { $out[$dst] = $d[$src]; $dst++; $src++ } else {
                $b1 = [int]$d[$src]; $hi = $b1 -shr 4; $b2 = [int]$d[$src+1]
                if ($hi -eq 0) { $b3 = [int]$d[$src+2]; $len = (($b1 -band 0xF) -shl 4) + ($b2 -shr 4) + 0x11; $disp = ((($b2 -band 0xF) -shl 8) -bor $b3) + 1; $src += 3 }
                elseif ($hi -eq 1) { $b3 = [int]$d[$src+2]; $b4 = [int]$d[$src+3]; $len = ((($b1 -band 0xF) -shl 12) -bor ($b2 -shl 4) -bor ($b3 -shr 4)) + 0x111; $disp = ((($b3 -band 0xF) -shl 8) -bor $b4) + 1; $src += 4 }
                else { $len = $hi + 1; $disp = ((($b1 -band 0xF) -shl 8) -bor $b2) + 1; $src += 2 }
                for ($k = 0; $k -lt $len -and $dst -lt $size; $k++) { $out[$dst] = $out[$dst - $disp]; $dst++ } } } }
    return $out
}
function Palette($d) { $p = @(); for ($i = 0; $i -lt 16; $i++) { $v = [BitConverter]::ToUInt16($d, 40 + $i*2); $p += [System.Drawing.Color]::FromArgb(255, [int][Math]::Floor(($v -band 0x1F)*8.25), [int][Math]::Floor((($v -shr 5) -band 0x1F)*8.25), [int][Math]::Floor((($v -shr 10) -band 0x1F)*8.25)) }; return $p }
$b0 = $Species * 20
$pal = Palette (Entry ($b0 + 18)); $shiny = Palette (Entry ($b0 + 19))
"palette:       " + (($pal | ForEach-Object { '{0:X2}{1:X2}{2:X2}' -f $_.R,$_.G,$_.B }) -join ' ')
"shiny palette: " + (($shiny | ForEach-Object { '{0:X2}{1:X2}{2:X2}' -f $_.R,$_.G,$_.B }) -join ' ')
New-Item -ItemType Directory -Force $OutDir | Out-Null
function Sprite96([byte[]]$b, $p) {
    $img = New-Object System.Drawing.Bitmap(64, 144, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    for ($tile = 0; $tile -lt 144; $tile++) { $tx = $tile % 8; $ty = [Math]::Floor($tile / 8); for ($yT = 0; $yT -lt 8; $yT++) { for ($xT = 0; $xT -lt 8; $xT++) { $v = [int]$b[$tile*32 + $yT*4 + [Math]::Floor($xT/2) + 48]; $v = ($v -shr (($xT % 2) * 4)) -band 0xF; $img.SetPixel($tx*8 + $xT, $ty*8 + $yT, $(if ($v -eq 0) { [System.Drawing.Color]::Transparent } else { $p[$v] })) } } }
    $f = New-Object System.Drawing.Bitmap(96, 96, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb); $g = [System.Drawing.Graphics]::FromImage($f)
    $map = @(@(0,0,64,64, 0,0), @(64,0,32,8, 0,64), @(64,8,32,8, 32,64), @(64,16,32,8, 0,72), @(64,24,32,8, 32,72), @(64,32,32,8, 0,80), @(64,40,32,8, 32,80), @(64,48,32,8, 0,88), @(64,56,32,8, 32,88), @(0,64,64,32, 0,96), @(64,64,32,8, 0,128), @(64,72,32,8, 32,128), @(64,80,32,8, 0,136), @(64,88,32,8, 32,136))
    foreach ($m in $map) { $g.DrawImage($img, (New-Object System.Drawing.Rectangle($m[0],$m[1],$m[2],$m[3])), (New-Object System.Drawing.Rectangle($m[4],$m[5],$m[2],$m[3])), [System.Drawing.GraphicsUnit]::Pixel) }
    $g.Dispose(); $img.Dispose(); return $f
}
function Rig([byte[]]$b, $p) {
    $bmp = New-Object System.Drawing.Bitmap(256, 128, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    for ($i = 0; $i -lt 256*128; $i++) { $c = [int]$b[[Math]::Floor($i/2) + 48]; $c = $(if ($i % 2 -eq 0) { $c -band 0xF } else { ($c -shr 4) -band 0xF }); $bmp.SetPixel($i % 256, [Math]::Floor($i / 256), $(if ($c -eq 0) { [System.Drawing.Color]::Transparent } else { $p[$c] })) }
    return $bmp
}
function CompareImg($a, $path) {   # not "Compare": that is PowerShell's alias for Compare-Object
    if (-not (Test-Path $path)) { return "no reference" }
    $r = [System.Drawing.Bitmap]::FromFile($path); $diff = 0
    for ($y = 0; $y -lt $a.Height; $y++) { for ($x = 0; $x -lt $a.Width; $x++) { $p1 = $a.GetPixel($x,$y); $p2 = $r.GetPixel($x,$y); if (($p1.A -eq 0) -ne ($p2.A -eq 0)) { $diff++ } elseif ($p1.A -ne 0 -and ($p1.R -ne $p2.R -or $p1.G -ne $p2.G -or $p1.B -ne $p2.B)) { $diff++ } } }
    $r.Dispose(); return "$diff pixels differ from $(Split-Path $path -Leaf)"
}
$front = Sprite96 (Lz11 (Entry $b0)) $pal; $front.Save("$OutDir\front.png"); "front sprite: " + (CompareImg $front "$CompareDir\front.png")
$fsh = Sprite96 (Lz11 (Entry $b0)) $shiny; $fsh.Save("$OutDir\front-shiny.png")
$back = Sprite96 (Lz11 (Entry ($b0 + 9))) $pal; $back.Save("$OutDir\back.png"); "back sprite: " + (CompareImg $back "$CompareDir\back.png")
$bsh = Sprite96 (Lz11 (Entry ($b0 + 9))) $shiny; $bsh.Save("$OutDir\back-shiny.png")
$frig = Rig (Lz11 (Entry ($b0 + 2))) $pal; $frig.Save("$OutDir\front-rig.png"); "front rig: " + (CompareImg $frig "$CompareDir\front-rig.png")
$brig = Rig (Lz11 (Entry ($b0 + 11))) $pal; $brig.Save("$OutDir\back-rig.png"); "back rig: " + (CompareImg $brig "$CompareDir\back-rig.png")
"sizes (compressed): front $((Entry $b0).Length) rig $((Entry ($b0+2)).Length) back $((Entry ($b0+9)).Length) backrig $((Entry ($b0+11)).Length)"
$fs.Close()

