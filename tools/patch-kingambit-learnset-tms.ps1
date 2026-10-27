param([string]$Rom, [switch]$Apply)
# Writes Kingambit's level-up learnset into a/0/1/8 entry 601 (in place, FF-padded) and copies Bisharp's
# TM/tutor compatibility bytes (0x28..0x4B of a/0/1/6) onto entry 601, adding TM91 Flash Cannon.
# Without -Apply it only prints what it would do.
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
function EntryRange($narcPath, $i) {
    $id = $files[$narcPath]; $base = U32 ($fatOff + $id * 8)
    $cnt = U32 ($base + 0x18); $btnfOff = $base + 0x10 + (U32 ($base + 0x14)); $btnfSize = U32 ($btnfOff + 4); $gmif = $btnfOff + $btnfSize + 8
    $s = U32 ($base + 0x1C + $i*8); $e = U32 ($base + 0x1C + $i*8 + 4)
    return @{ start = $gmif + $s; end = $gmif + $e; size = $e - $s }
}
# ---- learnset: (move, level) pairs; Kowtow Cleave is slot 128
$learnset = @(
    @(128,1), @(210,1), @(43,1), @(368,1), @(232,1), @(10,1),   # Kowtow Cleave, Fury Cutter, Leer, Metal Burst, Metal Claw, Scratch
    @(259,15), @(184,20), @(372,25), @(555,30), @(163,35), @(400,40), # Torment, Scary Face, Assurance, Snarl, Slash, Night Slash
    @(334,45), @(514,50), @(442,57), @(128,61), @(14,64), @(12,71)    # Iron Defense, Retaliate, Iron Head, Kowtow Cleave, Swords Dance, Guillotine
)
$r = EntryRange "a/0/1/8" 601
"learnset entry 601: $($r.size) bytes at 0x$($r.start.ToString('X')); new list needs $(($learnset.Count+1)*4) bytes"
if (($learnset.Count+1)*4 -gt $r.size) { throw "new learnset does not fit in place" }
$buf = New-Object byte[] $r.size; for ($k = 0; $k -lt $buf.Length; $k++) { $buf[$k] = 0xFF }
$o = 0; foreach ($mv in $learnset) { [BitConverter]::GetBytes([uint16]$mv[0]).CopyTo($buf, $o); [BitConverter]::GetBytes([uint16]$mv[1]).CopyTo($buf, $o+2); $o += 4 }
# ---- TM/tutor bytes from Bisharp (625), plus TM91
$rb = EntryRange "a/0/1/6" 625; $rk = EntryRange "a/0/1/6" 601
$fs.Position = $rb.start + 0x28; $tm = $br.ReadBytes(0x4C - 0x28)
$tm[11] = $tm[11] -bor 0x04   # TM91 Flash Cannon: bit 90 -> byte 11 bit 2
"TM/tutor bytes to write: " + (($tm | ForEach-Object { $_.ToString('X2') }) -join ' ')
if ($Apply) {
    $fs.Position = $r.start; $bw.Write($buf)
    $fs.Position = $rk.start + 0x28; $bw.Write($tm)
    $bw.Flush(); "APPLIED"
} else { "dry run only (pass -Apply to write)" }
$fs.Close()
