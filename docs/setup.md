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

**More movement: A B A B A B C B (later still).** With the dip softened the idle read as too still, so the
sequence itself was rewritten with `tools/make-nanr-pattern.ps1`: three small A→B flicks (20 + 8 frames each)
and then the C settle (20) with its B return (8), 112 frames = 1.87 s per loop. The front sequence keeps its 32
steps (the pattern cycled four times); the back sequence had only 4 steps and had to grow to 8, and the
longer file compresses to 398 bytes, four more than its 394-byte entry. `tools/grow-narc-entry.ps1` rewrites
the NARC in place (later entries shift, the BTAF table, block sizes and the ROM FAT end are fixed up) using
the padding that follows the archive in the ROM (374 bytes of slack after `a/0/0/4`). Pattern and durations
are both free now, so later tweaks are a script run, not an editor session.

**Slow breath (current).** The 8-frame flicks read as twitches, so the idle is now one breath and a long rest:
A 74 / B 14 / C 18 / B 14 frames = 120 frames = 2.0 s per loop, with 1.23 s of rest on the base pose. The back
sequence went back to 4 steps (395-byte entry, written with `grow-narc-entry.ps1`); the front keeps 32 steps.

**Fourth pose, the full dip (current).** Avery wanted the GIF's deepest frame back as a fourth pose D after a quiet
breath: A B C B C D C B at A 70 / B 14 / C 16 / B 14 / C 14 / D 20 / C 14 / B 14 frames = 176 frames = 2.93 s.
Poses are GIF frames 0, 1, 2 and 4. The back fits four 64-wide columns on the 256-wide sheet. The front's 72-wide
poses only fit three columns, so D goes into the unused 32-row strip under them as three 72x32 bands
(`make-rig-sheet-poses.ps1 -BandPose`). A rig part is a single textured quad and a sequence frame shows one part,
so D is three parts (3, 5, 7) driven by three sequences in step: sequence 0 shows A/B/C/D-top, sequence 1 shows
D-middle (part 5) only during the D step and the blank corner window (part 4) otherwise, sequence 2 the same with
D-bottom (7) and blank (6). All three have identical step durations, so they stay locked. Parts come from an
explicit list now (`patch-rig-cells-spec.ps1`: x, y of the quad's top-left relative to its pivot, Y up, width,
height, sheet u, v); the three band quads sit at y 48, 16 and -16. The first try drew the bands from three
different pivots: the cell file holds only the quad's offset from its pivot, and each *sequence's* pivot comes
from the RCMN file (file 6 front / 15 back, "KBCM" block: 18 entries of u16 sequence, s16 x, s16 y, u8 flags,
u8 order; sequence 0 of the old Klinklang rig sits at (0,-40), its gear sequences elsewhere). Setting sequences
1 and 2 to (0,-40) as well (`patch-bytes.ps1` on entry 12026) lines the bands up. The editor opens the ROM fine
after the in-place NARC rewrites.

## Cry

Gen 5 cries live in `swan_sound_data.sdat` (NitroFS file 346): one SWAR per Pokémon, `WAVE_ARC_PVnnn` (SWAR
index nnn, found through the SYMB and INFO blocks), holding a single SWAV of signed 8-bit PCM, no loop, played
through `BANK_PVnnn` and the shared `SEQ_PV`. Klinklang's is 10512 Hz, 21628 bytes (2.06 s); Bisharp's is
22050 Hz, 0.8 s. The SDAT packs its files back to back, so the replacement must fit the old data area.
Kingambit's official cry (PokeAPI `cries/pokemon/latest/983.ogg`, 2.0 s at 48 kHz; its energy is gone by 1.7 s)
was trimmed to 1.70 s with a 150 ms fade, given +0.6 dB (peak 121/127, nothing clipped) and resampled to mono
signed 8-bit at 12700 Hz with ffmpeg (`-f s8`), 21590 bytes. `tools/patch-cry.ps1` writes it in place: new rate,
ARM7 timer value floor(16756991 / rate) and length in words in the SWAV header, data zero-padded to the old
size. The bank and sequence are untouched. ffmpeg came from `winget install Gyan.FFmpeg`.

Two editor lessons from this step: the editor's loader throws "There was an error in the XML file of language"
(a misleading catch-all) when a compressed sprite entry has unused trailing bytes, so an in-place replacement
must fill the entry exactly (`lz11-compress-optimal.ps1 -ExactSize`); and PowerShell unrolls a List returned from a
function unless you `return ,$list`.

A true rig (body parts with their own motion) would still be a pixel-art and animation project the editor cannot do.

