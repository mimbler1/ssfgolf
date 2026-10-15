# Character Art Specification (v2, "toon golfers")

Benchmark: the *feel* of Golf Blitz's golfers (readability, compact silhouettes, bold ink, playful
motion). Every design, name and asset here is original. We match qualities, never copy designs.

## 1. Why the v1 characters felt wrong

Compared against the reference screenshots (character select grid, hat screen, gameplay):

| Area | Reference | v1 (ours) | Fix |
|---|---|---|---|
| Anatomy | One soft "bean" body; no visible thighs, knees or elbows. | Human skeleton: thigh, shin, knee, elbow, separate torso. | Bean body + noodle arms; legs are short stubs or hidden. |
| Head | Head ≈ body width, about 35–40% of total height. | Head about 30%, on a thin neck over a narrow torso. | Head radius 14 on a 70-unit golfer (40% of the height). |
| Silhouette | Reads as one solid lump: head, body and arms fuse. | Reads as a stack of separate parts with gaps between limbs. | Merged silhouette outline; no gaps between legs and body. |
| Centre of gravity | Low and wide; the base sits flat on the ground. | High; long legs with narrow feet. | Widest point in the lower third of the body. |
| Outline | Very dark ink, about 3.5% of height in game, 2.5% in cards; smooth round joins. | 2.1-unit bake outline plus 1.5 inner lines in many colours. | One ink colour; outer width set in screen pixels; inner lines 55% of that. |
| Fill | Flat colours, one shadow tone, rare highlight. | Shadow and highlight crescents on every part, so it looks busy. | One shadow crescent per major mass and a small highlight only on heads and glossy items. |
| Club | Thick dark-outlined shaft; a big bright iron head; clearly in both hands. | Thin grey stick; small head; a hand-sized gap. | Club drawn as a character part: 1.6-unit shaft, an iron head of about 8×5, and the hands overlapping the grip. |
| Pose | Exaggerated: club over the shoulder, body curved like a "C". | Upright and stiff; small backswing. | Spine is a curve (lean + bend), with wrist hinge in the backswing. |
| Variety | Robots, snowmen and animals keep their own shapes. | Everyone shares one human body with costume colours. | Per-character body builders on a shared animation skeleton. |
| Card framing | The character fills about 85% of the card; same ground line for all. | Small, offset, and some heads cropped. | Normalise by measured artwork bounds with a shared baseline. |

## 2. Proportion guide (rig units, golfer faces +x, origin = ground between the feet)

The standard golfer is 70 units tall (91 px in game at 1.3×, about 5 ball diameters).

| Part | Standard | Notes |
|---|---|---|
| Feet/legs | 0–7 | Stubby: rounded shoes or nubs; may be hidden by robes or fur. |
| Body (bean) | 7–41 | Spine curve. Radii: base 11, middle 10, top 8.5. |
| Head | centre about −50, radius 14 | Overlaps the body top by 3 units, so there is no neck. |
| Shoulder | spine 78%, +2 forward | Both noodle arms start here. |
| Arms | width 4.6, reach 17 | Curved noodle with no elbow. Mitten hands with radius 3.6. |
| Club | 30 long | Pivots at the grip. The head reaches the ball at BALL_OFFSET (30). |

Characters may deviate deliberately: Frost is wider than tall, Tee-Rex is horizontal with a tail,
the wizard's robe hides the feet, and Bolt rolls on a wheel.

## 3. Ink and colour rules

- **Ink:** `#191a33` (dark navy) for all character outlines. The classic golfer's outline colour
  stays customisable.
- **Outer silhouette width (screen pixels):** `clamp(0.034 × displayed height, 2.6, 7)`.
  - Gameplay: about 3 px.
  - Cards: about 5 px.
  - Large preview: 7 px.
  - The renderer converts this to rig units each frame using the node's canvas scale.
- **Inner lines:** 55% of the outer width. They separate overlapping parts, such as an arm over the
  body or a hat over the head.
- **Shading:** one shadow tone (fill darkened 18–22%, nudged cool) on the side away from the
  top-left light. It is drawn as a crescent: the shadow-coloured shape, then the lit shape shifted
  toward the light. Highlights are only on heads, helmets, metal and glass.
- **No gradients, textures or glow** on bodies. Effects (sparkles, LEDs) are small and flat.
- **Accent colour:** each character has one strong accent that also drives its default ball trail.

## 4. Rendering pipeline

`Golfer` (Node2D) solves a pose on the shared skeleton, then calls the character's builder.
The builder emits parts into `ToonCanvas`:

1. **Silhouette pass:** every part, grown by the outer width, in ink. This makes one merged outline.
2. **Part pass, in layer order:**
   - rear effects;
   - back arm and back foot;
   - body;
   - clothing;
   - front foot;
   - head;
   - hair and headwear;
   - face;
   - held items and club;
   - front arm;
   - front effects.

   Each part draws an inner-width ink rim (when it overlaps something), its fill, its shadow
   crescent and its detail callback (faces, buttons, stripes).

Shapes are tubes (chains of convex circle hulls), ellipses, and local-space polygons that are
cached per grow size. The renderer never clips polygons at runtime, so it is cheap enough for 4
golfers in game and 15 in the card grid.

Everything is drawn live: recolours, hats and future decals follow the animated parts. There are no
baked sheets.

## 5. Animation rules

- The shared skeleton has these controls:
  - root offset and squash/stretch;
  - spine lean and bend;
  - head tilt;
  - feet;
  - hands (on the club or free);
  - club angle and wrist hinge;
  - expression.
- Swing timing (impact is near-immediate, so the ball leaves on the impact frame):

  | Phase | Time |
  |---|---|
  | Address (aim) | — |
  | Downswing | 45 ms |
  | Impact | 45 ms |
  | Follow-through | 45–300 ms, with a smear arc behind the club |
  | Hold | 300–550 ms |
  | Recover to watch | 550–750 ms |

- Idle: breathing squash (±2%), a blink every 2–5 s, a club waggle every 3 s, and secondary sway
  on accessories (plume, scarf, tail, antenna) driven by a spring.
- Each character can override motion through its definition, for example:
  - Bolt rolls instead of walking.
  - The robe and Frost's fur hide steps.
  - Tee-Rex's tail counter-swings.

## 6. Presentation rules

- Cards and previews use the same `Golfer` node and builder at different scales.
- Every character publishes its idle bounds (measured from the actual geometry).
  - The grid uses one shared scale for all cards, so size differences between characters stay
    meaningful.
  - All characters share a common ground baseline in the cards.
  - Each character is centred horizontally on its own bounds.
- Selected card: a 3 px sun-coloured border, a soft pulsing glow, and an "EQUIPPED" chip. It
  never covers the art.
