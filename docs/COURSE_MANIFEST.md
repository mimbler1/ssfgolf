# Course Manifest

These are the six main courses as implemented (`client/data/courses/*.json`, authored in `tools/courses/<id>.py`).
Every hole below is completed by the solver bot with the plain ball and no spin (`client/tests/test_playable.gd`).
It also passes the geometry and random-shot robustness checks (`client/tests/test_sim.gd`).

## Reference fidelity

The six courses follow the order and themes of Super Stickman Golf 3's first six courses: Golf Land, Beach Land,
Sticky Zone, Snow Field, Gravity Lab and Spin Land.

**Every hole layout is original.** SSG3's level geometry, par values and collectible placements were not available
as authorised reference data: the wiki pages were not retrievable from this environment, and the game's data is
proprietary. So nothing here claims to reproduce an SSG3 hole. Each course instead builds its holes around the
mechanic the course is known for. Pars are this game's own design values.

## Summary

| # | Course | Theme art | Difficulty | Holes | Par | Core mechanic |
|---|---|---|---|---|---|---|
| 1 | Golf Land (`golf_land`) | authored (meadow) | Beginner | 9 | 33 | Fundamentals: power, angle, bounce, roll, water and sand |
| 2 | Beach Land (`beach_land`) | procedural fallback; authored art in production | Easy | 9 | 36 | Sand that plugs, water carries, cliffs and long shots |
| 3 | Sticky Zone (`sticky_zone`) | procedural fallback; authored art in production | Medium | 9 | 37 | Goo walls, ceilings and islands: shoot from wherever you stick |
| 4 | Snow Field (`snow_field`) | procedural fallback; authored art in production | Medium | 9 | 35 | Snow grabs, ice slides: power control, slopes and frozen water |
| 5 | Gravity Lab (`gravity_lab`) | procedural fallback; authored art in production | Hard | 9 | 36 | Gravity fields: low-G, heavy-G, lifts, sideways pull and zero-G |
| 6 | Spin Land (`spin_land`) | procedural fallback; authored art in production | Hard | 9 | 36 | Spin control: perched greens, long rolls and conveyors |

Total: **54 playable holes.**

Online Blitz matches draw holes from all six courses (`GameData.POOL_ID` = `blitz_pool`), and each hole keeps
its own world theme. A private room can instead pick one course id. The practice-only Physics Lab (`physics_lab`) is
excluded from both. The old id `sunny_meadows` resolves to Golf Land, so existing data stays valid.

## 1. Golf Land

| Hole | Name | Par | Design |
|---|---|---|---|
| 1 | Opening Drive | 3 |  |
| 2 | Pond Hop | 3 |  |
| 3 | Step Up | 4 | Three terraces. Each riser is rock: hit up onto the next shelf with enough height to stop. |
| 4 | Bounce House | 3 |  |
| 5 | Downhill Dash | 3 |  |
| 6 | Tunnel Vision | 4 |  |
| 7 | Island Green | 4 |  |
| 8 | Long Valley | 5 |  |
| 9 | Grand Finale | 4 |  |

## 2. Beach Land

| Hole | Name | Par | Design |
|---|---|---|---|
| 1 | Shoreline | 3 | A straightforward drive. The pot bunker plugs anything that lands short; the sea waits behind the green. |
| 2 | Tide Pools | 4 | Three tide pools with short dry banks between them: carry them one at a time or fly them all. |
| 3 | Lighthouse Cliff | 4 | The green is on top of the cliff. A sandy ledge halfway up catches short shots (and plugs them). |
| 4 | Dune Run | 5 | Long rolling dunes. Sand fills every trough, so each shot has to land on a crest or roll over one. |
| 5 | Pier Pressure | 4 | Carry the bay, or play safe: lay up on the wooden pier halfway and chip on. |
| 6 | Hidden Cove | 4 | The cup hides under a rock overhang. Keep it low and run it in, or bank it off the ceiling. |
| 7 | High Tide | 4 | Hit down off the bluff over a wide channel. The extra height carries further than it looks. |
| 8 | Sandcastle | 3 | The cup sits in the courtyard of a sandcastle. Lob it in high; anything that hits the walls plugs. |
| 9 | Coastal Classic | 5 | Everything at once: a water carry, a cliff, a bunker across the top and a long final approach. |

## 3. Sticky Zone

| Hole | Name | Par | Design |
|---|---|---|---|
| 1 | First Stick | 3 | A goo wall. Stick to its face, then pop the ball up and over from there; or clear it in one big shot. |
| 2 | Ceiling Crawl | 4 | A pit of bubbling goo with a sticky ceiling above it. Stick to the ceiling, then drop the ball forward to the green. |
| 3 | Glue Gully | 4 | Goo strips cover the low ground; rocky humps between them are safe. Land on a hump or past the goo. |
| 4 | Wall Climb | 4 | The green is a thousand pixels up. Climb it: goo blocks and a goo cliff face are the handholds. |
| 5 | Goo Islands | 4 | Three floating goo islands over a goo pit. Hop from island to island, sticking each time. |
| 6 | Sticky Trap | 4 | A tiny green ringed by goo. Anything slightly long or short sticks and leaves an awkward chip. |
| 7 | The Chimney | 5 | A narrow shaft between two goo faces. Bounce-stick your way up it, then pop over the lip to the ledge green. |
| 8 | Under the Bridge | 4 | The bridge deck is ordinary wood on top but goo underneath. A low line sticks under it; a high one rides over. |
| 9 | Goo Gauntlet | 5 | Goo on the floor, on the risers and on the ceiling. Use the risers to climb; avoid the floor strips. |

