# Course Reference Manifest: SSG3 courses 2–6

Research record for Beach Land, Sticky Zone, Snow Field, Gravity Lab and Spin Land, compiled
2026-10-16 before any layout work. It separates what is **verified** from what is **our design**.

## Sources consulted

| Source | How | Result |
|---|---|---|
| superstickmangolf.fandom.com: *Super Stickman Golf 3*, *Courses*, tour pages, each course page, *Hole N (Beach Land)*, *Power-ups*, *Achievements*, *Cards* | MediaWiki API (`api.php?action=parse`), since the HTML pages return HTTP 402 to automated fetches | Course list and order, Beach Land per-hole pars, Golf Land pars, medal thresholds, power-up unlocks, achievement texts. The Sticky Zone, Snow Field, Gravity Lab and Spin Land pages are empty stubs with no pars. Every per-hole page is an empty stub. |
| speedrun.com/ssg3 (public API) | `/levels`, `/records` | Level order and Any% (No Powerups) per-course world-record times |
| Web search (reviews, GameFAQs, Exophase, Tapatalk) | Search | No per-hole pars or geometry for courses 3–6. Reviews describe sticky walls and gravity shifts, and say spin can be added at almost any point in flight, with more spin the earlier you commit. |
| YouTube walkthroughs ("Gameplay Walkthrough Part 2 – Tour 1: Sticky Zone, Snow Field", course playthroughs) | Titles only | They exist, but video content cannot be inspected from this environment. No geometry was taken from them. |

No proprietary level files, screenshots or artwork were downloaded or reused.

## Verified facts

### Structure

- SSG3 single player has 5 tours of 4 courses, with 9 holes per course. Tour 1 (Easy) is Golf Land,
  Beach Land, Sticky Zone and Snow Field. Tour 2 (Easy) is Gravity Lab, Spin Land, Portal Land and
  Rocky Land. *(wiki, speedrun.com)*
- The next course unlocks when you score **par or under** on the previous one. *(review snippet via
  search; matches the wiki's "Par Snow Field → Ice Ball" style unlocks)*
- Medal thresholds, verified on the Golf Land and Beach Land infoboxes:
  - **Bronze:** par
  - **Silver:** par −5
  - **Gold:** par −10

### Par values

| Course | H1 | H2 | H3 | H4 | H5 | H6 | H7 | H8 | H9 | Total | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Golf Land (ref.) | 4 | 4 | 4 | 4 | 4 | 4 | 5 | 4 | 5 | 38 | verified |
| **Beach Land** | 5 | 5 | 5 | 5 | 4 | 4 | 4 | 4 | 5 | **41** | **verified** |
| Sticky Zone | – | – | – | – | – | – | – | – | – | – | **not available** |
| Snow Field | – | – | – | – | – | – | – | – | – | – | **not available** |
| Gravity Lab | – | – | – | – | – | – | – | – | – | – | **not available** |
| Spin Land | – | – | – | – | – | – | – | – | – | – | **not available** |

### Per-course facts (from achievements and power-up unlocks)

| Course | Verified fact | Source |
|---|---|---|
| Beach Land | Hole 4 (par 5) can be holed in one with no power-ups | Achievement text |
| Sticky Zone | Par unlocks the **Sticky Ball** ("Stick your ball to walls!") | Power-ups table |
| Sticky Zone | Hole 7 can be completed without touching a sticky wall | Achievement: "Complete Hole 7 of Sticky Zone Without Hitting a Sticky Wall" |
| Snow Field | Par unlocks the **Ice Ball** ("Land on water!") | Power-ups table |
| Snow Field | Hole 4 can be aced touching only the green | Achievement "No Snow" |
| Gravity Lab | Par unlocks the **Anti-Grav Ball** ("Defy gravity for a short time!") | Power-ups table |
| Gravity Lab | Hole 6 allows a "Nil Score" with no power-ups. The scoring mechanism behind it is not documented | Achievement "Use the Force" |
| Spin Land | The course can be finished under par **without using spin** | Achievement "Opposite Day" |
| SSG3 general | Spin can be applied in flight; committing earlier gives more spin | Review snippet |

### Relative course length

Any% (No Powerups) world-record times for a full course (speedrun.com):

| Course | Golf Land | Beach Land | Sticky Zone | Snow Field | Gravity Lab | Spin Land |
|---|---|---|---|---|---|---|
| Record | 43.1 s | 63.2 s | 95.7 s | 76.4 s | 111.2 s | 89.5 s |
| vs. Golf Land | 1.0× | 1.5× | 2.2× | 1.8× | 2.6× | 2.1× |

Expert play of these courses runs about 1.5–2.6× longer than Golf Land. We use this ratio for hole
length and for the number of shots a hole needs.

## What is NOT verified, and how we handle it

- **Geometry.** No hole geometry, cup positions, platform layouts or hazard placements are verified
  for any of these courses. **Every one of the 45 holes is an original layout.** Each is designed to
  express the course's verified mechanical identity:
  - Beach Land: sand and water.
  - Sticky Zone: sticky walls and ceilings.
  - Snow Field: snow and ice.
  - Gravity Lab: gravity shifts.
  - Spin Land: spin.

  None of them is a replica or a reconstruction of the original holes.
- **Par for Sticky Zone, Snow Field, Gravity Lab and Spin Land.** These are our **design pars**,
  chosen from the solver's shot counts and from the relative course lengths above. They are marked
  `"parSource": "design"` in the course files. Beach Land uses `"parSource": "ssg3"`. Golf Land keeps
  this game's existing layouts and pars.
- **Exact material behaviour** (how sticky, how slippery, how strong the spin) is our own tuning,
  documented in `data/materials.json` and `data/balance.json`.
- The verified per-hole facts are kept as **design constraints**:
  - Beach Land hole 4 is a par 5 that can be aced by a perfect shot with the standard ball.
  - Sticky Zone hole 7 has a route that never touches sticky.
  - Snow Field hole 4 is aceable without touching snow.
  - Spin Land can be finished under par without spin.

  Gravity Lab hole 6's "Nil Score" depends on an undocumented SSG3 scoring rule, so it is not
  reproduced.

## Where the layouts live

- The design for every hole (shape, hazards, routes and notes) is in `tools/courses/<course>.py`.
- The generated per-hole tables, with pars, solver shots and the proof of each verified detail, are in
  `docs/COURSE_MANIFEST.md`.
