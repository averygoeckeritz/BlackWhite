param([string]$Rom, [int]$Species = 601, [int]$FrontWidth, [int]$FrontSpriteX, [int]$BackWidth, [int]$BackSpriteX, [string]$PartPoses = "0:0,1:1,2:2,3:1", [switch]$Apply)
# Rig cells for a multi-pose sheet: pose i occupies sheet columns [i*Width, (i+1)*Width), all 96 rows.
# $PartPoses maps part index -> pose index; every other part becomes an 8x8 window in the empty corner.
$map = @{}; foreach ($kv in $PartPoses -split ',') { $p = $kv -split ':'; $map[[int]$p[0]] = [int]$p[1] }
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
$id = $files["a/0/0/4"]; $base = U32 ($fatOff + $id * 8)
$btnfOff = $base + 0x10 + (U32 ($base + 0x14)); $btnfSize = U32 ($btnfOff + 4); $gmif = $btnfOff + $btnfSize + 8
function EntryStart($i) { return $gmif + (U32 ($base + 0x1C + $i*8)) }
foreach ($which in @(@{ idx = 8; label = 'front'; w = $FrontWidth; sx = $FrontSpriteX }, @{ idx = 17; label = 'back'; w = $BackWidth; sx = $BackSpriteX })) {
    $st = EntryStart ($Species * 20 + $which.idx); $fs.Position = $st; $count = $br.ReadByte()
    "$($which.label) rig cells: $count parts, pose width $($which.w), sprite X $($which.sx)"
    for ($i = 0; $i -lt $count; $i++) {
        $o = $st + 12 + $i*48
        if ($map.ContainsKey($i)) { $pose = $map[$i]; $new = @([int]($which.sx * 0x100), [int](48 * 0x100), [int]($which.w * 0x1000), [int](96 * 0x1000), [int]($pose * $which.w * 0x1000), 0); "  part $i -> pose $pose at sheet x $($pose * $which.w)" }
        else { $new = @(0, 0, 0x8000, 0x8000, 0xF8000, 0x78000) }
        if ($Apply) { $fs.Position = $o; foreach ($v in $new) { $bw.Write([int]$v) }; for ($k = 0; $k -lt 6; $k++) { $bw.Write([int]0) } }
    }
}
if ($Apply) { $bw.Flush(); "APPLIED" } else { "dry run only (pass -Apply to write)" }
$fs.Close()
