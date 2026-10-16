# art/ui sources

Committed picks are the raw SDXL generations that `tools/artgen/build_ui.py` cuts into
`client/assets/ui/`. Rebuilding needs no GPU. Everything was generated locally with SDXL base 1.0
and nerijs/pixel-art-xl, using `tools/artgen/gen_ui.py`, img2img from the guides in `guides/`
(made by `tools/artgen/ui_guides.py`). The style suffix for each job is in `gen_ui.py` (`STYLES`).

## Ability icons (`icons/<id>.png`, 1024 px, style `@ICON`)

| id | job (jobs file) | seed | strength | prompt |
|---|---|---|---|---|
| standard | icon_standard_s60 (ui_icons) | 11002 | 0.60 | a white golf ball with round dimples resting on a wooden golf tee |
| nitro | icon_nitro_s80 (ui_icons2) | 13003 | 0.80 | a white golf ball blasting forward trailing a roaring fire jet with flickering flame tongues and embers |
| sticky | icon_sticky_s80 (ui_icons2) | 13061 | 0.80 | a white golf ball covered in dripping glossy purple slime goo, thick drips |
| grenade | icon_grenade_s65 (ui_icons2) | 13083 | 0.65 | a green hand grenade with golf ball dimples, steel cap, lever and gold pull ring |
| heavy | icon_heavy_s80 (ui_icons2) | 13043 | 0.80 | a heavy cast iron kettlebell weight with a riveted steel band, scratched dark metal |
| air_brake | icon_air_brake_s65 (ui_icons2) | 13072 | 0.65 | a white golf ball hanging under an open cyan parachute with strings |
| anti_grav | icon_anti_grav_r3s62 (ui_icons3) | 14002 | 0.62 | a white golf ball levitating above two glowing mint green hover rings with big up arrows |
| free_shot | icon_free_shot_s80 (ui_icons2) | 13012 | 0.80 | an ornate shiny golden ticket with an engraved border and a white star, gleaming gold |
| ice | icon_ice_s65 (ui_icons2) | 13021 | 0.65 | a golf ball frozen inside a chunky block of clear blue ice, ice crystals, icicles |
| laser | icon_laser_s60 (ui_icons) | 11092 | 0.60 | a red targeting crosshair reticle around a white golf ball, laser beam |
| magnet | icon_magnet_r3s62 (ui_icons3) | 14011 | 0.62 | a red horseshoe magnet with silver tips pulling a white golf ball, magnetic waves |
| mulligan | icon_mulligan_r3s62 (ui_icons3) | 14022 | 0.62 | a white golf ball inside a thick golden rewind arrow |
| shield | icon_shield_s60 (ui_icons) | 11122 | 0.60 | a blue knight shield with silver rim and a golf ball emblem |
| super | icon_super_s60 (ui_icons) | 11132 | 0.60 | a glowing golden golf ball with a bright yellow starburst aura |
| zig_zag | icon_zig_zag_s80 (ui_icons2) | 13052 | 0.80 | a jagged purple zig zag lightning bolt crackling with electricity and a small white golf ball |

Note: the zig_zag pick was painted from an earlier revision of its guide (smaller ball, radius
120 at 250,860). The current guide has a bigger ball; regenerating with the same seed will not
reproduce the pick exactly. The committed raw pick is what the build uses.

## HUD and podium

See "HUD and podium picks" in docs/UI_ART.md (picks `hud/*.png`, `studio/podium_raw.png`, jobs in
`tools/artgen/jobs/ui_hud*.json`).
