# Kingambit (replacing Klinklang, #601)

Target: Gen 9 Kingambit, adapted to the Volt White 2 Redux v1.4.1 engine and move pool.
Source data: PokeAPI (Scarlet/Violet learnset in [`kingambit-gen9-learnset.json`](kingambit-gen9-learnset.json)).

## Species data

| Field | Value |
| --- | --- |
| Name | Kingambit |
| Classification | Big Blade Pokémon |
| Type | Dark / Steel |
| Base stats | 100 HP / 135 Atk / 120 Def / 60 SpA / 85 SpD / 50 Spe (550) |
| EV yield | 3 Attack |
| Abilities | Defiant / Pressure. Decided 2026-10-27: Supreme Overlord is a stretch goal for after the patch ships, since it needs new battle-engine ASM, not editor data. |
| Catch rate | 25 |
| Base experience | 275 |
| Base happiness | 50 |
| Growth rate | Medium Fast |
| Egg group | Human-Like |
| Gender | 50% male / 50% female |
| Egg cycles | 20 |
| Height / weight | 2.0 m / 120.0 kg |
| Pokédex text | "Though it commands a massive army in battle, it's not skilled at devising complex strategies. It just uses brute strength to keep pushing." (Violet) |

## Evolution

- **Bisharp → Kingambit at level 61** (chosen). A standard Gen 5 level-up evolution, no code changes needed.
  (Gen 9's real method, defeating three Bisharp holding a Leader's Crest, can't be done in Gen 5.)
- **Klang stops evolving** (chosen). Its level-49 evolution into slot #601 is removed, so Klang is the end of its line.

## Level-up moves

Gen 9 list, with the two moves that don't exist in Redux handled:

| Level | Move | Note |
| --- | --- | --- |
| Evolve | **Kowtow Cleave** | New move, see below |
| 1 | Fury Cutter, Leer, Metal Burst, Metal Claw, Scratch | |
| 15 | Torment | |
| 20 | Scary Face | |
| 25 | Assurance | |
| 30 | ~~Metal Sound~~ → **Iron Defense** moved earlier, or Snarl | Redux replaced Metal Sound with Scorching Sands |
| 35 | Slash | |
| 40 | Night Slash | |
| 45 | Iron Defense | |
| 50 | Retaliate | |
| 57 | Iron Head | |
| 64 | Swords Dance | |
| 71 | Guillotine | |

Gen 5 can't teach a move "on evolution", so Kowtow Cleave goes at level 1 *and* at the evolution level.

## Kowtow Cleave

Gen 9: Dark, Physical, 85 power, never misses, 10 PP, makes contact.

Gen 5 has no slot for a new move, so copy these values onto a move slot that nothing in Redux uses,
then rename it. **Slot: Clamp (#128)**, which nothing in Redux uses (see [`../docs/setup.md`](../docs/setup.md)).
Effect: plain damage; accuracy: the "always hits" value Aerial Ace uses; animation: Night Slash's.

## TM compatibility

All of Kingambit's Gen 9 TMs that exist in Redux (set compatibility by move name in the editor,
since Redux changed some TM numbers):

Aerial Ace, Air Slash, Brick Break, Dark Pulse, Dig, Endure, Facade, False Swipe, Flash Cannon, Fling,
Focus Blast, Foul Play, Giga Impact, Grass Knot, Hyper Beam, Iron Defense, Iron Head, Low Kick, Low Sweep,
Metal Claw, Poison Jab, Protect, Rain Dance, Rest, Reversal, Rock Tomb, Sandstorm, Scary Face, Shadow Claw,
Sleep Talk, Snarl, Spite, Stealth Rock, Stone Edge, Substitute, Swords Dance, Take Down, Taunt, Thief,
Thunder Wave, X-Scissor, Zen Headbutt.

Not available in Redux: Lash Out, Steel Beam, Throat Chop, Tera Blast (Gen 7+) and Metal Sound (removed).
Gen 5-only TMs Bisharp can learn (e.g. Return, Frustration, Hidden Power, Payback, Embargo) should carry over too.

## Things in Redux that use Klinklang

| Where | Was | Becomes (chosen) |
| --- | --- | --- |
| Colress, Plasma Frigate | Klinklang lv.66 @Life Orb: Gear Grind, Shift Gear, Wild Charge, High Horsepower | **Kingambit** [Defiant] lv.66 @Life Orb: Kowtow Cleave, Iron Head, Sucker Punch, Swords Dance |
| Ranger♂ Eddie | Klinklang lv.70: Shift Gear, Superpower, Gear Grind, Wild Charge | **Kingambit** [Defiant] lv.70: Kowtow Cleave, Iron Head, Sucker Punch, Brick Break |
| Colress (postgame) | Klinklang lv.88: Gear Grind, Shift Gear, Wild Charge, Superpower | **Kingambit** [Defiant] lv.88: Kowtow Cleave, Iron Head, Sucker Punch, Swords Dance |
| P2 Laboratory, shaking grass | Klinklang lv.68, 5% | **Klang** lv.68, 5% |

Sucker Punch comes from Bisharp's Redux level-up list (level 55), so it's a move Kingambit can legitimately have.

## Sprites

### Primary: animated set by Ghasty001

[`../sprites/kingambit/animated/`](../sprites/kingambit/animated/), from
[Animated_sprites_by_Ghasty001](https://github.com/Ghasty001/Animated_sprites_by_Ghasty001) (free to use with credit;
base art by Anarlaurendil). All four are 96×96 GIFs with transparency and a 0.12 s frame delay. Inspected 2026-10-27:

| File | Frames | Opaque colours | Fits 16-colour palette? | Shiny is a pure palette swap? |
| --- | --- | --- | --- | --- |
| `front.gif` | 42 | 14 | Yes | — |
| `front-shiny.gif` | 42 | 14 | Yes | Yes: same pixels, 1:1 colour map |
| `back.gif` | 7 | 15 | Yes (exactly at the limit) | — |
| `back-shiny.gif` | 7 | 17 | **No**, 2 over | **No**: hand-recoloured, 554 pixels break the colour map |

Gen 5 stores one tile set per side and swaps the palette for shiny, so the shiny back can't be used as-is.
To do: rebuild `back-shiny.gif` by mapping each of the normal back's 15 colours to one shiny colour
(take the dominant mapping from the current file), which fixes both problems at once.

### Fallback: static Showdown sprites

[`../sprites/kingambit/`](../sprites/kingambit/): Gen 5-style front and shiny front, 96×96,
15 colours + transparency. From the Smogon Sprite Project via Pokémon Showdown.
The "back" files there are a second front pose, not a true back view.
