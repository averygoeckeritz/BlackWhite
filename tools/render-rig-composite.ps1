param([string]$Rom, [int[]]$Species = @(632), [switch]$Back, [string]$OutDir, [int]$Frame = 0)
# Assembles a battle sprite the way the rig draws it: for every RCMN entry of multi-cell 0, the sequence's frame
# $Frame (NANR) picks a rig cell, and that cell's quad (cells file: X,Y, W,H, U,V) is cut from the rig sheet and
# placed at RCMN (x,y) + cell (X,Y) + the frame's translation (type 2). Rotation/scale (type 1) are ignored.
# Prints the lowest opaque row and the feet's horizontal centre (bottom 6 rows) relative to the origin (positive =
# below / right), and writes <species>.png (256x256, origin at 128,128, red cross).
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force $OutDir | Out-Null
$tmp = Join-Path $OutDir 'raw'; New-Item -ItemType Directory -Force $tmp | Out-Null
function Lz([byte[]]$d) {
    $size = [int]$d[1] -bor ([int]$d[2] -shl 8) -bor ([int]$d[3] -shl 16); $out = New-Object byte[] $size; $src = 4; $dst = 0
    while ($dst -lt $size) { $flags = [int]$d[$src]; $src++
        for ($bit = 7; $bit -ge 0 -and $dst -lt $size; $bit--) {
            if ((($flags -shr $bit) -band 1) -eq 0) { $out[$dst] = $d[$src]; $dst++; $src++ } else {
                $b1 = [int]$d[$src]; $hi = $b1 -shr 4; $b2 = [int]$d[$src+1]
                if ($hi -eq 0) { $b3 = [int]$d[$src+2]; $len = (($b1 -band 0xF) -shl 4) + ($b2 -shr 4) + 0x11; $disp = ((($b2 -band 0xF) -shl 8) -bor $b3) + 1; $src += 3 }
                elseif ($hi -eq 1) { $b3 = [int]$d[$src+2]; $b4 = [int]$d[$src+3]; $len = ((($b1 -band 0xF) -shl 12) -bor ($b2 -shl 4) -bor ($b3 -shr 4)) + 0x111; $disp = ((($b3 -band 0xF) -shl 8) -bor $b4) + 1; $src += 4 }
                else { $len = $hi + 1; $disp = ((($b1 -band 0xF) -shl 8) -bor $b2) + 1; $src += 2 }
                for ($k = 0; $k -lt $len -and $dst -lt $size; $k++) { $out[$dst] = $out[$dst - $disp]; $dst++ } } } }
    return ,$out
}
foreach ($sp in $Species) {
    $b0 = $sp * 20; $o = $(if ($Back) { 9 } else { 0 })
    & "$PSScriptRoot\dump-narc-entries.ps1" -Rom $Rom -Narc a/0/0/4 -First $b0 -Count 20 -OutDir $tmp | Out-Null
    function E($k) { return ,[IO.File]::ReadAllBytes((Join-Path $tmp ("a-0-0-4_{0}.bin" -f ($b0 + $k)))) }
    $sheet = Lz (E ($o + 2)); $nanr = Lz (E ($o + 5)); $rcmn = E ($o + 6); $cells = E ($o + 8); $pal = E 18
    $colors = @(); for ($i = 0; $i -lt 16; $i++) { $v = [BitConverter]::ToUInt16($pal, 40 + $i*2); $colors += [Drawing.Color]::FromArgb(255, ($v -band 0x1F)*8, (($v -shr 5) -band 0x1F)*8, (($v -shr 10) -band 0x1F)*8) }
    $img = New-Object Drawing.Bitmap 256, 256
    $mask = New-Object 'bool[,]' 256, 256
    $framesStart = [BitConverter]::ToUInt16($nanr, 0x20) + 0x18; $valuesStart = [BitConverter]::ToUInt16($nanr, 0x24) + 0x18
    $n = [BitConverter]::ToUInt16($rcmn, 0x2C); $off = [BitConverter]::ToUInt32($rcmn, 0x30)
    $entries = @(); for ($i = 0; $i -lt $n; $i++) { $e = 0x3C + $off + $i*8; $entries += ,@([BitConverter]::ToUInt16($rcmn, $e), [BitConverter]::ToInt16($rcmn, $e+2), [BitConverter]::ToInt16($rcmn, $e+4), $rcmn[$e+7]) }
    foreach ($en in ($entries | Sort-Object { -$_[3] })) {
        $h = 0x30 + 0x10 * $en[0]; $fc = [BitConverter]::ToInt32($nanr, $h); $type = [BitConverter]::ToUInt16($nanr, $h + 4); $ss = [BitConverter]::ToInt32($nanr, $h + 0xC) + $framesStart
        $fr = [Math]::Min($Frame, $fc - 1); $vp = [BitConverter]::ToInt32($nanr, $ss + 8*$fr) + $valuesStart
        $cell = [BitConverter]::ToUInt16($nanr, $vp); $tx = 0; $ty = 0
        if ($type -eq 2) { $tx = [BitConverter]::ToInt16($nanr, $vp + 4); $ty = [BitConverter]::ToInt16($nanr, $vp + 6) }
        if ($type -eq 1) { $tx = [BitConverter]::ToInt16($nanr, $vp + 0xC); $ty = [BitConverter]::ToInt16($nanr, $vp + 0xE) }   # u16 cell, u16 rot, s32 sx, s32 sy, s16 x, s16 y
        $p = 12 + $cell * 48
        $X = [BitConverter]::ToInt32($cells, $p) / 256; $Y = [BitConverter]::ToInt32($cells, $p+4) / 256
        $W = [BitConverter]::ToInt32($cells, $p+8) / 4096; $H = [BitConverter]::ToInt32($cells, $p+12) / 4096
        $U = [BitConverter]::ToInt32($cells, $p+16) / 4096; $V = [BitConverter]::ToInt32($cells, $p+20) / 4096
        # cell Y is Y-up (top edge), the RCMN offset and frame translation are screen-down; this is the reading under
        # which every vanilla rig assembles cleanly, and their feet then end on the origin (the ground point)
        $left = 128 + $en[1] + $X + $tx; $top = 128 - $Y + $en[2] + $ty
        for ($yy = 0; $yy -lt $H; $yy++) { for ($xx = 0; $xx -lt $W; $xx++) {
            $su = $U + $xx; $sv = $V + $yy; if ($su -ge 256 -or $sv -ge 128) { continue }   # not $u/$v: PowerShell names ignore case
            $i = $sv * 256 + $su; $c = [int]$sheet[48 + [Math]::Floor($i/2)]; $c = $(if ($i % 2 -eq 0) { $c -band 0xF } else { $c -shr 4 })
            $sx = [int]($left + $xx); $sy = [int]($top + $yy)
            if ($c -ne 0 -and $sx -ge 0 -and $sx -lt 256 -and $sy -ge 0 -and $sy -lt 256) { $img.SetPixel($sx, $sy, $colors[$c]); $mask[$sx, $sy] = $true } } }
    }
    $bot = -1; for ($y = 255; $y -ge 0 -and $bot -lt 0; $y--) { for ($x = 0; $x -lt 256; $x++) { if ($mask[$x, $y]) { $bot = $y; break } } }
    $fl = 999; $fr2 = -1; for ($y = $bot - 5; $y -le $bot; $y++) { for ($x = 0; $x -lt 256; $x++) { if ($mask[$x, $y]) { if ($x -lt $fl) { $fl = $x }; if ($x -gt $fr2) { $fr2 = $x } } } }
    $wl = 999; $wr = -1; for ($y = 0; $y -lt 256; $y++) { for ($x = 0; $x -lt 256; $x++) { if ($mask[$x, $y]) { if ($x -lt $wl) { $wl = $x }; if ($x -gt $wr) { $wr = $x } } } }
    for ($k = -3; $k -le 3; $k++) { $img.SetPixel(128 + $k, 128, [Drawing.Color]::Red); $img.SetPixel(128, 128 + $k, [Drawing.Color]::Red) }
    $img.Save((Join-Path $OutDir "$sp.png")); $img.Dispose()
    "{0,4}: feet bottom {1,4} below origin, feet x {2}..{3} (centre {4,5:N1}), whole x {5}..{6} (centre {7,5:N1})" -f $sp, ($bot - 128), ($fl - 128), ($fr2 - 128), (($fl + $fr2) / 2 - 128), ($wl - 128), ($wr - 128), (($wl + $wr) / 2 - 128)
}
Remove-Item -Recurse -Force $tmp
