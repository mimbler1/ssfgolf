# Sprite Character Pipeline (v3)

Finished golfers are hand-authored pixel art, frame by frame. The live vector rig
(`Golfer` + `ToonCanvas` + `ToonParts`/`ToonCharacters`/`ToonRoster`, see CHARACTER_ART_SPEC.md)
is now a prototype path only. It stays for the existing roster until each character has sprite
art, and it must not be used to make new finished characters.

## Why the old characters looked like vector cartoons

They are drawn every frame from `draw_colored_polygon` / `draw_circle` / `draw_line` calls:
bean bodies, tube limbs and ellipse eyes, posed by an IK skeleton, with a computed outline.
The PNGs in `assets/characters/*.png` (ace, nana...) are bakes of that same rig, so they are not
sprite art either. No amount of rig tuning turns that into pixel art.

## Source format

```
art/characters/<id>/
  palette.txt            key  hex  region  role     (one char per colour; '.' = transparent)
  character.src.json     anims (frame names + ms), contact frame, anchors, variants, slots
  src/<anim>_<NN>.txt    one frame: 128 rows x 96 palette keys = one key per pixel
  review/                approval images (native, 4x, gameplay, in-game screenshots)
```

The grid is the editable master. Edit it directly, or paint in Aseprite or LibreSprite with the
palette loaded and convert back. Each pixel is chosen by hand. The tools only validate and
render; they never generate art.

## Tools

| Command | What it does |
|---|---|
| `python tools/sprites/build_character.py <id>` | Validates, then exports `client/assets/characters/<id>/<anim>.png` strips and `character.json` |
| `... --check` | Validates only (part of `tools/dev.ps1 test`) |
| `python tools/sprites/preview.py <dir> <frame> out.png` | Native, 4x and gameplay-size review sheet |
| `python tools/sprites/zoom.py <dir> <frame> x0 y0 x1 y1 k out.png` | Magnified crop for pixel review |

Validation checks: grid size and keys; that the frame bottom sits on the pivot row (no foot
jitter); a transparent margin; no orphan pixels; anchors inside the frame; that variants only
touch recolourable regions; and the frame count against each animation's target.

## Frame specification

- 96 x 128 px per frame, RGBA, pivot (48, 124) = ground point between the feet.
- 1 sprite px = 1 world px at camera zoom 1 (`rig_units_per_px` 0.7692 cancels `GOLFER_SCALE` 1.3).
- Drawn with nearest-neighbour filtering. No smoothing, glow or fake pixelation.

| Anim | Target frames | Game animations that use it |
|---|---|---|
| idle | 8 | idle, emotes (until emote art exists) |
| prepare | 6 | aim |
| swing | 12 | swing (`contact_frame` is aligned to the shot event) |
| recovery | 6 | watch |
| walk | 8 | walk |
| victory | 12 | celebrate, victory, dance |
| defeat | 8 | sad |

Missing animations fall back to idle, so a character can be reviewed before its set is done.
It stays `hidden` in `CharacterDefs` until every target is met and approved.

## Runtime

`SpriteCharacter` (scripts/render/sprite/sprite_character.gd) loads `character.json` and the
strips. `Golfer` draws sprite frames whenever the character has them, so match, studio, cards and
the emote wheel need no changes.

Swing timing: the swing anim is offset so that its `contact_frame` starts exactly `Golfer.IMPACT`
seconds after `swing()` is called. That is the moment the client shows the accepted shot's ball
launch. The animation never moves the ball. Ball position, velocity, collisions, cooldowns and
scoring stay server-authoritative in `MatchSim`.

## Customisation on sprite art

| Feature | Method | Status |
|---|---|---|
| Recolours | Exact palette swap of artist-authored ramps per region (`variants`) | Implemented (`SpriteCharacter.load_for(id, variant)`); not yet in the profile/appearance schema |
| Hats / back items | Per-frame anchors (`head_top`, `back`) + hat art drawn per pose family | Anchors defined; no hat art yet |
| Club cosmetics | Palette swap of club metal/grip keys | Planned |
| Player drawings on clothes | Per-frame UV map: each shirt pixel stores the (u, v) of a 16x16 drawing canvas, so the drawing follows every pose | Designed (`surfaces`), not built. Needs a UV layer authored for every frame |
| Different body shapes | A separate sprite set per character | By design; no freeform rig |

Rigid overlays that ignore the pose are not offered as "freeform" customisation.

## Approval gate

1. Concept and one finished idle frame. **← current (adventurer idle_00)**
2. Review at native, 4x, gameplay size and in-game.
3. Fix the style until approved.
4. Draw the remaining 59 frames. Keep anchors filled per frame.
5. Demo every animation in game. Remove `hidden`.
6. Only then start the next character.
