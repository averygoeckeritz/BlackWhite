param([string]$Rom)
# Finds the TM/HM move table (95 TMs + 6 HMs) by searching the whole ROM for the first TM moves, then names them.
$bytes = [IO.File]::ReadAllBytes($Rom)
# Search for TM01..TM03 as u16 little-endian: Hone Claws 468, Dragon Claw 337, Psyshock 473
$pat = [byte[]](0xD4,0x01, 0x51,0x01, 0xD9,0x01)
$hits = @()
for ($i = 0; $i -lt $bytes.Length - 6; $i += 2) {
    if ($bytes[$i] -eq $pat[0] -and $bytes[$i+1] -eq $pat[1] -and $bytes[$i+2] -eq $pat[2] -and $bytes[$i+3] -eq $pat[3] -and $bytes[$i+4] -eq $pat[4] -and $bytes[$i+5] -eq $pat[5]) { $hits += $i }
}
"table candidates at: " + (($hits | ForEach-Object { '0x' + $_.ToString('X') }) -join ', ')
if ($hits.Count -eq 0) { return }
$off = $hits[0]
$ids = @(); for ($k = 0; $k -lt 101; $k++) { $ids += [BitConverter]::ToUInt16($bytes, $off + 2*$k) }
# names from text file 403
$names = & (Join-Path $PSScriptRoot "dump-text.ps1") -Rom $Rom -File 403 -All | Select-Object -Skip 1
$map = @{}; foreach ($l in $names) { if ($l -match '^\s*(\d+): (.*)$') { $map[[int]$matches[1]] = $matches[2] } }
for ($k = 0; $k -lt 101; $k++) {
    # arm9 table order is TM01-92, HM01-06, TM93-95; the personal-data bitfield order is TM01-95, HM01-06
    $label = if ($k -lt 92) { "TM{0:D2} (bit {1})" -f ($k+1), ($k+1) } elseif ($k -lt 98) { "HM{0:D2} (bit {1})" -f ($k-91), ($k+4) } else { "TM{0:D2} (bit {1})" -f ($k-5), ($k-5) }
    "{0}  move {1,3}  {2}" -f $label, $ids[$k], $map[[int]$ids[$k]]
}
