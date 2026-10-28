param([string]$Rom, [int]$Top = 40, [switch]$SingleStageOnly, [switch]$ExcludeUndiscovered)
# -ExcludeUndiscovered drops egg group 15 (legendaries, mythicals, babies), whose static encounters are scripted.
# Ranks species 1-649 by how much the game uses them, to pick a slot to replace with a new Pokemon:
# trainer Pokemon (a/0/9/1 + a/0/9/2), wild encounter tables that contain them (a/1/2/7, any slot or season),
# and whether they evolve from or into anything (a/0/1/9). Gift and static encounters live in scripts and are
# not counted. Prints the least-used species first.
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
    for ($i = 0; $i -lt $cnt; $i++) { $s = [BitConverter]::ToUInt32($d, $fatb + $i*8); $e = [BitConverter]::ToUInt32($d, $fatb + $i*8 + 4); if ($e -gt $s) { $seg = New-Object byte[] ($e - $s); [Array]::Copy($d, $gmif + $s, $seg, 0, $e - $s); [void]$out.Add($seg) } else { [void]$out.Add((New-Object byte[] 0)) } }
    return ,$out
}
$names = & (Join-Path $PSScriptRoot "dump-text.ps1") -Rom $Rom -File 90 -All | Select-Object -Skip 1
$sn = @{}; foreach ($l in $names) { if ($l -match '^\s*(\d+): (.*)$') { $sn[[int]$matches[1]] = $matches[2] } }
$trainers = New-Object int[] 700; $wild = New-Object int[] 700; $evoIn = New-Object bool[] 700; $evoOut = New-Object bool[] 700; $bst = New-Object int[] 700; $undisc = New-Object bool[] 700
$tr = NarcEntries (ReadFileById $files["a/0/9/1"]); $tp = NarcEntries (ReadFileById $files["a/0/9/2"])
for ($t = 0; $t -lt $tp.Count; $t++) {
    if ($tr[$t].Length -eq 0) { continue }
    $flags = $tr[$t][0]; $size = 8; if ($flags -band 2) { $size += 2 }; if ($flags -band 1) { $size += 8 }
    $f = $tp[$t]; $n = [Math]::Floor($f.Length / $size)
    for ($i = 0; $i -lt $n; $i++) { $sp = [BitConverter]::ToUInt16($f, $i*$size + 4) -band 0x3FF; if ($sp -gt 0 -and $sp -lt 700) { $trainers[$sp]++ } }
}
$enc = NarcEntries (ReadFileById $files["a/1/2/7"])
foreach ($f in $enc) {
    $seen = @{}
    for ($blk = 0; $blk + 232 -le $f.Length; $blk += 232) { for ($s = 0; $s -lt 56; $s++) { $sp = [BitConverter]::ToUInt16($f, $blk + 8 + 4*$s) -band 0x7FF; if ($sp -gt 0 -and $sp -lt 700) { $seen[$sp] = 1 } } }
    foreach ($k in $seen.Keys) { $wild[$k]++ }
}
$evo = NarcEntries (ReadFileById $files["a/0/1/9"])
for ($s = 1; $s -le 649; $s++) { $f = $evo[$s]; for ($k = 0; $k -lt 7 -and 6*$k + 5 -lt $f.Length; $k++) { $m = [BitConverter]::ToUInt16($f, 6*$k); $tg = [BitConverter]::ToUInt16($f, 6*$k + 4); if ($m -ne 0 -and $tg -gt 0 -and $tg -lt 700) { $evoOut[$s] = $true; $evoIn[$tg] = $true } } }
$per = NarcEntries (ReadFileById $files["a/0/1/6"])
for ($s = 1; $s -le 649; $s++) { $f = $per[$s]; $bst[$s] = $f[0] + $f[1] + $f[2] + $f[3] + $f[4] + $f[5]; $undisc[$s] = ($f[0x16] -eq 15) }
$fs.Close()
$rows = for ($s = 1; $s -le 649; $s++) {
    $single = -not $evoIn[$s] -and -not $evoOut[$s]
    if ($SingleStageOnly -and -not $single) { continue }
    if ($ExcludeUndiscovered -and $undisc[$s]) { continue }
    [pscustomobject]@{ Id = $s; Name = $sn[$s]; Trainers = $trainers[$s]; WildTables = $wild[$s]; Line = $(if ($single) { 'single' } elseif ($evoIn[$s] -and $evoOut[$s]) { 'middle' } elseif ($evoIn[$s]) { 'final' } else { 'base' }); BST = $bst[$s] }
}
$rows | Sort-Object @{ Expression = { $_.Trainers + $_.WildTables } }, Trainers, Id | Select-Object -First $Top | Format-Table -AutoSize | Out-String -Width 200
