# snow stage art: sources

Generated on the local GPU with SDXL base 1.0 + madebyollin/sdxl-vae-fp16-fix + nerijs/pixel-art-xl (LoRA 1.0) via `tools/artgen/stage_gen.py` (same job format as generate.py). Raw outputs land in tools/artgen/out/<job>/<seed>.png; the committed copies are in `picks/`.

Rebuild without the GPU:

```
tools/artgen/.venv/Scripts/python tools/artgen/stage_hand.py snow
tools/artgen/.venv/Scripts/python tools/artgen/stage_pick.py art/worlds/snow/decor.picks.json
tools/artgen/.venv/Scripts/python tools/artgen/build_stage.py snow
```

## Picks

| file | job (file) | seed | size | prompt |
|---|---|---|---|---|
| beach_props_3821.png | beach_props (stage_beach.json) | 3821 | 1024x1024  | sprite sheet of beach props: seashells, starfish, grey boulders, dune grass tufts, driftwood, arranged in a grid, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| meadow_water_804.png | copied from another theme's picks | | | see that theme's SOURCES / jobs |
| snow_far_5203.png | snow_far (stage_snow.json) | 5203 | 1536x640  | wide panorama of snowy hills covered with a dense forest of snow covered pine trees, a small wooden ski lodge, isolated on a plain flat red background ; style: pixel art, 2d game stage background, crisp pixels, rich cel shading, vibrant saturated colors, highly detailed |
| snow_near_5301.png | snow_near (stage_snow.json) | 5301 | 1536x512  | wide panorama of deep snow drifts with dark green snowy pine trees and grey rocks, isolated on a plain flat red background ; style: pixel art, 2d game stage background, crisp pixels, rich cel shading, vibrant saturated colors, highly detailed |
| snow_pine2_5862.png | snow_pine2 (stage_fix1.json) | 5862 | 768x1280  | one single dark green fir tree with snow on its branches, full tree visible, no ground, no snowfall, game sprite, isolated on a plain flat red background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| snow_pine2_5864.png | snow_pine2 (stage_fix1.json) | 5864 | 768x1280  | one single dark green fir tree with snow on its branches, full tree visible, no ground, no snowfall, game sprite, isolated on a plain flat red background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| snow_props_5821.png | snow_props (stage_snow.json) | 5821 | 1024x1024  | sprite sheet of winter props: blue ice blocks, ice crystal spikes, snowy grey boulders, frozen bushes, arranged in a grid, isolated on a plain flat red background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| snow_props_5823.png | snow_props (stage_snow.json) | 5823 | 1024x1024  | sprite sheet of winter props: blue ice blocks, ice crystal spikes, snowy grey boulders, frozen bushes, arranged in a grid, isolated on a plain flat red background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| snow_rock_5502.png | snow_rock (stage_snow.json) | 5502 | 1024x1024 seamless | seamless tileable texture of grey granite stone blocks with patches of snow and frost, even lighting ; style: pixel art texture, crisp pixels, cel shading, detailed |
| snow_sky_5102.png | snow_sky (stage_snow.json) | 5102 | 1536x768  | snowy alpine mountain range panorama, bright winter blue sky, soft white clouds, sunlit snowy peaks with blue and lavender shadows, empty foreground ; style: pixel art, 2d game stage background, crisp pixels, rich cel shading, vibrant saturated colors, highly detailed |
| snow_sky_5102_x4.png | detail upscale of `art/worlds/snow/picks/snow_sky_5102.png` | 7 | x4 | img2img strength 0.4: snowy alpine mountain range panorama, bright winter blue sky, white clouds, sunlit snowy peaks with lavender shadows |
| snow_snowman_5811.png | snow_snowman (stage_snow.json) | 5811 | 1024x1024  | single cute snowman with carrot nose, red scarf and stick arms, isolated on a plain flat red background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| snow_soil_5401.png | snow_soil (stage_snow.json) | 5401 | 1024x1024 seamless | seamless tileable texture of frozen blue grey mountain rock cross-section, layered slate with frost and thin ice veins, side view, low contrast, platform game ground fill ; style: pixel art texture, crisp pixels, cel shading, detailed |

## Processing

- `stage.src.json`: backdrop/terrain processing (grid snap, quantise, sky cut) and the world.json.
- `decor.picks.json`: decor sprite crops, sizes and clean-up flags (stage_pick.py).
- `hand/`: pixel pieces drawn in code by `tools/artgen/stage_hand.py` (caps, flags, signs) and the decor sprites written by stage_pick.py; `hand/flag.png` is the meadow cup flag.
- `guides/`: paint-over guides (hand cap scaled 8x) used by jobs/stage_caps.json.
