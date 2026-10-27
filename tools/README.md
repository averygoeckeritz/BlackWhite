# ROM-reading scripts

Small PowerShell scripts that read a Black 2 / White 2 `.nds` directly (NitroFS + NARC parsing, no extraction)
to check facts the editor can't show in bulk. Run them from any folder; they only read the ROM.

| Script | What it does |
| --- | --- |
| `find-move-usage.ps1 -Rom <file> -MoveId <n>` | Lists every species whose level-up learnset (`a/0/1/8`) and every trainer Pokémon (`a/0/9/2`) that has move `n`. |
| `find-move-usage-eggs-tms.ps1 -Rom <file> -MoveId <n>` | Same for egg moves (`a/1/2/4`), then scans arm9 and the overlays for the TM/HM table. The TM scan is slow (tens of minutes). |
| `dump-move-data.ps1 -Rom <file> -Ids 128,332,400` | Prints the raw 36-byte move-data entries from `a/0/2/1` with type, power, accuracy, PP and effect decoded. |

Example, from the repo root:

```powershell
.\tools\find-move-usage.ps1 -Rom .\rom\White2Redux-original.nds -MoveId 128
```

Used on 2026-10-27 to confirm the Clamp slot (#128) was unused before it became Kowtow Cleave.
