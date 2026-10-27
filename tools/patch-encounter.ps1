param([string]$Rom, [string]$Narc = "a/1/2/7", [int]$Entry = 42, [int]$Offset = 0x80, [int]$FromSpecies = 601, [int]$ToSpecies = 600, [switch]$Apply)
# Replaces one wild-encounter slot's species in place (4-byte slot: u16 species|form<<11, u8 minLv, u8 maxLv).
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
$id = $files[$Narc]; $base = U32 ($fatOff + $id * 8)
$btnfOff = $base + 0x10 + (U32 ($base + 0x14)); $btnfSize = U32 ($btnfOff + 4); $gmif = $btnfOff + $btnfSize + 8
$st = $gmif + (U32 ($base + 0x1C + $Entry*8)) + $Offset
$fs.Position = $st; $v = $br.ReadUInt16(); $min = $br.ReadByte(); $max = $br.ReadByte()
"$Narc entry $Entry offset 0x$($Offset.ToString('X')): species $($v -band 0x7FF) form $($v -shr 11) lv $min-$max"
if (($v -band 0x7FF) -ne $FromSpecies) { throw "slot does not hold species $FromSpecies" }
if ($Apply) { $fs.Position = $st; $bw.Write([uint16](($v -band 0xF800) -bor $ToSpecies)); $bw.Flush(); $fs.Position = $st; $v2 = $br.ReadUInt16(); "APPLIED: now species $($v2 -band 0x7FF) lv $min-$max" } else { "dry run only (pass -Apply to write)" }
$fs.Close()
