param([string]$Rom, [int]$Swar = 601, [string]$Raw, [int]$Rate, [string]$Sdat = "swan_sound_data.sdat", [switch]$Apply)
# Replaces a Pokémon cry in place. Gen 5 cries are one SWAV per Pokémon inside WAVE_ARC_PVnnn (SWAR index nnn of
# the SDAT), 8-bit signed PCM (type 0), no loop. $Raw is signed 8-bit mono PCM (ffmpeg -f s8) at $Rate Hz; it must
# fit the existing wave's data area (the file keeps its size; the rest is zero padding). The SWAV header gets the
# new rate, the ARM7 timer value floor(16756991 / rate), and the new length in 32-bit words.
$pcm = [IO.File]::ReadAllBytes($Raw)   # not $raw: assigning to a [string] parameter's variable would stringify it
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
$id = $files[$Sdat]; $base = U32 ($fatOff + $id * 8)
$info = $base + (U32 ($base + 0x18)); $fat = $base + (U32 ($base + 0x20))
$swarRec = U32 ($info + 8 + 4*3); $recO = U32 ($info + $swarRec + 4 + 4*$Swar); $fileId = U16 ($info + $recO)
$fo = U32 ($fat + 12 + 16*$fileId); $fsz = U32 ($fat + 12 + 16*$fileId + 4); $st = $base + $fo
$fs.Position = $st; $magic = [Text.Encoding]::ASCII.GetString($br.ReadBytes(4)); if ($magic -ne 'SWAR') { throw "SWAR $Swar is not a SWAR ($magic)" }
$waves = U32 ($st + 0x38); $wo = $st + (U32 ($st + 0x3C)); $type = $br.ReadByte(); $fs.Position = $wo; $type = $br.ReadByte(); $loop = $br.ReadByte()
$oldRate = U16 ($wo + 2); $oldLen = U32 ($wo + 8); $dataStart = $wo + 12; $dataArea = ($st + $fsz) - $dataStart
"SWAR $Swar (sdat file $fileId, $fsz bytes, $waves wave): type $type loop $loop rate $oldRate Hz, $($oldLen*4) data bytes, data area $dataArea bytes"
$words = [Math]::Ceiling($pcm.Length / 4); if ($words * 4 -gt $dataArea) { throw "cry does not fit: $($pcm.Length) bytes > $dataArea" }
$timer = [Math]::Floor(16756991 / $Rate)
"new: rate $Rate Hz (timer $timer), $($pcm.Length) bytes = $([Math]::Round($pcm.Length / $Rate, 3)) s, $words words"
if (-not $Apply) { "dry run only (pass -Apply to write)"; $fs.Close(); return }
$fs.Position = $wo; $bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([uint16]$Rate); $bw.Write([uint16]$timer); $bw.Write([uint16]0); $bw.Write([uint32]$words)
$fs.Position = $dataStart; $bw.Write($pcm); for ($k = $pcm.Length; $k -lt $dataArea; $k++) { $bw.Write([byte]0) }
$bw.Flush(); $fs.Close(); "APPLIED"
