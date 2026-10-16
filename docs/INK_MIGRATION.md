# Ink art migration manifest

This tracks the conversion from the SSF2 pixel-art direction to the hand-drawn ink direction
(`INK_ART_SPEC.md`, `INK_REFERENCE_ANALYSIS.md`). Branch: `ink-art`.

The statuses mean:

- **Not started**
- **In progress**
- **Converted:** new art exists.
- **Integrated:** it is in the live game.
- **Tested:** automated checks plus a screenshot review.
- **Approved:** signed off by the project owner.

Nothing here is "Approved" yet: that needs your review.

Screenshots of the new art are in `docs/screens/ink/`. The pixel-art baseline is in
`docs/screens/baseline_v4_pixel/`.

## Rendering pipeline

| System | Status | Notes |
|---|---|---|
| InkCanvas stroke/fill renderer | Tested | One triangle array per item, robust fills (union fallback for self-intersections) |
| Paper sky shader | Tested | Gradient, paper grain, faint swirls |
| Pixel-specific rendering | Integrated | No nearest-filter art remains in active scenes. Pixel shaders, sprite sheets, the pixel UI art and the world sprite sets are moved to `client/legacy_pixel/` (gdignored, not deleted) |
| Physics separation | Tested | Art reads collision polygons and never adds collision. Sim, ability and solver suites are unchanged (results below) |

## Characters

| System | Status | Notes |
|---|---|---|
| Master stick-figure rig and animation | Tested | `test_ink.gd`: 752 checks. These cover every clip solving to finite poses, the club in the hands, and grounding at address |
| 17 collectible golfers as themed outfits (same ids) | Tested | Catalog ids map 1:1 to outfits. v1 profiles migrate automatically |
| Hair (16), face, pants (8 cuts, 11 patterns, 4 cuffs, sliders), tops (10), hats (17), eyewear, neck/back, gloves, shoes, clubs (8), companions | Integrated | Studio tabs. Thumbnails reviewed |
| Signature parts unlock with their outfit | Tested | Client locks plus backend enforcement (`collection.test.ts`) |
| Clothing drawing editor | Integrated | Pen, marker, line and eraser. Size, opacity and smoothing. Undo/redo, mirror and clear. Pants (both or front leg) and top. Stored in garment (u, v) space, so drawings move with the cloth |
| Drawing editor: layers, selection/move/rotate, fill, shape tools, zoom/pan | **Not started** | Requested in the directive and not built yet |
| Drawing moderation pipeline | **Not started** | Until it exists, other players' drawings are hidden unless the viewer opts in (Settings → Gameplay) |

## Courses (54 holes)

| Course | Status |
|---|---|
| Golf Land | Tested (in-game screenshots, all holes render) |
| Beach Land | Tested (screenshot) |
| Sticky Zone | Tested (screenshot) |
| Snow Field | Tested (screenshot) |
| Gravity Lab | Tested (screenshot) |
| Spin Land | Tested (screenshot) |
| Decor (30 types), water/acid, ice patches, gravity fields, conveyor belts, flag, cup | Integrated |

## Interfaces

| Screen | Status |
|---|---|
| Main menu (logo, all entries) | Integrated. Friends is shown locked because friends lists don't exist yet |
| Golfer Studio | Tested (perf probe, screenshots) |
| Collection | Integrated |
| Card-pack opening (float, click, shake, burst, flip, rarity treatment, summary) | Integrated (`--dev-reveal` screenshot) |
| Course select (live ink previews for all six worlds) | Integrated |
| Gameplay HUD: score panels (2–6), energy, cards, controls card, banner, timer | Integrated |
| Ability icons (all 15 balls) | Integrated |
| Aim arrow, spin glyph, classic meter, dotted guide, Laser beam, debug path, ghost paths, off-screen markers | Integrated |
| Pause menu, results, stroke-play scorecard, match end with winner pose, speech bubbles, emote wheel | Integrated (they inherit the ink theme). Online result screens are not yet screenshot-reviewed |
| Settings, lobby / private room, leaderboard, profile, welcome dialog, error toasts | Integrated (ink theme). Not individually screenshot-reviewed |
| Loading / boot | Integrated (paper clear colour) |
| Login / account creation | The game uses guest accounts plus the welcome naming dialog (ink). There is no separate login screen |
| Tutorials | Not applicable: the game has no tutorial screens. The controls card is the in-game help |

## Effects

| Effect | Status |
|---|---|
| Shot impact, dust, splash, explosion, nitro, brake, goo, ice patch, confetti, sparkle, poof | Integrated |
| Ball skins and state overlays (shield, frost, anti-grav, magnet) | Integrated |
| Reduced motion | Integrated (reuses the existing setting: fewer particles and no paper grain) |

## Removal of the old art (phase 8)

The old systems are moved to `client/legacy_pixel/`. Nothing active references them. They can be
deleted once you approve the new art. Git history keeps everything.

| Old system | Moved |
|---|---|
| Toon roster renderer (`render/toon`) | Yes |
| Sprite characters and sheets (`render/sprite`, `character_skin`, `character_sheet`, sprite baker) | Yes |
| Pixel world art (`world_art.gd`, `assets/worlds`) | Yes |
| Pixel UI art (`ui_art.gd`, `assets/ui`), pixel effects flipbooks | Yes |
| Pixel shaders (sky, sprite outline, terrain fill, world soil) | Yes |
| `tools/artgen`, `tools/sprites`, `bake_sprites.ps1` (offline pixel pipelines) | Still in `tools/` (not used by the game). Delete when approved |
