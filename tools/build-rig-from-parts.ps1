param([string]$Spec, [string]$TemplateDir, [int]$TemplateBase, [string]$TargetDir, [int]$TargetBase, [switch]$Back,
      [string]$OutDir)
# Re-skins another species' battle-sprite rig with a still image: the image is cut into parts (polygons in the spec,
# image pixel coordinates), each part is packed into a fresh 256x128 rig sheet with its own pivot, and the
# template's animation (NANR), RAMN and RCMN are reused, so the parts move exactly like the template's parts.
# Spec (JSON):
#   image, palette   still PNG (96x96) and the palette json (colours matched on "src" and "rgb")
#   origin [x,y]     image point that becomes the sprite origin (feet bottom row = y-1, centred on x)
#   extend n         default underpaint depth: each part also gets the pixels of parts drawn above it within n px
#                    of its own, filled with its nearest own colour, so gaps do not open when parts move
#   parts[]          name, cells [template cell indices it replaces], pivot [x,y], order (0 = drawn on top),
#                    polys [[[x,y],...],...] (a pixel belongs to the first part, in list order, whose polygon holds
#                    its centre), optional extend, optional default:true (takes every pixel no polygon claims),
#                    optional fill (palette index for its underpaint instead of the nearest own colour: a flat
#                    shade reads better than a smear where a big part swings away)
#   negate[]         template sequences whose rotation is mirrored (for anatomy that faces the other way)
#   zeroMove[]       template sequences whose x/y translation is dropped
# Every template cell that a used sequence shows but no part claims points at an empty 8x8 corner of the sheet.
# Writes OutDir\a-0-0-4_<TargetBase+k>.bin for all 20 files (sheet and NANR uncompressed; the rest copied from
# TargetDir), plus sheet.png and parts.png previews.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
if (-not ('RigAnim' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'RigAnim.cs') }
$cfg = Get-Content $Spec -Raw | ConvertFrom-Json
$root = Split-Path $PSScriptRoot -Parent
$o = $(if ($Back) { 9 } else { 0 })
New-Item -ItemType Directory -Force $OutDir | Out-Null
function TE($k) { return ,[IO.File]::ReadAllBytes((Join-Path $TemplateDir ("a-0-0-4_{0}.bin" -f ($TemplateBase + $k)))) }
function GE($k) { return ,[IO.File]::ReadAllBytes((Join-Path $TargetDir ("a-0-0-4_{0}.bin" -f ($TargetBase + $k)))) }

# image -> palette indices
$pmap = @{}; foreach ($e in (Get-Content (Join-Path $root $cfg.palette) -Raw | ConvertFrom-Json).entries) { $pmap[$e.src.ToUpper()] = [int]$e.index; $pmap[$e.rgb.ToUpper()] = [int]$e.index }
$bmp = [Drawing.Bitmap]::FromFile((Join-Path $root $cfg.image)); $IW = $bmp.Width; $IH = $bmp.Height
$pix = New-Object 'int[,]' $IW, $IH
for ($y = 0; $y -lt $IH; $y++) { for ($x = 0; $x -lt $IW; $x++) { $c = $bmp.GetPixel($x, $y)
    if ($c.A -gt 0) { $key = '{0:X2}{1:X2}{2:X2}' -f $c.R, $c.G, $c.B; if (-not $pmap.ContainsKey($key)) { throw "colour $key at $x,$y not in palette" }; $pix[$x, $y] = $pmap[$key] } } }
$bmp.Dispose()

