param([string]$In, [string]$OutFile)
# Decompresses a Nintendo LZ11 (0x11) file. (The output parameter is not called $Out: PowerShell variable
# names are case-insensitive, so it would collide with the $out buffer below.)
$Out = $OutFile
$d = [IO.File]::ReadAllBytes($In)
if ($d[0] -ne 0x11) { throw "not LZ11 (first byte 0x$($d[0].ToString('X2')))" }
# Note: PowerShell keeps [byte] -shl results as bytes (they overflow to 0), so every operand is cast to [int].
$size = [int]$d[1] -bor ([int]$d[2] -shl 8) -bor ([int]$d[3] -shl 16)
$out = New-Object byte[] $size; $src = 4; $dst = 0
while ($dst -lt $size) {
    $flags = [int]$d[$src]; $src++
    for ($bit = 7; $bit -ge 0 -and $dst -lt $size; $bit--) {
        if ((($flags -shr $bit) -band 1) -eq 0) { $out[$dst] = $d[$src]; $dst++; $src++ }
        else {
            $b1 = [int]$d[$src]; $hi = $b1 -shr 4; $b2 = [int]$d[$src+1]
            if ($hi -eq 0) { $b3 = [int]$d[$src+2]; $len = (($b1 -band 0xF) -shl 4) + ($b2 -shr 4) + 0x11; $disp = ((($b2 -band 0xF) -shl 8) -bor $b3) + 1; $src += 3 }
            elseif ($hi -eq 1) { $b3 = [int]$d[$src+2]; $b4 = [int]$d[$src+3]; $len = ((($b1 -band 0xF) -shl 12) -bor ($b2 -shl 4) -bor ($b3 -shr 4)) + 0x111; $disp = ((($b3 -band 0xF) -shl 8) -bor $b4) + 1; $src += 4 }
            else { $len = $hi + 1; $disp = ((($b1 -band 0xF) -shl 8) -bor $b2) + 1; $src += 2 }
            for ($k = 0; $k -lt $len -and $dst -lt $size; $k++) { $out[$dst] = $out[$dst - $disp]; $dst++ }
        }
    }
}
[IO.File]::WriteAllBytes($OutFile, $out)
"$OutFile`: $size bytes, magic " + [Text.Encoding]::ASCII.GetString($out, 0, 4)
