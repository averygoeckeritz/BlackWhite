param([string]$Gif, [int[]]$Frames, [int]$Ticks = 24, [int]$OffsetX, [int]$OffsetY, [string]$PaletteJson,
      [string]$Merge = '', [string]$TargetDir, [int]$TargetBase, [string]$OutDir, [int]$Band = 16,
      [string[]]$Png, [switch]$Back)
# Turns frames of an animated GIF into a front battle-sprite rig that plays them in order (a flipbook), for when
# more poses are wanted than three 72-px columns hold. Each chosen frame is cut into $Band-row strips, each strip
# trimmed to its own width (rounded up to 8), and all strips are packed into the 256x128 rig sheet (16-row shelves;
# a strip that no longer fits whole is split into two 8-row halves for the leftover gaps). Every strip is a cell
# placed so GIF pixel (0,0) lands at ($OffsetX, $OffsetY) from the sprite origin. NANR sequences 0..n-1 show strip
# n of the current frame ($Ticks per frame, looping), so the RCMN entries that list those sequences (the target's
# own multi-cell 0) draw the frame; every RCMN entry is moved to (0,0) and multi-cell 1 is made a copy of 0.
# Colours map to palette indices through the palette json ("src"/"rgb"), plus -Merge "RRGGBB=index,...".
# -Png takes still pose images (played in the given order) instead of GIF frames; -Back builds the back rig
# (files 11/14/15/16/17) instead of the front (2/5/6/7/8).
# Writes OutDir\a-0-0-4_<TargetBase+k>.bin (all 20 files; sheet and NANR uncompressed) and sheet.png.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
if (-not ('RigAnim' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'RigAnim.cs') }
New-Item -ItemType Directory -Force $OutDir | Out-Null
$o = $(if ($Back) { 9 } else { 0 })
function GE($k) { return ,[IO.File]::ReadAllBytes((Join-Path $TargetDir ("a-0-0-4_{0}.bin" -f ($TargetBase + $k)))) }

$pmap = @{}; foreach ($e in (Get-Content $PaletteJson -Raw | ConvertFrom-Json).entries) { $pmap[$e.src.ToUpper()] = [int]$e.index; $pmap[$e.rgb.ToUpper()] = [int]$e.index }
foreach ($m in ($Merge -split ',' | Where-Object { $_ })) { $kv = $m -split '='; $pmap[$kv[0].ToUpper()] = [int]$kv[1] }
if ($Png) { $Frames = 0..($Png.Count - 1); $first = [Drawing.Bitmap]::FromFile((Resolve-Path $Png[0]).Path); $GW = $first.Width; $GH = $first.Height; $first.Dispose() }
else { $img = [Drawing.Image]::FromFile((Resolve-Path $Gif).Path); $fd = New-Object Drawing.Imaging.FrameDimension($img.FrameDimensionsList[0]); $GW = $img.Width; $GH = $img.Height }
$pix = @()
foreach ($f in $Frames) {
    if ($Png) { $b = [Drawing.Bitmap]::FromFile((Resolve-Path $Png[$f]).Path) }
    else { $img.SelectActiveFrame($fd, $f) | Out-Null; $b = New-Object Drawing.Bitmap $GW, $GH; $g = [Drawing.Graphics]::FromImage($b); $g.DrawImage($img, 0, 0, $GW, $GH); $g.Dispose() }
    $a = New-Object 'int[,]' $GW, $GH
    for ($y = 0; $y -lt $GH; $y++) { for ($x = 0; $x -lt $GW; $x++) { $c = $b.GetPixel($x, $y)
        if ($c.A -gt 0) { $key = '{0:X2}{1:X2}{2:X2}' -f $c.R, $c.G, $c.B; if (-not $pmap.ContainsKey($key)) { throw "frame $f colour $key at $x,$y not in palette" }; $a[$x, $y] = $pmap[$key] } } }
    $b.Dispose(); $pix += ,$a }
if (-not $Png) { $img.Dispose() }

# strips (pose, top row, rows, x range)
function Strip($pi, $y0, $h) { $mn = 999; $mx = -1
    for ($y = $y0; $y -lt [Math]::Min($GH, $y0 + $h); $y++) { for ($x = 0; $x -lt $GW; $x++) { if ($pix[$pi][$x, $y]) { if ($x -lt $mn) { $mn = $x }; if ($x -gt $mx) { $mx = $x } } } }
    if ($mx -lt 0) { return $null }; return [pscustomobject]@{ pose = $pi; y0 = $y0; h = $h; x0 = $mn; w = [int]([Math]::Ceiling(($mx - $mn + 1) / 8) * 8) } }
