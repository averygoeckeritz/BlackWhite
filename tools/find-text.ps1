param([string]$Rom, [string]$Pattern, [string]$Narc = "a/0/0/2", [int]$MaxFile = 500)
# Searches every text file in a text NARC for a regex and prints file:line: text.
$dump = Join-Path $PSScriptRoot "dump-text.ps1"
for ($f = 0; $f -le $MaxFile; $f++) {
    try { $lines = & $dump -Rom $Rom -Narc $Narc -File $f -All 2>$null } catch { continue }
    foreach ($l in $lines) { if ($l -match '^\s*(\d+): (.*)$' -and $matches[2] -match $Pattern) { "file {0,3} line {1,4}: {2}" -f $f, $matches[1], $matches[2] } }
}
