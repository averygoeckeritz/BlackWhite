param([string]$StaticDir, [string]$OutJson)
# Builds the shared 16-colour palette (index 0 = transparent) for Kingambit from front.png/back.png, plus the
# shiny palette from the front/front-shiny 1:1 map and the dominant back/back-shiny map for back-only colours.
# Colours are rounded through the editor's 15-bit conversion so PNGs can be matched exactly.
Add-Type -AssemblyName System.Drawing
function Pixels($p) { $b = [System.Drawing.Bitmap]::FromFile($p); $o = @{}; for ($y=0;$y -lt $b.Height;$y++){for($x=0;$x -lt $b.Width;$x++){ $c=$b.GetPixel($x,$y); if ($c.A -ne 0) { $o["$x,$y"] = ("{0:X2}{1:X2}{2:X2}" -f $c.R,$c.G,$c.B) } }}; $b.Dispose(); return $o }
$front = Pixels "$StaticDir\front.png"; $frontS = Pixels "$StaticDir\front-shiny.png"; $back = Pixels "$StaticDir\back.png"; $backS = Pixels "$StaticDir\back-shiny.png"
# merge: front 78621F -> 846B22 (both dark gold) so the union fits 15 colours
$merge = @{ "78621F" = "846B22" }
$counts = @{}
foreach ($v in $front.Values) { $k = $(if ($merge[$v]) { $merge[$v] } else { $v }); $counts[$k] = 1 + $(if ($counts[$k]) { $counts[$k] } else { 0 }) }
foreach ($v in $back.Values)  { $k = $(if ($merge[$v]) { $merge[$v] } else { $v }); $counts[$k] = 1 + $(if ($counts[$k]) { $counts[$k] } else { 0 }) }
$colours = $counts.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { $_.Key }
"union colours: $($colours.Count) (must be <= 15)"
if ($colours.Count -gt 15) { throw "too many colours" }
# shiny map: front pixels 1:1; back-only colours by dominant mapping
$map = @{}
foreach ($kv in $front.GetEnumerator()) { $src = $(if ($merge[$kv.Value]) { $merge[$kv.Value] } else { $kv.Value }); $dst = $frontS[$kv.Key]; if (-not $map[$src]) { $map[$src] = @{} }; $map[$src][$dst] = 1 + $(if ($map[$src][$dst]) { $map[$src][$dst] } else { 0 }) }
foreach ($kv in $back.GetEnumerator())  { $src = $(if ($merge[$kv.Value]) { $merge[$kv.Value] } else { $kv.Value }); $dst = $backS[$kv.Key];  if (-not $map[$src]) { $map[$src] = @{} }; if ($front.Values -notcontains $src -or $src -eq "846B22") { $map[$src][$dst] = 1 + $(if ($map[$src][$dst]) { $map[$src][$dst] } else { 0 }) } }
function To555($hex) { $r=[Convert]::ToInt32($hex.Substring(0,2),16); $g=[Convert]::ToInt32($hex.Substring(2,2),16); $b=[Convert]::ToInt32($hex.Substring(4,2),16); return ([Math]::Ceiling($r/8.25) -bor ([Math]::Ceiling($g/8.25) -shl 5) -bor ([Math]::Ceiling($b/8.25) -shl 10)) }
# the editor truncates (C# int cast); PowerShell's [int] rounds, so use Floor
function From555($v) { return ("{0:X2}{1:X2}{2:X2}" -f [int][Math]::Floor(($v -band 0x1F)*8.25), [int][Math]::Floor((($v -shr 5) -band 0x1F)*8.25), [int][Math]::Floor((($v -shr 10) -band 0x1F)*8.25)) }
$pal = @(); $shiny = @(); $i = 1
$entries = @()
foreach ($c in $colours) {
    $best = ($map[$c].GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key
    $v = To555 $c; $vs = To555 $best
    $entries += [ordered]@{ index = $i; src = $c; rgb = (From555 $v); val555 = $v; shinySrc = $best; shinyRgb = (From555 $vs); shinyVal555 = $vs; count = $counts[$c] }
    "{0,2}: {1} -> {2} (0x{3:X4})   shiny {4} -> {5} (0x{6:X4})   {7} px" -f $i, $c, (From555 $v), $v, $best, (From555 $vs), $vs, $counts[$c]
    $i++
}
@{ merge = $merge; entries = $entries } | ConvertTo-Json -Depth 4 | Set-Content -Encoding utf8 $OutJson
"written $OutJson"
