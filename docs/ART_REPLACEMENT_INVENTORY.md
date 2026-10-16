# Art Replacement Inventory (Milestone 2)

This file lists every code path that still draws production art procedurally (shapes, vector
outlines, generated faces) and what replaces it. Status is updated as each item lands. Per-character
progress is tracked in `docs/CHARACTER_CONVERSION.md`.

Method: search all scripts for `draw_circle`, `draw_colored_polygon`, `draw_polyline`, `draw_arc`,
`draw_line`, `draw_rect` and `ToonCanvas`, then trace each hit to the screen where it shows.
Debug and tooling paths stay; anything a player sees is replaced.

## Characters

| Path | What it draws | Where it is seen | Replacement | Status |
|---|---|---|---|---|
| `render/toon/toon_canvas.gd`, `toon_parts.gd`, `toon_characters.gd`, `toon_roster.gd` | Every legacy golfer: the Stickman, Ace, Nana, Brick, Bolt, Skipper, Frost, Knight, Pirate, Wizard, Dino, Astronaut, Skeleton and Cowboy are built from bean bodies, tube limbs, ellipse eyes and a merged ink outline | Studio cards and preview, gameplay, menu backdrop golfer, emote wheel, HUD chips | Sprite sheets via the `tools/artgen` pipeline, keeping the same character ids so profiles and ownership survive | In progress (background art track); tracked per character |
| `render/golfer.gd` (toon branch of `_draw`, `visual_bounds`) | Calls the toon builders when a character has no sprite sheet | All golfer displays | Same `Golfer` node already draws sprite frames when a sheet exists | Will be unreachable from the roster once every visible id has sprites |
| `render/character_skin.gd` + `dev/sprite_baker.gd` | Painter and baker behind the old baked PNGs (`assets/characters/ace.json` and similar) | Not loaded at runtime (dev tool only) | Retire once nothing references the old baked PNGs | Dev only |
| Studio customisation tabs (Body, Face, Headwear, Shirt, Presets) | Toon parts: head shapes, eyes, mouths, vector hats, shirts | Golfer Studio | Sprite equipment layers (hats on per-frame anchors) and palette variants (`SPRITE_PIPELINE.md`) | Not started. These tabs only apply to the toon Stickman, so they disappear with it |
| `ui/customize.gd` `_Podium` | Vector ellipse podium | Studio preview | Pixel-art podium sprite | Not started (Milestone 9) |
| `ui/customize.gd` `_BallPreview` | Vector ball and trail | Studio ball test | Sprite ball (see Ball below) | Not started |

## Gameplay world

| Path | What it draws | Replacement | Status |
|---|---|---|---|
| `render/terrain_view.gd` (non-art branch) | Flat-colour soil, bands and polygon decor when a theme has no `"art"` | Authored `WorldArt` materials. Every course theme must ship art; the vector branch then stays only as a debug fallback | Meadow done; Beach, Sticky, Snow, Lab and Spin to come with Milestones 6–7 |
| `render/backdrop.gd` (non-art branch) | Gradient sky and flat polygon mountains | Illustrated parallax layers per theme | Meadow done; other themes as above |
| `render/ball_view.gd` | Ball as shaded circles, spin marks, trail line, cooldown ring | Sprite ball (rotation frames), sprite trail particles. Keep a thin outline ring for readability (directive 17.14) | Not started |
| `render/trajectory_view.gd` | Dotted trajectory | Removed for normal shots (Milestone 4). The Laser Ball guide gets its own sprite-dot style | Pending Milestone 4 |
| `render/fx_layer.gd` (particle pass) | Spark, confetti and droplet circles | Flipbooks already cover impact, dust, splash, sparkle and flame; particles move to sprite textures | Partly done |
| `ui/menu_backdrop.gd` | Foreground hill, flag and golfer for the menus | Meadow stage art and a sprite golfer | Partly done (inherits the meadow art; its golfer follows the roster conversion) |

## Interface

| Path | What it draws | Replacement | Status |
|---|---|---|---|
| `ui/ability_icon.gd` | Vector ability glyphs (the circles in the directive's image 2) | Pixel-art icon sheet: one authored icon per ability (15) | Not started (Milestone 9; required before Milestone 5 ships the new abilities) |
| `ui/icon.gd` | Small vector UI glyphs (coins, trophies, gear and similar) | Pixel icon atlas | Not started |
| `game/hud.gd` | Player chips, energy bar, ability cards | SSF2-style portrait and score panels (2–6 players) and a sprite ability bar | Milestone 8 |
| `game/emote_wheel.gd` | Wheel ring shapes; the golfer previews come from `Golfer` | Pixel wheel frame; golfers follow the roster | Not started |
| `game/game_scene.gd` (3 calls) | Results-card chips and practice-panel accents | Covered by the Milestone 9 results redesign | Not started |
