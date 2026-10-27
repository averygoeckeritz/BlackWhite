param([string]$Rom, [string]$PaletteJson, [int]$Species = 601, [switch]$Apply)
# Writes the normal and shiny 16-colour palettes (RLCN files 18 and 19 of the species' 20-file set in a/0/0/4)
# in place: 16 x u16 BGR555 at offset 40. Index 0 is kept from the original (transparent/background colour).
$pal = Get-Content $PaletteJson -Raw | ConvertFrom-Json
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
$id = $files["a/0/0/4"]; $base = U32 ($fatOff + $id * 8)
$btnfOff = $base + 0x10 + (U32 ($base + 0x14)); $btnfSize = U32 ($btnfOff + 4); $gmif = $btnfOff + $btnfSize + 8
function EntryStart($i) { return $gmif + (U32 ($base + 0x1C + $i*8)) }
foreach ($which in @(@{ idx = 18; key = 'val555'; label = 'palette' }, @{ idx = 19; key = 'shinyVal555'; label = 'shiny palette' })) {
    $st = EntryStart ($Species * 20 + $which.idx)
    $fs.Position = $st; $magic = [Text.Encoding]::ASCII.GetString($br.ReadBytes(4)); if ($magic -ne 'RLCN') { throw "entry is not RLCN ($magic)" }
    $cur = @(); for ($i = 0; $i -lt 16; $i++) { $cur += (U16 ($st + 40 + $i*2)) }
    "$($which.label) current: " + (($cur | ForEach-Object { '{0:X4}' -f $_ }) -join ' ')
    $new = @($cur[0]); foreach ($e in ($pal.entries | Sort-Object index)) { $new += [int]$e.($which.key) }
    while ($new.Count -lt 16) { $new += 0 }
    "$($which.label) new:     " + (($new | ForEach-Object { '{0:X4}' -f $_ }) -join ' ')
    if ($Apply) { $fs.Position = $st + 40; foreach ($v in $new) { $bw.Write([uint16]$v) }; $bw.Flush() }
}
if ($Apply) { "APPLIED" } else { "dry run only (pass -Apply to write)" }
$fs.Close()
