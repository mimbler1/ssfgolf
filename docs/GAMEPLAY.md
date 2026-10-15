# Gameplay Rules (v1)

All numbers live in `client/data/balance.json` and `client/data/materials.json`.

## Shooting

- Drag anywhere and release to shoot.
  - Power is the drag length divided by the "full power" distance (Settings).
  - Speed ranges from 140 to 1520 px/s.
  - Gravity is 1500 px/s².
- You can shoot when:
  - your ball is touching ground (rolling counts),
  - your **1.7 s cooldown** has finished,
  - and it isn't resetting from a hazard.
- If you release less than 0.4 s before your cooldown ends, the shot is queued.
- **R** returns your ball to your last shot spot. This costs a 3 s cooldown.
- Balls can't collide until they have left the tee, so spawns never shove each other.

## Energy and abilities

- Energy maxes at 10. You start each match with 4, and it regenerates at 0.45/s while holes are
  in play.
- Choosing a special ball spends its cost when you shoot. Selection resets to Standard after
  each shot.

| Ball | Cost | Behaviour |
|---|---|---|
| Standard | 0 | No tricks. |
| Nitro | 3 | Press Space mid-flight: +640 px/s along your path (capped at 2300). |
| Sticky | 2 | Glues to the first surface it touches, including walls and ceilings. Shots off a sticky surface ignore sticky capture for 0.25 s, so you can climb. |
| Grenade | 4 | Arms after 0.12 s, then explodes on its first impact or a ball hit, after 3 s, or when you press Space. Pushes balls within 175 px, scaled by distance and mass. Your own ball gets 40%. |
| Heavy | 3 | 4× mass, 40% bounce, 1.18× gravity, less rolling drag. Shoves other balls. |
| Air Brake | 2 | Press Space mid-flight: keeps 12% of your speed, with reduced gravity for 0.4 s. Drops almost straight down. |

## Materials

| Material | Character |
|---|---|
| Grass | The baseline. |
| Rough | Slower rolling. |
| Sand | Kills bounces, heavy drag. |
| Ice | Almost no friction. |
| Rock and wood | Lively bounces. |
| Sticky | Instant stick. |
| Bouncy pad | One 780 px/s launch per shot (re-armed by touching another surface). |
| Cup | Absorbs speed. |

Balls come to rest when they are slow enough on a slope gentler than the material's limit.

## Hazards

- Water, lava, acid zones, or leaving the hole bounds, send your ball back to your last *safe*
  shot spot after 1.1 s.
- If that spot leads straight back into a hazard (within 2.5 s), the ball goes to the tee instead.

## The cup

- A ball that falls deep into the cup is holed at any speed.
- A ball that dips into the mouth while moving under 620 px/s is also holed. This makes the cup
  arcade-forgiving: fast balls still skip over.

## Scoring (online)

- Points by finishing place:
  - 4 players: 3 / 2 / 1 / 0
  - 3 players: 3 / 1 / 0
  - 2 players: 3 / 0
- Players who don't finish get 0.
- Ties within the same simulation tick share the better place (standard competition ranking).
- When the first player finishes, everyone else gets **25 s**. The hard cap per hole is 120 s.
  The hole never waits on disconnected players.
- **Win:** the first player to reach the target (default 9) *with a unique lead* at the end of a
  hole. If the lead is tied, holes continue (sudden death) up to 15 holes.
- **Final order:** players still in the match first, then points, holes won, total finishing time,
  then slot.

## Rewards (ranked Quick Play)

Settled by the backend (`docs/API.md` §2.1).

| Players | Trophies by place |
|---|---|
| 4 | +30 / +12 / −6 / −16 |
| 3 | +25 / 0 / −12 |
| 2 | +20 / −12 |

- Trophies never go below 0.
- XP: `40 + 15·holesWon + [30,20,10,0][place]`.
- Coins: `15 + 5·holesWon + [25,15,8,0][place]`.
- Private matches don't change trophies, give half XP, and give no coins.

## Fairness

- All players currently have the same ability set and identical stats.
- Cosmetics never affect hitboxes or physics.
- There are no bots in online play. The headless test client in `client/tests` is a developer tool
  and is never matched with real players.
