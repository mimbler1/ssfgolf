# Character Conversion (toon rig -> v4 sprite golfers)

Milestone 2, character track. Every player-facing golfer moved from the procedural vector rig
(`toon_*.gd`) to v4 sprite art built with `tools/artgen/g4_*` (docs/SPRITE_PIPELINE.md, "v4 golfer
pipeline"). Ids never change: player profiles store them, and `LEGACY_IDS` keep resolving.

Review gate for every row: frames inspected at 3-5x, consistency across all frames checked,
in-game check at 1920x1080 (practice hole 1, idle and `--dev-aim -0.8,0.6`), and
`tests/test_characters.gd` passing. Screenshots: `docs/screens/v4/characters/`.

## Status

All 17 sprite characters: 96 x 128 frames, pivot (48, 124), 2 world px per art px, body about
84 art px tall (size factor in the spec), anims `idle` 7 (loop), `swing` 8 (contact = frame 5,
`impact`), `victory` 6 (loop), 64 x 64 `portrait.png`. Walk, defeat, prepare and emotes fall back to
idle at runtime.

| Id | Name | Builder | Idle | Swing | Victory | Portrait | Seed / picks | Known issues |
|---|---|---|---|---|---|---|---|---|
| rex | Rex | sprite (redone v4) | 7 | 8 | 6 | yes | b 11 | halfback/down: hands read as a white blob at the waist |
| mira | Mira | sprite (redone v4) | 7 | 8 | 6 | yes | c 12 | visor picks up a lavender tint in a few frames |
| bjorn | Bjorn | sprite (redone v4) | 7 | 8 | 6 | yes | c 11 + 4 frames from seeds 12/13 (vest consistency) | face detail varies slightly between mixed-seed frames |
| stickman | Stickman | sprite (was classic) | 7 | 8 | 6 | yes | b 11 | deliberately minimal; reads as a suited stick figure; customisation slots gone (compat []) |
| ace | Ace | sprite (was ace) | 7 | 8 | 6 | yes | b 11 | none significant |
| nana | Nana Birdie | sprite (was nana) | 7 | 8 | 6 | yes | b 11 | none significant |
| brick | Brick | sprite (was brick) | 7 | 8 | 6 | yes | b 11 | none significant |
| bolt | Bolt | sprite (was robot) | 7 | 8 | 6 | yes | b 11, finish c 12 (club-over-shoulder pose) | antenna light is an authored spot (consistent); arm shading varies |
| skipper | Skipper | sprite (was skipper) | 7 | 8 | 6 | yes | b 11 | none significant |
| frost | Frost | sprite (was frost) | 7 | 8 | 6 | yes | e 12 | horns dropped from the design (they flickered between frames); scarf stripe ratio varies |
| dino | Tee-Rex | sprite (was dino) | 7 | 8 | 6 | yes | b 11 | green-on-green reads mostly through the outline on grass stages |
| wizard | Fizzwick | sprite (was wizard) | 7 | 8 | 6 | yes | b 11 | hat tip reaches ~104 px (test bound raised for sprites) |
| astronaut | Nova | sprite (was astronaut) | 7 | 8 | 6 | yes | b 11 | victory fist is orange, swing gloves white |
| knight | Sir Putts | sprite (was knight) | 7 | 8 | 6 | yes | c 11 (larger tabard guide) | gauntlets merge with armour (hands hard to read) |
| pirate | Cap'n Slice | sprite (was pirate) | 7 | 8 | 6 | yes | c 12, finish d 13 (club-over-shoulder pose) | peg leg dropped (it flickered); hands hidden under the beard in the finish |
| skeleton | Rattles | sprite (was skeleton) | 7 | 8 | 6 | yes | b 11 | portrait skull is flat |
| cowboy | Dusty | sprite (was cowboy) | 7 | 8 | 6 | yes | b 11 | none significant |

`adventurer` (v3 hand-grid test, hidden) is unchanged.

## Remaining toon dependencies

- No player-facing roster entry uses a toon builder any more. `ToonCharacters` / `toon_*.gd`
  remain in the code (other systems may still reference them, e.g. the studio's body/face/hat
  tabs and `Golfer`'s skeleton solve), but nothing in `ROSTER` draws with them.
- Toon `rig` and `colors` data are kept in each ROSTER entry (unused by sprite drawing).
- The old toon bakes `client/assets/characters/{ace,bolt,brick,frost,nana,skipper}.png/.json`
  (CharacterSheet / sprite_baker output) are not loaded by any runtime path and can be deleted.
- Stickman's customisation (body colour, face, hat, shirt, proportions) no longer applies:
  `compat` is `[]` as requested. Its tagline still says "Yours to design from head to toe".
- Sprite recolour variants, hats and shirt drawings are not authored for v4 characters yet
  (see SPRITE_PIPELINE.md, customisation table).

## Rebuild

```
python tools/artgen/g4_build.py process <id>    # raw picks (art/characters/<id>/v4/raw) -> frames
python tools/artgen/g4_build.py build <id>      # frames -> client/assets/characters/<id>/
python tools/artgen/g4_portrait.py reprocess <id> && python tools/artgen/g4_portrait.py build <id>
```

No GPU needed for any of these. New generations: `g4_queue.py <seed> <id>...`, review with
`g4_build.py preview`, then `pick`, `archive`, `process`, `build`.
