# Reference analysis: the Fancy Pants Adventures visual language

Compiled 2026-10-16 before any ink-style art was made. It records what the reference games do
visually, so that our original art follows the same *visual language* without copying any
character design, level, asset or animation frame.

## Sources studied

| Source | What was examined |
|---|---|
| Super Fancy Pants Adventure, Steam store screenshots (app 668210, 9 images at 1920×1080) | Polished modern style: character, terrain, layering, palette, HUD |
| The Fancy Pants Adventures Classic Pack, Steam store screenshots (app 1668460, 8 images at 1920×1080) | Worlds 1–3 style: black ink terrain, scribble texture, paper backgrounds |
| Enlarged crops of the player character from eight of those screenshots (4× zoom) | Proportions, line weight, pants, hair, feet |
| bornegames.com, the Kongregate developer Q&A, and the YouTube trailer (links supplied) | Linked for context. The video was not viewable from this environment, so no motion was measured from it. Motion rules below come from the stills and general knowledge of the games. |

The screenshots were kept in a local scratch folder for study only. They are **not** in the
repository, and nothing was traced or sampled from them.

## 1. Character

### Proportions (measured on the enlarged crops)

| Part | Share of standing height (feet to head top, hair excluded) |
|---|---|
| Head (circle diameter) | ≈ 22% |
| Neck + torso (head bottom to waist) | ≈ 30% |
| Waist to ground (almost all of it pants) | ≈ 46% |
| Arm, shoulder to fingertip | ≈ 42%; hands hang near mid-thigh |

- **Head:** a slightly imperfect circle drawn as **an outline only. The inside is not filled:
  the background shows through.** It has no ears, nose, cheeks or jaw. At gameplay size it has no
  facial features at all. Larger cutscene and portrait art adds dot eyes and a single mouth line.
- **Hair:** 2–4 large spikes swept back and up from the crown. They are drawn as **open outline
  strokes with no fill**, starting and ending on the head circle so they never cross the face.
  It reads as messy and scribbled, not as a helmet.
- **Torso and neck:** one single ink stroke, gently curved, with no shoulders drawn.
- **Arms:** one stroke each, bending at an elbow. They are long and loose. **There are no hands
  drawn**: the stroke just ends with a round cap. Hands only appear when holding something.
- **Legs:** single strokes, mostly hidden by the pants. Only the shin and ankle show below the
  cuff.
- **Feet:** tiny solid black wedges, slightly pointed forward.
- **Silhouette:** a big circle on a thin line over a bold coloured triangle. It reads instantly
  even at about 40 px tall.

### Line quality

- Body strokes are about **3% of figure height** wide. That is 3 px at a 100 px figure, so
  2–4 px at our gameplay sizes.
- Stroke ends are round. Width varies slightly along a stroke, like a pen whose pressure changes.
  Curves are smooth, Flash-vector style, with no visible polygon facets.
- The ink is near-black (`#141414`–`#1e1a1a`). It is the same on the body, hair and pants.
- Pants outlines are similar in weight to the body lines or a little thinner. Fold lines
  inside the pants are thin and short.

### Pants (the signature element)

- They are **a flat, saturated fill with an ink outline**, with no gradients.
- **The shape:** from a narrow waist the pants flare out to a wide, open bell or triangle cuff
  at the ankle. Each leg is its own lobe. Standing, the two lobes merge into one trapezoid with a
  notch between the legs.
- **In motion** the pants deform heavily. When running, the two lobes stretch into long flapping
  cones. In the air they billow out and trail backwards. The hem edge goes irregular and wavy.
- **The fabric lags behind the legs.** The cuff follows the ankle with a delay and overshoot, so
  the pants feel like cloth on a fast, light body.

### Animation principles (from poses in the stills)

- The poses are extreme and readable: long lean angles, wide strides, arms flung back.
- Bodies arc: the torso curves into the motion direction instead of staying straight.
- Secondary motion appears on the pants, and on the hair to a lesser degree.
- The weight is light: the character looks like it barely touches the ground.

