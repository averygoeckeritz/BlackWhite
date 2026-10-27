param([string]$Rom, [int]$Species = 601, [string]$OutPng)
# Reads the party icon of a species from a/0/0/7 (file 8 + id*2, uncompressed 32x64 4bpp NCGR), the three shared
# icon palettes (file 0, 16 colours each at 40 + 32*i) and the species' icon palette id from arm9 (0x8C578 + id,
# +2 when id > 680; low nibble). Writes the icon as PNG and prints the palettes.
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
$id = $files["a/0/0/7"]; $base = U32 ($fatOff + $id * 8)
$cnt = U32 ($base + 0x18); $btnfOff = $base + 0x10 + (U32 ($base + 0x14)); $btnfSize = U32 ($btnfOff + 4); $gmif = $btnfOff + $btnfSize + 8
function Entry($i) { $s = U32 ($base + 0x1C + $i*8); $e = U32 ($base + 0x1C + $i*8 + 4); $fs.Position = $gmif + $s; return $br.ReadBytes($e - $s) }
"a/0/0/7: $cnt entries"
$p0 = Entry 0
$pals = @(); for ($i = 0; $i -lt 3; $i++) { $pal = @(); for ($j = 0; $j -lt 16; $j++) { $v = [BitConverter]::ToUInt16($p0, 40 + 32*$i + $j*2); $pal += [System.Drawing.Color]::FromArgb(255, [int][Math]::Floor(($v -band 0x1F)*8.25), [int][Math]::Floor((($v -shr 5) -band 0x1F)*8.25), [int][Math]::Floor((($v -shr 10) -band 0x1F)*8.25)) }; $pals += ,$pal; "icon palette $i`: " + (($pal | ForEach-Object { '{0:X2}{1:X2}{2:X2}' -f $_.R,$_.G,$_.B }) -join ' ') }
$arm9Off = U32 0x20; $pidOff = $arm9Off + 0x8C578 + $Species + $(if ($Species -gt 680) { 2 } else { 0 }); $fs.Position = $pidOff; $pb = $br.ReadByte()
"species $Species icon palette byte at ROM 0x$($pidOff.ToString('X')): 0x$($pb.ToString('X2')) (male palette $($pb -band 0xF), female $($pb -shr 4))"
$icon = Entry (8 + $Species*2)
"icon file $(8 + $Species*2): $($icon.Length) bytes, magic " + [Text.Encoding]::ASCII.GetString($icon, 0, 4)
if ($OutPng) {
    $pal = $pals[$pb -band 0xF]; $bmp = New-Object System.Drawing.Bitmap(32, 64)
    for ($tile = 0; $tile -lt 32; $tile++) { $tx = $tile % 4; $ty = [Math]::Floor($tile / 4); for ($yT = 0; $yT -lt 8; $yT++) { for ($xT = 0; $xT -lt 8; $xT++) { $v = [int]$icon[$tile*32 + $yT*4 + [Math]::Floor($xT/2) + 48]; $v = ($v -shr (($xT % 2) * 4)) -band 0xF; $bmp.SetPixel($tx*8 + $xT, $ty*8 + $yT, $pal[$v]) } } }
    $bmp.Save($OutPng, [System.Drawing.Imaging.ImageFormat]::Png); "written $OutPng"
}
$fs.Close()
