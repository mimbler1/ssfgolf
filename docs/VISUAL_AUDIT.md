# Visual Audit (2026-10-15)

Every visual in the game is vector art drawn in code. Nothing is authored artwork.

| System | File | Current technique | Replacement |
|---|---|---|---|
| Golfers | render/golfer.gd, render/toon/* | IK skeleton + `draw_colored_polygon` beans/tubes, computed outline | Sprite strips (`SpriteCharacter`), done for the render path |
| Soil | render/terrain_view.gd + terrain_fill.gdshader | `Polygon2D` + gradient/strata shader | Seamless pixel material tile (`WorldArt`) |
| Surfaces (grass, sand, ice, rock, wood, sticky, bouncy) | terrain_view.gd `_Edges` | Offset `draw_polyline` bands, scallops, speckles | Textured cap strips following the curve, per material |
| Decor (tree, bush, flowers, rock) | terrain_view.gd `_Tree` etc. | Circle blobs | Cut-out sprite props |
| Water / lava / acid | terrain_view.gd `_Water` | Sine polygon + vertex gradient | Pixel material + animated surface strip |
| Cup / flag | terrain_view.gd `_Cup`, `_Flag` | `draw_rect` / polygon flag | Sprite flag flipbook + cup sprite |
| Sky + parallax | render/backdrop.gd + sky.gdshader | Gradient shader, circle clouds, polygon hills | Illustrated parallax PNG layers |
| Ball | render/ball_view.gd | Procedural ball, trail, flames | Ball sprite with rotation frames; trail stays procedural (effect) |
| Effects | render/fx_layer.gd | 5 particle primitives (circle, ring, confetti, spark, smoke) | Flipbook sprites for impact, splash, cup, abilities; particles kept for confetti/sparks |
| Trajectory | render/trajectory_view.gd | Dots + ring | Keep (UI overlay), restyle |
| HUD | game/hud.gd | Rounded StyleBoxFlat candy panels | Arcade panels: slanted, thick rims, display font |
| Menus | ui/main_menu.gd, ui/customize.gd, ui/ui_theme.gd | Candy theme, Fredoka/Nunito | Arcade theme (see ART_STYLE_GUIDE §1) |
| Icons | ui/icon.gd, ui/ability_icon.gd | Procedural vector glyphs | Pixel icons sheet |
| Collection / packs / shop | none | n/a | New screens (phase 4) |

Course data (`data/courses/*.json`): terrain polygons with per-edge materials (grass, rough, sand,
ice, rock, wood, sticky, bouncy, cup), zones (water, plus lava/acid in code, oob), and decor (tree,
bush, flowers, rock). One theme (`meadow`). There are no portals, lasers, moving platforms or
other hazard objects in the simulation yet. Those are gameplay features, not art.

Fonts: Fredoka (headings) and Nunito (body), both OFL.
