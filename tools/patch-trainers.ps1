param([string]$Rom, [switch]$Apply)
# Rewrites the movesets (and ability slot) of the three scripted Klinklang trainers, now Kingambit.
# Trainer Pokemon entry (a/0/9/2): u8 ivs, u8 abilityslot<<4|gender, u16 level, u16 species, [u16 item], [4 x u16 moves]
$edits = @(
    @{ t = 344; slot = 5; moves = @(128, 442, 389, 14);  ability = 0x10 },  # Colress, Plasma Frigate: Kowtow Cleave, Iron Head, Sucker Punch, Swords Dance
    @{ t = 658; slot = 0; moves = @(128, 442, 389, 280); ability = 0x10 },  # Ranger Eddie: Kowtow Cleave, Iron Head, Sucker Punch, Brick Break
    @{ t = 813; slot = 5; moves = @(128, 442, 389, 14);  ability = 0x10 }   # Colress, postgame: same as Frigate set
)
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
function NarcInfo($path) { $id = $files[$path]; $base = U32 ($fatOff + $id * 8); $btnfOff = $base + 0x10 + (U32 ($base + 0x14)); $btnfSize = U32 ($btnfOff + 4); return @{ base = $base; gmif = $btnfOff + $btnfSize + 8 } }
function EntryStart($n, $i) { return $n.gmif + (U32 ($n.base + 0x1C + $i*8)) }
$ntr = NarcInfo "a/0/9/1"; $npk = NarcInfo "a/0/9/2"
foreach ($e in $edits) {
    $flags = $br.ReadByte(); $fs.Position = (EntryStart $ntr $e.t); $flags = $br.ReadByte()
    $hasMoves = ($flags -band 1) -ne 0; $hasItem = ($flags -band 2) -ne 0
    if (-not $hasMoves) { throw "trainer $($e.t) has no custom moves flag" }
    $size = 8 + $(if ($hasItem) { 2 } else { 0 }) + 8
    $st = (EntryStart $npk $e.t) + $e.slot * $size
    $fs.Position = $st; $b = $br.ReadBytes($size)
    $sp = [BitConverter]::ToUInt16($b, 4); $lv = [BitConverter]::ToUInt16($b, 2); $mo = 8 + $(if ($hasItem) { 2 } else { 0 })
    $old = @(); for ($m = 0; $m -lt 4; $m++) { $old += [BitConverter]::ToUInt16($b, $mo + $m*2) }
    "trainer $($e.t) slot $($e.slot): species $sp lv $lv ability/gender byte 0x$($b[1].ToString('X2')) moves $($old -join ',')  ->  moves $($e.moves -join ',') ability byte 0x$($e.ability.ToString('X2'))"
    if ($sp -ne 601) { throw "slot does not hold species 601" }
    if ($Apply) {
        $fs.Position = $st + 1; $bw.Write([byte]($e.ability -bor ($b[1] -band 0x0F)))
        $fs.Position = $st + $mo; foreach ($m in $e.moves) { $bw.Write([uint16]$m) }
        $bw.Flush()
    }
}
if ($Apply) { "APPLIED" } else { "dry run only (pass -Apply to write)" }
$fs.Close()
