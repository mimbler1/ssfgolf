# spin stage art: sources

Generated on the local GPU with SDXL base 1.0 + madebyollin/sdxl-vae-fp16-fix + nerijs/pixel-art-xl (LoRA 1.0) via `tools/artgen/stage_gen.py` (same job format as generate.py). Raw outputs land in tools/artgen/out/<job>/<seed>.png; the committed copies are in `picks/`.

Rebuild without the GPU:

```
tools/artgen/.venv/Scripts/python tools/artgen/stage_hand.py spin
tools/artgen/.venv/Scripts/python tools/artgen/stage_pick.py art/worlds/spin/decor.picks.json
tools/artgen/.venv/Scripts/python tools/artgen/build_stage.py spin
```

## Picks

| file | job (file) | seed | size | prompt |
|---|---|---|---|---|
| meadow_water_804.png | copied from another theme's picks | | | see that theme's SOURCES / jobs |
| spin_balloon_7823.png | spin_balloon (stage_spin.json) | 7823 | 768x1280  | bunch of shiny colorful party balloons on long strings tied to a small wooden stake, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| spin_bush_7841.png | spin_bush (stage_spin.json) | 7841 | 1024x1024  | single round green bush with pink and yellow flowers, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| spin_far_7202.png | spin_far (stage_spin.json) | 7202 | 1536x640  | wide panorama of rolling hills with old windmills, colorful carnival tents and a ferris wheel at sunset, isolated on a plain flat white background ; style: pixel art, 2d game stage background, crisp pixels, rich cel shading, vibrant saturated colors, highly detailed |
| spin_gear_7831.png | spin_gear (stage_spin.json) | 7831 | 1024x1024  | single big brass cog gear on a metal stand, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| spin_gear_7832.png | spin_gear (stage_spin.json) | 7832 | 1024x1024  | single big brass cog gear on a metal stand, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| spin_near_7302.png | spin_near (stage_spin.json) | 7302 | 1536x512  | wide panorama of green hedges, flower fields with tulips, wooden fences and leafy trees at sunset, isolated on a plain flat white background ; style: pixel art, 2d game stage background, crisp pixels, rich cel shading, vibrant saturated colors, highly detailed |
| spin_pinwheel_7811.png | spin_pinwheel (stage_spin.json) | 7811 | 768x1280  | single colorful toy pinwheel on a tall wooden stick, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| spin_pinwheel_7812.png | spin_pinwheel (stage_spin.json) | 7812 | 768x1280  | single colorful toy pinwheel on a tall wooden stick, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| spin_pinwheel_7813.png | spin_pinwheel (stage_spin.json) | 7813 | 768x1280  | single colorful toy pinwheel on a tall wooden stick, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| spin_rock_7502.png | spin_rock (stage_spin.json) | 7502 | 1024x1024 seamless | seamless tileable texture of warm beige cobblestone wall, rounded stones, even lighting ; style: pixel art texture, crisp pixels, cel shading, detailed |
| spin_sky_7101.png | spin_sky (stage_spin.json) | 7101 | 1536x768  | warm sunset countryside panorama, orange and pink sky with glowing golden clouds, distant pink rolling hills with tiny windmills and a ferris wheel, empty foreground ; style: pixel art, 2d game stage background, crisp pixels, rich cel shading, vibrant saturated colors, highly detailed |
| spin_sky_7101_x4.png | detail upscale of `art/worlds/spin/picks/spin_sky_7101.png` | 7 | x4 | img2img strength 0.4: warm sunset countryside panorama, orange and pink sky with glowing clouds, ferris wheel and windmill, fields |
| spin_soil_7403.png | spin_soil (stage_spin.json) | 7403 | 1024x1024 seamless | seamless tileable texture of warm red brown clay earth cross-section with small pebbles, roots and darker clumps, side view, low contrast, platform game ground fill ; style: pixel art texture, crisp pixels, cel shading, detailed |
| spin_windmill_7802.png | spin_windmill (stage_spin.json) | 7802 | 768x1280  | single old wooden windmill with four large sails and a red roof, side view, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| spin_windmill_7803.png | spin_windmill (stage_spin.json) | 7803 | 768x1280  | single old wooden windmill with four large sails and a red roof, side view, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| spin_windmill_7804.png | spin_windmill (stage_spin.json) | 7804 | 768x1280  | single old wooden windmill with four large sails and a red roof, side view, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |

## Processing

- `stage.src.json`: backdrop/terrain processing (grid snap, quantise, sky cut) and the world.json.
- `decor.picks.json`: decor sprite crops, sizes and clean-up flags (stage_pick.py).
- `hand/`: pixel pieces drawn in code by `tools/artgen/stage_hand.py` (caps, flags, signs) and the decor sprites written by stage_pick.py; `hand/flag.png` is the meadow cup flag.
- `guides/`: paint-over guides (hand cap scaled 8x) used by jobs/stage_caps.json.
