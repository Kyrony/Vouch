# Leonardo farm-country layer pack (aligned SoT)

Kyle / Leonardo plates for the **open farm** Host Match. Soft-go: **terrain, roads, and labeled spawn markers only** — no building or mast meshes in the live Start Match world.

| Layer | Plate | What it locks |
| --- | --- | --- |
| **L1 / L1b** | farm-country + QA terrain/roads | Open/hilly footprint, ~80 m scale, west hub + east oval loop, curbs, contour hills. |
| **L2** | QA spawn pins + CSV | 11 alive-only child pins. **Eng short `spawn_id`s are SoT 1:1** — ignore art camelCase / pin-number drift. |
| **L3** | (deferred) | Tower candidates are **not** built into the live farm. |
| **L4** | (deferred) | PM interior rooms are **not** built into the live farm. |

## L2 eng short ids (do not “fix” from the art sheet)

**James verify (locked):** camelCase / plate typos (`master_become`, `unclebecome`) are **not** SoT. Use `master_bedroom` / `uncle_bedroom`. Art may stamp a second **1** in the north clearing — only one `pm_attic`.

QA **v2** places all 11 pins, including pin 9 on the SE road bend.

Live markers use only:

1. `pm_attic` — west-inner north of the east loop (central stack)
2. `master_bedroom`
3. `bunker_utility`
4. `basement` — pin 4, slightly west of the stack south end
5. `uncle_bedroom` — east of the central stack
6. `uncle_garage` — south-east of pin 5
7. `family_shed` — far west shed path / pad (no circular ring)
8. `storm_drain` — south of the shed, west intersection
9. `under_porch_crawl` — SE road bend of the east loop, **no grave**
10. `garden_well` — west of the central stack, between parallel lanes
11. `car_trunk` — south access three-way on the QA entrance road

Canonical table: [`../L2_child_rng_spawns.csv`](../L2_child_rng_spawns.csv).

## Live Host Match

World: +X east, +Z south. Authored `HorrorWorld.tscn` only — no runtime OutdoorTerrain / road loops.

Terrain is a sealed heightfield (`farm_hills.obj`): CCW-up winding, underside cap, side skirts, double-sided grass, heightmap + bed collision. Roads follow the L1b / QA Leonardo network only:

- elevated rounded-rect loop around the hilltop main house
- west exit that splits SW to House D and west past Uncle House to House B
- second lane south of Uncle House (house sits between two paths)
- south curve from the loop to House D
- north branch toward Lansis
- QA south access through `car_trunk`
- shed path from House B (pad, not a ring)

No L1 cul-de-sac `HubRing`, no inner 32 m grid, no shed circle. Families spawn on outdoor pads; PM on the east courtyard pad.

`NeighborhoodV05.OUTDOOR_ONLY` is on. `GRAYBOX_NEIGHBORHOOD` is off.
