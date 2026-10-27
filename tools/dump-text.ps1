param([string]$Rom, [int]$File = 403, [int[]]$Lines, [string]$Narc = "a/0/0/2", [switch]$All)
# Decodes strings from a B2W2 text NARC (default a/0/0/2 = "misc" text; a/0/0/3 = story text).
# Gen 5 text format: per file, u16 sections, u16 lines, u32 fileSize, u32 unused, u32 sectionOffset[s];
# each section: u32 size, then per line u32 offset (from section start), u16 len, u16 unused;
# each char u16 XOR'd with a rolling key: key starts (0x2983 * (lineIndex + 3)) & 0xFFFF, then rotl3 per char.
$fs = [IO.File]::OpenRead($Rom); $br = New-Object IO.BinaryReader($fs)
function U32($o) { $fs.Position = $o; return $br.ReadUInt32() }
function U16($o) { $fs.Position = $o; return $br.ReadUInt16() }
$fntOff = U32 0x40; $fatOff = U32 0x48
$files = @{}
function Walk($dirId, $path) {
    $e = $fntOff + ($dirId -band 0xFFF) * 8; $subOff = U32 $e; $firstId = U16 ($e + 4)
    $p = $fntOff + $subOff; $id = $firstId
    while ($true) {
        $fs.Position = $p; $len = $br.ReadByte(); if ($len -eq 0) { break }
        $isDir = ($len -band 0x80) -ne 0; $n = $len -band 0x7F
        $name = [Text.Encoding]::ASCII.GetString($br.ReadBytes($n)); $p += 1 + $n
        if ($isDir) { $sub = U16 $p; $p += 2; Walk $sub "$path$name/" } else { $files["$path$name"] = $id; $id++ }
    }
}
Walk 0xF000 ""
$id = $files[$Narc]; $s = U32 ($fatOff + $id * 8); $e = U32 ($fatOff + $id * 8 + 4); $fs.Position = $s; $d = $br.ReadBytes($e - $s)
$fs.Close()
$cnt = [BitConverter]::ToUInt32($d, 0x18); $fatb = 0x1C; $btnfOff = 0x10 + [BitConverter]::ToUInt32($d, 0x14)
$btnfSize = [BitConverter]::ToUInt32($d, $btnfOff + 4); $gmif = $btnfOff + $btnfSize + 8
$ms = [BitConverter]::ToUInt32($d, $fatb + $File*8); $me = [BitConverter]::ToUInt32($d, $fatb + $File*8 + 4)
$t = $d[($gmif+$ms)..($gmif+$me-1)]
$sections = [BitConverter]::ToUInt16($t, 0); $nLines = [BitConverter]::ToUInt16($t, 2)
$secOff = [BitConverter]::ToUInt32($t, 0xC)
"text file $File of $Narc`: $nLines lines, $sections section(s)"
function DecodeLine($i) {
    $off = [BitConverter]::ToUInt32($t, $secOff + 4 + $i*8); $len = [BitConverter]::ToUInt16($t, $secOff + 4 + $i*8 + 4)
    $key = (0x2983 * ($i + 3)) -band 0xFFFF
    $sb = New-Object System.Text.StringBuilder
    for ($k = 0; $k -lt $len; $k++) {
        $c = [BitConverter]::ToUInt16($t, $secOff + $off + $k*2) -bxor $key
        $key = ((($key -shl 3) -bor ($key -shr 13)) -band 0xFFFF)
        if ($c -eq 0xFFFF) { break }
        elseif ($c -eq 0xFFFE) { [void]$sb.Append("[N]") }
        elseif ($c -eq 0xF000) { # variable/escape: next u16 = kind, then count u16 args
            $kind = [BitConverter]::ToUInt16($t, $secOff + $off + ($k+1)*2) -bxor $key; $key = ((($key -shl 3) -bor ($key -shr 13)) -band 0xFFFF)
            $n = [BitConverter]::ToUInt16($t, $secOff + $off + ($k+2)*2) -bxor $key; $key = ((($key -shl 3) -bor ($key -shr 13)) -band 0xFFFF)
            $args = @(); for ($a = 0; $a -lt $n; $a++) { $args += ([BitConverter]::ToUInt16($t, $secOff + $off + ($k+3+$a)*2) -bxor $key); $key = ((($key -shl 3) -bor ($key -shr 13)) -band 0xFFFF) }
            [void]$sb.Append("[VAR $kind($($args -join ','))]"); $k += 2 + $n
        }
        else { [void]$sb.Append([char]$c) }
    }
    return $sb.ToString()
}
if ($All) { $Lines = 0..($nLines-1) }
if (-not $Lines) { $Lines = 0..([Math]::Min(9, $nLines-1)) }
foreach ($i in $Lines) { "{0,4}: {1}" -f $i, (DecodeLine $i) }
