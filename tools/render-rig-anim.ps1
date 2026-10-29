param([string]$Rom, [int]$Species = 632, [string]$Dir, [int]$Base = -1, [switch]$Back, [string]$OutDir,
      [double]$Seconds = 8, [int]$Step = 2, [int]$Zoom = 3, [int]$RotSign = 1, [string]$Name = 'anim', [int]$Mc = -1)
# Plays a battle sprite rig the way the game does and writes an animated GIF of it (frames kept as PNGs):
# the RAMN (file 7 / 16) picks the multi-cell over time, each RCMN entry of that multi-cell plays its NANR sequence
# from the moment the multi-cell starts, and every frame's cell is placed at RCMN (x,y) + frame (x,y), rotated and
# scaled about that point (type 1: u16 cell, u16 rotation /65536, s32 scale X/Y 0x1000 = 1, s16 x, s16 y; type 2:
# cell, x at +4, y at +6). Cell rect: X..X+W right of the pivot, -Y..-Y+H below it (cell Y is Y-up).
# Source: -Rom/-Species (dumped to a temp folder) or -Dir/-Base, a folder of raw a/0/0/4 entries named
# a-0-0-4_<n>.bin (base = species*20), so a rig can be previewed before it goes into the ROM. -Mc forces one
# multi-cell. Needs ffmpeg (winget Gyan.FFmpeg) for the GIF.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
if (-not ('RigAnim' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'RigAnim.cs') }
New-Item -ItemType Directory -Force $OutDir | Out-Null
if ($Rom) { $Dir = Join-Path $OutDir 'raw'; $Base = $Species * 20; & "$PSScriptRoot\dump-narc-entries.ps1" -Rom $Rom -Narc a/0/0/4 -First $Base -Count 20 -OutDir $Dir | Out-Null }
$o = $(if ($Back) { 9 } else { 0 })
function E($k) { return ,[IO.File]::ReadAllBytes((Join-Path $Dir ("a-0-0-4_{0}.bin" -f ($Base + $k)))) }
# only the sheet and the NANR can be LZ11 (or raw, from build-rig-from-parts.ps1); a cell file with 17 cells also
# starts with 0x11, so nothing else goes through Unpack
$sheet = [RigAnim]::Unpack((E ($o + 2))); $nanr = [RigAnim]::Unpack((E ($o + 5))); $rcmn = E ($o + 6); $ramn = E ($o + 7); $cells = E ($o + 8); $pal = E 18
$argb = New-Object int[] 16; for ($i = 0; $i -lt 16; $i++) { $v = [BitConverter]::ToUInt16($pal, 40 + $i*2); $argb[$i] = [Drawing.Color]::FromArgb(255, ($v -band 0x1F)*8, (($v -shr 5) -band 0x1F)*8, (($v -shr 10) -band 0x1F)*8).ToArgb() }
$S = 112; $ox = 56; $oy = 100
$fdir = Join-Path $OutDir "$Name-frames"; New-Item -ItemType Directory -Force $fdir | Out-Null
Get-ChildItem $fdir -Filter *.png | ForEach-Object { [IO.File]::Delete($_.FullName) }
$total = [int]($Seconds * 60); $k = 0
for ($T = 0; $T -lt $total; $T += $Step) {
    $local = 0; $mcNow = $(if ($Mc -ge 0) { $local = $T; $Mc } else { [RigAnim]::McAt($ramn, $T, [ref]$local) })
    $buf = [RigAnim]::Frame($sheet, $nanr, $rcmn, $cells, $mcNow, $local, $S, $ox, $oy, $RotSign)
    $px = [RigAnim]::Argb($buf, $argb, $S, $Zoom, $ox, $oy)
    $bm = New-Object Drawing.Bitmap ($S*$Zoom), ($S*$Zoom), ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $bd = $bm.LockBits((New-Object Drawing.Rectangle 0, 0, ($S*$Zoom), ($S*$Zoom)), 'WriteOnly', ([Drawing.Imaging.PixelFormat]::Format32bppArgb))
    [Runtime.InteropServices.Marshal]::Copy($px, 0, $bd.Scan0, $px.Length); $bm.UnlockBits($bd)
    $bm.Save((Join-Path $fdir ('f{0:D4}.png' -f $k))); $bm.Dispose(); $k++
}
$ff = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter ffmpeg.exe -ErrorAction SilentlyContinue | Select-Object -First 1
$gif = Join-Path $OutDir "$Name.gif"
& $ff.FullName -loglevel error -y -framerate (60 / $Step) -i (Join-Path $fdir 'f%04d.png') -vf "split[a][b];[a]palettegen[p];[b][p]paletteuse" $gif
"$k frames -> $gif"
