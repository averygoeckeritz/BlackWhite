param([string]$Rom, [int]$Species = 601, [string[]]$Narcs = @("a/1/2/6", "a/1/2/7"))
# B2W2 wild encounter files: 8-byte rate header, then slots of 4 bytes (u16 species|form<<11, u8 minLv, u8 maxLv):
# 12 grass, 12 dark grass, 12 shaking grass, 5 surf, 5 surf rare, 5 fish, 5 fish rare (= 56 slots, 232 bytes),
# repeated up to 4 times for seasons in one entry (928 bytes).
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
$groups = @("grass",12),@("dark grass",12),@("shaking grass",12),@("surf",5),@("surf rare",5),@("fish",5),@("fish rare",5)
foreach ($narc in $Narcs) {
    if (-not $files.ContainsKey($narc)) { "$narc`: not in ROM"; continue }
    $id = $files[$narc]; $base = U32 ($fatOff + $id * 8)
    if ($base -eq 0) { continue }
    $fs.Position = $base; if ([Text.Encoding]::ASCII.GetString($br.ReadBytes(4)) -ne "NARC") { "$narc`: not a NARC"; continue }
    $cnt = U32 ($base + 0x18); $btnfOff = $base + 0x10 + (U32 ($base + 0x14)); $btnfSize = U32 ($btnfOff + 4); $gmif = $btnfOff + $btnfSize + 8
    "$narc`: $cnt entries"
    for ($i = 0; $i -lt $cnt; $i++) {
        $s = U32 ($base + 0x1C + $i*8); $e = U32 ($base + 0x1C + $i*8 + 4); $len = $e - $s
        if ($len -lt 232) { continue }
        $fs.Position = $gmif + $s; $d = $br.ReadBytes($len)
        $seasons = [Math]::Floor($len / 232)
        for ($se = 0; $se -lt $seasons; $se++) {
            $o = $se * 232 + 8; $slot = 0
            foreach ($g in $groups) {
                for ($k = 0; $k -lt $g[1]; $k++) {
                    $v = [BitConverter]::ToUInt16($d, $o); $sp = $v -band 0x7FF
                    if ($sp -eq $Species) { "  entry $i season $se $($g[0]) slot $k`: species $sp form $($v -shr 11) lv $($d[$o+2])-$($d[$o+3])  (file offset 0x$($o.ToString('X')))" }
                    $o += 4; $slot++
                }
            }
        }
    }
}
$fs.Close()