## 2. Environments

### Super Fancy Pants Adventure (polished)

- **Sky:** pale warm grey-lilac (`#e6dedd`-ish) or soft pale blue, almost flat, with a very
  subtle paper-like grain.
- **Far layers:** low-contrast silhouettes of mountains and hills, desaturated and pushed toward
  the sky colour. Their edges are softened or blurred, and some have very faint outlines.
- **Mid layers:** flat rolling hills and tree masses in desaturated greens. The outlines are a
  slightly darker *shade of the same hue*, never black.
- **Foreground terrain:**
  - Saturated flat fill.
  - Outlined in a darker shade of its own colour.
  - Layered *contour bands* follow the surface: a lighter lip at the top, darker strata below,
    and curved highlight strokes that follow the slope.
  - Grass has small white, purple and pink dot flowers and occasional blade strokes. Nothing on
    it repeats like a tile.
- **Props and platforms:**
  - Thick dark outlines, chunky hand-drawn shapes and goo drips.
  - Crosshatch or woven patterns on structures.
- **Trees:** big curved trunks with darker outlines, and blob foliage with leaf-shaped marks.

### Classic worlds (World 1–3)

- **Backgrounds:** paper-coloured, with huge faint swirl and leaf silhouettes as decoration.
- **Ground:**
  - Black ink outlines on the top surface.
  - A thick green grass band over brown soil.
  - Rock is filled with **scribbled hatch strokes**: dense, loose, visibly hand-made.
- **Water and ice:** pale blue with short ink ripple and crack strokes on the edges.
- **Trees:** scribbly pine trees with dense hatched foliage.

### Scale and depth

- The character is small relative to the screen (about 4–6% of screen height). The world reads
  as big and open.
- Depth comes from colour: each receding layer is lighter, less saturated and lower contrast.
  The pictures don't rely on blur or heavy parallax.

## 3. Colour

- **The palette is simple and confident:** the pants are the strongest accent. Terrain uses one
  saturated hue per material. Backgrounds are muted.
- **There is almost no gloss**: the only gradients are atmospheric (sky) and soft vertical soil
  darkening.
- **Each world has its own key colour.** Examples: sand-orange, purple cave, cyan water.

## 4. UI and effects

- **The HUD is minimal.** It has:
  - a top-left bar with an ink outline;
  - a swirl icon with a **hand-lettered** count;
  - a warning-triangle icon.
- **Speech bubbles** are hand-drawn white ellipses with ink outlines and hand-lettered text.
- **Effects are drawn, not particle-glossy.** They are:
  - curved white speed streaks;
  - outlined white smoke puffs;
  - scribble spirals for collectibles;
  - a thin straight laser line.

## 5. Rules we take from this (summary for the art spec)

1. Ink first: near-black round-capped strokes, about 3% of figure height, with slight pressure
   variation.
2. The stick figure is a hollow head, single-stroke torso, arms and legs, no drawn hands, tiny
   black shoes, and big flat-filled flared pants.
3. Pants and hair lag behind the body (spring secondary motion), and their shapes deform with
   speed.
4. Terrain is a flat saturated fill plus contour bands plus hand-placed sketch marks, with the
   outline following the real collision edge exactly.
5. Backgrounds are paper-pale, low contrast and atmospheric, with same-hue outlines.
6. The UI uses hand-lettered type, ink-outlined paper shapes and very little chrome.

## What we deliberately do differently (originality)

- **The default golfer is not orange-panted.** The starter pants are a different colour and cut
  from the reference's signature garment. Our hair styles, pants cuts and accessories are our own
  designs.
- **No reference level layouts, enemies, logos, swirl collectibles or the reference's font are
  used.** Our type is OFL-licensed handwriting fonts.
- **Golf-specific readability needs:**
  - Gameplay surfaces get stronger ink than the reference, because the ball must read against
    every material.
  - A player-colour marker sits on each golfer. With six players on screen, identity can't rely
    on pants colour alone.