$strips = @(); for ($pi = 0; $pi -lt $Frames.Count; $pi++) { for ($y0 = 0; $y0 -lt $GH; $y0 += $Band) { $s = Strip $pi $y0 $Band; if ($s) { $s | Add-Member band ([int]($y0 / $Band)); $strips += $s } } }
# pack: 8-row lanes; a whole strip takes the same span in two neighbouring lanes of one 16-row shelf; 8x8 at (248,120) stays empty
$lanes = New-Object int[] 16; $lanes[15] = 248; $placed = @()
foreach ($s in ($strips | Sort-Object w -Descending)) {
    $best = -1; $left = 9999
    for ($r = 0; $r -lt 8; $r++) { $fill = [Math]::Max($lanes[2*$r], $lanes[2*$r + 1]); $cap = $(if ($r -eq 7) { 248 } else { 256 }); if ($fill + $s.w -le $cap -and ($cap - $fill - $s.w) -lt $left) { $left = $cap - $fill - $s.w; $best = $r } }
    if ($best -ge 0) { $fill = [Math]::Max($lanes[2*$best], $lanes[2*$best + 1]); $s | Add-Member U $fill; $s | Add-Member V (16 * $best); $lanes[2*$best] = $fill + $s.w; $lanes[2*$best + 1] = $fill + $s.w; $placed += $s; continue }
    foreach ($half in 0, 8) { $hs = Strip $s.pose ($s.y0 + $half) 8; if (-not $hs) { continue }; $hs | Add-Member band $s.band
        $l = -1; for ($k = 0; $k -lt 16; $k++) { $cap = $(if ($k -eq 15) { 248 } else { 256 }); if ($lanes[$k] + $hs.w -le $cap) { $l = $k; break } }
        if ($l -lt 0) { throw "frames do not fit the sheet" }
        $hs | Add-Member U $lanes[$l]; $hs | Add-Member V (8 * $l); $lanes[$l] += $hs.w; $placed += $hs } }

# sheet
$sheet = [RigAnim]::Unpack((GE ($o + 2))); $sheet = $sheet.Clone(); for ($i = 48; $i -lt 48 + 256*128/2; $i++) { $sheet[$i] = 0 }
foreach ($s in $placed) { for ($yy = 0; $yy -lt $s.h; $yy++) { for ($xx = 0; $xx -lt $s.w; $xx++) { $gx = $s.x0 + $xx; $gy = $s.y0 + $yy
    if ($gx -ge $GW -or $gy -ge $GH) { continue }; $c = $pix[$s.pose][$gx, $gy]; if (-not $c) { continue }
    $i = ($s.V + $yy) * 256 + $s.U + $xx; $b = 48 + [Math]::Floor($i / 2)
    if ($i % 2 -eq 0) { $sheet[$b] = [byte](($sheet[$b] -band 0xF0) -bor $c) } else { $sheet[$b] = [byte](($sheet[$b] -band 0x0F) -bor ($c -shl 4)) } } } }

# cells: one per placed strip, then the blank one
$cellsT = GE ($o + 8); $nCells = $placed.Count + 1
$cells = New-Object byte[] (12 + 48 * $nCells + 4); [Array]::Copy($cellsT, 0, $cells, 0, 12); [BitConverter]::GetBytes([uint16]$nCells).CopyTo($cells, 0)
function SetCell($c, $X, $Y, $W, $H, $U, $V) { $p = 12 + $c * 48
    [BitConverter]::GetBytes([int32]($X * 256)).CopyTo($cells, $p); [BitConverter]::GetBytes([int32]($Y * 256)).CopyTo($cells, $p + 4)
    foreach ($t in @(@(8, $W), @(12, $H), @(16, $U), @(20, $V))) { [BitConverter]::GetBytes([int32]($t[1] * 4096)).CopyTo($cells, $p + $t[0]) } }
for ($c = 0; $c -lt $placed.Count; $c++) { $s = $placed[$c]; $s | Add-Member cell $c; SetCell $c ($s.x0 + $OffsetX) (-($s.y0 + $OffsetY)) $s.w $s.h $s.U $s.V }
$blank = $placed.Count; SetCell $blank 0 0 8 8 248 120

# NANR: sequence j shows the j-th piece (by band, then top row) of the current pose; poses play in order
$byPose = @{}; foreach ($s in $placed) { if (-not $byPose[$s.pose]) { $byPose[$s.pose] = @() }; $byPose[$s.pose] += $s }
$maxPieces = ($byPose.Values | ForEach-Object { $_.Count } | Measure-Object -Maximum).Maximum
$specParts = @(); for ($j = 0; $j -lt $maxPieces; $j++) {
    $cl = @(); for ($pi = 0; $pi -lt $Frames.Count; $pi++) { $list = @($byPose[$pi] | Sort-Object band, y0); $cl += $(if ($j -lt $list.Count) { $list[$j].cell } else { $blank }) }
    $specParts += "$j=$($cl -join ',')@$Ticks" }
