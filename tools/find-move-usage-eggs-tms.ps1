param([string]$Rom, [int]$MoveId = 128)
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
# --- egg moves: find the NARC whose every non-empty entry is (u16 n)(n x u16 move<700) with ~650+ entries
"scanning $($files.Count) files for the egg-move NARC..."
foreach ($kv in ($files.GetEnumerator() | Sort-Object Name)) {
    $d = ReadFileById $kv.Value
    if ($d.Length -lt 16 -or [Text.Encoding]::ASCII.GetString($d, 0, 4) -ne "NARC") { continue }
    $ent = NarcEntries $d
    if ($ent.Count -lt 600 -or $ent.Count -gt 800) { continue }
    $ok = $true; $nonEmpty = 0
    foreach ($f in $ent) {
        if ($f.Length -eq 0) { continue }
        if ($f.Length -lt 2 -or ($f.Length % 2) -ne 0) { $ok = $false; break }
        $n = [BitConverter]::ToUInt16($f, 0)
        if ($f.Length -ne 2 + 2*$n) { $ok = $false; break }
        for ($i = 0; $i -lt $n; $i++) { $m = [BitConverter]::ToUInt16($f, 2 + 2*$i); if ($m -eq 0 -or $m -gt 700) { $ok = $false; break } }
        if (-not $ok) { break }; $nonEmpty++
    }
    if ($ok -and $nonEmpty -gt 300) {
        "egg-move NARC candidate: $($kv.Name) ($($ent.Count) entries, $nonEmpty with moves)"
        $hits = @()
        for ($sp = 0; $sp -lt $ent.Count; $sp++) { $f = $ent[$sp]; if ($f.Length -lt 2) { continue }; $n = [BitConverter]::ToUInt16($f, 0); for ($i = 0; $i -lt $n; $i++) { if ([BitConverter]::ToUInt16($f, 2 + 2*$i) -eq $MoveId) { $hits += "species $sp has egg move $MoveId" } } }
        if ($hits.Count -eq 0) { "  egg moves: no species has move $MoveId" } else { $hits }
    }
}
# --- TM/HM table: a run of >= 95 u16 values, all in 1..700, mostly distinct, inside arm9 or any overlay
"scanning arm9 and overlays for the TM/HM table..."
$arm9Off = U32 0x20; $arm9Size = U32 0x2C; $ov9Off = U32 0x50; $ov9Size = U32 0x54
$regions = @(@{name="arm9"; data=(& { $fs.Position = $arm9Off; $br.ReadBytes($arm9Size) })})
$fs.Position = $ov9Off; $ovt = $br.ReadBytes($ov9Size)
for ($i = 0; $i -lt $ov9Size; $i += 32) { $ovId = [BitConverter]::ToUInt32($ovt, $i); $fid = [BitConverter]::ToUInt32($ovt, $i + 24); $regions += @{name="overlay $ovId"; data=(ReadFileById $fid)} }
foreach ($r in $regions) {
    $d = $r.data; $run = 0; $start = 0
    for ($o = 0; $o + 1 -lt $d.Length; $o += 2) {
        $v = [BitConverter]::ToUInt16($d, $o)
        if ($v -ge 1 -and $v -le 700) { if ($run -eq 0) { $start = $o }; $run++ } else {
            if ($run -ge 95) { $vals = @(); for ($k = 0; $k -lt $run; $k++) { $vals += [BitConverter]::ToUInt16($d, $start + 2*$k) }; $distinct = ($vals | Select-Object -Unique).Count
                if ($distinct -ge 90) { "  $($r.name) @0x$($start.ToString('X')): run of $run move-like values, $distinct distinct; first: $($vals[0..5] -join ',')"; if ($vals -contains $MoveId) { "    CONTAINS move $MoveId at index $([Array]::IndexOf($vals, [uint16]$MoveId))" } else { "    does not contain move $MoveId" } } }
            $run = 0 }
    }
}
$fs.Close()
