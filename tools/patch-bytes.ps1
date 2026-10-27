param([string]$Rom, [string]$Narc, [int]$Entry, [int]$Offset, [string]$Hex, [switch]$Apply)
# Generic in-place byte patch: writes the hex string (e.g. "FF" or "59 02 05 05") at $Offset inside NARC entry $Entry.
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
$s = U32 ($base + 0x1C + $Entry*8); $e = U32 ($base + 0x1C + $Entry*8 + 4)
$bytes = [byte[]]($Hex -split '\s+' | Where-Object { $_ } | ForEach-Object { [Convert]::ToByte($_, 16) })
if ($Offset + $bytes.Length -gt ($e - $s)) { throw "patch runs past the entry (entry size $($e - $s))" }
$st = $gmif + $s + $Offset; $fs.Position = $st; $old = $br.ReadBytes($bytes.Length)
"$Narc entry $Entry @0x$($Offset.ToString('X')): " + (($old | ForEach-Object { $_.ToString('X2') }) -join ' ') + "  ->  " + (($bytes | ForEach-Object { $_.ToString('X2') }) -join ' ')
if ($Apply) { $fs.Position = $st; $bw.Write($bytes); $bw.Flush(); "APPLIED" } else { "dry run only (pass -Apply to write)" }
$fs.Close()
