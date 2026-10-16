# HUD Specification

This describes the in-match HUD as implemented: `client/scripts/game/hud.gd`, `score_panels.gd`,
`ui/portrait.gd`, `render/aim_view.gd` and `render/trajectory_view.gd`. Screenshots are in
`docs/screens/v4/hud_*`.

## Player score panels (SSF2-inspired)

One panel per player sits along the top edge, split into a left group and a right group around
the hole banner. Right-side panels mirror, so the portraits face inward. The design takes its
principles from Super Smash Flash 2's player displays (big portrait, big number, strong colour).
No SSF2 graphics are used.

| Element | Shows |
|---|---|
| Portrait | The equipped character (see Portraits). It sits in a well tinted with the player's slot colour |
| Big number | **Blitz:** match points. **Stroke play:** strokes on this hole. **Practice:** shots |
| Caption under the number | Names the scoring system: `PTS / <target>`, `STROKES · PAR <n>` or `SHOTS`. Points are never confused with strokes |
| Name | Display name, plus "(YOU)" on the local player's panel, which also gets a bright frame |
| Placement badge (Blitz) | 1ST–6TH by match points. Ties share a place |
| Status | `HOLED` once finished this hole; `RECONNECTING` or `LEFT` for connection state, with the panel dimmed |
| Slot colour | Bottom bar and frame, one of six: yellow, cyan, pink, green, purple, orange |

**Score changes.** The authoritative value arrives in a snapshot (or from the local sim). The
number pops (scale 1.45 → 1, 0.35 s, back-ease), the panel flashes in the player colour for
0.6 s, and the placement badge updates. Nothing blocks input or gameplay.

## Adaptive layout

Size classes, in canvas pixels on the 1920×1080 base canvas:

| Players | Class | Panel | Portrait | Score font | Name font |
|---|---|---|---|---|---|
| 1–2 | L | 360 × 116 | 100 | 64 | 22 |
| 3–4 | M | 292 × 100 | 86 | 54 | 19 |
| 5–6 | S | 236 × 88 | 74 | 46 | 17 |
| Last resort | XS | 200 × 80 | 64 | 40 | 15 |

- **Groups and rows.** The left group gets ⌈n/2⌉ panels, the right group the rest. A group is laid
  out in one row if it fits beside the 360 px banner; otherwise it wraps to two rows. Only if two
  rows still do not fit does it drop one size class.
- **Small windows.** The game renders a 1920×1080 canvas scaled to the window (stretch mode
  `canvas_items`, aspect `expand`). On windows smaller than about 1630×920, panels are enlarged by
  up to 1.5× (`0.85 / screen scale`), so on-screen text stays readable and the groups wrap to two
  rows rather than the text shrinking. On-screen sizes at 1280×720 with 6 players are: score about
  39 px, name about 14 px, caption about 11 px.
- **Verified** with real renders, saved as `docs/screens/v4/hud_<n>p_<res>.png`:
  - 2–6 players at 1920×1080;
  - 4 and 6 players at 1280×720;
  - 6 players at 1160×736, 2560×1440 and 3440×1440.

  The panels never cover the tee, the ball or the ability bar, and the menu button moved to the
  bottom-right for them. On small windows with 5–6 players, the two-row groups take about 22% of
  the screen height in the top corners.

## Portraits

`Portrait.texture_for(character)` is cached per character. It tries, in order:

1. The authored `assets/characters/<id>/portrait.png`, from the character art track.
2. A head-and-shoulders crop of the first idle sprite frame.
3. For legacy toon characters, a static head-framed golfer (drawn once).

The HUD never regenerates portraits during play.

## Aiming (directive §5, §7)

| Element | When | Notes |
|---|---|---|
| Aim arrow | While aiming, in both control styles | Solid ink-outlined arrow (never dots). Length follows power; the colour runs white → gold → red with power, tinted by the selected ball |
| Power % | At the arrow tip | The actual power sent, including the putting scale |
| PUTT tag | Putting profile active | Within 420 px of the cup, on the ground |
| Spin readout | Spin set | "TOPSPIN 75%" or "BACKSPIN 50%", plus a rotating ring |
| Classic power meter | Classic controls | Horizontal 12-cell bar under the ball with a moving marker |
| Laser guide | **Only** with the Laser Ball selected | Red beam to the first bounce, a short fade after, crosshair at the landing |
| Debug flight path | **Only** in practice, with the toggle on | White dots, clearly not the laser |

## Ability bar

Six cards per page. Q flips pages (14 balls online, plus Free Shot in stroke play). Keys 1–6 pick
on the current page, or click a card. Each card shows the hotkey, icon, name and cost pips
(energy online, charges left in stroke play). The selected card is lifted and framed in the
ball's colour; cards you can't afford are dimmed. The energy bar sits above the cards and is
hidden in stroke play.

**Status:** layout and behaviour are final. The icons are still the old vector glyphs; pixel-art
icons and card frames are in production (UI art track) and will replace them without layout
changes.

## Other HUD elements

- **Hole banner (top centre):** hole number, then name with `First to N` (Blitz) or `Par N`
  (stroke play).
- **Finish-window timer:** a pill under the banner.
- **Announcements:** large centre text such as GO!, 1ST!, BIRDIE! and HOLE IN ONE!.
- **Toasts:** smaller centre messages, such as "Shield saved you!" and "SWISH!".
- **Controls card (bottom-left):** fades after the first shot.
- **"Shots this hole" (Blitz):** bottom-right.

## Not yet done

- Off-screen opponent indicators (arrows at the screen edge).
- Pixel-art icons and frames for the ability bar.
- An optional compact layout for spectators.
