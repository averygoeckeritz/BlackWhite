param([string]$In, [string]$OutFile, [string]$Spec, [int]$BlankCell = 8, [int]$BlankFrames = 1)
# Rebuilds every sequence of a decompressed Gen 5 RNAN (part animation) as a plain cell-switching (type 0, looping)
# sequence, from a spec like "0=0,1,2,1,2,3,2,1@24,24,24,24,24,24,24,24;1=4,4,4,4,4,5,4,4@..." (per sequence:
# cells, then '@' and durations in 1/60 s frames; durations cycle if shorter). Sequences not in the spec show
# $BlankCell for $BlankFrames frames of 1 s (a part that is an invisible window). The sequence count, LABL and
# UEXT blocks are kept from the input, so the file still matches its RCMN. Use this when the original rig
# animates with translations/rotations (types 1/2) that make-nanr-pattern.ps1 cannot reuse.
$b = [IO.File]::ReadAllBytes($In)
function U16($o) { return [BitConverter]::ToUInt16($b, $o) }
function U32($o) { return [BitConverter]::ToUInt32($b, $o) }
if ([Text.Encoding]::ASCII.GetString($b, 0, 4) -ne 'RNAN') { throw "not an RNAN file" }
$abnkSize = U32 0x14; $seqCount = U16 0x18
$tail = New-Object byte[] ($b.Length - (0x10 + $abnkSize)); [Array]::Copy($b, 0x10 + $abnkSize, $tail, 0, $tail.Length)   # LABL + UEXT
$seqSpec = @{}
foreach ($item in ($Spec -split ';' | Where-Object { $_ })) {
    $kv = $item -split '='; $parts = $kv[1] -split '@'; $cells = @($parts[0] -split ',' | ForEach-Object { [int]$_ }); $durs = if ($parts.Count -gt 1) { @($parts[1] -split ',' | ForEach-Object { [int]$_ }) } else { @(8) }
    $seqSpec[[int]$kv[0]] = @{ cells = $cells; durs = $durs }
}
# frame data: one u16 cell index per distinct cell, 4-byte aligned entries (cell, 0xCCCC pad like the originals)
$cellOff = @{}; $fdata = New-Object System.Collections.Generic.List[byte]
function CellOffset($c) { if (-not $cellOff.ContainsKey($c)) { $cellOff[$c] = $fdata.Count; $fdata.Add([byte]($c -band 0xFF)); $fdata.Add([byte]($c -shr 8)); $fdata.Add(0xCC); $fdata.Add(0xCC) }; return $cellOff[$c] }
$seqHdr = New-Object System.Collections.Generic.List[byte]; $frames = New-Object System.Collections.Generic.List[byte]; $total = 0; $desc = @()
for ($i = 0; $i -lt $seqCount; $i++) {
    if ($seqSpec.ContainsKey($i)) { $cells = $seqSpec[$i].cells; $durs = $seqSpec[$i].durs } else { $cells = @($BlankCell) * $BlankFrames; $durs = @(60) }
    $frameOff = $frames.Count; $sum = 0
    for ($j = 0; $j -lt $cells.Count; $j++) {
        $fo = CellOffset $cells[$j]; $dur = $durs[$j % $durs.Count]; $sum += $dur
        $frames.AddRange([BitConverter]::GetBytes([uint32]$fo)); $frames.AddRange([BitConverter]::GetBytes([uint16]$dur)); $frames.Add(0xEF); $frames.Add(0xBE)
    }
    $total += $cells.Count
    # sequence header: u16 frames, u16 loop start, u16 type (0 = cell only), u16 mode (1 = loop), u32 frame offset ... as in the originals: frames u32, type u16, mode u16, pad u32, offset u32
    $seqHdr.AddRange([BitConverter]::GetBytes([uint32]$cells.Count)); $seqHdr.AddRange([BitConverter]::GetBytes([uint16]0)); $seqHdr.AddRange([BitConverter]::GetBytes([uint16]1)); $seqHdr.AddRange([BitConverter]::GetBytes([uint32]2)); $seqHdr.AddRange([BitConverter]::GetBytes([uint32]$frameOff))
    if ($seqSpec.ContainsKey($i)) { $desc += "seq $i`: $($cells.Count) frames, $sum = $([Math]::Round($sum/60,2)) s" }
}
while ($fdata.Count % 4 -ne 0) { $fdata.Add(0xCC) }
# ABNK block: 8 header + 0x18 fixed (count u16, total u16, seq off u32, frame off u32, fdata off u32, 2 x u32 0)
$seqStart = 0x18; $frameStart = $seqStart + $seqHdr.Count; $fdataStart = $frameStart + $frames.Count
$blockSize = 8 + $fdataStart + $fdata.Count
$abnk = New-Object System.Collections.Generic.List[byte]
$abnk.AddRange([Text.Encoding]::ASCII.GetBytes('KNBA')); $abnk.AddRange([BitConverter]::GetBytes([uint32]$blockSize))
$abnk.AddRange([BitConverter]::GetBytes([uint16]$seqCount)); $abnk.AddRange([BitConverter]::GetBytes([uint16]$total))
$abnk.AddRange([BitConverter]::GetBytes([uint32]$seqStart)); $abnk.AddRange([BitConverter]::GetBytes([uint32]$frameStart)); $abnk.AddRange([BitConverter]::GetBytes([uint32]$fdataStart))
$abnk.AddRange([BitConverter]::GetBytes([uint32]0)); $abnk.AddRange([BitConverter]::GetBytes([uint32]0))
$abnk.AddRange($seqHdr); $abnk.AddRange($frames); $abnk.AddRange($fdata)
$out = New-Object System.Collections.Generic.List[byte]
$out.AddRange([byte[]]$b[0..15]); $out.AddRange($abnk); $out.AddRange($tail)
$nb = $out.ToArray(); [BitConverter]::GetBytes([uint32]$nb.Length).CopyTo($nb, 8)
[IO.File]::WriteAllBytes($OutFile, $nb)
"$seqCount sequences rebuilt ($($seqSpec.Count) from spec, rest blank cell $BlankCell); $total frames; $($b.Length) -> $($nb.Length) bytes -> $OutFile"
$desc
