# White 2 Redux mods

Changes to **Pokémon Volt White 2 Redux v1.4.1** (Drayano & AphexCubed) for personal play.
Game files (`.nds`) are never committed here. The finished result is shipped as a patch
(`.xdelta`) to apply on top of a patched Volt White 2 Redux ROM.

## Project 1: Kingambit replaces Klinklang

Kingambit (Gen 9) takes over Klinklang's slot (#601), as close to Gen 9 as the Gen 5 engine allows,
and becomes Bisharp's evolution.

- Data sheet: [`data/kingambit.md`](data/kingambit.md)
- Sprites: [`sprites/kingambit/`](sprites/kingambit/)
- Tools and step-by-step order: [`docs/setup.md`](docs/setup.md)

### Status

- [x] Gen 9 data collected and mapped to what exists in Redux
- [x] Gen 5-style sprite found (front, shiny; 96×96, 15 colours + transparency)
- [x] Animated Gen 5-style set found (front, back, both shinies; 96×96) from Ghasty001, now the primary sprite source
- [x] Decisions: Bisharp evolves at level 61, Klang stops evolving, Colress/Eddie use Kingambit, P2 Lab gets Klang
- [x] Tool chosen: Frost's Gen 5 Editor (supports Redux); Kowtow Cleave slot: Clamp
- [x] Install the editor on a computer and do the Fairy-type fix (2026-10-27)
- [x] Edit species data, learnset, TMs, evolution, name and Pokédex text (2026-10-27, byte-verified)
- [x] Kowtow Cleave: rebuild Clamp (#128) as Kowtow Cleave (2026-10-27)
- [x] Import sprites and palettes (2026-10-27: front/back/shinies with a three-pose slow-breath idle animation (A B C B, 2.0 s with a long rest), and the party icon; see `docs/setup.md`)
- [x] Fix trainers and wild encounters that used Klinklang (2026-10-27)
- [x] Kingambit's own cry in Klinklang's slot (2026-10-27): the official cry from the PokeAPI cries archive, trimmed
      to 1.7 s and resampled to 8-bit 12.7 kHz to fit the slot; see `docs/setup.md`
- [x] Boot test in melonDS (2026-10-27): the edited ROM loads, plays the intro and reaches the overworld
- [x] In-game check of Kingambit (2026-10-27): wild Kingambit battles on Route 19 in melonDS and in Delta on the phone
      (sprite, icon, idle animation). A test ROM with Kingambit in Route 19's grass is at
      `rom/White2Redux-Kingambit-TEST.nds` (not for release). The finished ROM lives in Google Drive as
      `My Drive\Pokémon\White 2 Redux Ultra.nds`
- [x] Make the patch (2026-10-27): `patch/White2Redux-Kingambit.bps`, built with `tools/bps.ps1` and verified by
      applying it back onto the untouched ROM (identical SHA-256). Apply it with
      [Rom Patcher JS](https://www.marcrobledo.com/RomPatcher.js/) on a Volt White 2 Redux v1.4.1 ROM. The xdelta
      format was dropped: no xdelta tool could be installed here. `patch/*.Vpatch` is the editor's own format.
- [ ] Stretch, after the patch ships: Supreme Overlord as a new ability (needs battle-engine ASM; no editor support)

### Credits

- Volt White 2 Redux: Drayano & AphexCubed
- Animated Gen 5-style Kingambit sprites (front, back, shinies): [Ghasty001](https://github.com/Ghasty001/Animated_sprites_by_Ghasty001),
  free to use with credit; base Kingambit art by Anarlaurendil (DeviantArt)
- Static Gen 5-style Kingambit sprites (fallback): Smogon Sprite Project, via Pokémon Showdown
- Party icon: CarmaNekko (Gen 9 Sprite Project), from the Smogon
  [Gen 3/4/5-style menu icons for Gen 6+ Pokémon](https://www.smogon.com/forums/threads/gen-3-4-5-style-menu-icons-for-gen-6-pok%C3%A9mon.3710134/)
  pack organised by KRLW890; free for non-profit use with credit
- Data: PokeAPI