Rule when mixing the two: the editor saves from memory, so after any script patch, reload the ROM in the
editor ("Open Rom") before the editor saves again, or the patch is lost. A dated backup goes in
`rom/backups/` after every step.

## Project 2: Hisuian Zoroark in Durant's slot (2026-10-27)

Same recipe as Kingambit, scripted end to end except the four image imports. Slot 632 (Durant) was Avery's
pick; `tools/survey-species-usage.ps1` ranks slots by trainer and wild use if another is ever needed.

1. Usage: `find-encounters.ps1` (a/1/2/7 only; a/1/2/6 hits are false positives from another table) and the
   trainer part of `find-species-usage.ps1`: 26 wild slots and 5 trainer Pokémon, all moved to Escavalier (588)
   with `patch-encounter.ps1` / `patch-bytes.ps1` (trainer entry species u16 at slot*size+4).
2. Species data: Zoroark's 76 bytes copied onto 632 with stats 55/100/60/110/125/60, Normal/Ghost, abilities
   23 (Shadow Tag) / 0 / 149 (Illusion), weight 730, plus TM61; EV yield left at Redux's 0.
3. Learnset: Scarlet/Violet level-up list from PokeAPI mapped to Gen 5 move ids by name (`dump-text.ps1` file
   403); Bitter Malice has no Gen 5 move, so Hex (506) at 46. Written with `grow-narc-entry.ps1` on a/0/1/8.
4. Evolution: Zorua (a/0/1/9 entry 570) slot 2 = method 8 (use item), 108 (Dusk Stone), 632. Durant's entry is
   empty already.
5. Text: `tools/patch-text.ps1` rebuilds a text file with changed lines and writes it back through
   `grow-narc-entry.ps1` (a round-trip self-test proved the writer byte-exact on files 90, 464 and 442 first).
   Name "H-Zoroark" (file 90), "Baneful Fox Pokémon" (464), a new dex entry (442). a/0/0/2 had only 34 bytes of
   slack in the ROM; 16 remain, so future text edits should stay the same length or shorter.
