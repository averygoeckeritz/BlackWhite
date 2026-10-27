param([string]$In, [string]$OutFile, [int]$Seq = 0, [int[]]$Cells = @(0, 1, 0, 1, 0, 1, 2, 3), [int[]]$Durations = @(20, 8, 20, 8, 20, 8, 20, 8), [int]$Frames = 0)
# Rebuilds one sequence of a decompressed Gen 5 RNAN (part animation) file with an explicit step pattern:
# -Cells is the cell (rig part) shown at each step, -Durations the step lengths in 1/60 s frames, both cycled over
# -Frames steps (default: the pattern length). The sequence may grow or shrink: bytes are inserted or removed after
# its frame list and every offset that follows is fixed up. Cells must already appear in the sequence (their
# frame-data entries are reused). Writes the raw RNAN; compress it with lz11-compress-optimal.ps1 -ExactSize.
# Default: A B A B A B C B with parts 0,1,2,3 = poses A,B,C,B, 20/8 ... = 112 frames = 1.87 s per loop.
$b = [IO.File]::ReadAllBytes($In)
function U16($o) { return [BitConverter]::ToUInt16($b, $o) }
function I32($o) { return [BitConverter]::ToInt32($b, $o) }
function Put16($o, $v) { [BitConverter]::GetBytes([uint16]$v).CopyTo($b, $o) }
function Put32($o, $v) { [BitConverter]::GetBytes([int32]$v).CopyTo($b, $o) }
if ($b.Length -ne (I32 8)) { throw "file size field $(I32 8) != $($b.Length)" }
$seqCount = U16 0x18; $framesStart = (U16 0x20) + 0x18; $valuesStart = (U16 0x24) + 0x18
$h = 0x30 + 0x10 * $Seq; $oldCount = I32 $h; $seqOff = I32 ($h + 0xC); $seqStart = $seqOff + $framesStart
# cell -> frame-data offset, from the sequence's existing frames
$cellOff = @{}
for ($j = 0; $j -lt $oldCount; $j++) { $vo = I32 ($seqStart + 8*$j); $c = [int](U16 ($valuesStart + $vo)); if (-not $cellOff.ContainsKey($c)) { $cellOff[$c] = $vo } }
foreach ($c in $Cells) { if (-not $cellOff.ContainsKey($c)) { throw "cell $c is not used by sequence $Seq (has $($cellOff.Keys -join ','))" } }
if ($Frames -le 0) { $Frames = [Math]::Max($Cells.Count, $Durations.Count) }
$delta = ($Frames - $oldCount) * 8
# grow/shrink the frame list in place
$cut = $seqStart + 8*$oldCount
if ($delta -gt 0) { $b = $b[0..($cut-1)] + (New-Object byte[] $delta) + $b[$cut..($b.Length-1)] }
elseif ($delta -lt 0) { $b = $b[0..($cut+$delta-1)] + $b[$cut..($b.Length-1)] }
# fix headers: file size, ABNK size, total frames, frame-data offset, later sequences' frame offsets
Put32 8 ((I32 8) + $delta); Put32 0x14 ((I32 0x14) + $delta); Put16 0x1A ((U16 0x1A) + $Frames - $oldCount)
Put32 0x24 ((I32 0x24) + $delta)
for ($i = 0; $i -lt $seqCount; $i++) { $hi = 0x30 + 0x10*$i; $o = I32 ($hi + 0xC); if ($i -ne $Seq -and $o -gt $seqOff) { Put32 ($hi + 0xC) ($o + $delta) } }
Put32 $h $Frames
$total = 0; $desc = @()
for ($j = 0; $j -lt $Frames; $j++) {
    $c = $Cells[$j % $Cells.Count]; $d = $Durations[$j % $Durations.Count]; $total += $d; $desc += "$c($d)"
    Put32 ($seqStart + 8*$j) $cellOff[$c]; Put16 ($seqStart + 8*$j + 4) $d; Put16 ($seqStart + 8*$j + 6) 0xBEEF
}
[IO.File]::WriteAllBytes($OutFile, $b)
"seq $Seq`: $oldCount -> $Frames frames: $($desc -join ' ')"
"total: $total frames = $([Math]::Round($total/60, 2)) s per loop; file $($b.Length) bytes -> $OutFile"