# pixel ownership
function InPoly($px, $py, $poly) {
    $in = $false; $n = $poly.Count
    $j = $n - 1
    for ($i = 0; $i -lt $n; $i++) {
        $xi = $poly[$i][0]; $yi = $poly[$i][1]; $xj = $poly[$j][0]; $yj = $poly[$j][1]
        if ((($yi -gt $py) -ne ($yj -gt $py)) -and ($px -lt ($xj - $xi) * ($py - $yi) / ($yj - $yi) + $xi)) { $in = -not $in }
        $j = $i }
    return $in
}
$parts = @($cfg.parts); $nParts = $parts.Count
$owner = New-Object 'int[,]' $IW, $IH
$def = -1; for ($p = 0; $p -lt $nParts; $p++) { if ($parts[$p].default) { $def = $p } }
for ($y = 0; $y -lt $IH; $y++) { for ($x = 0; $x -lt $IW; $x++) { $owner[$x, $y] = -1; if ($pix[$x, $y] -eq 0) { continue }
    $hit = -1; for ($p = 0; $p -lt $nParts -and $hit -lt 0; $p++) { foreach ($poly in $parts[$p].polys) { if (InPoly ($x + 0.5) ($y + 0.5) $poly) { $hit = $p; break } } }
    if ($hit -lt 0) { $hit = $def }; if ($hit -lt 0) { throw "pixel $x,$y belongs to no part" }; $owner[$x, $y] = $hit } }

# per part: own pixels plus underpaint (BFS from own pixels into opaque pixels of parts drawn above it)
$layers = @()
for ($p = 0; $p -lt $nParts; $p++) {
    $depth = $(if ($null -ne $parts[$p].extend) { [int]$parts[$p].extend } else { [int]$cfg.extend })
    $L = New-Object 'int[,]' $IW, $IH; $dist = New-Object 'int[,]' $IW, $IH; $q = New-Object 'System.Collections.Generic.Queue[int]'
    for ($y = 0; $y -lt $IH; $y++) { for ($x = 0; $x -lt $IW; $x++) { $dist[$x, $y] = -1; if ($owner[$x, $y] -eq $p) { $L[$x, $y] = $pix[$x, $y]; $dist[$x, $y] = 0; $q.Enqueue($y * $IW + $x) } } }
    while ($q.Count) { $v = $q.Dequeue(); $x = $v % $IW; $y = [int][Math]::Floor($v / $IW); if ($dist[$x, $y] -ge $depth) { continue }
        foreach ($d in @(@(1,0),@(-1,0),@(0,1),@(0,-1))) { $nx = $x + $d[0]; $ny = $y + $d[1]
            if ($nx -lt 0 -or $ny -lt 0 -or $nx -ge $IW -or $ny -ge $IH -or $dist[$nx, $ny] -ge 0) { continue }
            $w = $owner[$nx, $ny]; if ($w -lt 0 -or $parts[$w].order -ge $parts[$p].order) { continue }
            # copy the source neighbour's colour, but never spread outline black inward
            $col = $L[$x, $y]; if ($col -eq 1) { $col = $pix[$nx, $ny] }
            if ($null -ne $parts[$p].fill) { $col = [int]$parts[$p].fill }
            $L[$nx, $ny] = $col; $dist[$nx, $ny] = $dist[$x, $y] + 1; $q.Enqueue($ny * $IW + $nx) } }
    $x0 = $IW; $y0 = $IH; $x1 = -1; $y1 = -1
    for ($y = 0; $y -lt $IH; $y++) { for ($x = 0; $x -lt $IW; $x++) { if ($L[$x, $y]) { if ($x -lt $x0) { $x0 = $x }; if ($x -gt $x1) { $x1 = $x }; if ($y -lt $y0) { $y0 = $y }; if ($y -gt $y1) { $y1 = $y } } } }
    $layers += ,@{ L = $L; x0 = $x0; y0 = $y0; W = [int]([Math]::Ceiling(($x1 - $x0 + 1) / 8) * 8); H = [int]([Math]::Ceiling(($y1 - $y0 + 1) / 8) * 8) }
}

# shelf-pack into 256x128 (tallest first), keeping 8x8 at (248,120) empty for blank cells
$sheetW = 256; $sheetH = 128
$order = 0..($nParts - 1) | Sort-Object { -$layers[$_].H }, { -$layers[$_].W }
$cx = 0; $cy = 0; $rowH = 0
foreach ($p in $order) { $ly = $layers[$p]
    if ($cx + $ly.W -gt $sheetW) { $cx = 0; $cy += $rowH; $rowH = 0 }
    if ($cy + $ly.H -gt $sheetH -or ($cx + $ly.W -gt 248 -and $cy + $ly.H -gt 120)) { throw "parts do not fit the 256x128 sheet" }
    $ly.U = $cx; $ly.V = $cy; $cx += $ly.W; if ($ly.H -gt $rowH) { $rowH = $ly.H } }
