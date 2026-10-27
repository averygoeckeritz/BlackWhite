param([string]$Rom, [int]$MoveId = 128)
# Minimal NitroFS + NARC reader: find every level-up learnset and trainer Pokemon that uses $MoveId.
$fs = [IO.File]::OpenRead($Rom); $br = New-Object IO.BinaryReader($fs)
function U32($o) { $fs.Position = $o; return $br.ReadUInt32() }
function U16($o) { $fs.Position = $o; return $br.ReadUInt16() }
$fntOff = U32 0x40; $fatOff = U32 0x48
# Walk the FNT recursively to map "a/0/1/8" -> file id
$files = @{}
function Walk($dirId, $path) {
    $e = $fntOff + ($dirId -band 0xFFF) * 8
    $subOff = U32 $e; $firstId = U16 ($e + 4)
    $p = $fntOff + $subOff; $id = $firstId
    while ($true) {
        $fs.Position = $p; $len = $br.ReadByte(); if ($len -eq 0) { break }
        $isDir = ($len -band 0x80) -ne 0; $n = $len -band 0x7F
        $name = [Text.Encoding]::ASCII.GetString($br.ReadBytes($n)); $p += 1 + $n
        if ($isDir) { $sub = U16 $p; $p += 2; Walk $sub "$path$name/" }
        else { $files["$path$name"] = $id; $id++ }
    }
}
Walk 0xF000 ""
function ReadFile($name) {
    $id = $files[$name]; if ($null -eq $id) { throw "no file $name" }
    $s = U32 ($fatOff + $id * 8); $e = U32 ($fatOff + $id * 8 + 4)
    $fs.Position = $s; return $br.ReadBytes($e - $s)
}
function NarcEntries([byte[]]$d) {
    # NARC: header 16, then BTAF ('FATB') chunk: 'BTAF' size count, then count*(start,end); then BTNF; then GMIF('FIMG') data
    $cnt = [BitConverter]::ToUInt32($d, 0x18)
    $fatb = 0x1C; $btnfOff = 0x10 + [BitConverter]::ToUInt32($d, 0x14)
    $btnfSize = [BitConverter]::ToUInt32($d, $btnfOff + 4); $gmif = $btnfOff + $btnfSize + 8
    $out = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt $cnt; $i++) {
        $s = [BitConverter]::ToUInt32($d, $fatb + $i*8); $e = [BitConverter]::ToUInt32($d, $fatb + $i*8 + 4)
        [void]$out.Add($d[($gmif+$s)..($gmif+$e-1)])
    }
    return ,$out
}
"files in ROM: $($files.Count)"
# --- level-up learnsets: a/0/1/8, each file = (u16 move, u16 level)* until FFFF FFFF
$ls = NarcEntries (ReadFile "a/0/1/8")
"learnset entries: $($ls.Count)"
$hits = @()
for ($sp = 0; $sp -lt $ls.Count; $sp++) {
    $f = $ls[$sp]; for ($o = 0; $o + 3 -lt $f.Length; $o += 4) {
        $mv = [BitConverter]::ToUInt16($f, $o); $lv = [BitConverter]::ToUInt16($f, $o+2)
        if ($mv -eq 0xFFFF) { break }
        if ($mv -eq $MoveId) { $hits += "species $sp learns move $MoveId at level $lv" }
    }
}
if ($hits.Count -eq 0) { "learnsets: no species learns move $MoveId" } else { $hits }
# --- trainer Pokemon: a/0/9/2; per trainer file: entries sized by trainer flags (a/0/9/1 byte 0: bit0 = moves, bit1 = item)
$tr = NarcEntries (ReadFile "a/0/9/1"); $tp = NarcEntries (ReadFile "a/0/9/2")
"trainers: $($tr.Count)"
$thits = @()
for ($t = 0; $t -lt $tp.Count; $t++) {
    $flags = $tr[$t][0]; $hasMoves = ($flags -band 1) -ne 0; $hasItem = ($flags -band 2) -ne 0
    if (-not $hasMoves) { continue }
    $size = 8; if ($hasItem) { $size += 2 }; $size += 8
    $f = $tp[$t]; $n = [Math]::Floor($f.Length / $size)
    for ($i = 0; $i -lt $n; $i++) {
        $b = $i * $size; $mvOff = $b + 8; if ($hasItem) { $mvOff += 2 }
        for ($m = 0; $m -lt 4; $m++) { if ([BitConverter]::ToUInt16($f, $mvOff + $m*2) -eq $MoveId) { $sp = [BitConverter]::ToUInt16($f, $b+4); $thits += "trainer $t slot $i species $sp uses move $MoveId" } }
    }
}
if ($thits.Count -eq 0) { "trainers: no trainer Pokemon uses move $MoveId" } else { $thits }
$fs.Close()
