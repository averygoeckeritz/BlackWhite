param([string]$Rom, [int]$Species = 601, [string]$Front, [string]$Back, [switch]$Apply)
# Rig cells from an explicit part list. Each rig file (front: file 8, back: file 17 of the species' 20) holds
# 48-byte part records: screen X, screen Y (x0x100), width, height, sheet U, sheet V (x0x1000), then six zeros.
# A sequence frame shows one record, so one visible pose = one quad; a pose split over several records must be
# driven by several sequences in step. Spec string per rig: "part:x,y,w,h,u,v;part:x,y,w,h,u,v;..." (screen X/Y
# of the quad's top-left, Y up, from the sprite centre; sheet U/V of its top-left). Parts not listed become the
# usual 8x8 window in the empty bottom-right corner of the sheet. Omit -Front or -Back to leave that rig alone.
function ParseSpec($s) { $m = @{}; foreach ($item in ($s -split ';' | Where-Object { $_ })) { $kv = $item -split ':'; $m[[int]$kv[0]] = @($kv[1] -split ',' | ForEach-Object { [int]$_ }) }; return $m }
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
foreach ($which in @(@{ idx = 8; label = 'front'; spec = $Front }, @{ idx = 17; label = 'back'; spec = $Back })) {
    if (-not $which.spec) { continue }
    $map = ParseSpec $which.spec
    $st = EntryStart ($Species * 20 + $which.idx); $fs.Position = $st; $count = $br.ReadByte()
    "$($which.label) rig cells: $count parts, $($map.Count) specified"
    for ($i = 0; $i -lt $count; $i++) {
        $o = $st + 12 + $i*48
        if ($map.ContainsKey($i)) { $q = $map[$i]; $new = @([int]($q[0] * 0x100), [int]($q[1] * 0x100), [int]($q[2] * 0x1000), [int]($q[3] * 0x1000), [int]($q[4] * 0x1000), [int]($q[5] * 0x1000)); "  part $i`: screen ($($q[0]),$($q[1])) size $($q[2])x$($q[3]) sheet ($($q[4]),$($q[5]))" }
        else { $new = @(0, 0, 0x8000, 0x8000, 0xF8000, 0x78000) }
        if ($Apply) { $fs.Position = $o; foreach ($v in $new) { $bw.Write([int]$v) }; for ($k = 0; $k -lt 6; $k++) { $bw.Write([int]0) } }
    }
}
if ($Apply) { $bw.Flush(); "APPLIED" } else { "dry run only (pass -Apply to write)" }
$fs.Close()
