# Art Direction Guide

**Style:** bold, playful vector illustration. Everything is drawn procedurally from shapes:
crisp at any resolution, recolourable, and consistent. Gameplay clarity always comes first.

## Shapes and lines

- **Outlines** are dark ink (`#1b2040` UI, `#2a3a2a`/theme outline in worlds).
  - Characters: 2.7 px outlines, merged into one silhouette (all outlines are drawn first, then all
    fills).
  - Terrain: 3.5 px. Balls: 2.2 px.
- **Corners:** soft. UI panels use a 26 px radius, buttons 18 px, small elements 12 px. Capsule
  limbs have round ends.
- **Light** comes from the top-left: highlights at the upper-left, shading crescents at the
  lower-right. There are no hard cast shadows; contact shadows are soft ellipses that shrink with
  height.

## Characters

Characters follow **docs/CHARACTER_ART_SPEC.md** (v2 toon golfers):

- Each golfer has a lean bean body, a big round head and noodle arms, with no ears.
- One merged dark-navy ink silhouette, sized in screen pixels.
- Flat fills with one shadow crescent. No blur, smear or AA feathering; MSAA keeps edges clean.
- Everything is drawn live by `Golfer` + `ToonCanvas` from data in `CharacterDefs`, with one
  builder per character in `ToonCharacters` and `ToonRoster`.
- There are no baked sprite sheets.
- 14 characters: Stickman (customisable), Bolt, Cap'n Slice, Fizzwick, Tee-Rex, Nova, Rattles,
  Frost, Dusty, Sir Putts, Ace, Nana Birdie, Brick and Skipper.
- Validate them with `tests/test_characters.gd`.

## Emotes

Eight emotes: Wave, Laugh, Wow, Good Game (thumbs up), Clap, Facepalm, Flex and Dance. Each is a
full-body animation (1.6–2.4 s) with a matching expression, plus a speech bubble in the player's
slot colour. The emote wheel previews the player's own golfer frozen mid-emote in each slot.

## Colour

Each theme defines its own palette (see `docs/COURSES.md`).

**Sunny Meadows:**

| Element | Colours |
|---|---|
| Sky | `#3fa9f5` → `#c9f0ff` |
| Grass | `#6ccf4a`, `#9be36b` light, `#3d9a2f` dark |
| Soil | `#8a5a3c` → `#5b3a29` |

**Atmospheric depth:** each parallax layer is lighter and closer to the sky colour as it recedes.

**UI tokens** (`ui_theme.gd`):

| Token | Value | Use |
|---|---|---|
| Ink | `#1b2040` | Panels |
| Paper | `#fff8ec` | Text |
| Sun | `#ffd166` | Accent, coins |
| Grass | `#3ec46d` | Primary action |
| Sky | `#4c8df6` | Secondary action |
| Coral | `#ef476f` | Danger |
| Muted | `#aab3e0` | Secondary text |

**Player slot colours:** gold `#ffd166`, cyan `#4cc9f0`, coral `#ef476f`, mint `#80ed99`. They are
used for names, chips and markers.

**Rarity** (for collectibles, planned):

| Rarity | Colour | Glyph |
|---|---|---|
| Common | silver | ● |
| Uncommon | green | ◆ |
| Rare | blue | ★ |
| Epic | purple | ✦ |
| Legendary | gold | ♛ |
| Mythic | pink | ✷ |

Rarity is always shown with its name and glyph too, never colour alone.

## Typography

| Font | Use | Weight |
|---|---|---|
| **Fredoka** (OFL) | Headings and buttons | wght 640 |
| **Nunito** (OFL) | Body | wght 650; bold 850 |

- Big announcements use Fredoka with a 10–16 px ink outline and a soft drop shadow.

## Surfaces and materials

Every gameplay material has a distinct surface band, even on walls and ceilings:

| Material | Look |
|---|---|
| Grass | Dark scalloped fringe, light rim, tufts |
| Sand | Beige band with speckles |
| Ice | Pale blue with white rim and glints |
| Sticky | Purple goo with drips |
| Bouncy | Red/white stripes |
| Rock and wood | Grey and brown bands |
| Cup | Dark interior with white liner |

## Motion and effects

- **Particles:** dust on landings, splash and bubbles in water, explosion (flash, double shockwave,
  sparks, smoke), confetti on holing, goo on stick, puffs for respawns and appear/disappear.
  - Max 900 particles.
  - Effects must never hide the ball.
- **UI motion:**
  - buttons spring to 1.04× on hover and 0.96× on press;
  - panels pop in with a back-ease over 0.25–0.3 s;
  - scene changes fade over 0.18 s out / 0.25 s in.
- **Ambient motion:** clouds drift, trees sway slightly (rotation only, no redraws), water waves,
  the flag waves, and the ready pulse ring around your ball.

## Audio

All sound effects are synthesised by `tools/gen_sfx.py`, so they are original and regenerable.
Surface materials map to impact sounds in `materials.json`.
