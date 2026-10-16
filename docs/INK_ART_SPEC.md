# Ink art specification (v4, hand-drawn)

This replaces the SSF2 pixel-art direction (`ART_STYLE_GUIDE.md`, `SPRITE_PIPELINE.md`,
`CHARACTER_ART_SPEC.md`), which is now historical. The observations behind every rule are in
`INK_REFERENCE_ANALYSIS.md`. Migration status lives in `INK_MIGRATION.md`.

## 1. Rendering pipeline

**Everything visible is drawn from vector data by one renderer, `InkCanvas`**
(`client/scripts/render/ink/ink_canvas.gd`). This is not a filter over raster art, and no pixel
textures are involved.

| Stage | What happens |
|---|---|
| Author | Shapes are authored as Bézier and polyline paths in code or data: rig poses, terrain from course JSON, decor and UI shapes, and player drawings as stroke lists. |
| Stroke | `InkCanvas.stroke()` turns a centre line into a triangle strip. Width varies along the stroke (pressure curve and taper), and each stroke gets a seeded micro-wobble so lines look hand-made but never shimmer. Joins and caps are round, as triangle fans. |
| Fill | `InkCanvas.fill()` triangulates closed shapes. Gradients are per-vertex colours, used only for atmosphere and soil depth. |
| Submit | All geometry for one canvas item (one golfer, one terrain layer, one backdrop layer) goes in **one** `canvas_item_add_triangle_array` call, painter-ordered with per-vertex colour. That is one draw command for the whole item, however many strokes it has. |
| Rasterise | GPU, with 4× MSAA on 2D (`anti_aliasing/quality/msaa_2d`). Lines stay smooth at every resolution and zoom because geometry is rebuilt in screen-aware units, not scaled bitmaps. |

**Caching:**

- Static art is built once and kept by Godot's retained canvas, so it costs nothing per frame:
  terrain, decor, backdrop tiles, UI frames and icons.
- Animated art is rebuilt each frame from its rig: golfers, the flag, water, effects.
- Golfer thumbnails in grids render once into a `SubViewport` texture
  (`InkThumbs`, the studio fix).

**Texture filtering:**

- The global default is now **linear with mipmaps**. Nearest-neighbour is gone from active
  scenes.
- Pixel snapping stays off for world art. UI controls still snap to whole pixels, which keeps
  text crisp.
- Physics coordinates are untouched.

## 2. Line rules

| Element | Width (screen px at 1080p, zoom 1) | Colour |
|---|---|---|
| Golfer body, limbs, head | 2.6–3.4 (3% of figure height, clamped 2.2–6) | Ink `#1c1714` |
| Golfer pants and clothes outline | 85% of body width | Ink |
| Fold, crease and pattern lines | 40–55% of body width | Ink at 60–80% alpha, or a darker garment tone |
| Gameplay terrain surface (top) | 3.6 | Theme ink |
| Terrain walls and undersides | 2.6 | Theme ink |
| Soil sketch marks | 1.2–2.0, tapered both ends | Darker soil tone, never black |
| Mid-background | 1.6–2.2 | Darker shade of the layer's own hue |
| Far background | 0–1.4 | Barely darker than the fill |
| UI frames | 2.5–3.5 | Ink |

**Stroke shape:**

- Every stroke starts and ends with a short taper (0.6×–0.8× width over the first and last 10–
  20% of its length). This is the "pen lifted" look.
- Pressure noise is ±12% of width at low frequency.

**Wobble:**

- At most 0.35 px on gameplay collision edges, so the line sits on the true surface.
- Up to 1.5 px on decoration.

## 3. Colour rules

**Ink:**

- Near-black warm ink `#1c1714`.
- Themes may tint their terrain ink, for example deep navy on Snow Field.

**Characters:**

- Bodies are ink only.
- Heads are hollow by default. A *paper* fill is optional (`headFill`).
- Colour comes from the pants (the main accent), hair, clothes and accessories: flat fills with
  at most one darker shade, for back legs and fold shadows.

**Environments:**

- One saturated key colour per material.
- Background layers are mixed toward the sky colour by 25% (near), 50% (mid) and 70% (far).
- No glossy highlights. Water gets sparse white ripple strokes, not specular blobs.

**Players and UI:**

- Six player slot colours: gold `#f2b630`, sky `#3fa3e8`, coral `#ef5a5a`, mint `#3dbf7f`,
  violet `#9b6be8` and tangerine `#f28c38`.
- Each appears on the golfer marker, the ball ring and the HUD frame.
- UI uses paper `#fbf6ec` on ink `#1c1714`. Accents are the slot colours plus energy violet
  `#8a5cf0`.

## 4. The golfer rig

**One master stick figure** (`InkGolfer`, drawn by `Golfer` so every scene keeps working).
Units are rig units. The figure is 74 tall, and gameplay draws it at 1.3×, about 96 px at 1080p.

