# Setup: tools and first steps

## Tool: Frost's Gen 5 Editor

One program that covers almost everything this project needs: Pokémon stats, movesets, evolutions,
TMs, tutors and egg moves; move data and move animations (experimental); trainers and teams; wild
encounters; text; Pokémon sprites and icons (experimental); and making a patch.

- Download: [Project Pokemon page](https://projectpokemon.org/home/files/file/5689-frosts-gen-5-editor/)
  (v5.0.1) or [GitHub](https://github.com/FrostFalcon/FrostsGen5Editor)
- Platform: a Windows (.NET) desktop app. On a Mac it needs a Windows virtual machine or a compatibility layer.
- Fully supports Black 2 / White 2, and says it works with ROM hacks.
- Installed on Avery's PC (2026-10-26): `C:\Users\avery\Tools\FrostsGen5Editor\FrostsGen5Editor.exe` (v5.0.1, needs .NET Framework 4.8, which is present).
  The zip also ships `Patches\White2Fairy.Vpatch`; check whether the editor applies it as part of the Fairy fix below.

### Required first step for Redux (Fairy type)

Before any other edit, per the editor's own instructions:

1. Open the **Text editor**, file **398** (the type names list for B2W2).
2. Add **Fairy** to the list of types.
3. Save.

Skipping this can corrupt Fairy-type data when saving other edits.

**Done 2026-10-27** on `rom/White2Redux-Kingambit.nds`. File 398 had 17 entries (Normal … Dark);
Fairy was added as line 17 with no trailing blank line, applied, and the ROM saved. Verified by reopening the
saved file. The bundled `Patches\White2Fairy.Vpatch` was not used: it adds the Fairy type to a vanilla ROM,
and Redux already has it.

Note: the editor trims padding on save, so the working copy is now 289,015,808 bytes instead of 512 MiB.
The editor reloads it fine, and emulators accept trimmed ROMs. The `.xdelta` is still made from the
untouched 512 MiB original, so players patch the same file they already have.

### Editor quirks

- The file-number box in the Text Editor doesn't react to typed numbers. Open the dropdown and click the file,
  or focus the box and use the arrow keys.
- "Save Rom" always opens a Save As dialog; type the working copy's full path and confirm the overwrite.
- Launch the editor from its own folder, or it writes `Preferences.txt` into whatever folder it was started from.

## Working copy

1. Patch a clean **Pokémon White 2** ROM with **Volt White 2 Redux v1.4.1** (the same file you play).
2. Copy it to `White2Redux-Kingambit.nds` and only ever edit the copy.
3. Keep the untouched Redux ROM. The final `.xdelta` patch is made from it to the edited copy.
4. Save often, and keep dated backups of the copy after each step.

Done 2026-10-27. The master copy lives in Google Drive as `My Drive\Pokémon\White 2 Redux.nds`
(mounted as `G:` on Avery's PC). Local copies are in `rom/`, which `.gitignore` excludes:

| File | Role |
| --- | --- |
| `rom/White2Redux-original.nds` | Untouched Redux ROM; the `.xdelta` source. Never edit. |
| `rom/White2Redux-Kingambit.nds` | The working copy that the editor opens. |

Header check: title `POKEMON W2`, game code `IRDO` (White 2, US), 512 MiB.
SHA-256 of the original: `95F34213D26DBEED09C00DD0FE484FEC9A0F19D41B4E6CE5EAED13E5333CA0DC`.

## Kowtow Cleave slot: Clamp (#128)

Clamp never appears in Redux's documentation: no Pokémon's level-up list, no trainer team, no TM, no
move tutor. In the editor, first confirm nothing else uses it (egg moves), then turn it into Kowtow Cleave:

| Field | Value |
| --- | --- |
| Name | Kowtow Cleave (text file for move names) |
| Description | "The user slashes at the target after kowtowing to make the target let down its guard. This attack never misses." |
| Type | Dark |
| Category | Physical |
| Power | 85 |
| Accuracy | Never misses (same value Aerial Ace uses) |
| PP | 10 |
| Effect | Plain damage (remove Clamp's trapping effect) |
| Flags | Makes contact; affected by Protect, King's Rock |
| Animation | Reuse Night Slash's |

Other candidates if Clamp turns out to be used: Ice Ball (#301), Mud Sport (#300), Water Sport (#346).

**Done 2026-10-27.** Before overwriting, a script read the untouched ROM directly and confirmed move 128 appears in
no level-up learnset (710 entries, `a/0/1/8`), no trainer team (891 trainers, `a/0/9/2`) and no egg-move list
(650 species, `a/1/2/4`). Redux had already altered the slot's data (Fire, physical, 110 power, 100 accuracy,
5 PP, effect 27) while leaving the Clamp name and description, so it was an abandoned slot either way.

What was set in the Move Editor, then verified byte-for-byte in the saved ROM (`a/0/2/1`, entry 128):

| Field | Value |
| --- | --- |
| Type / Dmg Type / Category | Dark / Physical / Damage |
| Target | Single Target (same as Night Slash and Aerial Ace) |
| Base Power / Accuracy / PP | 85 / 101 / 10 (101 is the never-miss value Aerial Ace uses) |
| AI Code (effect) | 17, the same always-hit effect Aerial Ace uses |
| Inflictions | None |
| Flags | Makes contact, Affected by Protect, Copied by Mirror Move (Redux's existing flags, kept) |
| Animation | Night Slash's script pasted in via "Apply Anim Data" |
| Name | Kowtow Cleave, text file 403 line 128 |
| Description | "The user slashes at the target after[N]kowtowing to make the target let down[N]its guard. This attack never misses." in text file 402 line 128 |

Editor quirk: the Move Editor's "Set Name" and "Set Description" buttons reported nothing but did not change
the text files. The name and description had to be edited in the Text Editor (files 403 and 402, `[N]` = line break).
The Text Editor's Search button also crashed with "Specified cast is not valid"; the editor survives "Continue".

## How the species step was actually done (2026-10-27)

The Pokemon Editor is usable but fragile: holding Down through 600 species queues one load per key press,
garbles the panels until the queue drains (several minutes), and threw an unhandled "SelectedIndex" exception
once. What worked:

- **Base data** (stats, EV yield, types, abilities, growth, gender, exp, friendship, catch rate, height, weight,
  egg groups) in the Pokemon Editor on Klinklang - 601, then "Apply Pokemon" and "Save Rom". The editable
  dropdowns (Level Rate, Gender Ratio, Egg Groups) must be picked from their lists; typing into them is kept as
  literal text. Verified with `tools/dump-species-data.ps1`.
- **Name, classification and dex entry**: the Pokedex panel's "Apply" changed nothing (same bug as the Move
  Editor's Set Name). Edited in the Text Editor instead: file 90 line 601 (name), file 464 line 601
  (classification), file 442 line 601 (dex entry, `[N]` = line break). Verified with `tools/dump-text.ps1`.
- **Level-up moves and TM/tutor compatibility**: written straight into the saved ROM by
  `tools/patch-kingambit-learnset-tms.ps1` (the editor's Paste button is disabled and the list would have
  needed ~80 clicks). The learnset is rewritten in place and FF-padded; the TM/tutor bytes are Bisharp's plus
  TM91 Flash Cannon. Level 30 got Snarl (Gen 9 has Metal Sound there, which Redux removed).
- **Evolutions**: `tools/patch-evolutions.ps1` (Bisharp: level 61 → 601; Klang: evolution removed).
- **Trainers**: `tools/patch-trainers.ps1` rewrote the three scripted sets. The ROM also has two other
  Klinklang users with no custom moves (trainer ids 135 at lv 77 and 744 at lv 79, likely PWT or similar);
  they become Kingambit automatically and use the last four level-up moves.

Rule when mixing the two: the editor saves from memory, so after any script patch, reload the ROM in the
editor ("Open Rom") before the editor saves again, or the patch is lost. A dated backup goes in
`rom/backups/` after every step.

## Order of work

1. Fairy fix (above).
2. Kowtow Cleave (Clamp slot).
3. Klinklang slot → Kingambit: name, Pokédex text, types, stats, abilities, EV yield, catch rate, growth rate,
   egg group, height/weight, level-up moves, TMs/tutors.
4. Evolutions: Bisharp → Kingambit at 61; remove Klang's evolution.
5. Trainers: Colress ×2 and Ranger Eddie (see the data sheet).
6. Wild: P2 Laboratory shaking grass → Klang lv.68.
7. Sprites: the animated set in `sprites/kingambit/animated/` (fix the shiny back first, see the data sheet),
   palettes, and the party icon. Check whether the editor's sprite tool takes multi-frame input before committing to it.
8. Test, then build the `.xdelta` patch.
