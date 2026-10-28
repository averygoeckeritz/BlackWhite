param([string]$Rom, [int]$Species, [string]$Png, [switch]$Back, [string]$PaletteJson, [switch]$Apply)
# Writes a 256x128 rig sheet PNG straight into a species' rig sheet (a/0/0/4 file 2 front / 11 back) without the
# editor: the entry is decompressed, the 4bpp linear pixels after the 0x30-byte header are replaced (colours
# mapped to palette indices through the palette json's "rgb" values, transparent = 0), and the result is
# recompressed with lz11-compress-optimal.ps1 and written back with grow-narc-entry.ps1.
Add-Type -AssemblyName System.Drawing
$tmp = Join-Path ([IO.Path]::GetTempPath()) "rigsheet-$PID"; New-Item -ItemType Directory -Force $tmp | Out-Null
$entry = $Species * 20 + $(if ($Back) { 11 } else { 2 })
& "$PSScriptRoot\dump-narc-entries.ps1" -Rom $Rom -Narc a/0/0/4 -First $entry -Count 1 -OutDir $tmp | Out-Null
$d = [IO.File]::ReadAllBytes((Get-ChildItem "$tmp\*_$entry.bin").FullName)
if ($d[0] -ne 0x11) { throw "entry $entry is not LZ11" }
$size = [int]$d[1] -bor ([int]$d[2] -shl 8) -bor ([int]$d[3] -shl 16); $raw = New-Object byte[] $size; $src = 4; $dst = 0
while ($dst -lt $size) { $flags = [int]$d[$src]; $src++
    for ($bit = 7; $bit -ge 0 -and $dst -lt $size; $bit--) {
        if ((($flags -shr $bit) -band 1) -eq 0) { $raw[$dst] = $d[$src]; $dst++; $src++ } else {
            $b1 = [int]$d[$src]; $hi = $b1 -shr 4; $b2 = [int]$d[$src+1]
            if ($hi -eq 0) { $b3 = [int]$d[$src+2]; $len = (($b1 -band 0xF) -shl 4) + ($b2 -shr 4) + 0x11; $disp = ((($b2 -band 0xF) -shl 8) -bor $b3) + 1; $src += 3 }
            elseif ($hi -eq 1) { $b3 = [int]$d[$src+2]; $b4 = [int]$d[$src+3]; $len = ((($b1 -band 0xF) -shl 12) -bor ($b2 -shl 4) -bor ($b3 -shr 4)) + 0x111; $disp = ((($b3 -band 0xF) -shl 8) -bor $b4) + 1; $src += 4 }
            else { $len = $hi + 1; $disp = ((($b1 -band 0xF) -shl 8) -bor $b2) + 1; $src += 2 }
            for ($k = 0; $k -lt $len -and $dst -lt $size; $k++) { $raw[$dst] = $raw[$dst - $disp]; $dst++ } } } }
if ($size -lt 48 + 256*128/2) { throw "entry $entry decompresses to $size bytes, too small for a 256x128 sheet" }
$map = @{}; foreach ($e in (Get-Content $PaletteJson -Raw | ConvertFrom-Json).entries) { $map[$e.rgb.ToUpper()] = [int]$e.index }
$img = [System.Drawing.Bitmap]::FromFile((Resolve-Path $Png).Path)
if ($img.Width -ne 256 -or $img.Height -ne 128) { throw "sheet must be 256x128" }
$unmatched = 0
for ($y = 0; $y -lt 128; $y++) { for ($x = 0; $x -lt 256; $x += 2) {
    $v = 0; foreach ($k in 0,1) { $c = $img.GetPixel($x + $k, $y); $i = 0
        if ($c.A -ne 0) { $key = '{0:X2}{1:X2}{2:X2}' -f $c.R, $c.G, $c.B; if ($map.ContainsKey($key)) { $i = $map[$key] } else { $unmatched++ } }
        $v = $v -bor ($i -shl (4 * $k)) }
    $raw[48 + ($y * 256 + $x) / 2] = [byte]$v } }
$img.Dispose()
if ($unmatched) { throw "$unmatched pixels have colours outside the palette json" }
[IO.File]::WriteAllBytes("$tmp\sheet.bin", $raw)
& "$PSScriptRoot\lz11-compress-optimal.ps1" -In "$tmp\sheet.bin" -OutFile "$tmp\sheet.lz11" -NoPad
"entry ${entry}: $($d.Length) -> $((Get-Item "$tmp\sheet.lz11").Length) bytes compressed"
& "$PSScriptRoot\grow-narc-entry.ps1" -Rom $Rom -Narc a/0/0/4 -Entry $entry -File "$tmp\sheet.lz11" -Apply:$Apply
Remove-Item -Recurse -Force $tmp