$sheetT = GE ($o + 2); $sheetT = [RigAnim]::Unpack($sheetT)
$sheet = $sheetT.Clone(); for ($i = 48; $i -lt 48 + 256*128/2; $i++) { $sheet[$i] = 0 }
for ($p = 0; $p -lt $nParts; $p++) { $ly = $layers[$p]
    for ($yy = 0; $yy -lt $ly.H; $yy++) { for ($xx = 0; $xx -lt $ly.W; $xx++) { $sx = $ly.x0 + $xx; $sy = $ly.y0 + $yy
        if ($sx -ge $IW -or $sy -ge $IH) { continue }; $c = $ly.L[$sx, $sy]; if (-not $c) { continue }
        $i = ($ly.V + $yy) * 256 + $ly.U + $xx; $b = 48 + [Math]::Floor($i / 2)
        if ($i % 2 -eq 0) { $sheet[$b] = [byte](($sheet[$b] -band 0xF0) -bor $c) } else { $sheet[$b] = [byte](($sheet[$b] -band 0x0F) -bor ($c -shl 4)) } } } }

# NANR / RAMN from the template, with optional per-sequence edits
$nanr = [RigAnim]::Lz((TE ($o + 5)))
$fs = [BitConverter]::ToUInt16($nanr, 0x20) + 0x18; $vs = [BitConverter]::ToUInt16($nanr, 0x24) + 0x18
function SeqValues($s) { $h = 0x30 + 0x10 * $s; $fc = [BitConverter]::ToInt32($nanr, $h); $ss = [BitConverter]::ToInt32($nanr, $h + 0xC) + $fs
    return @{ type = [BitConverter]::ToUInt16($nanr, $h + 4); vps = @(0..($fc - 1) | ForEach-Object { [BitConverter]::ToInt32($nanr, $ss + 8*$_) + $vs } | Select-Object -Unique) } }
$edited = @{}
foreach ($s in @($cfg.negate)) { if ($null -eq $s) { continue }; $sv = SeqValues $s; if ($sv.type -ne 1) { continue }
    foreach ($vp in $sv.vps) { if ($edited["n$vp"]) { continue }; $edited["n$vp"] = 1; $r = [BitConverter]::ToUInt16($nanr, $vp + 2); [BitConverter]::GetBytes([uint16]((65536 - $r) % 65536)).CopyTo($nanr, $vp + 2) } }
foreach ($s in @($cfg.zeroMove)) { if ($null -eq $s) { continue }; $sv = SeqValues $s
    foreach ($vp in $sv.vps) { $at = $(if ($sv.type -eq 1) { 0xC } elseif ($sv.type -eq 2) { 4 } else { -1 }); if ($at -ge 0) { [BitConverter]::GetBytes([int32]0).CopyTo($nanr, $vp + $at) } } }
# (values shared between sequences are edited once; a shared value edited for one sequence changes the others too)

