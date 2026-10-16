> **Superseded** by `INK_ART_SPEC.md` (hand-drawn ink direction). Kept for history.

# UI pixel art (ability icons, ball, HUD frames, studio podium)

Updated 2026-10-15. Everything here is pixel art at a fixed **native art-pixel size**. Show it
with `texture_filter = NEAREST` at an integer scale (2x at 1080p matches the sprite layer;
3x also works). No `.import` overrides were added: Godot 4 sets filtering per CanvasItem, so the
nodes that draw these textures must set `TEXTURE_FILTER_NEAREST`. Import defaults (lossless,
no mipmaps) are already right.

Rebuild everything from the committed picks, no GPU needed:

```
tools/artgen/.venv/Scripts/python tools/artgen/build_ui.py            # icons ball hud podium sheet
tools/artgen/.venv/Scripts/python tools/artgen/build_ui.py icons sheet  # just a part
```

## Asset list

| Asset | Path | Native size (art px) | Notes |
|---|---|---|---|
| Ability icons (15) | `client/assets/ui/abilities/<id>.png` | 48 x 48 | Transparent, 1 px ink outline `#20141e`, light from top left. Ids match `balance.json` |
| Golf ball | `client/assets/ui/ball/ball.png` | 18 x 18 | White ball, 16 px body + outline, dimples and a printed seam |
| Ball spin strip | `client/assets/ui/ball/ball_spin.png` | 144 x 18 (8 frames of 18 x 18) | Frame *i* = surface turned *i* x 45 degrees clockwise; lighting fixed |
| Tint ball | `client/assets/ui/ball/ball_tint.png` | 18 x 18 | Neutral greys (white highlight) for `modulate`; outline stays dark |
| Tint spin strip | `client/assets/ui/ball/ball_tint_spin.png` | 144 x 18 | Same frames as `ball_spin.png`, greyscale |
| Player panel | `client/assets/ui/hud/panel.png` | 160 x 48 | 9-slice, see margins |
| Portrait frame | `client/assets/ui/hud/portrait_frame.png` | 64 x 64 | Transparent window 50 x 50 at (7, 7); 9-slice |
| Ability card | `client/assets/ui/hud/ability_card.png` | 52 x 60 | 9-slice, steel rim |
| Ability card (selected) | `client/assets/ui/hud/ability_card_selected.png` | 52 x 60 | 9-slice, gold rim + inner glow line |
| Energy cell, empty | `client/assets/ui/hud/energy_cell_empty.png` | 14 x 24 | Plain sprite (not 9-slice) |
| Energy cell, full | `client/assets/ui/hud/energy_cell_full.png` | 14 x 24 | Same frame, glowing cyan charge |
| Studio podium | `client/assets/ui/studio/podium.png` | 201 x 68 | Replaces the vector ellipse podium |
| Icon contact sheet | `art/ui/review/abilities_sheet.png` | - | All icons at 1x (dark and light backing) and 3x, with each ability's `balance.json` colour bar |

### 9-slice patch margins (NinePatchRect `patch_margin_left/top/right/bottom`, art px)

| Texture | left | top | right | bottom | Stretch notes |
|---|---|---|---|---|---|
| `panel.png` | 36 | 24 | 24 | 23 | Stretch **horizontally**. The slanted gold stripes run the full height inside the left patch, so the vertical stretch band is a single row (row 24). Keep the panel at its native height (48 x scale); stretching it vertically repeats that row and turns the stripes into vertical bars |
| `portrait_frame.png` | 16 | 16 | 16 | 16 | Any size. Gold brackets live in the corners |
| `ability_card.png` | 12 | 12 | 12 | 12 | Any size. To hold a 48 px icon with 4 px padding use at least 56 x 64 art px (the native 52 x 60 is the minimum look) |
| `ability_card_selected.png` | 12 | 12 | 12 | 12 | Same geometry as `ability_card.png`, swap textures to select |

All stretchable bands (edges and centre) are uniform along their stretch axis, so the default
`AXIS_STRETCH_MODE_STRETCH` never smears detail. Detail (rivets, chamfers, vents/LEDs, brackets)
sits in the corners.

### Podium placement

The grass top is an ellipse centred at **(100, 16)** in `podium.png`, radii about 98 x 14 art px.
Stand the golfer's feet and the ball on that ellipse (y = 16 at the centre line). The stone drum
below runs to y = 67. At the studio's large preview scale, draw it with NEAREST at an integer
multiple of the golfer's scale.

## How it was made

1. **Guides** (`tools/artgen/ui_guides.py` -> `art/ui/guides/`): a flat-shaded composition per
   icon (1024 px, subject on black, accent colour from `balance.json`, top-left light), and HUD
   and podium layouts drawn at art resolution then upscaled 8x. Guides fix silhouette, scale and
   colour so the set is consistent. They are init images, not game art.
2. **Paint-over** (`tools/artgen/gen_ui.py`, jobs `tools/artgen/jobs/ui_*.json`): SDXL +
   pixel-art-xl img2img over each guide, strength 0.6-0.8 for icons, 0.45 for HUD frames and 0.7
   for the podium. `--offload` runs with sequential CPU offload when another pipeline already
   fills the GPU.
