# beach stage art: sources

Generated on the local GPU with SDXL base 1.0 + madebyollin/sdxl-vae-fp16-fix + nerijs/pixel-art-xl (LoRA 1.0) via `tools/artgen/stage_gen.py` (same job format as generate.py). Raw outputs land in tools/artgen/out/<job>/<seed>.png; the committed copies are in `picks/`.

Rebuild without the GPU:

```
tools/artgen/.venv/Scripts/python tools/artgen/stage_hand.py beach
tools/artgen/.venv/Scripts/python tools/artgen/stage_pick.py art/worlds/beach/decor.picks.json
tools/artgen/.venv/Scripts/python tools/artgen/build_stage.py beach
```

## Picks

| file | job (file) | seed | size | prompt |
|---|---|---|---|---|
| beach_buoy_3851.png | beach_buoy (stage_beach.json) | 3851 | 768x1280  | single red and white channel marker buoy on a tall wooden post with a small lamp, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| beach_crab_3841.png | beach_crab (stage_beach.json) | 3841 | 1024x1024  | single cute red cartoon crab with raised claws, side view, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| beach_far_3202.png | beach_far (stage_beach.json) | 3202 | 1536x640  | wide panorama of tall orange sandstone sea cliffs and rocky islets with palm trees and a small white lighthouse above turquoise sea, isolated on a plain flat white background ; style: pixel art, 2d game stage background, crisp pixels, rich cel shading, vibrant saturated colors, highly detailed |
| beach_lighthouse_3812.png | beach_lighthouse (stage_beach.json) | 3812 | 768x1280  | single tall red and white striped lighthouse on a small rocky base, glowing lamp room, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| beach_near_3303.png | beach_near (stage_beach.json) | 3303 | 1536x512  | wide panorama of golden sand dunes with tall dune grass, wooden beach fences, palm trees and small beach huts, isolated on a plain flat white background ; style: pixel art, 2d game stage background, crisp pixels, rich cel shading, vibrant saturated colors, highly detailed |
| beach_palm2_3862.png | beach_palm2 (stage_fix1.json) | 3862 | 768x1024  | one single coconut palm tree standing alone, slightly curved trunk, green fronds, full tree visible with empty space around it, game sprite, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| beach_palm2_3863.png | beach_palm2 (stage_fix1.json) | 3863 | 768x1024  | one single coconut palm tree standing alone, slightly curved trunk, green fronds, full tree visible with empty space around it, game sprite, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| beach_props_3821.png | beach_props (stage_beach.json) | 3821 | 1024x1024  | sprite sheet of beach props: seashells, starfish, grey boulders, dune grass tufts, driftwood, arranged in a grid, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| beach_props_3822.png | beach_props (stage_beach.json) | 3822 | 1024x1024  | sprite sheet of beach props: seashells, starfish, grey boulders, dune grass tufts, driftwood, arranged in a grid, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| beach_rock_3502.png | beach_rock (stage_beach.json) | 3502 | 1024x1024 seamless | seamless tileable texture of grey brown coastal rock wall, stacked wet stones with barnacles and seaweed, even lighting ; style: pixel art texture, crisp pixels, cel shading, detailed |
| beach_sky_3101.png | beach_sky (stage_beach.json) | 3101 | 1536x768  | tropical seaside sky panorama, bright blue sky, huge fluffy white cumulus clouds with soft lavender shading, calm turquoise sea horizon along the bottom, distant green islands, empty foreground ; style: pixel art, 2d game stage background, crisp pixels, rich cel shading, vibrant saturated colors, highly detailed |
| beach_sky_3101_x4.png | detail upscale of `art/worlds/beach/picks/beach_sky_3101.png` | 7 | x4 | img2img strength 0.4: tropical seaside sky panorama, bright blue sky, huge fluffy white cumulus clouds with soft lavender shading, calm turquoise sea horizon |
| beach_soil_3402.png | beach_soil (stage_beach.json) | 3402 | 1024x1024 seamless | seamless tileable texture of layered warm sandstone rock cross-section, horizontal tan and orange strata, small embedded shells and pebbles, side view, low contrast, platform game ground fill ; style: pixel art texture, crisp pixels, cel shading, detailed |
| beach_umbrella2_3871.png | beach_umbrella2 (stage_fix1.json) | 3871 | 1024x1024  | one red and white striped beach parasol, straight side view, open canopy on a tall pole, no shadow, game sprite, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| meadow_water_804.png | copied from another theme's picks | | | see that theme's SOURCES / jobs |

## Processing

- `stage.src.json`: backdrop/terrain processing (grid snap, quantise, sky cut) and the world.json.
- `decor.picks.json`: decor sprite crops, sizes and clean-up flags (stage_pick.py).
- `hand/`: pixel pieces drawn in code by `tools/artgen/stage_hand.py` (caps, flags, signs) and the decor sprites written by stage_pick.py; `hand/flag.png` is the meadow cup flag.
- `guides/`: paint-over guides (hand cap scaled 8x) used by jobs/stage_caps.json.
