# Art Style Guide (v3: "arcade stage" direction)

**Visual benchmark:** the craft and presentation of Super Smash Flash 2. That means detailed
pixel sprites, illustrated layered stages, punchy effects and bold arcade menus.
**Gameplay benchmark:** Golf Blitz.
All assets are original. We match qualities, never designs, characters or stages.

## 1. One world, three rendering layers

| Layer | Look | Density | Filtering |
|---|---|---|---|
| Sprites (golfers, balls, props, hazards, pickups, effects) | Pixel art, dark outer outline, 3–5 tone ramps per material | **1 art px = 2 screen px at 1080p** (world zoom 1) | Nearest |
| Stage (terrain, foreground platforms, decor) | Pixel-art materials, same density as sprites | 1 art px = 2 screen px | Nearest |
| Backdrop (sky, far mountains, hills, forest) | Illustrated pixel art; may be softer and lower contrast with distance | Parallax layers, 1 art px = 2–3 screen px | Nearest |
| UI (menus, HUD, cards) | Bold arcade panels: slanted shapes, thick dark rims, saturated fills, heavy display type | Vector or high-res raster at screen resolution | Linear |
| Effects | Sprite flipbooks plus additive glows for energy (impact flashes, ability auras) | Sprite density | Nearest, additive allowed |

UI is intentionally not pixelated. SSF2's menus are clean, bold vector-like panels around
pixel characters, and ours follow the same split. Cohesion comes from a shared palette, shared
outline colour and shared motion language, not from pixelating every element.

## 2. Pixel density and scale

- World unit = 1 px at 1080p and zoom 1. The art scale is **2**: every sprite and stage texture
  is drawn at half its world size and shown with nearest filtering at 2×.
- Golfer: about 43 art px tall (86 world px). Ball: 7 art px across. Cup: 10 art px.
- Camera: gameplay zoom snaps to 1.0 or 0.5 when not tracking a shot, so art pixels stay whole.
  During flight the zoom can be fractional; nearest filtering keeps it sharp, and the slight
  unevenness is accepted while moving.
- Any asset that does not match its layer's density is a bug.

## 3. Palette

- Outline / ink: `#20141e`. Never pure black. Sprites use it for the outer silhouette.
  Interior lines use the darkest shade of the local material (selective outlining).
- Light comes from the top-left of the stage; sprite highlights sit on the top edge.
- Each stage theme has a **stage palette image** (`art/worlds/<theme>/palette.png`, up to 48 colours).
  Generated art is quantised to that palette, so sky, terrain and props share one colour world.
- Ramps run 3–5 shades, hue-shifted: shadows lean cool/purple, highlights lean warm/yellow.

## 4. Animation

| Thing | Frames | Rate |
|---|---|---|
| Golfer idle | 6–8 | 8 fps |
| Golfer swing | 8–12, contact frame marked | 12–24 fps, frontloaded so contact lands on the shot event |
| Water / lava surface | 8 | 8 fps loop |
| Flag | 6 | 10 fps loop |
| Impact / splash / cup effects | 6–10 | 20–24 fps one-shot |

Frames share one pivot (ground point). Validators reject frames whose feet leave the pivot row.

## 5. Production pipeline

```
concept / generation   tools/artgen/generate.py   (local SDXL + pixel-art LoRA on the dev GPU)
        |
clean-up               tools/artgen/pixelize.py   (grid snap, stage-palette quantise, hard alpha, outline)
        |
hand correction        Aseprite / LibreSprite / grid sources (art/**)
        |
build + validate       tools/sprites/build_character.py, tools/artgen/build_stage.py
        |
game assets            client/assets/{characters,worlds,effects,ui,...}  (+ JSON metadata)
```

Raw generations are never game art. Each one is picked, cleaned, quantised to its palette,
reviewed at 1× and in-game, then committed under `art/` with its source prompt and seed
(`art/**/SOURCES.md`) so it can be regenerated.

## 6. Asset layout

```
client/assets/
  characters/<id>/        sprite strips + character.json (see SPRITE_PIPELINE.md)
  worlds/<theme>/         world.json, backdrop layers, terrain materials, decor, animated props
  effects/                flipbook strips + effects.json
  ui/                     panels, frames, buttons (9-slice), icons
  cards/ packs/           card frames per rarity, pack art
  golf_balls/ trails/ hats/ clothing/ equipment/ portraits/
  audio/
```

## 7. Import settings

- Pixel textures: filter Nearest, mipmaps off, compression Lossless.
  Each pixel-art node sets `texture_filter = NEAREST`. Project default stays Linear for UI.
- Strips: one PNG per animation, frames left to right, fixed frame size, described in JSON.
- Repeating terrain materials are 128×128 seamless tiles drawn with `texture_repeat = ENABLED`.

## 8. Physics separation

Art never changes gameplay geometry. Terrain polygons, surface materials and hazards come from
course JSON and the simulation. The renderer wraps them in material art: textured fill, a grass
or edge cap following the surface curve, and decor stamped along it. Ball collision is still the
smooth curve.
