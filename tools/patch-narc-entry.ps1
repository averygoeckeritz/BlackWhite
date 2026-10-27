param([string]$Rom, [string]$Narc, [int]$Entry, [string]$File, [switch]$Apply)
# Writes a whole file into an existing NARC entry in place. The file must be no larger than the entry; the rest
# of the entry is zero-filled (harmless after an LZ stream, which carries its own length).
$new = [IO.File]::ReadAllBytes($File)
$fs = [IO.File]::Open($Rom, 'Open', 'ReadWrite'); $br = New-Object IO.BinaryReader($fs); $bw = New-Object IO.BinaryWriter($fs)
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
$id = $files[$Narc]; $base = U32 ($fatOff + $id * 8)
$btnfOff = $base + 0x10 + (U32 ($base + 0x14)); $btnfSize = U32 ($btnfOff + 4); $gmif = $btnfOff + $btnfSize + 8
$s = U32 ($base + 0x1C + $Entry*8); $e = U32 ($base + 0x1C + $Entry*8 + 4); $size = $e - $s
"$Narc entry $Entry`: $size bytes; new file $($new.Length) bytes"
if ($new.Length -gt $size) { throw "file is larger than the entry" }
if ($Apply) {
    $fs.Position = $gmif + $s; $bw.Write($new); for ($k = $new.Length; $k -lt $size; $k++) { $bw.Write([byte]0) }; $bw.Flush(); "APPLIED"
} else { "dry run only (pass -Apply to write)" }
$fs.Close()
