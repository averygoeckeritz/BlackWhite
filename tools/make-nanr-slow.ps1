param([string]$In, [string]$OutFile, [int]$Seq = 0, [int]$Duration = 0, [int[]]$Durations = @(52, 8, 32, 8))
# -Duration N sets every step to N. Otherwise -Durations is a pattern applied cyclically over the steps (default
# A 52, B 8, C 32, B 8 = 100 frames = 1.67 s, next to Bisharp's 1.63 s idle cadence; see docs/setup.md).
# History: 4 (original gears, flickers), 16 uniform (1.07 s, too fast), 48 uniform (3.2 s, too slow),
# 40/12/28/12 (back file could not fill its entry size exactly), 40/8/24/8 (1.33 s), 52/10/32/10 (same size
# problem as 40/12/28/12), 52/8/32/8 (current).
# Rewrites every frame duration of one RNAN sequence (decompressed input) and writes the result as a valid
# LZ11 stream using literal-only encoding (no back references; always decodes correctly, just not small).
$b = [IO.File]::ReadAllBytes($In)
function U16($o) { return [BitConverter]::ToUInt16($b, $o) }
function I32($o) { return [BitConverter]::ToInt32($b, $o) }
$framesStart = (U16 0x20) + 0x18
$h = 0x30 + 0x10 * $Seq; $frameCount = I32 $h; $seqStart = (I32 ($h + 0xC)) + $framesStart
$total = 0
for ($j = 0; $j -lt $frameCount; $j++) { $d = $(if ($Duration -gt 0) { $Duration } else { $Durations[$j % $Durations.Count] }); $total += $d; [BitConverter]::GetBytes([uint16]$d).CopyTo($b, $seqStart + 8*$j + 4) }
"seq $Seq`: $frameCount frames, durations $(if ($Duration -gt 0) { "$Duration each" } else { "pattern $($Durations -join '/')" }), $total frames = $([Math]::Round($total/60,2)) s per loop"
# LZ11 literal-only: header 0x11 + 24-bit size, then groups of 8 literals preceded by a 0x00 flag byte
$out = New-Object System.Collections.Generic.List[byte]
$out.Add(0x11); $out.Add([byte]($b.Length -band 0xFF)); $out.Add([byte](($b.Length -shr 8) -band 0xFF)); $out.Add([byte](($b.Length -shr 16) -band 0xFF))
for ($i = 0; $i -lt $b.Length; $i += 8) { $out.Add(0); for ($k = 0; $k -lt 8 -and ($i + $k) -lt $b.Length; $k++) { $out.Add($b[$i + $k]) } }
while ($out.Count % 4 -ne 0) { $out.Add(0) }
[IO.File]::WriteAllBytes($OutFile, $out.ToArray())
"$OutFile`: $($out.Count) bytes (LZ11 literal-only)"
