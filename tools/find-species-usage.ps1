param([string]$Rom, [int]$Species = 601)
# Lists trainer Pokemon of a species (a/0/9/1 + a/0/9/2, with trainer names from text file 190) and
# scans every NARC for entries containing the species id as a u16, to locate wild-encounter tables.
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
function ReadFileById($id) { $s = U32 ($fatOff + $id * 8); $e = U32 ($fatOff + $id * 8 + 4); $fs.Position = $s; return $br.ReadBytes($e - $s) }
function NarcEntries([byte[]]$d) {
    $cnt = [BitConverter]::ToUInt32($d, 0x18); $fatb = 0x1C; $btnfOff = 0x10 + [BitConverter]::ToUInt32($d, 0x14)
    $btnfSize = [BitConverter]::ToUInt32($d, $btnfOff + 4); $gmif = $btnfOff + $btnfSize + 8
    $out = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt $cnt; $i++) { $s = [BitConverter]::ToUInt32($d, $fatb + $i*8); $e = [BitConverter]::ToUInt32($d, $fatb + $i*8 + 4); if ($e -gt $s) { [void]$out.Add($d[($gmif+$s)..($gmif+$e-1)]) } else { [void]$out.Add(@()) } }
    return ,$out
}
# trainer names from text file 190 (B2W2 trainer names)
$names = & (Join-Path $PSScriptRoot "dump-text.ps1") -Rom $Rom -File 190 -All | Select-Object -Skip 1
$tn = @{}; foreach ($l in $names) { if ($l -match '^\s*(\d+): (.*)$') { $tn[[int]$matches[1]] = $matches[2] } }
$tr = NarcEntries (ReadFileById $files["a/0/9/1"]); $tp = NarcEntries (ReadFileById $files["a/0/9/2"])
"--- trainer Pokemon of species $Species ---"
for ($t = 0; $t -lt $tp.Count; $t++) {
    $flags = $tr[$t][0]; $hasMoves = ($flags -band 1) -ne 0; $hasItem = ($flags -band 2) -ne 0
    $size = 8; if ($hasItem) { $size += 2 }; if ($hasMoves) { $size += 8 }
    $f = $tp[$t]; if ($f.Length -lt $size) { continue }; $n = [Math]::Floor($f.Length / $size)
    for ($i = 0; $i -lt $n; $i++) {
        $b = $i * $size; $sp = [BitConverter]::ToUInt16($f, $b+4) -band 0x3FF
        if ($sp -eq $Species) {
            $lv = [BitConverter]::ToUInt16($f, $b+2); $item = if ($hasItem) { [BitConverter]::ToUInt16($f, $b+8) } else { 0 }
            $mv = @(); if ($hasMoves) { $mo = $b + 8 + $(if ($hasItem) { 2 } else { 0 }); for ($m = 0; $m -lt 4; $m++) { $mv += [BitConverter]::ToUInt16($f, $mo + $m*2) } }
            "trainer $t ($($tn[$t])) slot $i`: lv $lv item $item moves $($mv -join ',')  [entry size $size, abilityByte=$($f[$b+1]) ivByte=$($f[$b])]"
        }
    }
}
"--- NARCs with entries containing u16 $Species (candidates for encounter tables) ---"
foreach ($kv in ($files.GetEnumerator() | Sort-Object Name)) {
    if ($kv.Name -match '^a/0/9/|^a/0/1/[689]$|^a/0/0/[23]$') { continue }
    $d = ReadFileById $kv.Value
    if ($d.Length -lt 16 -or [Text.Encoding]::ASCII.GetString($d, 0, 4) -ne "NARC") { continue }
    $ent = NarcEntries $d; $hits = @()
    for ($i = 0; $i -lt $ent.Count; $i++) { $f = $ent[$i]; for ($o = 0; $o + 1 -lt $f.Length; $o += 2) { if (([BitConverter]::ToUInt16($f, $o) -band 0x7FF) -eq $Species) { $hits += "entry $i @0x$($o.ToString('X'))" } } }
    if ($hits.Count -gt 0 -and $hits.Count -le 40) { "$($kv.Name) ($($ent.Count) entries): $($hits -join '; ')" }
}
$fs.Close()
