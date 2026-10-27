param([string]$Rom, [int]$Species = 601, [int]$Size = 96, [int[]]$HostParts = @(0,1,2,3), [switch]$Apply)
# Rewrites the battle "rig cells" (part rectangles) of a species in place, files 8 (front) and 17 (back) of its
# 20-file set in a/0/0/4. Layout (from the editor source): byte 0 = part count; part i at 12 + i*48:
#   spriteX, spriteY (int, 1/256 px), width, height, cellX, cellY (int, 1/4096 px), then the same 6 ints for the sub cell.
# Host parts become one Size x Size window at sheet (0,0) centred on the origin; all other parts become an
# 8 x 8 window in the empty bottom-right corner of the sheet, so they draw nothing.
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
function I32($o) { $fs.Position = $o; return $br.ReadInt32() }
foreach ($which in @(@{ idx = 8; label = 'front' }, @{ idx = 17; label = 'back' })) {
    $st = EntryStart ($Species * 20 + $which.idx); $fs.Position = $st; $count = $br.ReadByte()
    "$($which.label) rig cells: $count parts"
    for ($i = 0; $i -lt $count; $i++) {
        $o = $st + 12 + $i*48
        $cur = "sprite ({0},{1}) size {2}x{3} at sheet ({4},{5})" -f ((I32 $o)/0x100), ((I32 ($o+4))/0x100), ((I32 ($o+8))/0x1000), ((I32 ($o+12))/0x1000), ((I32 ($o+16))/0x1000), ((I32 ($o+20))/0x1000)
        $half = [int]($Size / 2); $sx = [int](0 - $half * 0x100); $sy = [int]($half * 0x100); $wh = [int]($Size * 0x1000)
        if ($HostParts -contains $i) { $new = @($sx, $sy, $wh, $wh, 0, 0) } else { $new = @(0, 0, 0x8000, 0x8000, 0xF8000, 0x78000) }
        if ($i -lt 6 -or $HostParts -contains $i) { "  part $i`: $cur" }
        if ($Apply) { $fs.Position = $o; foreach ($v in $new) { $bw.Write([int]$v) }; for ($k = 0; $k -lt 6; $k++) { $bw.Write([int]0) } }
    }
}
if ($Apply) { $bw.Flush(); "APPLIED" } else { "dry run only (pass -Apply to write)" }
$fs.Close()
