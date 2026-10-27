param([string]$Rom, [string]$Narc, [int]$First, [int]$Count, [string]$OutDir)
# Writes raw NARC entries [$First, $First+$Count) of $Narc to $OutDir\<narc>_<index>.bin and prints their magic bytes.
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
$id = $files[$Narc]; $base = U32 ($fatOff + $id * 8)
$cnt = U32 ($base + 0x18); $btnfOff = $base + 0x10 + (U32 ($base + 0x14)); $btnfSize = U32 ($btnfOff + 4); $gmif = $btnfOff + $btnfSize + 8
"$Narc`: $cnt entries"
New-Item -ItemType Directory -Force $OutDir | Out-Null
$tag = $Narc -replace '/', '-'
for ($i = $First; $i -lt $First + $Count; $i++) {
    $s = U32 ($base + 0x1C + $i*8); $e = U32 ($base + 0x1C + $i*8 + 4)
    $fs.Position = $gmif + $s; $d = $br.ReadBytes($e - $s)
    $out = Join-Path $OutDir ("{0}_{1}.bin" -f $tag, $i); [IO.File]::WriteAllBytes($out, $d)
    $magic = if ($d.Length -ge 4) { [Text.Encoding]::ASCII.GetString($d, 0, 4) -replace '[^\x20-\x7E]', '.' } else { '' }
    "entry {0,6}: {1,7} bytes  magic '{2}'  first bytes {3}" -f $i, $d.Length, $magic, (($d[0..[Math]::Min(7,$d.Length-1)] | ForEach-Object { $_.ToString('X2') }) -join ' ')
}
$fs.Close()
