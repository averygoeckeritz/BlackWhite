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
