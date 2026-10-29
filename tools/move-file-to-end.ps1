param([string]$Rom, [string]$Path, [switch]$Apply, [switch]$FixHeaderOnly)
# Moves one NitroFS file (e.g. the a/0/0/4 sprite NARC) to the end of the ROM, 0x200-aligned, and points its FAT
# entry there, so grow-narc-entry.ps1 can grow it without limit (a last file has no neighbour to collide with).
# The old copy is left in place, unused. Also sets the header's "total used ROM size" (0x80) to the highest FAT
# end and recomputes the header CRC16 (0x15E over 0x000-0x15D). -FixHeaderOnly just does that last step, for
# after a moved file has grown.
# WARNING: a ROM with a/0/0/4 moved this way ran in melonDS on the PC but went to a white screen on battle start
# in Delta on Avery's phone (2026-10-28). Do not use it for builds meant for the phone; free space in place.
$fs = [IO.File]::Open($Rom, 'Open', 'ReadWrite'); $br = New-Object IO.BinaryReader($fs); $bw = New-Object IO.BinaryWriter($fs)
function U32($o) { $fs.Position = $o; return $br.ReadUInt32() }
function U16($o) { $fs.Position = $o; return $br.ReadUInt16() }
$fntOff = U32 0x40; $fatOff = U32 0x48; $fatSize = U32 0x4C
function MaxEnd { $m = 0; for ($i = 0; $i -lt $fatSize/8; $i++) { $e = U32 ($fatOff + $i*8 + 4); if ($e -gt $m) { $m = $e } }; return $m }
if (-not $FixHeaderOnly) {
    $files = @{}
    function Walk($dirId, $p0) {
        $e = $fntOff + ($dirId -band 0xFFF) * 8; $subOff = U32 $e; $firstId = U16 ($e + 4)
        $p = $fntOff + $subOff; $id = $firstId
        while ($true) {
            $fs.Position = $p; $len = $br.ReadByte(); if ($len -eq 0) { break }
            $isDir = ($len -band 0x80) -ne 0; $n = $len -band 0x7F
            $name = [Text.Encoding]::ASCII.GetString($br.ReadBytes($n)); $p += 1 + $n
            if ($isDir) { $sub = U16 $p; $p += 2; Walk $sub "$p0$name/" } else { $files["$p0$name"] = $id; $id++ }
        }
    }
    Walk 0xF000 ""
    $id = $files[$Path]; if ($null -eq $id) { throw "no file $Path" }
    $start = U32 ($fatOff + $id*8); $end = U32 ($fatOff + $id*8 + 4)
    $top = [Math]::Max([Math]::Max((MaxEnd), [uint32]$fs.Length), (U32 0x80))   # also clear of the header's used size
    $newStart = [uint32]([Math]::Ceiling($top / 0x200) * 0x200)
    "$Path (file $id) 0x$($start.ToString('X'))-0x$($end.ToString('X')), $($end - $start) bytes -> 0x$($newStart.ToString('X'))"
    if (-not $Apply) { "dry run only (pass -Apply to write)"; $fs.Close(); return }
    $fs.Position = $start; $data = $br.ReadBytes($end - $start)
    if ($fs.Length -lt $newStart) { $fs.SetLength($newStart) }
    $fs.Position = $newStart; $bw.Write($data)
    $fs.Position = $fatOff + $id*8; $bw.Write([uint32]$newStart); $bw.Write([uint32]($newStart + $data.Length))
}
if ($Apply -or $FixHeaderOnly) {
    $used = MaxEnd; if ($fs.Length -lt $used) { $fs.SetLength($used) }
    $old = U32 0x80; if ($old -gt $used) { $used = $old }   # never shrink it (this ROM's value is past its last file)
    $fs.Position = 0x80; $bw.Write([uint32]$used)
    $fs.Position = 0; $h = $br.ReadBytes(0x15E); $crc = 0xFFFF
    foreach ($b in $h) { $crc = $crc -bxor $b; for ($k = 0; $k -lt 8; $k++) { if ($crc -band 1) { $crc = ($crc -shr 1) -bxor 0xA001 } else { $crc = $crc -shr 1 } } }
    $fs.Position = 0x15E; $bw.Write([uint16]$crc); $bw.Flush()
    "header: used ROM size 0x$($used.ToString('X')), header CRC 0x$($crc.ToString('X4')); file is $($fs.Length) bytes"
}
$fs.Close()
