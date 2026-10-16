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
| Beach Land, Sticky Zone, Snow Field, Gravity Lab, Spin Land stages | Pixel-art stage sets from the same pipeline: parallax backdrops, surface and soil tiles, material strips and sprite decor (STAGE_ART.md, `docs/screens/v4/stages/`). Weak points: some soil tiles are busy at close zoom, and stage props are static (no animated props yet) |
| Golfers | All 17 roster golfers are sprites, with the same ids as before (CHARACTER_CONVERSION.md). Each has idle, swing, victory and an authored portrait. Walk, defeat and emote animations still fall back to idle |
| Portraits | Authored `portrait.png` in a pixel frame (UI_ART.md) |
| Ball, trail, aim ring | Sprite ball with tint and in-flight spin. Trails and the aim arrow are drawn shapes, kept deliberately flat |
| Ability icons | Pixel-art icons for all 15 balls |
| Effects | Flipbooks for impact, dust, splash, sparkle and flame. Sparks, confetti and some ability states (shield bubble, magnet pull) are still procedural |
| UI | Arcade panels, display font, nine-slice pixel frames, SSF2-inspired player score panels (HUD_SPEC.md), energy cells and pips |
| Menus | Main menu, Golfer Studio (pixel podium), course select, Collection and pack reveal, and results with the victory pose. No pixel-art logo yet; the title is set in the display font |
