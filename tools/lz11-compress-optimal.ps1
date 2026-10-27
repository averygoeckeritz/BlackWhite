param([string]$In, [string]$OutFile, [switch]$NoPad)
# LZ11 compressor with optimal parsing (dynamic programming over token costs, flag bytes approximated at 1/8).
$d = [IO.File]::ReadAllBytes($In); $n = $d.Length
# best match at every position
$mLen = New-Object int[] $n; $mDisp = New-Object int[] $n
for ($pos = 0; $pos -lt $n; $pos++) {
    $bestLen = 0; $bestDisp = 0; $start = [Math]::Max(0, $pos - 4096); $max = [Math]::Min($n - $pos, 0x10110)
    for ($s = $pos - 1; $s -ge $start; $s--) {
        if ($d[$s] -ne $d[$pos]) { continue }
        $len = 1; while ($len -lt $max -and $d[$s + $len] -eq $d[$pos + $len]) { $len++ }
        if ($len -gt $bestLen) { $bestLen = $len; $bestDisp = $pos - $s; if ($len -ge $max) { break } }
    }
    $mLen[$pos] = $bestLen; $mDisp[$pos] = $bestDisp
}
function TokBytes($len) { if ($len -le 0x10) { 2 } elseif ($len -le 0x110) { 3 } else { 4 } }
# DP from the end: cost[i] = cheapest encoding of d[i..]; choice[i] = match length used (1 = literal)
$cost = New-Object double[] ($n + 1); $choice = New-Object int[] ($n + 1)
for ($i = $n - 1; $i -ge 0; $i--) {
    $best = 1.125 + $cost[$i + 1]; $ch = 1
    if ($mLen[$i] -ge 3) {
        # try every usable length up to the best match (shorter lengths can be cheaper to encode)
        $top = $mLen[$i]
        foreach ($len in @(3..[Math]::Min($top, 0x10)) + @($(if ($top -gt 0x10) { [Math]::Min($top, 0x110) })) + @($(if ($top -gt 0x110) { $top }))) {
            if (-not $len -or $len -lt 3) { continue }
            $c = (TokBytes $len) + 0.125 + $cost[$i + $len]
            if ($c -lt $best) { $best = $c; $ch = $len }
        }
    }
    $cost[$i] = $best; $choice[$i] = $ch
}
$out = New-Object System.Collections.Generic.List[byte]
$out.Add(0x11); $out.Add([byte]($n -band 0xFF)); $out.Add([byte](($n -shr 8) -band 0xFF)); $out.Add([byte](($n -shr 16) -band 0xFF))
$pos = 0
while ($pos -lt $n) {
    $flagIndex = $out.Count; $out.Add(0); $flags = 0
    for ($bit = 7; $bit -ge 0 -and $pos -lt $n; $bit--) {
        $len = $choice[$pos]
        if ($len -ge 3) {
            $flags = $flags -bor (1 -shl $bit); $disp = $mDisp[$pos] - 1
            if ($len -le 0x10) { $l = $len - 1; $out.Add([byte](($l -shl 4) -bor ($disp -shr 8))); $out.Add([byte]($disp -band 0xFF)) }
            elseif ($len -le 0x110) { $l = $len - 0x11; $out.Add([byte]($l -shr 4)); $out.Add([byte]((($l -band 0xF) -shl 4) -bor ($disp -shr 8))); $out.Add([byte]($disp -band 0xFF)) }
            else { $l = $len - 0x111; $out.Add([byte](0x10 -bor ($l -shr 12))); $out.Add([byte](($l -shr 4) -band 0xFF)); $out.Add([byte]((($l -band 0xF) -shl 4) -bor ($disp -shr 8))); $out.Add([byte]($disp -band 0xFF)) }
            $pos += $len
        } else { $out.Add($d[$pos]); $pos++ }
    }
    $out[$flagIndex] = [byte]$flags
}
$raw = $out.Count
if (-not $NoPad) { while ($out.Count % 4 -ne 0) { $out.Add(0) } }
[IO.File]::WriteAllBytes($OutFile, $out.ToArray())
"$OutFile`: $n -> $raw bytes unpadded ($($out.Count) written)"
