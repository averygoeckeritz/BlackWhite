param([string]$Rom, [int[]]$Entries, [int]$Target)
# Recompresses a/0/0/4 entries optimally (only if they decompress byte-identically and get smaller) until $Target bytes are freed.
Set-Location C:\Users\avery\GitHub\BlackWhite
Add-Type -Path tools\RigAnim.cs
$w = Join-Path $env:TEMP "freesp-$PID"; New-Item -ItemType Directory -Force $w | Out-Null
$freed = 0
foreach ($e in $Entries) {
    if ($freed -ge $Target) { break }
    .\tools\dump-narc-entries.ps1 -Rom $Rom -Narc a/0/0/4 -First $e -Count 1 -OutDir $w | Out-Null
    $orig = [IO.File]::ReadAllBytes("$w\a-0-0-4_$e.bin"); if ($orig.Length -lt 8 -or $orig[0] -ne 0x11) { "skip $e (not LZ11)"; continue }
    $raw = [RigAnim]::Lz($orig); [IO.File]::WriteAllBytes("$w\raw.bin", $raw)
    .\tools\lz11-compress-optimal.ps1 -In "$w\raw.bin" -OutFile "$w\new.bin" -NoPad | Out-Null
    $new = [IO.File]::ReadAllBytes("$w\new.bin")
    if ([Convert]::ToBase64String([RigAnim]::Lz($new)) -ne [Convert]::ToBase64String($raw)) { "skip $e (round trip differs)"; continue }
    if ($new.Length -ge $orig.Length) { "skip $e (no gain)"; continue }
    .\tools\grow-narc-entry.ps1 -Rom $Rom -Narc a/0/0/4 -Entry $e -File "$w\new.bin" -Apply | Out-Null
    $freed += $orig.Length - $new.Length; "entry $e`: $($orig.Length) -> $($new.Length), freed so far $freed"
}
Remove-Item -Recurse -Force $w
"total freed $freed"
