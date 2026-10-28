param([string]$Rom, [int]$File, [string]$Narc = "a/0/0/2", [hashtable]$Set = @{}, [string]$OutFile, [switch]$Apply, [switch]$RoundTrip)
# Rewrites lines of a Gen 5 text file (see dump-text.ps1 for the format) and writes the rebuilt file back into
# the text NARC with grow-narc-entry.ps1 (the file may change size). -Set @{ 632 = "H-Zoroark"; ... } gives the
# new text per line index; "[N]" is a line break. Lines not listed keep their original encrypted bytes.
# -RoundTrip rebuilds the file with no changes and checks it is byte-identical (a self-test of the writer).
# -OutFile writes the rebuilt file to disk instead of / in addition to patching.
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
$fatb = 0x1C; $btnfOff = 0x10 + [BitConverter]::ToUInt32($d, 0x14); $btnfSize = [BitConverter]::ToUInt32($d, $btnfOff + 4); $gmif = $btnfOff + $btnfSize + 8
$ms = [BitConverter]::ToUInt32($d, $fatb + $File*8); $me = [BitConverter]::ToUInt32($d, $fatb + $File*8 + 4)
$t = New-Object byte[] ($me - $ms); [Array]::Copy($d, $gmif + $ms, $t, 0, $me - $ms)
$sections = [BitConverter]::ToUInt16($t, 0); $nLines = [BitConverter]::ToUInt16($t, 2)
if ($sections -ne 1) { throw "only single-section text files are supported (this one has $sections)" }
$secOff = [BitConverter]::ToUInt32($t, 0xC); $secSize = [BitConverter]::ToUInt32($t, $secOff)
"text file $File`: $nLines lines, section at 0x$($secOff.ToString('X')) size $secSize, file $($t.Length) bytes (header size field $([BitConverter]::ToUInt32($t, 4)))"
function Encode([string]$text, [int]$i) {
    $u = New-Object System.Collections.Generic.List[uint16]
    $k = 0
    while ($k -lt $text.Length) {
        if ($text.Substring($k).StartsWith("[N]")) { $u.Add(0xFFFE); $k += 3 }
        else { $u.Add([uint16][char]$text[$k]); $k++ }
    }
    $u.Add(0xFFFF)
    $key = (0x2983 * ($i + 3)) -band 0xFFFF
    $out = New-Object byte[] (2 * $u.Count)
    for ($k = 0; $k -lt $u.Count; $k++) { [BitConverter]::GetBytes([uint16]($u[$k] -bxor $key)).CopyTo($out, 2*$k); $key = ((($key -shl 3) -bor ($key -shr 13)) -band 0xFFFF) }
    return ,$out
}
# gather per-line raw data (original encrypted bytes, or newly encoded)
$lines = @()
for ($i = 0; $i -lt $nLines; $i++) {
    $off = [BitConverter]::ToUInt32($t, $secOff + 4 + $i*8); $len = [BitConverter]::ToUInt16($t, $secOff + 4 + $i*8 + 4); $extra = [BitConverter]::ToUInt16($t, $secOff + 4 + $i*8 + 6)
    if ($Set.ContainsKey($i) -and -not $RoundTrip) { $raw = Encode $Set[$i] $i; "  line $i`: $len -> $($raw.Length/2) u16s: $($Set[$i])" }
    else { $raw = New-Object byte[] (2*$len); [Array]::Copy($t, $secOff + $off, $raw, 0, 2*$len) }
    $lines += [pscustomobject]@{ raw = $raw; extra = $extra }
}
# rebuild: header (0xC) + section offset + section (4 + 8n + data, padded to 4)
$tableSize = 4 + 8*$nLines; $dataSize = ($lines | ForEach-Object { $_.raw.Length } | Measure-Object -Sum).Sum
$newSecSize = $tableSize + $dataSize; while ($newSecSize % 4 -ne 0) { $newSecSize++ }
$nb = New-Object byte[] ($secOff + $newSecSize)
[Array]::Copy($t, 0, $nb, 0, $secOff)
[BitConverter]::GetBytes([uint32]$newSecSize).CopyTo($nb, $secOff)
$pos = $tableSize
for ($i = 0; $i -lt $nLines; $i++) {
    [BitConverter]::GetBytes([uint32]$pos).CopyTo($nb, $secOff + 4 + $i*8); [BitConverter]::GetBytes([uint16]($lines[$i].raw.Length / 2)).CopyTo($nb, $secOff + 4 + $i*8 + 4); [BitConverter]::GetBytes([uint16]$lines[$i].extra).CopyTo($nb, $secOff + 4 + $i*8 + 6)
    [Array]::Copy($lines[$i].raw, 0, $nb, $secOff + $pos, $lines[$i].raw.Length); $pos += $lines[$i].raw.Length
}
# header size field at 4 = total file size in the originals; keep that relation
if ([BitConverter]::ToUInt32($t, 4) -eq $t.Length) { [BitConverter]::GetBytes([uint32]$nb.Length).CopyTo($nb, 4) } elseif ([BitConverter]::ToUInt32($t, 4) -eq $secSize) { [BitConverter]::GetBytes([uint32]$newSecSize).CopyTo($nb, 4) }
if ($RoundTrip) {
    $same = ($nb.Length -eq $t.Length); if ($same) { for ($k = 0; $k -lt $t.Length; $k++) { if ($nb[$k] -ne $t[$k]) { $same = $false; "first difference at 0x$($k.ToString('X'))"; break } } }
    "round trip identical: $same ($($t.Length) -> $($nb.Length) bytes)"; return
}
"rebuilt file: $($t.Length) -> $($nb.Length) bytes"
$tmp = if ($OutFile) { $OutFile } else { Join-Path $env:TEMP "text-$File.bin" }
[IO.File]::WriteAllBytes($tmp, $nb)
if ($Apply) { & (Join-Path $PSScriptRoot "grow-narc-entry.ps1") -Rom $Rom -Narc $Narc -Entry $File -File $tmp -Apply } else { "dry run only (pass -Apply to write via grow-narc-entry.ps1)" }