6. Sprites: Showdown's Gen 5-style static front/back/shinies (96x96, 15/14 colours) and the gen5ani front GIF
   (72x77, 24 frames of a 2.4 s hair sway; placed at (12,5) in a 96x96 frame). Palette from
   `build-kingambit-palette.ps1 -Merge "251415=101010"` (a GIF-only near-black folded into black; the union was
   16). Poses are GIF frames 0, 4, 8 and 12: three 72-px columns plus frame 12 as the banded fourth pose,
   sequence A B C D C B at 24 frames each (2.4 s, the GIF's own period). The back has no animated source, so its
   rig is one pose and a one-frame sequence. Durant's own rig animates with translations and rotations
   (types 1/2), which `make-nanr-pattern.ps1` cannot reuse, so `tools/rebuild-nanr.ps1` writes every sequence
   fresh from a spec (blank cell for the rest, LABL/UEXT kept). `patch-rig-cells-spec.ps1` for the parts
   (front X -36, back X -32). The cell file's header (after the part count: u16 width, u16 height, s16 x, s16 y
   of the whole sprite) was raised from Durant's 59x37 to 72x96.
   The first build froze the game at "A wild H-Zo…": bisected in the test ROM (original cry, then original
   rig files, then one file at a time) to the RCMN pivot table. Durant's table has no entry for sequence 1 and
   my earlier "id or draw-order" match had overwritten a header field. Lesson: the first u16 of an RCMN entry
   IS the sequence index (the trailing byte is draw order) and only sequences listed there are drawn. So the
   three D bands now ride on sequences 0, 2 and 3, and only those entries (plus back sequence 0) were moved
   to (0,-40).
   RCMN layout, read properly later: block "KBCM", u16 multi-cell count at 0x18, then 8-byte multi-cell headers
   at 0x2C (u16 entries, u16 entries, u32 offset from 0x3C), then the 8-byte entries from 0x3C. Klinklang has one
   multi-cell; Durant has two, and its RAMN (file 7 front / 16 back) loops multi-cell 0 for 78 + 78 frames, then
   multi-cell 1 (a blink set on sequences 12-23) for 74 frames. Those sequences were blanked, so on the phone the
   sprite vanished for 1.2 s every 3.8 s. Fix: the RAMN's third frame now points at multi-cell 0 too
   (`patch-bytes.ps1` offset 0x50 = 0 on entries 12647 and 12656).
   It also floated: the Showdown sprites stand with their feet on row 81 of the 96 frame, Kingambit's on 92 (94
   back), and both use the same pivot. The front parts were lowered 11 px (Y 37 / 5 / -27) and the back 13 px
   (Y 35), so the feet sit where Kingambit's do. Checked in melonDS: grounded, no gaps over two blink periods.
   Back idle (2026-10-28): no animated back exists (Showdown's gen5ani-back has only Unovan Zoroark; PokeAPI
   and Ghasty001 have none), so `tools/make-sway-poses.ps1` builds poses from the still back: rows below 58
   stay planted, the body above is squashed down by up to 2 px with nearest-neighbour row sampling (no seam),
   and the tufts above row 40 lean up to 2 px. Poses squash/sway 0/0, 1/1, 2/2 in three 72-px columns of the
   back rig, sequence 0 = A B C B at 48/24/48/24 frames, the same 2.4 s as the front. On the phone the planted
   legs looked wrong (only the top moved), so the whole sprite now also moves with the bend: parts 0/1/2 sit at
   X -32/-31/-30, Y 35/34/33 (1 px right and down per step). Legs move 2 px, the head and mane up to 4 px.
   Matched to the front (2026-10-28): the front's poses drop the top of the sprite 0/1/4/5 px (rows 8/9/12/13)
   with the upper body leaning about 2-4 px, feet planted, in A B C D C B at 24 frames each. The back now does
   the same: `make-sway-poses.ps1 -Split 80 -Cut 58 -Poses "0:0;1:2;3:2"` (the squash runs down through the legs
   and the lean through the whole mane), and D reuses C's image one step lower through a fourth cell
   (part 3), so no banded pose or RCMN change was needed. Parts 0-3: X -32/-32/-31/-30, Y 35/35/34/33, U 0/72/
   144/144; sequence 0 = parts 0 1 2 3 2 1 at 24 frames (2.4 s). Top of the back sprite: rows 4/5/8/9.
   The sheet went in with `tools/write-rig-sheet.ps1` (decompress, replace the 4bpp pixels, recompress, grow the
   entry) instead of the editor; `lz11-compress-optimal.ps1`'s match search is now compiled C# (the PowerShell
   loop took over 10 minutes on a 16 KB sheet, now about 40 s overall).
   Planted feet and ground alignment (2026-10-28, Avery: feet should not move and should sit centred on the
   grass circle). Four real poses now, squash/lean 0:0, 1:2, 4:3, 5:4 (rows 73 and down are identical in all
   four), with D banded under the columns exactly like the front: parts 3/5/7 = D rows 0-31/32-63/64-95 at
   Y 42/10/-22, driven by sequences 0/1/2 (`0=0,1,2,3,2,1;1=4,4,4,5,4,4;2=6,6,6,7,6,6` at 24 frames, blank 4);
   the back RCMN entries for sequences 1 and 2 (offsets 0x4C and 0x54) were moved to (0,-40) like sequence 0.
   Where "on the ground" is: `tools/render-rig-composite.ps1` assembles a rig the way the game does (cell Y is
   Y-up, the RCMN offset and frame translation are screen-down; type-1 frame values are u16 cell, u16 rotation,
   s32 scale X/Y, s16 x/y, which `dump-nanr.ps1` had read at the wrong offsets). Every vanilla back and front
   checked (Zoroark, Lucario, Houndoom, Arcanine, Stoutland, Liepard, Sawsbuck, ...) ends its feet exactly on
   the sprite origin, the centre of the grass circle. H-Zoroark's back was 7 px low and 3 px left, its front
   5 px low: back cells now X -29 Y 42 (feet centred on the origin), front cells Y 42/42/42/42/10/-22. Kingambit
   is still 8 px (back) / 5 px (front) below the origin; left as Avery approved it.
   The bigger sheet did not fit: a/0/0/4 had 93 bytes of slack. First attempt: `tools/move-file-to-end.ps1`
   moved the whole NARC to the end of the ROM (0x113A5E00, header used size and CRC rewritten). That ran in
   melonDS on the PC (fresh boot, and a save state from the previous build), but on Avery's phone (Delta) the
   screen went white as soon as a battle started loading sprites. So do NOT relocate files for the release.
   What shipped instead: the NARC stays in place and space comes from recompressing 15 sprite entries with
   `lz11-compress-optimal.ps1` (each checked to decompress byte-identically): Kingambit 12020/12022/12029/12031,
   H-Zoroark 12640/12642/12649, and the rig sheets 12862/12871/12882/12891/12902/12911/12922/12931 of species
   643-646. That freed 1927 bytes; after the new sheet and NANR about 860 bytes of slack remain. The ROM keeps
   its 289,020,416-byte size and untouched header, like every build tested on the phone. The X build still
   empties Rayquaza's front sheet (7682) for the Oshawott swap.
   To see a back sprite in melonDS without catching one, a throwaway ROM copy swapped H-Zoroark's back files
   (9, 11, 13-18) into the starter's slot; a/0/0/4 has little slack, so the starter's front sheet and static
   sprite were emptied in that copy first. melonDS needs a .sav named like the ROM.
   For Avery's phone test the same swap went into the X build itself (test ROM only, never the release): space
   came from Rayquaza's front sheet (file 7682, emptied) instead of the starter's, so Oshawott keeps its front
   sprite, though with H-Zoroark's palette, since file 18 is shared by front and back.
   Order matters: `patch-sprite-palette.ps1` must run BEFORE the editor import, because the editor maps the
   PNG onto the palette already in the ROM (with Durant's palette the import came out blank).
   Zoroark's own animation (2026-10-29, Avery: copy Unovan Zoroark's movement, front and back). The pose-based
   rigs above were replaced by Zoroark's rig: its NANR, RAMN and RCMN (files 5-7 / 14-16 of species 571) drive
   H-Zoroark's still sprites cut into parts. Zoroark's idle is 12-14 parts each rotating about its own pivot
   (type-1 frames), two multi-cells: the RAMN plays multi-cell 1 (the big 2 s motion, 21-frame sequences) for
   120 frames, then multi-cell 0 (the 1 s breath) three times for 60. `tools/render-rig-anim.ps1` plays a rig
   like the game (core in `tools/RigAnim.cs`); its rotation sign was settled against Showdown's recording of
   Zoroark (gen5ani), which it matches frame for frame. `tools/build-rig-from-parts.ps1` does the re-skin from
   `sprites/zoroark-hisui/rig/front-parts.json` / `back-parts.json`: polygons pick each part's pixels, every
   part gets Zoroark cell numbers, a pivot and a draw order, and a few pixels of underpaint (nearest own colour)
   beneath the parts drawn over it so no holes open when they move. Mapping, front: head + mane + ponytail =
   Zoroark's head (cell 0), hanging left hair = its big mane (1), the side hair = its left arm (6), the raised
   arm's tip = its swinging arm (8/9), the right-leg tendrils = its tail (2, with the tail's drift dropped so they
   stay attached), collar (3), torso (5), legs (10/11) and still feet (12/13). Back: head (0) and the big mane (1)
   bow together as Zoroark's do, the spiky fur on the left leg = its tail (2, drift dropped), torso (4), legs
   (8/9), still feet (10/11). Parts moved over the middle of the body smeared (no real art behind them), so
   moving parts were kept at the edges. Zoroark cells left unused point at an empty 8x8 corner of the sheet.
   The packed sheets are smaller than the four-pose ones, so the whole change shrank a/0/0/4 by 1010 bytes. The
   ground placement is unchanged (feet bottom on the origin, centre 2.5 front / 0 back).
   On the phone the rotated parts did not look right (rotating detailed pixel art scrambles it), and a custom
   lunge (head down/forward, arm swinging out) did not either. Rework (2026-10-29): the still sprites stay the
   baseline and nothing rotates. Zoroark's rhythm is kept through its RAMN: breath (multi-cell 1, 2 s), three
   flicks (multi-cell 0, 1 s each), breath, two flicks, 9 s in all, as Avery read it off the GIF. The motion is
   written by `build-rig-from-parts.ps1`'s `motion.mcs` (one block per multi-cell, whole-pixel x/y only): the
   sprite is cut into horizontal bands plus the arm, hair, tendrils and a still base (legs and feet). Breath: the
   bands sink 4/4/3/3/2/1 px from the top down (a crouch). Flick: the bands shear forward 4/3/2/1/1 px (head tilt
   and mane flick) while the arm moves out 2 px and up 1. Back: the same, mirrored, with the hanging mane and
   the fur on the left leg instead of the arm.
7. Icon: Smogon pack ZOROARK_1 (the Hisuian one) via `make-icon-from-sheet.ps1` (palette 1 fit best).
8. Cry: PokeAPI 10239.ogg (1.38 s, silent after 1.2 s) trimmed to 1.25 s, +1.2 dB, 8-bit 16600 Hz = 20750
   bytes into Durant's 20768-byte slot with `patch-cry.ps1`.

Editor quirks met this time: the Sprite Editor's dropdown list rows sit about 20 px higher than the gap the
first rows suggest (verify the selected item with a zoom before importing), and importing a 256x128 sheet into
a 96x96 slot gives a modal "Sprite size should be 96 x 96" box that swallows later clicks until dismissed.
PowerShell trap, now hit five times: a variable named like a `[string]` parameter (`$raw`/`$Raw`, `$spec`,
`$merge`) silently turns the value into a string.

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
