param([string]$File, [int]$Seq = 0)
# Prints each frame of one RNAN sequence: part index and duration (in 1/60 s frames).
$b = [IO.File]::ReadAllBytes($File)
function U16($o) { return [BitConverter]::ToUInt16($b, $o) }
function I32($o) { return [BitConverter]::ToInt32($b, $o) }
$framesStart = (U16 0x20) + 0x18; $valuesStart = (U16 0x24) + 0x18
$h = 0x30 + 0x10 * $Seq; $frameCount = I32 $h; $type = U16 ($h + 4); $seqStart = (I32 ($h + 0xC)) + $framesStart
"seq $Seq`: $frameCount frames, type $type"
$total = 0; $line = @()
for ($j = 0; $j -lt $frameCount; $j++) { $vp = (I32 ($seqStart + 8*$j)) + $valuesStart; $dur = U16 ($seqStart + 8*$j + 4); $idx = U16 $vp; $total += $dur; $line += "$idx($dur)" }
"part(duration): " + ($line -join ' ')
"total: $total frames = $([Math]::Round($total/60, 2)) s per loop"