$nanrIn = Join-Path $OutDir 'nanr-in.bin'; [IO.File]::WriteAllBytes($nanrIn, [RigAnim]::Unpack((GE ($o + 5))))
& "$PSScriptRoot\rebuild-nanr.ps1" -In $nanrIn -OutFile (Join-Path $OutDir 'nanr-out.bin') -Spec ($specParts -join ';') -BlankCell $blank | Out-Null
$nanr = [IO.File]::ReadAllBytes((Join-Path $OutDir 'nanr-out.bin'))

# RCMN: all entries at (0,0); sequences 0..maxPieces-1 must be listed by multi-cell 0; multi-cell 1 = copy of 0
$rcmn = (GE ($o + 6)).Clone(); $mcs = [BitConverter]::ToUInt16($rcmn, 0x18)
$n0 = [BitConverter]::ToUInt16($rcmn, 0x2C); $o0 = [BitConverter]::ToUInt32($rcmn, 0x30); $listed = @()
for ($i = 0; $i -lt $n0; $i++) { $e = 0x3C + $o0 + $i*8; $listed += [BitConverter]::ToUInt16($rcmn, $e); [BitConverter]::GetBytes([int32]0).CopyTo($rcmn, $e + 2) }
for ($j = 0; $j -lt $maxPieces; $j++) { if ($listed -notcontains $j) { throw "multi-cell 0 does not list sequence $j" } }
for ($m = 1; $m -lt $mcs; $m++) { $nm = [BitConverter]::ToUInt16($rcmn, 0x2C + $m*8); $om = [BitConverter]::ToUInt32($rcmn, 0x30 + $m*8)
    # (the RAMN below never shows them; a copy is only a safety net, as far as the entry counts allow)
    [Array]::Copy($rcmn, 0x3C + $o0, $rcmn, 0x3C + $om, 8 * [Math]::Min($n0, $nm)) }

# RAMN: every frame shows multi-cell 0 for exactly one flipbook cycle, so a sequence restart at a RAMN frame
# change (if the game does that) can never cut the cycle short
$ramn = (GE ($o + 7)).Clone(); $rf = [BitConverter]::ToUInt16($ramn, 0x20) + 0x18; $rv = [BitConverter]::ToUInt16($ramn, 0x24) + 0x18
$rEnd = 0x10 + [BitConverter]::ToUInt32($ramn, 0x14); $rfc = [BitConverter]::ToInt32($ramn, 0x30)
for ($k = 0; $k -lt $rfc; $k++) { [BitConverter]::GetBytes([uint16]($Ticks * $Frames.Count)).CopyTo($ramn, $rf + 8*$k + 4) }
for ($k = $rv; $k + 1 -lt $rEnd; $k += 2) { $ramn[$k] = 0; $ramn[$k + 1] = 0 }

for ($k = 0; $k -lt 20; $k++) { [IO.File]::WriteAllBytes((Join-Path $OutDir ("a-0-0-4_{0}.bin" -f ($TargetBase + $k))), (GE $k)) }
function Out($k, $bytes) { [IO.File]::WriteAllBytes((Join-Path $OutDir ("a-0-0-4_{0}.bin" -f ($TargetBase + $o + $k))), $bytes) }
Out 2 $sheet; Out 5 $nanr; Out 6 $rcmn; Out 7 $ramn; Out 8 $cells
$pal = GE 18; $sb = New-Object Drawing.Bitmap 512, 256; $g = [Drawing.Graphics]::FromImage($sb); $g.Clear([Drawing.Color]::FromArgb(255, 200, 230, 200))
for ($i = 0; $i -lt 256*128; $i++) { $bb = $sheet[48 + [Math]::Floor($i/2)]; $c = $(if ($i % 2 -eq 0) { $bb -band 0xF } else { $bb -shr 4 })
    if ($c) { $v = [BitConverter]::ToUInt16($pal, 40 + $c*2); $br = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(255, ($v -band 0x1F)*8, (($v -shr 5) -band 0x1F)*8, (($v -shr 10) -band 0x1F)*8)); $g.FillRectangle($br, ($i % 256)*2, [Math]::Floor($i/256)*2, 2, 2); $br.Dispose() } }
$sb.Save((Join-Path $OutDir 'sheet.png')); $sb.Dispose()
"$($Frames.Count) poses, $($placed.Count) strips + blank = $nCells cells, $maxPieces sequences per pose; lane fill " + ($lanes -join ',')
