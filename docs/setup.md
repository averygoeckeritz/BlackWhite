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

## How the sprite step was done (2026-10-27)

Gen 5 battle sprites are not frame animations. Each Pokémon has a 256×128 "rig" sheet of body parts; a parts
file (file 8 of the species' 20-file set in `a/0/0/4`) lists each part's rectangle on the sheet and its position,
and the animation file (file 5) cycles part indices and moves them. Klinklang's gears "spin" by cycling four
pre-drawn gears (parts 0–3). There is also a static 96×96 sprite (file 0, stored scrambled as a 64×144 tile sheet)
and one 16-colour palette shared by front and back (files 18/19 for normal/shiny). All of this came from reading
the editor's source on GitHub (`Data/NARCTypes/PokemonSpritesNARC.cs`).

So Kingambit is **static** in battle. What was done, all verified by decoding the saved ROM back to PNG:

1. `tools/gif-frame-to-png.ps1`: frame 0 of each Ghasty001 GIF → `sprites/kingambit/static/`.
2. `tools/build-kingambit-palette.ps1`: one palette for front + back. The union was 16 colours, one too many, so
   the front's dark gold 78621F became the back's 846B22. Shiny palette from the front's 1:1 colour map.
   Values go through the editor's 15-bit rounding so the import PNGs match exactly.
3. `tools/patch-sprite-palette.ps1`: wrote both palettes into the ROM in place (index 0 untouched).
4. `tools/patch-rig-cells.ps1`: parts 0–3 of the front and back rigs became one 96×96 window at sheet (0,0),
   centred on the origin; every other part became an 8×8 window in the empty corner, so it draws nothing.
5. `tools/make-sprite-pngs.ps1`: exact-colour `front.png`, `back.png` and 256×128 rig sheets with the sprite at (0,0).
6. In the editor's Sprite Editor (Pokemon Editor → Sprite Editor): Import Image for Front Sprite, Front Rig,
   Back Sprite and Back Rig, then Save Rom. This is the only sprite step the editor does (LZ11 compression and
   the NARC rebuild).
7. Party icon: first a rough downscale (`tools/make-icon.ps1`), then replaced by CarmaNekko's hand-drawn
   Gen 5-style icon from the Smogon menu-icon pack (`sprites/kingambit/static/icon-smogon.png`, two 32×32
   frames at double size). `tools/make-icon-from-sheet.ps1` halves it, stacks the frames, snaps the 12 colours to
   whichever of the three shared icon palettes fits best (palette 0 won), writes the icon in place into
   `a/0/0/7` and the palette id into arm9.
8. `tools/render-sprites.ps1`: decoded everything back; 0 pixels differ.

**Two-pose idle animation (added later on 2026-10-27).** The gear-spin sequence (sequence 0 of the part
animation, file 5 front / file 14 back) only cycles parts 0,1,2,3 with no transforms, 4 game frames each. So:

- Frame 0 and frame 4 of each GIF (the extreme of the bob, found with `tools/gif-frame-diffs.ps1`) sit side by
  side on the rig sheet at (0,0) and (96,0); `tools/make-sprite-pngs.ps1` builds that sheet when a `*-b.png` exists.
- `tools/patch-rig-cells.ps1 -HostParts 0,1 -HostPartsB 2,3`: parts 0–1 show pose A, parts 2–3 show pose B.
- The 4-frame step would flicker at 15 Hz, so `tools/make-nanr-slow.ps1` rewrites the step durations of
  sequence 0. Uniform 16 (1.07 s) was too fast on the phone and uniform 48 (3.2 s) too slow, so
  `tools/dump-nanr-all.ps1` surveyed real idles: Bisharp 1.63 s, Pawniard 1.37, Lucario 0.90, Scizor 1.05,
  Tyranitar 1.47, Excadrill 2.0, Machamp 4.0, all with eased steps of 1–8 frames. Kingambit went through
  A 40 / B 8 / C 24 / B 8 (1.33 s) and now uses A 52 / B 8 / C 32 / B 8 frames: a 1.67 s breath that rests
  on the base pose, in the 1.5–2 s band next to Bisharp's 1.63 s. (40/12/28/12 and 52/10/32/10 were the first
  choices each time, but the back-sprite file then compressed to 393 bytes with its token count on a flag-byte
  boundary, so it could not fill the 394-byte entry exactly; the /8 patterns were the nearest that fit.) The
  result was recompressed with `tools/lz11-compress-optimal.ps1 -ExactSize` (the greedy one was a few bytes
  too big) and written in place with `tools/patch-narc-entry.ps1`.

**Three poses (later the same day).** The 96-wide frames waste columns, so `tools/make-rig-sheet-poses.ps1` crops
each pose to Kingambit's real width (front 72 px from x=10, back 64 px from x=18) and fits three poses on the
sheet. `tools/patch-rig-cells-poses.ps1` maps parts 0,1,2,3 to poses A,B,C,B with the sprite X offset shifted
to match the crop (-38 front, -30 back), so the bob eases through a middle frame. The poses were first GIF
frames 0, 2 and 4, but frame 4 (the fully crouched extreme) read as too strong a dip, so the sheet now uses
frames 0, 1 and 2: C is the GIF's half-way crouch and B the step before it. Only the sheet PNGs changed; the
cells and the animation file are the same.

Two editor lessons from this step: the editor's loader throws "There was an error in the XML file of language"
(a misleading catch-all) when a compressed sprite entry has unused trailing bytes, so an in-place replacement
must fill the entry exactly (`lz11-compress-optimal.ps1 -ExactSize`); and PowerShell unrolls a List returned from a
function unless you `return ,$list`.

A true rig (body parts with their own motion) would still be a pixel-art and animation project the editor cannot do.

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
