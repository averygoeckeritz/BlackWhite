param([string]$Rom, [int[]]$Ids = @(128, 332, 400))
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
$id = $files["a/0/2/1"]; $s = U32 ($fatOff + $id * 8); $e = U32 ($fatOff + $id * 8 + 4); $fs.Position = $s; $d = $br.ReadBytes($e - $s)
$cnt = [BitConverter]::ToUInt32($d, 0x18); $fatb = 0x1C; $btnfOff = 0x10 + [BitConverter]::ToUInt32($d, 0x14)
$btnfSize = [BitConverter]::ToUInt32($d, $btnfOff + 4); $gmif = $btnfOff + $btnfSize + 8
"a/0/2/1 (move data): $cnt entries"
$types = "Normal","Fighting","Flying","Poison","Ground","Rock","Bug","Ghost","Steel","Fire","Water","Grass","Electric","Psychic","Ice","Dragon","Dark","Fairy"
foreach ($i in $Ids) {
    $ms = [BitConverter]::ToUInt32($d, $fatb + $i*8); $me = [BitConverter]::ToUInt32($d, $fatb + $i*8 + 4)
    $m = $d[($gmif+$ms)..($gmif+$me-1)]
    $hex = ($m | ForEach-Object { $_.ToString("X2") }) -join ' '
    "move $i ($($m.Length) bytes): $hex"
    "   type=$($types[$m[0]]) ($($m[0]))  category=$($m[2])  power=$($m[3])  accuracy=$($m[4])  pp=$($m[5])  priority=$($m[6])  effect(u16@0x10)=$([BitConverter]::ToUInt16($m,0x10))"
}
$fs.Close()