| Part | Size | Notes |
|---|---|---|
| Head | radius 8.2 | Hollow, imperfect circle (a stroke that overlaps itself by 8°) |
| Neck and torso | 23 | One stroke, a quadratic curve controlled by `lean` and `bend` |
| Upper arm, forearm | 13.5, 13.5 | 2-bone IK to hand targets. There are no drawn hands, only gloves when equipped |
| Thigh, shin | 17, 17 | 2-bone IK to foot targets. Knees bend forward |
| Shoes | 6 × 3 | Filled ink wedges (or shoe colour with an ink outline) |
| Club | 31 | Held at the hands, or planted, on the shoulder, or carried |

**Draw order:**

1. Back accessories (cape, backpack)
2. Back arm
3. Back pant leg and shoe
4. Torso and shirt
5. Front pant leg and shoe
6. Club
7. Front arm and glove
8. Scarf
9. Head
10. Face
11. Hair
12. Hat
13. Floating companion

Layers swap during the swing follow-through: the club passes behind the head.

## 5. Pants (the signature system)

Each pant leg is a **deformable tube** in leg-local coordinates:

- `u` runs 0 → 1 from waist to cuff, along a smooth curve through hip, knee and ankle.
- `v` runs −1 → 1 across it.
- The half-width is `w(u) = lerp(waist, cuff, flare_curve(u)) + bag·sin(πu)`.
- The cuff end is driven by a damped spring that lags the ankle. That gives billow when moving,
  overshoot on stops and flutter in the air.
- The hem is a wave whose amplitude grows with cuff speed.

| Control | Range |
|---|---|
| `pantsCut` | `flare`, `bell`, `baggy`, `straight`, `skinny`, `shorts`, `capri`, `harem` (shape presets) |
| `pantsLength` | 0.45 (shorts) … 1.0 (ankle) |
| `pantsFlare` | 0.6 … 1.8 × the cut's cuff width |
| `pantsWaist` | −4 … +4 rig units (low and high rise) |
| `pantsCuff` | `open`, `narrow`, `rolled`, `frayed` |
| `pantsPattern` | `solid`, `stripes`, `pinstripe`, `twotone`, `dots`, `checks`, `zigzag`, `stars`, `flames`, `split` |
| `pantsColor`, `pantsColor2` | Any colour |

Patterns and **player drawings are stored in (u, v) space**, so they bend, stretch and flutter
with the fabric. They are drawn per leg, with the back leg darkened by 18%.

## 6. Other customisation

All of it attaches to rig spaces: the head frame, the torso tube, arm segments, hands, feet and
the neck.

| Category | Items |
|---|---|
| Hair | 16 styles: none, spikes, swept, messy, mohawk, curly, afro, bob, long, ponytail, pigtails, bun, braid, buzz, quiff, fringe. Optional fill colour, with **spring sway** |
| Face | Eyes (dots, lines, ovals, happy, sleepy, wide, wink, none), brows, mouth, and marks (freckles, scar, blush) |
| Tops | none, tee, polo, hoodie, jacket, sweater, tank, coat, robe, jersey. A thin tube on the torso line, plus sleeves on the upper arms |
| Headwear | cap, beanie, bucket, top hat, cowboy, crown, headband, wizard, viking, halo, bandana, pirate, dino hood, robot antenna |
| Eyewear | round glasses, square glasses, shades, visor, monocle, goggles |
| Back and neck | scarf (spring tails), cape (spring chain), backpack, golf bag, wings |
| Hands | gloves (golf glove, mittens), wristbands |
| Feet | shoe colour and style (sneaker, boot, loafer, spike) |
| Companion | none, bird, ghost, robo-drone, star, dino buddy (floats behind with a lag spring) |
| Club | iron, driver, wood, putter, golden, candy, laser, bone |
| Ball and trail | Colours, as before |

**Themed outfits replace the old roster characters.** Rex, Mira, Bjorn, Ace, Nana Birdie, Brick,
Bolt, Skipper, Frost and the toon roster are now outfits *on the stick figure*, for example a
dino hood with green baggy pants, or a robot antenna and visor with a metal jacket. Old ids stay
valid, and profiles that pick one get its outfit (§8).

## 7. Animation

**Key-pose animation (`InkAnims`).** Each clip is a list of authored keys
`[time, pose, ease]`.

- A pose sets: hip offset, torso lean and bend, head tilt, hand targets (or club arm angle and
  wrist hinge), foot targets with lift, club mode, and expression.
- Keys interpolate with per-key easing. The eases are smooth, ease-out back (overshoot) and
  ease-in power.
- Clip changes cross-fade over 0.12–0.25 s from the last shown pose, so nothing pops.

**Procedural layers on top:**

- breathing;
- blink;
- head look-at;
- hair, pants, scarf, cape and companion springs;
- landing squash.

**Clips:**

- **Core:** idle, look-around, blink, aim (backswing scrubbed by shot power), swing,
  watch (follow-through hold), recover, walk, run, jump, land.
- **Reactions and emotes:** victory, defeat, laugh, clap, dance, wave, celebrate, disappointed,
  wow, thumbs_up, facepalm, flex.

