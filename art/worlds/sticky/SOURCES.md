# sticky stage art: sources

Generated on the local GPU with SDXL base 1.0 + madebyollin/sdxl-vae-fp16-fix + nerijs/pixel-art-xl (LoRA 1.0) via `tools/artgen/stage_gen.py` (same job format as generate.py). Raw outputs land in tools/artgen/out/<job>/<seed>.png; the committed copies are in `picks/`.

Rebuild without the GPU:

```
tools/artgen/.venv/Scripts/python tools/artgen/stage_hand.py sticky
tools/artgen/.venv/Scripts/python tools/artgen/stage_pick.py art/worlds/sticky/decor.picks.json
tools/artgen/.venv/Scripts/python tools/artgen/build_stage.py sticky
```

## Picks

| file | job (file) | seed | size | prompt |
|---|---|---|---|---|
| sticky_acid_4603.png | sticky_acid (stage_sticky.json) | 4603 | 1024x1024 seamless | seamless tileable texture of bubbling toxic lime green slime liquid with round bubbles and bright highlights, even lighting ; style: pixel art texture, crisp pixels, cel shading, detailed |
| sticky_crystal_4821.png | sticky_crystal (stage_sticky.json) | 4821 | 1024x1024  | single cluster of glowing purple and teal crystals on a small rock, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| sticky_crystal_4822.png | sticky_crystal (stage_sticky.json) | 4822 | 1024x1024  | single cluster of glowing purple and teal crystals on a small rock, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| sticky_far_4202.png | sticky_far (stage_sticky.json) | 4202 | 1536x640  | wide panorama of a forest of giant glowing purple and teal mushrooms and twisted jungle trees with hanging vines, isolated on a plain flat white background ; style: pixel art, 2d game stage background, crisp pixels, rich cel shading, vibrant saturated colors, highly detailed |
| sticky_mushroom_4801.png | sticky_mushroom (stage_sticky.json) | 4801 | 1024x1024  | single giant glowing fantasy mushroom with purple spotted cap and pale stem, small mushrooms at its base, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| sticky_mushroom_4802.png | sticky_mushroom (stage_sticky.json) | 4802 | 1024x1024  | single giant glowing fantasy mushroom with purple spotted cap and pale stem, small mushrooms at its base, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| sticky_mushroom_4803.png | sticky_mushroom (stage_sticky.json) | 4803 | 1024x1024  | single giant glowing fantasy mushroom with purple spotted cap and pale stem, small mushrooms at its base, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| sticky_mushroom_4804.png | sticky_mushroom (stage_sticky.json) | 4804 | 1024x1024  | single giant glowing fantasy mushroom with purple spotted cap and pale stem, small mushrooms at its base, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| sticky_near_4302.png | sticky_near (stage_sticky.json) | 4302 | 1536x512  | wide panorama of dense dark swamp jungle foliage, big ferns, glowing mushrooms and hanging vines dripping purple slime, isolated on a plain flat white background ; style: pixel art, 2d game stage background, crisp pixels, rich cel shading, vibrant saturated colors, highly detailed |
| sticky_rock_4502.png | sticky_rock (stage_sticky.json) | 4502 | 1024x1024 seamless | seamless tileable texture of dark mossy purple grey stone blocks with teal moss, even lighting ; style: pixel art texture, crisp pixels, cel shading, detailed |
| sticky_sky_4102.png | sticky_sky (stage_sticky.json) | 4102 | 1536x768  | alien slime jungle at purple dusk, magenta and violet sky with pink glowing clouds, huge pale moon, distant purple mountains and giant mushroom silhouettes, empty foreground ; style: pixel art, 2d game stage background, crisp pixels, rich cel shading, vibrant saturated colors, highly detailed |
| sticky_sky_4102_x4.png | detail upscale of `art/worlds/sticky/picks/sticky_sky_4102.png` | 7 | x4 | img2img strength 0.4: alien slime jungle at purple dusk, magenta sky with pink clouds, big pale moon, purple mountains, giant mushroom silhouettes |
| sticky_soil_4401.png | sticky_soil (stage_sticky.json) | 4401 | 1024x1024 seamless | seamless tileable texture of dark swamp earth cross-section, deep brown and plum soil with twisted roots, small stones and faint glowing purple spores, side view, low contrast, platform game ground fill ; style: pixel art texture, crisp pixels, cel shading, detailed |
| sticky_vine_4811.png | sticky_vine (stage_sticky.json) | 4811 | 768x1280  | single tall curly jungle vine plant growing upward with big leaves and purple bulbs, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| sticky_vine_4813.png | sticky_vine (stage_sticky.json) | 4813 | 768x1280  | single tall curly jungle vine plant growing upward with big leaves and purple bulbs, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| sticky_water_4611.png | sticky_water (stage_sticky.json) | 4611 | 1024x1024 seamless | seamless tileable texture of murky purple swamp water with gentle ripples and pink highlights, even lighting ; style: pixel art texture, crisp pixels, cel shading, detailed |

## Processing

- `stage.src.json`: backdrop/terrain processing (grid snap, quantise, sky cut) and the world.json.
- `decor.picks.json`: decor sprite crops, sizes and clean-up flags (stage_pick.py).
- `hand/`: pixel pieces drawn in code by `tools/artgen/stage_hand.py` (caps, flags, signs) and the decor sprites written by stage_pick.py; `hand/flag.png` is the meadow cup flag.
- `guides/`: paint-over guides (hand cap scaled 8x) used by jobs/stage_caps.json.
