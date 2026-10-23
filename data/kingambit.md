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
| Abilities | Defiant / Pressure *(Supreme Overlord doesn't exist in Gen 5; see below)* |
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

- **Bisharp → Kingambit.** Gen 9's method (defeat three Bisharp holding a Leader's Crest) can't be done in Gen 5.
  Options: **level 64** (when Gen 9 Kingambit learns Swords Dance) or **level up holding a King's Rock**
  (fits the name; Redux already lets King's Rock be "used" like a stone). *Decision needed.*
- **Klang → (nothing).** Klang currently evolves into slot #601 at level 49, which would make it evolve into
  Kingambit. Remove that evolution so Klang becomes the end of its line. *Decision needed.*

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
then rename it. Its effect is the same as a normal hit (Night Slash's crit boost removed); "never misses"
is accuracy set to the "always hits" value used by Aerial Ace. *Which slot to use: to be confirmed in the editor.*

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

Every one of these becomes Kingambit unless changed. *Decisions needed.*

| Where | Current | Note |
| --- | --- | --- |
| Colress, Plasma Frigate | Klinklang lv.66 @Life Orb: Gear Grind, Shift Gear, Wild Charge, High Horsepower | His ace; moves would be wrong for Kingambit |
| Ranger♂ Eddie | Klinklang lv.70: Shift Gear, Superpower, Gear Grind, Wild Charge | |
| Colress (postgame) | Klinklang lv.88: Gear Grind, Shift Gear, Wild Charge, Superpower | |
| P2 Laboratory, shaking grass | Klinklang lv.68, 5% | Would become a wild Kingambit |

## Sprites

[`../sprites/kingambit/`](../sprites/kingambit/): Gen 5-style front and shiny front, 96×96,
15 colours + transparency (fits Gen 5's 16-colour palette). From the Smogon Sprite Project via Pokémon Showdown.
The "back" files are a second front pose, not a true back view: a back sprite still needs to be found or drawn.