**Swing:**

1. Address (the club sole grounded by IK behind the ball).
2. Aim shows the backswing by power: anticipation, with the torso coiling back and weight on the
   back foot.
3. On release the downswing reaches impact at `Golfer.IMPACT` (0.045 s), the same frame the
   authoritative shot event launches the ball.
4. Follow-through wraps the club over the lead shoulder, with the back heel lifted and the hips
   open.
5. Watch holds the finish.
6. Recover eases back to idle.

The ball's physics never reads anything from the animation.

## 8. Data format (Appearance v2)

- Appearance stays one JSON object.
- The **v1 keys stay required and valid**, so old clients and the backend keep working.
- v2 adds an optional `ink` object with the keys in §5–6, plus `drawings`.
  - `drawings` maps an item (`pants`, `shirt`, `hat`) to versioned stroke data:
    `{v: 1, strokes: [{c: "#rrggbb", w: width, a: alpha, p: [u, v, …]}]}`.
  - The coordinates are quantised to 0..1000.
  - Limits: 48 strokes and 1500 points per item.
- Migration: a profile without `ink` gets an outfit derived from its v1 `character`, colours and
  hat, so existing looks keep their colours.

**Custom drawings and other players:**

- Drawings are validated: limits, colour format, and bounds.
- They are **shown to other players only when they enable "Show other players' drawings"**
  (off by default). There is no moderation pipeline yet; see `INK_MIGRATION.md`.

## 9. Environments

**Terrain (`InkTerrain`), built once per hole from `SimTerrain` polygons:**

1. Soil fill with a vertical gradient (top to deep).
2. Two contour bands from `Geometry2D.offset_polygon`: a lighter topsoil lip and a darker
   stratum.
3. Seeded hand-drawn soil marks: pebble ovals, short curved dashes, root squiggles and buried
   stones. Each mark is kept inside the polygon and away from the surface.
4. Material strips along the surface. The strip shapes are:
   - grass: band, lip highlight, hanging scallops, blade tufts and dot flowers;
   - sand: band with stipple and ripple dashes;
   - snow: plump drift lip with a blue shadow line;
   - ice: pale band, white streaks and crack ticks;
   - sticky: goo band with outlined drips;
   - bouncy: striped pad;
   - rock: grey band with hatch;
   - wood: planks with grain;
   - metal: plates with rivets.
5. The ink outline exactly on the collision polygon, broken at hidden world-edge seams.

**Separation:**

- Decor (grass blades, flowers, trees) is pure art, never collision.
- Physics geometry is unchanged.

**Backdrop (`InkBackdrop`):**

1. Paper sky gradient, plus a faint paper grain and large faint swirl motifs (shader).
2. Far mountains.
3. Cloud layer (outlined puffs, drifting).
4. Mid hills with tree clumps.
5. Near tree line.

Each layer is a seeded, horizontally tiling vector strip built once, with its colour pulled
toward the sky by its depth.

**Water:**

- Translucent flat body, clipped to open air.
- An animated wavy ink surface line, sparse ripple ticks, and drawn splash effects.

## 10. UI

- **`InkStyleBox`** is a `StyleBox` subclass that draws a wobbly paper panel or button with an ink
  rim, seeded by its size so each box keeps its own hand-drawn shape.
  - Buttons get a pressed offset and a hover "re-ink": a thicker rim and a brighter fill.
- **Fonts:** headings use Kalam Bold, body text uses Patrick Hand. Both are OFL, in
  `assets/fonts`.
- **Icons** (`InkIcon`, `AbilityIcon`) are drawn with `InkCanvas` from the same line rules.
- **The HUD:**
  - Player plates show an ink portrait (the golfer's head and hair), name and score. They adapt
    from 2 to 6 players, and to two rows below 1600 px width.
  - The energy bar is hand-drawn.
  - The ability cards are paper cards with ink icons.

## 11. Effects

**Drawn, light and readable:**

- **Shot:** ink impact star and directional strokes.
- **Bounce:** surface-coloured dust puffs outlined in ink.
- **Splash:** outlined droplets plus a ring.
- **Nitro:** speed streaks.
- **Grenade:** a curved-line burst plus outlined smoke and a shockwave arc.
- **Ice:** outlined crystals.
- **Sticky:** goo blobs and strands.
- **Cup:** confetti squiggles and stars.

**Reduced effects** (Settings → Gameplay) halves particle counts and turns off camera shake and
the paper grain animation.

## 12. Performance budget (measured with `tools/perf.sh`, 1920×1080, vsync off)

| Scene | Target | Baseline (pixel build, 2026-10-16) |
|---|---|---|
| Gameplay, one golfer | < 6.9 ms mean, p99 < 10 ms | 6.18 ms mean, p99 7.0 ms |
| Six customised golfers | < 8 ms mean | not measured (no 6-player view) |
| Golfer Studio | < 8 ms mean | **55.4 ms mean (18 fps), 2211 draw calls** |
| Main menu | < 6.9 ms mean | 5.56 ms mean |
