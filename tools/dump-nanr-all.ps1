param([string]$File)
# For every sequence of a decompressed RNAN: frame count, motion type, loop length and the per-step durations.
$b = [IO.File]::ReadAllBytes($File)
function U16($o) { return [BitConverter]::ToUInt16($b, $o) }
function I32($o) { return [BitConverter]::ToInt32($b, $o) }
$seqCount = U16 0x18; $framesStart = (U16 0x20) + 0x18; $valuesStart = (U16 0x24) + 0x18
for ($i = 0; $i -lt $seqCount; $i++) {
    $h = 0x30 + 0x10 * $i; $frameCount = I32 $h; $type = U16 ($h + 4); $seqStart = (I32 ($h + 0xC)) + $framesStart
    $durs = @(); $parts = @()
    for ($j = 0; $j -lt $frameCount; $j++) { $vp = (I32 ($seqStart + 8*$j)) + $valuesStart; $durs += (U16 ($seqStart + 8*$j + 4)); $parts += (U16 $vp) }
    $total = ($durs | Measure-Object -Sum).Sum
    "seq {0,2}: {1,3} steps, type {2}, loop {3,4} frames = {4,5:N2} s, step durations {5}..{6}, parts {7}" -f $i, $frameCount, $type, $total, ($total/60), ($durs | Measure-Object -Min).Minimum, ($durs | Measure-Object -Max).Maximum, (($parts | Select-Object -Unique) -join '/')
}