# Optional own motion instead of the template's: "motion": { length (ticks), step (ticks per frame), rest (share of
# the loop spent still), parts: { name: { rot (degrees, + = clockwise), x, y } } }. Every sequence is rewritten as
# type 1: a part listed there follows a = (1 - cos)/2 from 0 up to 1 and back over the moving share of the loop
# (all listed parts in step), every other part holds still on its cell. The RAMN is pinned to multi-cell 0.
$ramnOut = TE ($o + 7)
if ($cfg.motion) {
    $mo = $cfg.motion; $len = [int]$mo.length; $step = [int]$mo.step; $restShare = [double]$mo.rest
    $seqCount = [BitConverter]::ToUInt16($nanr, 0x18); $abnkSize = [BitConverter]::ToUInt32($nanr, 0x14)
    $tail = New-Object byte[] ($nanr.Length - (0x10 + $abnkSize)); [Array]::Copy($nanr, 0x10 + $abnkSize, $tail, 0, $tail.Length)
    $partOfCell = @{}; for ($q = 0; $q -lt $nParts; $q++) { foreach ($c in $parts[$q].cells) { $partOfCell[[int]$c] = $parts[$q].name } }
    $vals = New-Object System.Collections.Generic.List[byte]; $valOff = @{}
    function ValOffset($cell, $rotDeg, $dx, $dy) {
        $r = [int]([Math]::Round($rotDeg * 65536 / 360)); if ($r -lt 0) { $r += 65536 }; $r = $r % 65536
        $key = "$cell,$r,$dx,$dy"; if ($valOff.ContainsKey($key)) { return $valOff[$key] }
        $valOff[$key] = $vals.Count
        $vals.AddRange([BitConverter]::GetBytes([uint16]$cell)); $vals.AddRange([BitConverter]::GetBytes([uint16]$r))
        $vals.AddRange([BitConverter]::GetBytes([int32]4096)); $vals.AddRange([BitConverter]::GetBytes([int32]4096))
        $vals.AddRange([BitConverter]::GetBytes([int16]$dx)); $vals.AddRange([BitConverter]::GetBytes([int16]$dy))
        return $valOff[$key] }
    $seqHdr = New-Object System.Collections.Generic.List[byte]; $frm = New-Object System.Collections.Generic.List[byte]; $totalFrames = 0
    for ($s = 0; $s -lt $seqCount; $s++) {
        $sv = SeqValues $s; $cell = [BitConverter]::ToUInt16($nanr, $sv.vps[0]); $name = $partOfCell[[int]$cell]
        $m = $(if ($name) { $mo.parts.$name } else { $null })
        $frameOff = $frm.Count; $nf = 0
        if ($m) {
            for ($t = 0; $t -lt $len; $t += $step) {
                $ph = $t / $len; $mv = 1 - $restShare
                $a = $(if ($ph -lt $restShare) { 0 } else { (1 - [Math]::Cos(2 * [Math]::PI * ($ph - $restShare) / $mv)) / 2 })
                $vo = ValOffset $cell ([double]$m.rot * $a) ([int][Math]::Round([double]$m.x * $a)) ([int][Math]::Round([double]$m.y * $a))
                $frm.AddRange([BitConverter]::GetBytes([uint32]$vo)); $frm.AddRange([BitConverter]::GetBytes([uint16]$step)); $frm.Add(0xEF); $frm.Add(0xBE); $nf++ }
        } else {
            $vo = ValOffset $cell 0 0 0
            $frm.AddRange([BitConverter]::GetBytes([uint32]$vo)); $frm.AddRange([BitConverter]::GetBytes([uint16]$len)); $frm.Add(0xEF); $frm.Add(0xBE); $nf = 1 }
        $totalFrames += $nf
        $seqHdr.AddRange([BitConverter]::GetBytes([uint32]$nf)); $seqHdr.AddRange([BitConverter]::GetBytes([uint16]1)); $seqHdr.AddRange([BitConverter]::GetBytes([uint16]1))
        $seqHdr.AddRange([BitConverter]::GetBytes([uint32]2)); $seqHdr.AddRange([BitConverter]::GetBytes([uint32]$frameOff))
    }
    $seqStart = 0x18; $frameStart = $seqStart + $seqHdr.Count; $valStart = $frameStart + $frm.Count
    $abnk = New-Object System.Collections.Generic.List[byte]
    $abnk.AddRange([Text.Encoding]::ASCII.GetBytes('KNBA')); $abnk.AddRange([BitConverter]::GetBytes([uint32](8 + $valStart + $vals.Count)))
    $abnk.AddRange([BitConverter]::GetBytes([uint16]$seqCount)); $abnk.AddRange([BitConverter]::GetBytes([uint16]$totalFrames))
    foreach ($v32 in @($seqStart, $frameStart, $valStart, 0, 0)) { $abnk.AddRange([BitConverter]::GetBytes([uint32]$v32)) }
    $abnk.AddRange($seqHdr); $abnk.AddRange($frm); $abnk.AddRange($vals)
    $nl = New-Object System.Collections.Generic.List[byte]; $nl.AddRange([byte[]]$nanr[0..15]); $nl.AddRange($abnk); $nl.AddRange($tail)
    $nanr = $nl.ToArray(); [BitConverter]::GetBytes([uint32]$nanr.Length).CopyTo($nanr, 8)
    $fs = [BitConverter]::ToUInt16($nanr, 0x20) + 0x18; $vs = [BitConverter]::ToUInt16($nanr, 0x24) + 0x18
    # RAMN: every frame's multi-cell value -> 0 (values are u16 from the value offset up to the LABL block)
    $ramnOut = $ramnOut.Clone(); $rv = [BitConverter]::ToUInt16($ramnOut, 0x24) + 0x18; $rEnd = 0x10 + [BitConverter]::ToUInt32($ramnOut, 0x14)
    for ($k = $rv; $k + 1 -lt $rEnd; $k += 2) { $ramnOut[$k] = 0; $ramnOut[$k + 1] = 0 }
}

