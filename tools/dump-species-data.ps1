param([string]$Rom, [int[]]$Ids = @(601))
# Prints decoded entries from a/0/1/6 (B2W2 "personal" species data, 0x4C bytes each).
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
$id = $files["a/0/1/6"]; $s = U32 ($fatOff + $id * 8); $e = U32 ($fatOff + $id * 8 + 4); $fs.Position = $s; $d = $br.ReadBytes($e - $s)
$cnt = [BitConverter]::ToUInt32($d, 0x18); $fatb = 0x1C; $btnfOff = 0x10 + [BitConverter]::ToUInt32($d, 0x14)
$btnfSize = [BitConverter]::ToUInt32($d, $btnfOff + 4); $gmif = $btnfOff + $btnfSize + 8
"a/0/1/6 (species data): $cnt entries"
$types = "Normal","Fighting","Flying","Poison","Ground","Rock","Bug","Ghost","Steel","Fire","Water","Grass","Electric","Psychic","Ice","Dragon","Dark","Fairy"
$growth = "Medium Fast","Erratic","Fluctuating","Medium Slow","Fast","Slow"
$eggs = "-","Monster","Water 1","Bug","Flying","Field","Fairy","Grass","Human-Like","Water 3","Mineral","Amorphous","Water 2","Ditto","Dragon","Undiscovered"
foreach ($i in $Ids) {
    $ms = [BitConverter]::ToUInt32($d, $fatb + $i*8); $me = [BitConverter]::ToUInt32($d, $fatb + $i*8 + 4)
    $m = $d[($gmif+$ms)..($gmif+$me-1)]
    "species $i ($($m.Length) bytes)"
    "  stats HP/Atk/Def/SpA/SpD/Spe: $($m[0])/$($m[1])/$($m[2])/$($m[4])/$($m[5])/$($m[3])  total $($m[0]+$m[1]+$m[2]+$m[3]+$m[4]+$m[5])"
    "  types: $($types[$m[6]]) / $($types[$m[7]])   catch rate: $($m[8])"
    $ev = [BitConverter]::ToUInt16($m, 0xA)
    "  EV yield HP/Atk/Def/Spe/SpA/SpD: $($ev -band 3)/$(($ev -shr 2) -band 3)/$(($ev -shr 4) -band 3)/$(($ev -shr 6) -band 3)/$(($ev -shr 8) -band 3)/$(($ev -shr 10) -band 3)"
    "  items: $([BitConverter]::ToUInt16($m,0xC)) / $([BitConverter]::ToUInt16($m,0xE)) / $([BitConverter]::ToUInt16($m,0x10))   gender byte: $($m[0x12])   egg cycles: $($m[0x13])   base friendship: $($m[0x14])"
    "  growth: $($growth[$m[0x15]])   egg groups: $($eggs[$m[0x16]]) / $($eggs[$m[0x17]])   abilities: $($m[0x18]) / $($m[0x19]) / $($m[0x1A])"
    "  base exp: $([BitConverter]::ToUInt16($m,0x22))   height: $([BitConverter]::ToUInt16($m,0x24))   weight: $([BitConverter]::ToUInt16($m,0x26))"
    $tm = @(); for ($b = 0; $b -lt 128; $b++) { if (($m[0x28 + [Math]::Floor($b/8)] -shr ($b % 8)) -band 1) { $tm += ($b+1) } }
    "  TM/HM bits set (1-based): $($tm -join ',')"
    "  raw: " + (($m | ForEach-Object { $_.ToString('X2') }) -join ' ')
}
$fs.Close()
