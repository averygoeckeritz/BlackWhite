# Balance changes (2026-10-27)

Requested by Avery. All edits are in `a/0/1/6` (species data) and `a/0/1/8` (level-up moves), made with
`tools/patch-bytes.ps1` and `tools/grow-narc-entry.ps1`, and read back with `tools/dump-species-data.ps1`.

## Bouffalant (#626)

| Field | Before (Redux 1.4.1) | After |
| --- | --- | --- |
| Types | Normal | Ground / Flying |
| Abilities | Reckless / Sap Sipper / Soundproof (hidden) | Thick Fat in all three slots |
| Stats HP/Atk/Def/SpA/SpD/Spe | 95/110/95/40/95/55 (490) | 95/105/115/30/100/45 (490) |
| TMs | — | + TM89 U-turn (already had TM26 Earthquake and TM40 Aerial Ace) |
| Level-up | — | + Aerial Ace 22, Roost 36, Earthquake 50 |

Roost has no TM in Redux (TM51 is Wave Crash) and is not a tutor move in B2W2, so it is level-up only.

## Kyurem (#646), White Kyurem (entry 703), Black Kyurem (entry 704)

Snow Warning in all three ability slots (was Pressure; Turboblaze on White, Teravolt on Black). The form
entries are found through Kyurem's species data: u16 at 0x1C = first form entry (703), byte 0x20 = form count (3).

## Mienshao (#620)

Magic Bounce in all three ability slots (was Reckless / Regenerator / Reckless). Mienfoo is unchanged; an
evolved Mienfoo keeps its slot number, so it becomes a Magic Bounce Mienshao either way.
