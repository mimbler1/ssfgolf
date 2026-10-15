# Roadmap

The approach is quality over count: each milestone ships complete, tested features. Nothing
visible in the game is a placeholder. Every button shown works, or is disabled with an
explanation.

## ✅ Milestone 1 — Playable online foundation (this build)

### Core game

- **Physics.** Authoritative fixed-step simulation: substep tunnelling guard, 9 materials,
  slope-aware resting, ball-to-ball impulses, explosions, a forgiving cup, and hazard respawn
  safety.
- **Abilities.** 6 genuinely distinct balls: Standard, Nitro, Sticky, Grenade, Heavy and Air Brake.
  They use energy, cooldowns and server validation.
- **Match rules.** 4-player race scoring to 9 points, finish window, hole cap, sudden-death
  tiebreaks, disconnect grace and forfeits.
- **Courses.** Sunny Meadows has 9 distinct holes: water carries, bounce pads over walls, a sticky
  cliff, a floating island green, a tunnel arch, a downhill run, and a combined finale. There is
  also a practice-only Physics Lab with a live tuning panel.

### Online

- **Accounts.** Guest accounts; profiles with level, XP, trophies, coins and stats; match history;
  leaderboard.
- **Quick Play.** Trophy-window matchmaking.
- **Private rooms.** Room codes, ready-up, host settings, and friendly (unranked) matches.
- **Dedicated servers.** Headless Godot servers that register with the backend and verify signed
  join tokens. They support reconnects, graceful leave, and idempotent, transactional reward
  settlement.

### Presentation

- **World art.** Vector art direction throughout: parallax sky, illustrated terrain, swaying decor,
  water and flag animation.
- **Characters.** A procedurally rigged stickman with 10 animations.
- **Feedback.** Trajectory preview with a hazard warning, 31 original synthesised sounds, particles
  and screen shake.

### Menus

- **Main menu.** A living backdrop with a live profile chip.
- **Golfer Studio.**
  - Customisation: 8 presets, body/outline colours, 4 head shapes, 8 eyes, 7 mouths, 10 hats,
    6 shirts, ball and trail colours, size sliders and custom colours.
  - An animated preview.
  - Saved looks with save, wear, copy, update and delete.
  - The equipped look syncs to the profile and is shown to opponents.
- **Settings.** Display, audio, gameplay, network, and full input remapping.

### Engineering

- **Tests.** About 160 automated checks across simulation, solver, backend and end-to-end flows.
- **Tooling.** Dev launcher, export presets, and docs.

## ✅ Post-M1 quality pass

- **Characters.** Six original roster characters (Ace, Nana Birdie, Brick, Bolt, Skipper, Frost)
  as baked, outlined sprite sheets with 16 animations each, alongside the customisable Stickman.
  A Character tab in the Golfer Studio; the choice syncs to the profile and opponents.
- **Emotes.** Eight animated emotes with expressions, an emote wheel (hold T) and F1–F8 hotkeys,
  synced online.
- **Polish.** The world continues past each hole's edges instead of ending in a cut-off cliff; a
  compact controls card replaces the overlapping hint text; larger golfers; softer, calmer ball
  sounds.

## Next milestones (proposed order)

### M2 — Character Drawing Studio

- Per-bone drawing canvases (head, face, torso, arms, legs, hands, feet, hats, shirts).
- Layers, and the full tool list: pencil and brushes, eraser, fill, shapes, selection
  transforms, mirror and symmetry, undo/redo.
- Stickers, a text tool, and a versioned stroke-based design format.
- Rasterised gameplay textures.
- Moderated upload pipeline: content review, report and block, safe fallbacks.
- Opponents only ever see approved art.

### M3 — Collection and cosmetics

- A data-driven cosmetic catalogue with rarity tiers.
- Inventory and collection screen: search, sort, filters, favourites, completion.
- Loadouts and set collections with set rewards.
- Equipment slots with attachment rules.
- Cape/scarf secondary motion.
- Trails, ball skins, club skins and victory animations as collectibles.

### M4 — Card packs and crafting

- Server-side drop tables with published odds, transactional grants and idempotent openings.
- The pack-opening scene: float, shake, burst, card flips, rare/legendary/mythic reveals, skip,
  reveal all, and bulk open.
- Duplicates convert to crafting currency and upgrade progress.
- Earnable only; no real-money loot boxes.

### M5 — Goals

- Daily and weekly missions, achievements and a reward calendar.
- Season framework with a free reward track and a seasonal leaderboard; events configured from
  the backend.

### M6 — Worlds and editor

- An in-game course editor:
  - spline terrain editing, materials and hazards;
  - portals, moving and rotating platforms;
  - validation and instant test;
  - multi-client test;
  - import/export.
- New themes: Crystal Caverns, Neon City, Frozen Peaks, Volcanic Valley, and more.
- New hazards: moving platforms, wind, conveyors, lasers, saws, magnets, gravity wells, breakables.

### M7 — Social

- Friends: codes, requests, presence and invites.
- Teams and clubs, with roles.
- Chat with rate limits, filtering, mute, block, report and moderation tools.
- Spectator mode.

### M8 — Depth and polish

- The remaining ability catalogue: Super, Bounce, Ghost, Shockwave, Laser, Magnet, Teleport,
  Portal, and others.
- Ability upgrades with balance caps or equalised ranked play.
- Golfer stat upgrades.
- Local prediction of your own ball.
- Latency and packet-loss test harness.
- Redis-backed horizontal scaling.
- Music.
- Production deployment guide, and code-signed Windows builds.
