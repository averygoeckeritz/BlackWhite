param([string]$File)
# Summarises a decompressed Gen 5 Pokemon RNAN (part animation) file: per sequence, motion type and value ranges.
$b = [IO.File]::ReadAllBytes($File)
function S16($o) { return [BitConverter]::ToInt16($b, $o) }
function U16($o) { return [BitConverter]::ToUInt16($b, $o) }
function I32($o) { return [BitConverter]::ToInt32($b, $o) }
$seqCount = U16 0x18; $totalFrames = U16 0x1A
$framesStart = (U16 0x20) + 0x18; $valuesStart = (U16 0x24) + 0x18
"sequences: $seqCount  total frames: $totalFrames  frames@0x$($framesStart.ToString('X')) values@0x$($valuesStart.ToString('X'))"
for ($i = 0; $i -lt $seqCount; $i++) {
    $h = 0x30 + 0x10 * $i
    $frameCount = I32 $h; $type = U16 ($h + 4); $mode = U16 ($h + 6); $seqStart = (I32 ($h + 0xC)) + $framesStart
    $idx = @(); $xs = @(); $ys = @(); $rots = @(); $sx = @(); $sy = @()
    for ($j = 0; $j -lt $frameCount; $j++) {
        $vp = (I32 ($seqStart + 8*$j)) + $valuesStart
        $idx += U16 $vp
        if ($type -eq 2) { $xs += S16 ($vp + 4); $ys += S16 ($vp + 6) }
        elseif ($type -eq 1) { $rots += [Math]::Round((U16 ($vp + 4)) * 360 / 65536); $sx += [Math]::Round((I32 ($vp + 8)) / 4096, 2); $sy += [Math]::Round((I32 ($vp + 0xC)) / 4096, 2); $xs += S16 ($vp + 0x10); $ys += S16 ($vp + 0x12) }
    }
    $desc = "seq $i`: $frameCount frames, type $type mode $mode, cell idx " + (($idx | Select-Object -Unique) -join '/')
    if ($type -eq 2) { $desc += "  x $(($xs | Measure-Object -Min).Minimum)..$(($xs | Measure-Object -Max).Maximum)  y $(($ys | Measure-Object -Min).Minimum)..$(($ys | Measure-Object -Max).Maximum)" }
    if ($type -eq 1) { $desc += "  rot $(($rots | Select-Object -Unique) -join '/')  scaleX $(($sx | Select-Object -Unique) -join '/')  scaleY $(($sy | Select-Object -Unique) -join '/')  x $(($xs | Measure-Object -Min).Minimum)..$(($xs | Measure-Object -Max).Maximum)  y $(($ys | Measure-Object -Min).Minimum)..$(($ys | Measure-Object -Max).Maximum)" }
    $desc
}
