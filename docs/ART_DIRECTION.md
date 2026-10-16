# Art Direction

**One art direction for the whole game:** detailed, intentionally authored 2D sprite art with
the craft and presentation of Super Smash Flash 2. That means:

- pixel characters with multi-tone shading and consistent dark outlines;
- frame-by-frame animation;
- illustrated, layered stages;
- punchy sprite effects;
- bold arcade menus.

All art is original. We match SSF2's qualities, never its designs, characters, stages or HUD
graphics.

The old procedural vector-cartoon style is **retired**: golfers built from beans and tubes, flat
polygon mountains, plain circle icons. It may survive only as a debug or tooling fallback. Any
player-facing use is tracked as a defect in `ART_REPLACEMENT_INVENTORY.md` until it is replaced.

| Document | Covers |
|---|---|
| `ART_STYLE_GUIDE.md` | The binding standards: pixel density (1 art px = 2 screen px at 1080p), palette and ink colour, ramps, animation frame counts, pipeline, import settings, physics separation |
| `SPRITE_PIPELINE.md` | The character sprite format |
| `CHARACTER_CONVERSION.md` | Per-character progress |
| `UI_ART.md` | Interface art assets and 9-slice margins |
| `ART_REPLACEMENT_INVENTORY.md` | Every remaining procedural render path and its replacement |

## Production method

Art is generated and cleaned with the local pipeline in `tools/artgen`: SDXL plus a pixel-art
LoRA running on the development GPU. Pose-guided paint-over gives consistent animation frames,
and every result is then grid-snapped, palette-quantised, defringed and outlined.

- Every pick is reviewed at 1× and in game before it is accepted.
- Chosen sources are committed under `art/`, so the game builds without the GPU.
- Hand-typing pixel grids is not a production method (it was tried and rejected as
  inefficient).

## Current status (honest)

| Area | State |
|---|---|
| Golf Land stage (meadow) | Authored pixel art: illustrated parallax sky, mountains and castle hills, painted grass and soil, material strips, textured animated water, sprite decor, flag flipbook |
| Beach Land, Sticky Zone, Snow Field, Gravity Lab, Spin Land stages | **Procedural fallback only.** Playable, but they look like the retired style until each theme's art set is produced |
| Golfers | Sprite golfers with idle and swing animations. The roster is being converted from the old toon rig in stages (see CHARACTER_CONVERSION.md). Walk, victory, defeat and emote animations still fall back to idle |
| Portraits | A cached head crop of the sprite, or an authored `portrait.png` where one exists |
| Ball, trail, aim ring | Still drawn procedurally; a sprite ball is in production |
| Ability icons | Old vector glyphs; pixel-art icons are in production |
| Effects | Flipbooks for impact, dust, splash, sparkle and flame. Sparks, confetti and new ability states are still procedural |
| UI | Arcade panels, display font, SSF2-inspired player score panels (HUD_SPEC.md). Pixel frame art for the HUD is in production |
| Menus | Main menu, Golfer Studio, course select and results use the arcade theme over the meadow backdrop. Card packs and the cosmetic collection have no screens yet |
