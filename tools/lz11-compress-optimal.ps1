param([string]$In, [string]$OutFile, [switch]$NoPad, [int]$ExactSize = 0)
# LZ11 compressor with optimal parsing (dynamic programming over token costs, flag bytes approximated at 1/8).
# -ExactSize N: after parsing, trailing matches are turned into literals until the stream is exactly N bytes, so a
# fixed-size NARC entry is fully consumed (DSDecmp-based decoders reject streams with unread trailing bytes).
$d = [IO.File]::ReadAllBytes($In); $n = $d.Length
# best match at every position (compiled: in plain PowerShell this search took over 10 minutes on a 16 KB rig sheet)
if (-not ('Lz11Match' -as [type])) { Add-Type -TypeDefinition @"
public static class Lz11Match {
    public static void Find(byte[] d, int[] mLen, int[] mDisp) {
        int n = d.Length;
        for (int pos = 0; pos < n; pos++) {
            int bestLen = 0, bestDisp = 0, start = System.Math.Max(0, pos - 4096), max = System.Math.Min(n - pos, 0x10110);
            for (int s = pos - 1; s >= start; s--) {
                if (d[s] != d[pos]) continue;
                int len = 1; while (len < max && d[s + len] == d[pos + len]) len++;
                if (len > bestLen) { bestLen = len; bestDisp = pos - s; if (len >= max) break; }
            }
            mLen[pos] = bestLen; mDisp[pos] = bestDisp;
        }
    }
}
"@ }
$mLen = New-Object int[] $n; $mDisp = New-Object int[] $n
[Lz11Match]::Find($d, $mLen, $mDisp)
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
# token list: (position, length) with length 1 = literal
$tokens = New-Object System.Collections.Generic.List[int[]]
$pos = 0; while ($pos -lt $n) { $len = $choice[$pos]; $tokens.Add(@($pos, $len)); $pos += $len }
function Emit($toks) {
    $o = New-Object System.Collections.Generic.List[byte]
    $o.Add(0x11); $o.Add([byte]($n -band 0xFF)); $o.Add([byte](($n -shr 8) -band 0xFF)); $o.Add([byte](($n -shr 16) -band 0xFF))
    $k = 0
    while ($k -lt $toks.Count) {
        $flagIndex = $o.Count; $o.Add(0); $flags = 0
        for ($bit = 7; $bit -ge 0 -and $k -lt $toks.Count; $bit--) {
            $p = $toks[$k][0]; $len = $toks[$k][1]; $k++
            if ($len -ge 3) {
                $flags = $flags -bor (1 -shl $bit); $disp = $mDisp[$p] - 1
                if ($len -le 0x10) { $l = $len - 1; $o.Add([byte](($l -shl 4) -bor ($disp -shr 8))); $o.Add([byte]($disp -band 0xFF)) }
                elseif ($len -le 0x110) { $l = $len - 0x11; $o.Add([byte]($l -shr 4)); $o.Add([byte]((($l -band 0xF) -shl 4) -bor ($disp -shr 8))); $o.Add([byte]($disp -band 0xFF)) }
                else { $l = $len - 0x111; $o.Add([byte](0x10 -bor ($l -shr 12))); $o.Add([byte](($l -shr 4) -band 0xFF)); $o.Add([byte]((($l -band 0xF) -shl 4) -bor ($disp -shr 8))); $o.Add([byte]($disp -band 0xFF)) }
            } else { $o.Add($d[$p]) }
        }
        $o[$flagIndex] = [byte]$flags
    }
    return ,$o   # comma keeps the List intact (PowerShell would otherwise unroll it into separate bytes)
}
$out = Emit $tokens
if ($ExactSize -gt 0) {
    if ($out.Count -gt $ExactSize) { throw "optimal stream ($($out.Count)) already larger than ExactSize $ExactSize" }
    # walk matches from the end; shorten each one (keeping >= 3) with literals after it until the size is exact
    $done = $false
    for ($ti = $tokens.Count - 1; $ti -ge 0 -and -not $done; $ti--) {
        $len = $tokens[$ti][1]; if ($len -lt 3) { continue }
        $p = $tokens[$ti][0]
        for ($keep = $len; $keep -ge 0; $keep--) {       # keep = remaining match length (0 = all literals)
            if ($keep -gt 0 -and $keep -lt 3) { continue }
            $trial = New-Object System.Collections.Generic.List[int[]]
            for ($j = 0; $j -lt $ti; $j++) { $trial.Add($tokens[$j]) }
            if ($keep -gt 0) { $trial.Add(@($p, $keep)) }
            for ($q = $p + $keep; $q -lt $p + $len; $q++) { $trial.Add(@($q, 1)) }
            for ($j = $ti + 1; $j -lt $tokens.Count; $j++) { $trial.Add($tokens[$j]) }
            $o2 = Emit $trial
            if ($o2.Count -eq $ExactSize) { $out = $o2; $done = $true; break }
            if ($o2.Count -gt $ExactSize) { break }     # overshoot: try the previous match instead
            if ($keep -eq 0) { $tokens = $trial }       # fully literal now, carry on to the previous match
        }
    }
    if (-not $done) { throw "could not hit exact size $ExactSize" }
}
$raw = $out.Count
if (-not $NoPad) { while ($out.Count % 4 -ne 0) { $out.Add(0) } }
[IO.File]::WriteAllBytes($OutFile, [byte[]]$out)
"$OutFile`: $n -> $raw bytes unpadded ($($out.Count) written)"
