# Stage Art (v4): beach, sticky, snow, lab, spin

Five authored stage themes that replace the procedural fallback on Beach Land, Sticky Zone,
Snow Field, Gravity Lab and Spin Land. They use the same format and density as the meadow
(ART_STYLE_GUIDE.md: 1 art px = 2 screen px, ink #20141e, palette-quantised, nearest filter).
Screenshots: `docs/screens/v4/stages/`.

## Pipeline

| Step | Tool | Notes |
|---|---|---|
| Generate candidates (shared GPU) | `tools/artgen/stage_gen.py gen jobs/stage_<theme>.json` | Same job format as generate.py. Uses model CPU offload by default so it can share the card with the character track. Compact style suffix, because CLIP reads only 77 tokens |
| Detail upscale of skies (x4) | `tools/artgen/stage_upscale.py` (list in `jobs/stage_upscales.json`) | Same recipe as the meadow sky: two passes of upscale.py at strength 0.4 |
| Hand pixel pieces | `tools/artgen/stage_hand.py <theme>` | Gameplay caps (grass, sand, goo, ice, snow, planks, belt, metal floor), flags, summit cairn, gravity arrows, dune tufts. Drawn in code, seamless at 128 px, deterministic |
| Decor sprites from picks | `tools/artgen/stage_pick.py art/worlds/<theme>/decor.picks.json` | Crop, size, background cut (flat or red chroma key), drop-shadow strip, largest island, outline |
| Build | `tools/artgen/build_stage.py <theme>` | Writes `client/assets/worlds/<theme>/` and world.json |
| Provenance | `tools/artgen/stage_sources.py <theme>` | Writes `art/worlds/<theme>/SOURCES.md` (job, seed, prompt per pick) |

New opt-in `build_stage.py` asset options. The meadow does not use them, and the meadow build is
verified byte-identical: `cut_top` + `keep_below` + `cloud` / `cloud_any` (cut the sky from the
top only, so land touching the sides is kept), `extend` (mirror and darken the bottom rows so pits
show layered undergrowth instead of a flat fill), `haze` (aerial perspective), `saturation`,
`height`, `trim`, `flip`, and `--out DIR` (build to another folder for diffing).

Full rebuild with no GPU (verified: a clean rebuild matches the shipped assets for all five):

```
tools/artgen/.venv/Scripts/python tools/artgen/stage_hand.py all
for t in beach sticky snow lab spin: stage_pick.py art/worlds/$t/decor.picks.json ; build_stage.py $t
```

Each world.json has a sky, a far parallax layer (factor 0.08, scale 4) and a near parallax layer
(factor 0.18 to 0.22, scale 4). It also has a soil fill, caps for every material the course uses,
zone fills with foam and edge colours, decor sprites for every decor type in the course, and the
meadow flag flipbook (copied).

## Per theme

### beach (Beach Land)
- Backdrop: x4 detail sky (cumulus over a turquoise sea), far sandstone sea cliffs with a
  lighthouse, near beach huts, palms and fences.
- Terrain: warm sandstone strata fill. Grass cap is a dune-grass rim (scalloped clumps plus long
  blades). Sand cap is rippled with shells. Rock cap is cut from a coastal rock tile. Wood cap is
  boardwalk planks with nails and seams.
- Water: the meadow water pick, more saturated, with white foam.
- Decor: palm x3, shell x6, umbrella, crab, lighthouse, buoy, grass_tuft x3 (hand), rock x4,
  flag_small x2 (hand).
- Good: three clear depth planes. Reads as bright coastal. Sand and grass are distinct.
- Weak: the soil is a fairly regular brick-like strata pattern and busier than the meadow soil.
  The umbrella and crab come from single picks and have no variants. The buoy sits on the seabed
  (see renderer notes).

### sticky (Sticky Zone)
- Backdrop: x4 magenta-dusk sky with a moon and giant mushroom silhouettes. Far layer is a
  glowing mushroom forest with hanging vines, extended into a swamp reflection. Near layer is a
  fern and vine strip.
- Terrain: plum-brown swamp stone fill. Grass cap is dark moss in scalloped clumps with pink and
  cyan flowers. The **sticky cap is hand-drawn glossy purple goo**: a bulging layer with specular
  streaks, bubbles and drips hanging off it. It is unmistakable against moss on floors, walls and
  undersides. Wood cap is rotten planks with moss.
- Acid: a bubbling lime slime tile. Water: murky purple swamp water.
- Decor: mushroom x6, vine x2, crystal x2.
- Good: strongest mood of the five. Goo readability is excellent.
- Weak: the vine sprites are bushy plants, not hanging vines, because placement is ground-only.
  The soil is still dark, so deep pits feel heavy.

### snow (Snow Field)
- Backdrop: x4 alpine sky with lavender-shadowed peaks. Far layer is snowy pines with a log lodge
  band. Near layer is a snow-laden pine forest, extended down.
- Terrain: blue-grey frozen slate fill. **Snow cap**: soft, matte, pillowy white with cool
  lavender shading and lumpy undersides, no glare. **Ice cap**: a glassy cyan sheet with a hard
  white rim, diagonal glare bands, cracks and icicle teeth. The two cannot be confused, even at
  overview zoom. Rock cap is granite.
- Water: the meadow water pick, darker and colder. It reads as a cold lake.
- Decor: pine x3, snowman, ice_chunk x3, icicle x3, flag_slalom red/blue (hand), summit_flag
  (hand cairn and banner), rock x3 (snow-capped in code), flag_small.
- Good: ice versus snow readability. Cohesive cold palette. The sky is the best of the set.
- Weak: icicles cannot hang from ceilings (renderer). The soil is a strong cobble pattern.

### lab (Gravity Lab)
- Backdrop: x4 night sky with a lab complex, a planet and antenna towers. Far layer is teal
  reactor domes with lit windows, hazed toward navy. Near layer is a bench of green chemical vats
  and pipes.
- Terrain: navy riveted wall plating fill (a tech wall, not dirt). The rock cap is **metal floor
  plating**: a bright steel lip, diamond tread, a cyan light seam, and a yellow/black hazard band.
  The `grass` key is also mapped to plating in case a lab hole uses grass.
- Acid: a glowing green bubble liquid with pale-lime foam and a dark green edge. The lab `water`
  key is mapped to the same chemical.
- Decor: lab_light x3, console x2, fan, vat_pipe, arrow_up / arrow_down (hand-drawn holographic
  arrows on emitter posts). Gravity fields are left to ForceOverlay.
- Good: clearly sci-fi interior at night. Floors read strongly against the walls. The hazard
  band gives an SSF2-like platform edge.
- Weak: the acid tile is very saturated and busy next to the calm walls. Only one vat sprite.

### spin (Spin Land)
- Backdrop: x4 sunset sky. Far layer is a carnival (tents, ferris wheels, windmills), hazed warm
  to sit back. Near layer is tulip fields and fences, extended down.
- Terrain: red clay brick fill. Grass cap is bright scalloped clumps with pink, yellow and white
  flowers. Sand cap is warm and rippled. Rock cap is cut from a beige cobblestone tile.
  **conveyor_r / conveyor_l cap**: a plain dark rubber belt over steel rollers in a riveted frame
  with gold ticks. It has no chevrons, so ForceOverlay's moving chevrons read on top.
- Water: the meadow water pick, tinted toward sunset.
- Decor: windmill x3, pinwheel x3, balloon, gear x2, bush x2.
- Good: warm, festive, readable. The belt is unmistakable as machinery.
- Weak: the far carnival layer is still the busiest backdrop of the five, even after haze. Only
  one balloon sprite. Balloons sit on the ground.

## Honest assessment against the meadow and SSF2

- **Meadow parity:** all five match the meadow format and pixel density, and use x4 skies like
  the meadow sky. Backdrops beat the meadow (two parallax layers each, where the meadow has one).
  Caps are cleaner and more gameplay-legible than the meadow's grass because they are hand-pixeled.
  Soil fills are at meadow level or a little busier (beach strata, snow cobbles, spin bricks).
- **Versus SSF2 stage craft:** depth separation and surface readability are close. SSF2 stages
  still have far more bespoke set dressing: unique hero props, animated background elements, and
  foreground occluders. Our far and near layers are AI paintings, cleaned and quantised. They are
  coherent but generic in places, and repeated mirrored tiles show at wide zoom. There are no
  animated backdrop elements (spinning windmills, bubbling vats, waves). Decor variety is thin for
  some types (1 umbrella, 1 crab, 1 buoy, 1 balloon, 1 vat).
- **Rejected along the way:** every SDXL "water" tile (the LoRA paints leaves or shards instead
  of water; themes reuse the meadow water pick, recoloured). SDXL paint-overs of the grass caps
  (jobs/stage_caps.json; too noisy, so hand caps were kept). First palm and pine rolls (pattern
  sheets, snowfall backgrounds). Top-down umbrellas.

## Renderer changes needed (not made: lead to apply)

1. **Decor anchoring** (terrain_view.gd `_build_art_decor`). Every decor sprite is ray-cast to
   the ground below `(x, y-400)`. That is wrong for balloons (y -300 to -500 in the course data),
   buoys (should float on the water surface, not sit on the seabed), icicles (should hang from a
   ceiling), and vines in Sticky Zone (should hang from ledges). Suggested change: an optional
   world.json map `"decor_anchor": {"balloon": "free", "buoy": "water", "icicle": "ceiling",
   "vine": "ceiling"}`.
   - `free`: place the sprite's bottom-centre at the decor's (x, y) with no raycast.
   - `water`: snap y to the top of the zone rect containing x, and bob ±2 px.
   - `ceiling`: raycast **up** from (x, y) and place the sprite top-centre at the hit, using
     `offset = Vector2(-w/2, 0)`.
   The art is already drawn for this (the icicles point down from their top edge).
2. **Decor scale** (optional). The course decor `scale` field (lighthouse 1.2 / 0.8) is ignored
   in art mode. Multiply `ground_sprite` scale by `d.scale` if wanted (it breaks the strict 2x
   pixel grid unless the value is 1, 0.5 or 2, so we left it alone).
3. No other changes are needed. Multiple parallax layers, the `acid` zone material and the
   `snow` / `conveyor_r` / `conveyor_l` material keys all work with the current code.