3. **Pick**: the chosen raw generation is copied to `art/ui/icons/<id>.png`,
   `art/ui/hud/hud_panel.png`, `art/ui/hud/hud_kit.png`, `art/ui/studio/podium_raw.png`.
   Provenance (job, seed, strength, prompt) is in `art/ui/SOURCES.md`.
4. **Build** (`tools/artgen/build_ui.py`):
   - icons: background flood-cut (border plus enclosed black gaps), square crop on the subject,
     per-block colour mode down to 46 x 46 (16-colour k-means palette in Lab, no blended
     colours), single-pixel spur clean-up, 1 px ink outline, centred on 48 x 48. Per-icon
     overrides live in `art/ui/picks.json` (only `heavy` has one: a mid-tone lift so the iron
     reads on the dark HUD).
   - HUD: the 8x paint-over snaps back onto the art grid by per-block mode. The alpha comes
     from the guide, so edges and 9-slice geometry are exact. Then the bands are made uniform and
     the silhouette edge is set to ink.
   - podium: same snap. Alpha is the guide silhouette plus painted grass/flowers within 2 px of
     it, then defringed and outlined.
   - ball: pre-rendered by `tools/artgen/ui_ball.py`. It is a sphere lit from the top left,
     banded into a 5-tone hue-shifted ramp, with Fibonacci-distributed 1 px dimples and a printed
     seam arc. The spin frames rotate only the surface pattern. At 18 px a generated ball does
     not survive the downscale, so the ball is rendered, not generated.

### HUD and podium picks

| Pick | Job (file) | Seed | Strength | Guide |
|---|---|---|---|---|
| `art/ui/hud/hud_panel.png` | hud2_panel_s45 (ui_hud2.json) | 12032 | 0.45 | `guides/hud_panel.png` |
| `art/ui/hud/hud_kit.png` | hud3_kit_s45 (ui_hud3.json) | 12142 | 0.45 | `guides/hud_kit.png` (portrait, cards, cells) |
| `art/ui/studio/podium_raw.png` | podium2_s70 (ui_hud2.json) | 12311 | 0.70 | `guides/podium.png` |

The part boxes on the HUD sheets are `HUD_BOXES` in `tools/artgen/ui_guides.py`. A part can be
taken from a different painted sheet with `"hud_parts"` in `art/ui/picks.json`.

## Quality notes (honest)

**Ability icons: satisfied.** The 15 icons share pixel density, outline weight, palette depth
and lighting, and each has its own silhouette and colour (tee, comet, goo cap, grenade,
kettlebell, parachute, hover rings, ticket, ice block, crosshair, horseshoe, rewind ring, heraldic
shield, sunburst, bolt). They read at 1x. Weaker points:
- Several icons share the same white ball (standard, mulligan, laser, anti_grav, air_brake,
  magnet, zig_zag). The surrounding motif carries the identity. That is fine side by side, but
  the white ball itself is not distinctive.
- `free_shot` (ticket) is the flattest: a mostly single-tone gold face with a small star.
- `magnet`'s field lines are only 1-2 px pink arcs at 48 px and barely read.
- `zig_zag` is a lightning bolt plus a ball, not a literal zig-zag flight path. The ball is small.
- The paint-overs follow the guides closely, so shapes are clean and readable rather than
  richly textured. They are cleaner than SSF2 item art but have less micro-detail.

**Golf ball: satisfied.** The ball has clear 5-tone shading, sparse 1 px dimples and a seam
that makes the spin obvious. 8 frames over 360 degrees means 45-degree steps. That is fine for a
fast-spinning ball, but a slow roll will look steppy. The tint version multiplies cleanly: the
shadows go darker with the chosen colour.

**HUD frames: acceptable, not exceptional.** They are clean, bold and consistent: dark
purple-navy glass, steel or gold bevel rims, chamfered corners, rivets and status LEDs. They are
original designs. At strength 0.45 the paint-over mostly keeps the authored guide, so these are
closer to hand-built pixel frames than to generated art. The body is a flat 3-band fill (it has
to be, to 9-slice cleanly). The energy cells are simple glass capsules. If the HUD needs more
flourish, the next step is a hand pass on the corners (Aseprite).

**Podium: satisfied for its role.** It has a textured grass top with small flowers, a lit
cobblestone drum and an ink outline. The top surface is clean enough to stand on. The grass
fringe over the stone is a little regular.

## Files

- Sources and picks: `art/ui/` (`icons/`, `hud/`, `studio/`, `guides/`, `picks.json`, `SOURCES.md`)
- Review: `art/ui/review/abilities_sheet.png` (icons), `art/ui/review/hud_sheet.png` (HUD, ball, podium)
- Tools: `tools/artgen/gen_ui.py`, `ui_guides.py`, `ui_ball.py`, `build_ui.py`; jobs
  `tools/artgen/jobs/ui_icons*.json`, `ui_hud*.json`
