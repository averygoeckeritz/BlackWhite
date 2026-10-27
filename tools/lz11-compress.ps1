param([string]$In, [string]$OutFile)
# Greedy LZ11 (Nintendo 0x11) compressor: longest match in a 4096-byte window, lengths 3..0x10110.
$d = [IO.File]::ReadAllBytes($In); $n = $d.Length
$out = New-Object System.Collections.Generic.List[byte]
$out.Add(0x11); $out.Add([byte]($n -band 0xFF)); $out.Add([byte](($n -shr 8) -band 0xFF)); $out.Add([byte](($n -shr 16) -band 0xFF))
$pos = 0
while ($pos -lt $n) {
    $flagIndex = $out.Count; $out.Add(0); $flags = 0
    for ($bit = 7; $bit -ge 0 -and $pos -lt $n; $bit--) {
        $bestLen = 0; $bestDisp = 0
        $start = [Math]::Max(0, $pos - 4096)
        for ($s = $pos - 1; $s -ge $start; $s--) {
            if ($d[$s] -ne $d[$pos]) { continue }
            $len = 0; $max = [Math]::Min($n - $pos, 0x10110)
            while ($len -lt $max -and $d[$s + $len] -eq $d[$pos + $len]) { $len++ }
            if ($len -gt $bestLen) { $bestLen = $len; $bestDisp = $pos - $s; if ($len -ge $max) { break } }
        }
        if ($bestLen -ge 3) {
            $flags = $flags -bor (1 -shl $bit); $disp = $bestDisp - 1
            if ($bestLen -le 0x10) { $l = $bestLen - 1; $out.Add([byte](($l -shl 4) -bor ($disp -shr 8))); $out.Add([byte]($disp -band 0xFF)) }
            elseif ($bestLen -le 0x110) { $l = $bestLen - 0x11; $out.Add([byte]($l -shr 4)); $out.Add([byte]((($l -band 0xF) -shl 4) -bor ($disp -shr 8))); $out.Add([byte]($disp -band 0xFF)) }
            else { $l = $bestLen - 0x111; $out.Add([byte](0x10 -bor ($l -shr 12))); $out.Add([byte](($l -shr 4) -band 0xFF)); $out.Add([byte]((($l -band 0xF) -shl 4) -bor ($disp -shr 8))); $out.Add([byte]($disp -band 0xFF)) }
            $pos += $bestLen
        } else { $out.Add($d[$pos]); $pos++ }
    }
    $out[$flagIndex] = [byte]$flags
}
while ($out.Count % 4 -ne 0) { $out.Add(0) }
[IO.File]::WriteAllBytes($OutFile, $out.ToArray())
"$OutFile`: $n -> $($out.Count) bytes"
