# Visual Overhaul Progress (v3, SSF2-inspired)

Updated 2026-10-15. See ART_STYLE_GUIDE.md (standards), VISUAL_AUDIT.md (what was replaced),
SPRITE_PIPELINE.md (character format). Screenshots: docs/screens/v3/.

## Art production pipeline (done)

| Step | Tool |
|---|---|
| Generate candidates on the local GPU (SDXL + pixel-art-xl LoRA, licences cleared for commercial use) | `tools/artgen/generate.py` + `jobs/*.json` |
| Seamless terrain tiles (circular padding) | `"tile": true` in a job |
| Paint-over of authored guides (grass edges, golfer poses) | `"init"` + `"strength"` in a job |
| 2x detail re-render of wide backdrops | `tools/artgen/upscale.py` |
| Grid snap, palette quantise, background and sky cut, defringe, outline | `tools/artgen/pixelize.py` |
| Cut prop sheets into sprites | `tools/artgen/extract_sprites.py` |
| Stage build: picks to `client/assets/worlds/<theme>/` + `world.json` | `tools/artgen/build_stage.py meadow` |
| Golfer animation: pose guides, painted sheet, grounded frames, authored club, outline | `tools/artgen/pose_sheet.py`, `build_golfer.py` |
| Effect flipbooks | `tools/artgen/build_fx.py` |

Raw generations stay local (`tools/artgen/out`, git-ignored). Chosen picks are committed under
`art/` so builds are reproducible without the GPU.

## First milestone checklist

| Requirement | Status |
|---|---|
| Three original sprite golfers | Done: Rex, Mira, Bjorn (distinct silhouettes) |
| Idle and swing animations | Done: 6-frame idle and 8-frame swing. Aiming shows the backswing by shot power; the impact frame is aligned to the shot event |
| Detailed original stage background | Done: illustrated sky and mountains (768 px) plus a castle-hills parallax layer |
| Detailed grass and ground | Done: painted grass edge, depth-shaded earth, gameplay material strips |
| Soil, water and hazard materials | Done: water is a textured, drifting body with a foam line. Bouncy, sticky, ice and wood have hand-made strips. Lava and acid have no art yet (no course uses them) |
| Working physics | Unchanged and verified: sim 81/81, playable 10/10, e2e online passes |
| HUD in the new style | Partly done: arcade panels, slanted cards and energy cells, display font. Icons are still the old vector glyphs |
| Impact effects | Done: impact, dust, splash, cup sparkle, nitro flame flipbooks |
| Playable hole, controls, camera | Done, using the existing systems |
| In-game screenshots | Done: 1280x720, 1920x1080, 2560x1440 practice, 3-player online, menu |
| No temporary vector scenery | Partly done: all Sunny Meadows terrain, backdrop, decor, flag and water are authored art. Trajectory dots, ball, trail and particle sparks are still procedural |

## Known gaps (honest)

- **Golfer detail is below SSF2.** The frames are clean and consistent, but shading is simple and
  bodies are small (about 30 art px). Next: a detail pass (img2img at about 0.35) and hand
  cleanup of faces and hands.
- **Missing animations:** walk, victory, defeat and emotes fall back to idle. The Adventurer
  (hand-grid, 86 px) is the wrong density and stays hidden.
- **Soil** is a strata texture. It reads well but is busy. A better pick is still to come.
- **Backdrop:** there is no near forest layer yet, so a flat green fill shows below the hills.
- **Not redesigned yet:** menus, the Golfer Studio, results, collection and packs. They inherit
  the new backdrop, font and panels but not new layouts. Collection, packs and leaderboards have
  no screens in the code yet.
- **Customisation on sprites:** only palette-swap recolour is implemented. Equipment layers and
  drawing on clothes are designed, not built (SPRITE_PIPELINE.md).
- **Hazard objects** (portals, lasers, moving platforms) do not exist in the simulation yet.
  They are gameplay work first.
