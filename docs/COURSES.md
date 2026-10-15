# Course Data Format

Courses live in `client/data/courses/<id>.json`. Every `.json` file there is loaded automatically.
They are currently authored with `tools/build_courses.py`; the in-game course editor (planned)
will write the same format.

```jsonc
{
  "id": "sunny_meadows",            // snake_case, unique
  "name": "Sunny Meadows",
  "version": 2,
  "practiceOnly": false,             // true = never used for matchmaking
  "theme": { "sky_top": "#3fa9f5", "grass": "#6ccf4a", ... },   // palette, see below
  "holes": [ {
    "id": "sm_01", "name": "Opening Drive",
    "bounds": {"x": -200, "y": -1500, "w": 3050, "h": 2100},  // falling below bottom+120 = out of bounds
    "tee": {"x": 350, "y": 0},       // balls are dropped onto the ground below this point
    "cup": {"x": 2360, "y": -40},    // the cup is cut into the surface nearest this y at this x
    "terrain": [ {
      "material": "grass",           // default material for edges
      "smooth": true,                // centripetal Catmull-Rom smoothing between non-corner points
      "kind": "ground",              // informational: ground | island | arch
      "points": [ [x, y], [x, y, {"m": "sand"}], [x, y, {"c": true}], ... ]
    } ],
    "zones": [ {"type": "water", "points": [[x,y], ...]} ],   // water | lava | acid
    "decor": [ {"type": "tree", "x": 560, "y": -10, "scale": 1.1} ] // tree | bush | flowers | rock
  } ]
}
```

## Points

- Coordinates are pixels, with **y pointing down** (negative is up).
- `{"m": "<material>"}` sets the material of the edge that **starts** at this point.
- `{"c": true}` marks a hard corner (no smoothing). Use it for cliffs, pads and bottom corners.
- Winding direction doesn't matter; polygons are normalised on load.
- Several polygons per hole are allowed: floating islands, arches and tunnels.
- Decor snaps to the ground below its x/y.

## Water and lava

- Draw a rectangle around the basin, with its top at the water line.
- It is rendered only in open air: it is clipped against the terrain automatically.
- Keep the water line a few pixels **below** the basin rims, so a ball resting on a rim is never
  inside the zone.

## Validation (automatic)

- `tests/test_sim.gd`, for every hole:
  - the cup was placed, has depth and has an open mouth;
  - the tee has ground;
  - 40 random shots with mixed abilities never leave a ball inside terrain or permanently
    unshootable.
- `tests/test_playable.gd`: a solver bot using the shared trajectory predictor must finish each
  hole within 30 shots.

## Theme palette keys

```
sky_top, sky_bottom, sun, far_hills, mid_hills, cloud
ground_top, ground_bottom, ground_strata, outline
grass, grass_light, grass_dark, water_top, water_bottom
```
