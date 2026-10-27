param([string]$Rom, [string]$Narc, [int]$Entry, [string]$File, [switch]$Apply)
# Replaces one NARC entry with a file of a different size, rewriting the NARC in place: later entries shift, the
# BTAF table, GMIF block size, NARC file size and the ROM's FAT end offset are fixed up. The NARC can only grow
# into the padding that follows it in the ROM (the tool measures that slack and refuses otherwise). Shrinking works
# too (the freed bytes become zero padding). Use this when patch-narc-entry.ps1 cannot fit the file exactly.
$new = [IO.File]::ReadAllBytes($File)
$fs = [IO.File]::Open($Rom, 'Open', 'ReadWrite'); $br = New-Object IO.BinaryReader($fs); $bw = New-Object IO.BinaryWriter($fs)
function U32($o) { $fs.Position = $o; return $br.ReadUInt32() }
function U16($o) { $fs.Position = $o; return $br.ReadUInt16() }
$fntOff = U32 0x40; $fatOff = U32 0x48; $fatSize = U32 0x4C
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
$id = $files[$Narc]; $base = U32 ($fatOff + $id * 8); $end = U32 ($fatOff + $id * 8 + 4)
$nextStart = [uint32]::MaxValue; for ($i = 0; $i -lt $fatSize/8; $i++) { $st = U32 ($fatOff + $i*8); if ($st -ge $end -and $st -lt $nextStart) { $nextStart = $st } }
$slack = $nextStart - $end
$fs.Position = $base; $arc = $br.ReadBytes($end - $base)
function N32($o) { return [BitConverter]::ToUInt32($arc, $o) }
$count = N32 0x18; $btafSize = N32 0x14
$btnfOff = 0x10 + $btafSize; $btnfSize = N32 ($btnfOff + 4); $gmifOff = $btnfOff + $btnfSize; $gmifSize = N32 ($gmifOff + 4); $data = $gmifOff + 8
if ($gmifOff + $gmifSize -ne $arc.Length) { throw "GMIF size $gmifSize does not reach the NARC end ($($arc.Length - $gmifOff))" }
$s = N32 (0x1C + $Entry*8); $e = N32 (0x1C + $Entry*8 + 4); $old = $e - $s; $delta = $new.Length - $old
"$Narc (file $id at 0x$($base.ToString('X')), $($arc.Length) bytes, $count entries, $slack bytes of slack after it)"
"entry $Entry`: $old bytes -> $($new.Length) bytes (delta $delta)"
if ($delta -gt $slack) { throw "not enough slack after the NARC ($slack bytes) to grow by $delta" }
if (-not $Apply) { "dry run only (pass -Apply to write)"; $fs.Close(); return }
# build the new NARC
$nb = New-Object byte[] ($arc.Length + $delta)
[Array]::Copy($arc, 0, $nb, 0, $data + $s); [Array]::Copy($new, 0, $nb, $data + $s, $new.Length)
[Array]::Copy($arc, $data + $e, $nb, $data + $s + $new.Length, $arc.Length - ($data + $e))
function P32($o, $v) { [BitConverter]::GetBytes([uint32]$v).CopyTo($nb, $o) }
P32 8 $nb.Length; P32 ($gmifOff + 4) ($gmifSize + $delta); P32 (0x1C + $Entry*8 + 4) ($e + $delta)
for ($i = $Entry + 1; $i -lt $count; $i++) { $o = 0x1C + $i*8; P32 $o ((N32 $o) + $delta); P32 ($o + 4) ((N32 ($o + 4)) + $delta) }
# write it back, zero the freed tail if it shrank, and fix the ROM FAT
$fs.Position = $base; $bw.Write($nb)
for ($k = $nb.Length; $k -lt $arc.Length; $k++) { $bw.Write([byte]0) }
$fs.Position = $fatOff + $id*8 + 4; $bw.Write([uint32]($base + $nb.Length)); $bw.Flush(); $fs.Close()
"APPLIED: NARC now $($nb.Length) bytes, ROM FAT end 0x$(($base + $nb.Length).ToString('X'))"