# RCMN: every entry gets its part's pivot and a draw order from the part orders
$rcmn = TE ($o + 6); $cells = TE ($o + 8)
$cellPart = @{}; for ($p = 0; $p -lt $nParts; $p++) { foreach ($c in $parts[$p].cells) { $cellPart[[int]$c] = $p } }
$ox = $cfg.origin[0]; $oy = $cfg.origin[1]
$mcCount = [BitConverter]::ToUInt16($rcmn, 0x18); $blankCells = @{}
for ($m = 0; $m -lt $mcCount; $m++) {
    $n = [BitConverter]::ToUInt16($rcmn, 0x2C + $m*8); $off = [BitConverter]::ToUInt32($rcmn, 0x30 + $m*8)
    $keys = @()
    for ($i = 0; $i -lt $n; $i++) { $e = 0x3C + $off + $i*8; $seq = [BitConverter]::ToUInt16($rcmn, $e)
        $sv = SeqValues $seq; $cell = [BitConverter]::ToUInt16($nanr, $sv.vps[0])
        if ($cellPart.ContainsKey([int]$cell)) { $p = $cellPart[[int]$cell]; $px = $parts[$p].pivot[0] - $ox; $py = $parts[$p].pivot[1] - $oy; $ord = $parts[$p].order }
        else { $blankCells[[int]$cell] = 1; $px = 0; $py = 0; $ord = 99 }
        [BitConverter]::GetBytes([int16]$px).CopyTo($rcmn, $e + 2); [BitConverter]::GetBytes([int16]$py).CopyTo($rcmn, $e + 4)
        $keys += ,@($ord, $i, $e) }
    $rank = 0; foreach ($k in ($keys | Sort-Object { $_[0] }, { $_[1] })) { $rcmn[$k[2] + 7] = [byte]$rank; $rank++ }
}

# cells: geometry relative to each part's pivot; header size/offset and cell 0's extra fields as the target had them
$cellsT = GE ($o + 8); [Array]::Copy($cellsT, 4, $cells, 4, 8)
for ($k = 36; $k -lt 60; $k++) { $cells[$k] = 0 }
function SetCell($c, $X, $Y, $W, $H, $U, $V) { $p = 12 + $c * 48
    [BitConverter]::GetBytes([int32]($X * 256)).CopyTo($cells, $p); [BitConverter]::GetBytes([int32]($Y * 256)).CopyTo($cells, $p + 4)
    foreach ($t in @(@(8, $W), @(12, $H), @(16, $U), @(20, $V))) { [BitConverter]::GetBytes([int32]($t[1] * 4096)).CopyTo($cells, $p + $t[0]) } }
for ($p = 0; $p -lt $nParts; $p++) { $ly = $layers[$p]
    foreach ($c in $parts[$p].cells) { SetCell ([int]$c) ($ly.x0 - $parts[$p].pivot[0]) ($parts[$p].pivot[1] - $ly.y0) $ly.W $ly.H $ly.U $ly.V } }
foreach ($c in $blankCells.Keys) { SetCell $c 0 0 8 8 248 120 }