## 4. Snow Field

| Hole | Name | Par | Design |
|---|---|---|---|
| 1 | First Frost | 3 | Snow holds the ball; the strip of ice in front of the green does not. Land past it or roll across it gently. |
| 2 | The Rink | 3 | A long sheet of ice. Power is everything: a putt-weight shot slides for hundreds of pixels. A rock lip behind the green stops the worst overruns. |
| 3 | Slalom | 4 | Downhill through gates of ice. Every icy patch speeds the ball up the hill's fall line. |
| 4 | Frozen Lake | 4 | An island green in a frozen-over lake that is not frozen enough to stand on. Carry it, or bring an Ice Ball. |
| 5 | Avalanche Ridge | 4 | Uphill in steps. The icy ramps between the shelves send short shots sliding back down. |
| 6 | Icicle Cave | 4 | A low cave with an ice floor. Run it in under the icicles; it will keep sliding if you hit it too hard. |
| 7 | Ski Jump | 4 | Roll down the icy in-run and off the kicker: the jump carries the gap. A soft flighted shot works too. |
| 8 | Crevasse | 4 | A deep crack in the ice field. The lip in front of it is ice, so lay up early or commit to the carry. |
| 9 | Summit | 5 | The long climb to the top: snowfields, an icy plateau and two rocky steps. |

## 5. Gravity Lab

| Hole | Name | Par | Design |
|---|---|---|---|
| 1 | Low-G Orientation | 3 | The whole room runs at 40% gravity. Shots fly two and a half times as far and hang in the air. |
| 2 | Lift Shaft | 4 | The wall is far too tall to clear. Roll into the lift shaft beside it and drift over the top. |
| 3 | Float Chamber | 4 | A low-gravity chamber over an acid vat. Hit it softly: the ball floats, and the ceiling is low. |
| 4 | Heavy Landing | 4 | A heavy-gravity field over the green slams long shots down early. Aim to land just inside it. |
| 5 | Crosswind | 4 | Gravity in the middle bay pulls back toward the tee as well as down. Over-hit into the headwind. |
| 6 | Ceiling Walk | 4 | Over the vat gravity points up. The ball falls onto the ceiling, rolls along it and drops off the far end. |
| 7 | Zero-G Corridor | 4 | No gravity at all over the vat: the ball flies dead straight. Aim the exit at the raised green. |
| 8 | Flip Floors | 4 | The cup is on the upper deck. A lift beside the deck carries the ball up and over onto it. |
| 9 | Experiment 9 | 5 | Float the vat, ride the lift to the upper deck, then a long approach on normal gravity. |

## 6. Spin Land

| Hole | Name | Par | Design |
|---|---|---|---|
| 1 | Check It | 3 | A small raised green with a run-off slope behind it. Backspin stops the ball on top; topspin runs it off. |
| 2 | Long Roller | 4 | A long, gently falling fairway. Topspin turns a decent drive into a huge rolling one. |
| 3 | Conveyor Belt | 4 | A belt runs back toward the tee across the middle. Fly it, or land with topspin to fight the drag. |
| 4 | Ledge | 4 | The green is a narrow shelf with drops on both sides. Land soft with backspin or chip on from the lower step. |
| 5 | Rollercoaster | 4 | Two big humps. Momentum management: carry the crests or let the dips swing the ball back and forth. |
| 6 | Back Door | 4 | The green sits on the edge of a steep drop into a bunker. Any release sends the ball over: stop it dead. |
| 7 | Belt Maze | 4 | Two belts: the low one carries you forward, the high one (with the green) drags you back toward its edge. |
| 8 | Half Pipe | 4 | A big bowl between two decks. Roll it through the pipe with exactly enough pace, or fly it straight over. |
| 9 | Spin Cycle | 5 | A backward belt, a rolling hill, a pond and a perched green to finish: every spin skill in one hole. |

## Course data per hole

Each hole has:
- tee spawn (up to 6 balls are spread across it automatically, or placed by an optional `spawns` list);
- cup;
- bounds (camera limits and out of bounds);
- terrain polygons with per-edge materials;
- hazard zones (water, acid, lava);
- gravity fields;
- decor;
- par;
- designer notes.

Moving obstacles are not implemented yet; no hole uses them.

## Not yet done

- **Stage art.** Authored art exists only for Golf Land. The other five courses render with the procedural
  fallback until their art sets are produced.
- **Decor types.** Each course's decor types (palms, pines, mushrooms, lab lights, windmills and so on) are
  placed in the data but only drawn once a theme's art set provides them.
- **Collectibles.** There are no optional collectibles or alternative objectives yet. The format can carry them.
