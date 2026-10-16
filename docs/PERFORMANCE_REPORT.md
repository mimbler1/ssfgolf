# Performance Report

Measured, not estimated. Every number here comes from a scripted run that is checked in, so it can
be repeated after any change.

**Test machine:** NVIDIA GeForce RTX 4080 SUPER, Windows 11, Godot 4.7.2 (Forward+), 1920x1080
window. VSync and the FPS cap are **off** during measurement, so frame time shows the actual work
and is not clamped to the display's refresh rate. The frame budget at 60 FPS is 16.7 ms.

## Golfer Studio (Milestone 1)

### How to reproduce

```powershell
tools/godot/Godot_v4.7.2-stable_win64_console.exe --path client --resolution 1920x1080 -- --profile perf --perf-studio "<abs path>/out.json" --perf-cycles 3
```

`scripts/dev/perf_probe.gd` drives the real studio through the directive's sequence. One cycle:

1. Open the studio.
2. Idle.
3. Scroll the roster top to bottom and back.
4. Switch character 30 times.
5. Switch to Stickman and equip/remove headwear 20 times.
6. Pick 20 colour swatches.
7. Preview every move and emote.
8. Return to the Character tab.
9. Save.
10. Go back to the main menu.

The cycle runs three times, so it also covers reopening the studio. Each phase records frame
count, average, 95th-percentile and worst frame time, and frames over 33 ms. Memory and object
counts are taken at fixed points. The probe presses Save, so it refuses to run without
`--profile`, which keeps a player's real local look untouched.

Raw results: `docs/perf/studio_before.log` (console log; that run stopped in cycle 3 on a since-fixed probe bug) and `docs/perf/studio_after1.json`.

### Root causes (confirmed by measurement and code inspection)

1. **Every card was a live, procedurally drawn golfer.** Each character card and option
   thumbnail had its own animated `Golfer` node, redrawn at 30 Hz. The legacy toon characters
   rebuild their whole body from polygons, ellipses and a merged outline on every redraw.
   An idle studio produced about 2,150–2,480 draw calls and 53–64 ms frames.
2. **Every click rebuilt the whole category.** Picking a character, hat or colour freed and
   re-created every card, and with each card a new `Golfer`, its bounds measurement and its first
   draw. This caused 100–160 ms hitches on each selection.
3. **Thumbnail updates were unthrottled.** Every look change re-applied the look to every
   thumbnail synchronously, and slider drags fire many changes per frame.

### Fixes

- `GolferView` is static by default. The golfer clock is frozen and per-frame processing is off,
  so a card draws once and then costs nothing per frame. Re-applying an identical look is
  skipped. `set_animated(true)` brings one view to life; it is used only while a card is hovered.
  The big preview is the only always-animated golfer.
- The studio restyles option cards in place (`_update_selection`) instead of rebuilding the
  category. This covers selected and equipped state, highlight borders and swatch rings. A
  category is rebuilt only when you switch tabs or edit saved looks.
- Thumbnail look updates are coalesced to at most once per frame (`_thumbs_dirty`).

### Results (1080p, three cycles; "before" is the build at commit 51c2f1f)

| Phase | Before: avg / p95 / max ms | After: avg / p95 / max ms | Frames over 33 ms (before → after) |
|---|---|---|---|
| Idle studio | 53.5–63.7 / 57.7–66.7 / 59–67 | 4.1–6.5 / 4.5–9.3 / 5.6–12.2 | all → 0 |
| Scroll roster | 53.8–60.6 / 56–65 / 63–73 | 4.5–8.7 / 5.1–10.3 / 5.3–14.3 | all → 0 |
| Switch 30 characters | 96.4–97.7 / 150 / 154–158 | 5.5–6.1 / 11.4–12.7 / 12.2–14.5 | all → 0 |
| Headwear equip x20 | 69.8–70.2 / 112–116 / 120–129 | 6.4–7.3 / 9.9–14.0 / 35–43 | all → 1 |
| Colour swatches x20 | 25.3–25.6 / 55 / 59–61 | 8.2–8.7 / 15–16.5 / 15.6–16.8 | 22–23 → 0 |
| Preview all animations | 7.4–8.1 / 17–18 / 19–20 | 3.7 / 4.1 / 5.0–5.6 | 0 → 0 |
| Save | 60.0–61.6 / 63–113 / 63–113 | 4.4–4.5 / 4.7–5.1 / 4.8–5.7 | all → 0 |
| Open studio (one-off) | first open max 137 | first open max 128, reopen max 80–82 | |

The "after" idle studio runs at about 230–250 FPS uncapped, against about 17 FPS before.

### Memory (after)

| Point | Static memory | Nodes | Orphan nodes |
|---|---|---|---|
| Menu (cycle 1 / 2 / 3) | 81.7 / 81.7 / 81.7 MB | 105 | 0 |
| Studio open (cycle 1 / 2 / 3) | 92.6 / 97.9 / 97.9 MB | 311 | 0 |

Memory returns to the same level every cycle, and there are no orphan nodes, so no leak was
observed across repeated open/close. The 5 MB rise between the first and second studio opens is
the warm-up of the shared sprite and bounds caches, and it stays flat afterwards.

### Remaining issues (tracked)

- **One-frame hitches remain.** Opening the studio still costs one 80–128 ms frame, and the first
  headwear pick one 35–43 ms frame. Both come from building legacy toon cards (bounds measurement
  of procedural golfers). They should disappear when the roster moves to sprite characters
  (Milestone 2), because sprite bounds are read from the sheet. If they don't, the next step is
  baking thumbnails once into cached textures on a background viewport.
- **Draw calls in the studio are still about 2,470.** These are the GPU commands of the static
  toon cards. They cost little on this GPU but would on weaker hardware. Sprite cards are one
  textured quad each, so these also go with Milestone 2.
- **Not measured:** the drawing editor (none exists in the codebase yet), and GPU time per
  frame. Godot's GPU timing monitors need the editor profiler; that is planned for Milestone 10.
- **Low-end hardware:** all numbers are from one high-end PC. A low-end pass (integrated GPU) is
  still to do.

## Gameplay

Not yet measured in this overhaul. Planned for Milestone 10, using the same probe approach for
practice holes and 6-ball online matches.
