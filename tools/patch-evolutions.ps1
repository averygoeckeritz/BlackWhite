param([string]$Rom, [switch]$Apply)
# a/0/1/9: one entry per species, 7 evolutions x (u16 method, u16 param, u16 target).
# Dry run prints Klink (599), Klang (600), Klinklang (601) and Bisharp (625).
# -Apply: Bisharp gains "level up at 61 -> 601"; Klang's evolution into 601 is removed.
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
$id = $files["a/0/1/9"]; $base = U32 ($fatOff + $id * 8)
$cnt = U32 ($base + 0x18); $btnfOff = $base + 0x10 + (U32 ($base + 0x14)); $btnfSize = U32 ($btnfOff + 4); $gmif = $btnfOff + $btnfSize + 8
function EntryStart($i) { return $gmif + (U32 ($base + 0x1C + $i*8)) }
function Show($i) {
    $st = EntryStart $i; $fs.Position = $st; $b = $br.ReadBytes(42)
    $parts = @(); for ($k = 0; $k -lt 7; $k++) { $m = [BitConverter]::ToUInt16($b, $k*6); $p = [BitConverter]::ToUInt16($b, $k*6+2); $t = [BitConverter]::ToUInt16($b, $k*6+4); if ($m -ne 0) { $parts += "method $m param $p -> $t" } }
    "species $i`: " + $(if ($parts.Count) { $parts -join '; ' } else { '(none)' })
}
"a/0/1/9: $cnt entries"
599,600,601,625 | ForEach-Object { Show $_ }
if ($Apply) {
    # Bisharp: first free slot gets (4 = level up, 61, 601)
    $st = EntryStart 625; $fs.Position = $st; $b = $br.ReadBytes(42); $slot = -1
    for ($k = 0; $k -lt 7; $k++) { if ([BitConverter]::ToUInt16($b, $k*6) -eq 0) { $slot = $k; break } }
    if ($slot -lt 0) { throw "Bisharp has no free evolution slot" }
    $fs.Position = $st + $slot*6; $bw.Write([uint16]4); $bw.Write([uint16]61); $bw.Write([uint16]601)
    # Klang: clear every evolution that targets 601
    $st = EntryStart 600; $fs.Position = $st; $b = $br.ReadBytes(42)
    for ($k = 0; $k -lt 7; $k++) { if ([BitConverter]::ToUInt16($b, $k*6+4) -eq 601) { $fs.Position = $st + $k*6; $bw.Write([uint16]0); $bw.Write([uint16]0); $bw.Write([uint16]0) } }
    $bw.Flush(); "APPLIED"; "--- after ---"; 600,625 | ForEach-Object { Show $_ }
}
$fs.Close()
