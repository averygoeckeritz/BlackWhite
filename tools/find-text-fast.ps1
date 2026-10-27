param([string]$Rom, [string]$Pattern, [string]$Narc = "a/0/0/2")
# Decodes every text file in a text NARC once and prints file:line for lines matching the regex.
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
$id = $files[$Narc]; $s = U32 ($fatOff + $id * 8); $e = U32 ($fatOff + $id * 8 + 4); $fs.Position = $s; $d = $br.ReadBytes($e - $s); $fs.Close()
$cnt = [BitConverter]::ToUInt32($d, 0x18); $fatb = 0x1C; $btnfOff = 0x10 + [BitConverter]::ToUInt32($d, 0x14)
$btnfSize = [BitConverter]::ToUInt32($d, $btnfOff + 4); $gmif = $btnfOff + $btnfSize + 8
$rx = [regex]$Pattern
for ($f = 0; $f -lt $cnt; $f++) {
    $ms = [BitConverter]::ToUInt32($d, $fatb + $f*8); $me = [BitConverter]::ToUInt32($d, $fatb + $f*8 + 4)
    if ($me - $ms -lt 16) { continue }
    $base = $gmif + $ms
    $nLines = [BitConverter]::ToUInt16($d, $base + 2); $secOff = [BitConverter]::ToUInt32($d, $base + 0xC)
    for ($i = 0; $i -lt $nLines; $i++) {
        $off = [BitConverter]::ToUInt32($d, $base + $secOff + 4 + $i*8); $len = [BitConverter]::ToUInt16($d, $base + $secOff + 4 + $i*8 + 4)
        if ($len -gt 2000) { continue }
        $key = (0x2983 * ($i + 3)) -band 0xFFFF; $sb = New-Object System.Text.StringBuilder
        for ($k = 0; $k -lt $len; $k++) {
            $c = [BitConverter]::ToUInt16($d, $base + $secOff + $off + $k*2) -bxor $key
            $key = ((($key -shl 3) -bor ($key -shr 13)) -band 0xFFFF)
            if ($c -eq 0xFFFF) { break } elseif ($c -eq 0xFFFE) { [void]$sb.Append("[N]") } elseif ($c -ge 0x20 -and $c -lt 0xF000) { [void]$sb.Append([char]$c) } else { [void]$sb.Append("?") }
        }
        $str = $sb.ToString()
        if ($rx.IsMatch($str)) { "file {0,3} line {1,4}: {2}" -f $f, $i, $str }
    }
}
