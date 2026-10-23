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
- [x] Decisions: Bisharp evolves at level 61, Klang stops evolving, Colress/Eddie use Kingambit, P2 Lab gets Klang
- [x] Tool chosen: Frost's Gen 5 Editor (supports Redux); Kowtow Cleave slot: Clamp
- [ ] Install the editor on a computer and do the Fairy-type fix
- [ ] Edit species data, learnset, TMs, evolution, name and Pokédex text
- [ ] Kowtow Cleave: rebuild Clamp (#128) as Kowtow Cleave
- [ ] Import sprites and palettes
- [ ] Fix trainers and wild encounters that used Klinklang
- [ ] Test in an emulator, then in Delta
- [ ] Make the `.xdelta` patch

### Credits

- Volt White 2 Redux: Drayano & AphexCubed
- Gen 5-style Kingambit sprites: Smogon Sprite Project, via Pokémon Showdown
- Data: PokeAPI