# output set
for ($k = 0; $k -lt 20; $k++) { [IO.File]::WriteAllBytes((Join-Path $OutDir ("a-0-0-4_{0}.bin" -f ($TargetBase + $k))), (GE $k)) }
function Out($k, $bytes) { [IO.File]::WriteAllBytes((Join-Path $OutDir ("a-0-0-4_{0}.bin" -f ($TargetBase + $o + $k))), $bytes) }
Out 2 $sheet; Out 5 $nanr; Out 6 $rcmn; Out 7 $ramnOut; Out 8 $cells

# previews
$pal = GE 18; $argb = @(); for ($i = 0; $i -lt 16; $i++) { $v = [BitConverter]::ToUInt16($pal, 40 + $i*2); $argb += [Drawing.Color]::FromArgb(255, ($v -band 0x1F)*8, (($v -shr 5) -band 0x1F)*8, (($v -shr 10) -band 0x1F)*8) }
$sb = New-Object Drawing.Bitmap 512, 256; $g = [Drawing.Graphics]::FromImage($sb); $g.Clear([Drawing.Color]::FromArgb(255, 200, 230, 200))
for ($i = 0; $i -lt 256*128; $i++) { $b = $sheet[48 + [Math]::Floor($i/2)]; $c = $(if ($i % 2 -eq 0) { $b -band 0xF } else { $b -shr 4 })
    if ($c) { $br = New-Object Drawing.SolidBrush $argb[$c]; $g.FillRectangle($br, ($i % 256)*2, [Math]::Floor($i/256)*2, 2, 2); $br.Dispose() } }
for ($p = 0; $p -lt $nParts; $p++) { $ly = $layers[$p]; $g.DrawRectangle([Drawing.Pens]::Blue, $ly.U*2, $ly.V*2, $ly.W*2 - 1, $ly.H*2 - 1); $g.DrawString($parts[$p].name, (New-Object Drawing.Font 'Arial', 7), [Drawing.Brushes]::Blue, $ly.U*2 + 1, $ly.V*2 + 1) }
$sb.Save((Join-Path $OutDir 'sheet.png')); $sb.Dispose()
$tints = @('E6194B','3CB44B','4363D8','F58231','911EB4','42D4F4','F032E6','BFEF45','469990','9A6324','800000','808000','000075','A9A9A9','FFE119','DCBEFF')
$Z = 6; $mb = New-Object Drawing.Bitmap ($IW*$Z), ($IH*$Z); $g = [Drawing.Graphics]::FromImage($mb); $g.Clear([Drawing.Color]::White)
for ($y = 0; $y -lt $IH; $y++) { for ($x = 0; $x -lt $IW; $x++) { $w = $owner[$x, $y]; if ($w -lt 0) { continue }
    $t = [Drawing.ColorTranslator]::FromHtml('#' + $tints[$w % 16]); $sh = 0.55 + 0.45 * ($pix[$x, $y] / 15)
    $br = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(255, [int]($t.R*$sh), [int]($t.G*$sh), [int]($t.B*$sh))); $g.FillRectangle($br, $x*$Z, $y*$Z, $Z, $Z); $br.Dispose() } }
for ($p = 0; $p -lt $nParts; $p++) { $t = [Drawing.ColorTranslator]::FromHtml('#' + $tints[$p % 16]); $px = $parts[$p].pivot[0]*$Z; $py = $parts[$p].pivot[1]*$Z
    $g.FillEllipse([Drawing.Brushes]::Black, $px - 5, $py - 5, 10, 10); $g.DrawString("$($parts[$p].name) (o$($parts[$p].order))", (New-Object Drawing.Font 'Arial', 9, ([Drawing.FontStyle]::Bold)), (New-Object Drawing.SolidBrush $t), $px + 6, $py - 7) }
$mb.Save((Join-Path $OutDir 'parts.png')); $mb.Dispose()
"parts: " + ((0..($nParts - 1) | ForEach-Object { "$($parts[$_].name) $($layers[$_].W)x$($layers[$_].H)@$($layers[$_].U),$($layers[$_].V)" }) -join '; ')
"blank cells: " + (($blankCells.Keys | Sort-Object) -join ',')
