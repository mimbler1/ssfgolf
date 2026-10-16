# lab stage art: sources

Generated on the local GPU with SDXL base 1.0 + madebyollin/sdxl-vae-fp16-fix + nerijs/pixel-art-xl (LoRA 1.0) via `tools/artgen/stage_gen.py` (same job format as generate.py). Raw outputs land in tools/artgen/out/<job>/<seed>.png; the committed copies are in `picks/`.

Rebuild without the GPU:

```
tools/artgen/.venv/Scripts/python tools/artgen/stage_hand.py lab
tools/artgen/.venv/Scripts/python tools/artgen/stage_pick.py art/worlds/lab/decor.picks.json
tools/artgen/.venv/Scripts/python tools/artgen/build_stage.py lab
```

## Picks

| file | job (file) | seed | size | prompt |
|---|---|---|---|---|
| lab_acid_6601.png | lab_acid (stage_lab.json) | 6601 | 1024x1024 seamless | seamless tileable texture of glowing radioactive green chemical liquid with bubbles and bright highlights, even lighting ; style: pixel art texture, crisp pixels, cel shading, detailed |
| lab_console_6803.png | lab_console (stage_lab.json) | 6803 | 1024x1024  | single sci-fi computer console terminal with glowing screens, buttons and levers, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| lab_fan_6821.png | lab_fan (stage_lab.json) | 6821 | 1024x1024  | single big industrial fan in a metal frame on a stand, side view, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| lab_far_6203.png | lab_far (stage_lab.json) | 6203 | 1536x640  | wide panorama of a sci-fi research facility at night, steel domes, towers, big pipes and tanks with glowing cyan windows, isolated on a plain flat white background ; style: pixel art, 2d game stage background, crisp pixels, rich cel shading, vibrant saturated colors, highly detailed |
| lab_lamp_6831.png | lab_lamp (stage_lab.json) | 6831 | 768x1280  | single tall sci-fi lamp post with a glowing cyan light on top, metal pole, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| lab_lamp_6832.png | lab_lamp (stage_lab.json) | 6832 | 768x1280  | single tall sci-fi lamp post with a glowing cyan light on top, metal pole, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| lab_lamp_6833.png | lab_lamp (stage_lab.json) | 6833 | 768x1280  | single tall sci-fi lamp post with a glowing cyan light on top, metal pole, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |
| lab_near_6301.png | lab_near (stage_lab.json) | 6301 | 1536x512  | wide panorama of industrial laboratory machinery at night, big glass tanks of glowing green liquid, pipes, catwalk railings and blinking consoles, isolated on a plain flat white background ; style: pixel art, 2d game stage background, crisp pixels, rich cel shading, vibrant saturated colors, highly detailed |
| lab_sky_6103.png | lab_sky (stage_lab.json) | 6103 | 1536x768  | futuristic science laboratory complex at night, dark navy sky with stars and a big moon, glowing domes, radio telescope dish and antenna towers, distant city lights, empty foreground ; style: pixel art, 2d game stage background, crisp pixels, rich cel shading, vibrant saturated colors, highly detailed |
| lab_sky_6103_x4.png | detail upscale of `art/worlds/lab/picks/lab_sky_6103.png` | 7 | x4 | img2img strength 0.4: futuristic science laboratory complex at night, starry navy sky, big planet, glowing domes and antenna towers, distant city lights |
| lab_soil_6402.png | lab_soil (stage_lab.json) | 6402 | 1024x1024 seamless | seamless tileable texture of dark blue grey sci-fi metal wall panels with rivets, seams, small vents and faint cyan lights, even lighting, low contrast ; style: pixel art texture, crisp pixels, cel shading, detailed |
| lab_vat_6811.png | lab_vat (stage_lab.json) | 6811 | 768x1280  | single tall glass chemical vat tank full of glowing green liquid with metal pipes and valves, isolated on a plain flat white background ; style: pixel art, 2d side view game sprite, crisp pixels, clean dark outlines, rich cel shading, vibrant, detailed |

## Processing

- `stage.src.json`: backdrop/terrain processing (grid snap, quantise, sky cut) and the world.json.
- `decor.picks.json`: decor sprite crops, sizes and clean-up flags (stage_pick.py).
- `hand/`: pixel pieces drawn in code by `tools/artgen/stage_hand.py` (caps, flags, signs) and the decor sprites written by stage_pick.py; `hand/flag.png` is the meadow cup flag.
- `guides/`: paint-over guides (hand cap scaled 8x) used by jobs/stage_caps.json.
