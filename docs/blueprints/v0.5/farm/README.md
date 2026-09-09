# Leonardo farm-country layer pack (aligned SoT)

Kyle / Leonardo plates for the **open farm** Host Match. Soft-go: **terrain, roads, and labeled spawn markers only** — no building or mast meshes in the live Start Match world.

| Layer | Plate | What it locks |
| --- | --- | --- |
| **L1 / Kyle T0** | `kyle_greybox_layout` + `kyle_T0_height_193x161.exr` | Open/hilly 288×240 m (4× area), Family A–D west, Uncle north of mansion, east cliff. |
| **L2** | QA spawn pins + CSV | 11 alive-only child pins. **Eng short `spawn_id`s are SoT 1:1** — ignore art camelCase / pin-number drift. |
| **L3** | (deferred) | Tower candidates are **not** built into the live farm. |
| **L4** | (deferred) | PM interior rooms are **not** built into the live farm. |

## L2 eng short ids (do not “fix” from the art sheet)

**James verify (locked):** camelCase / plate typos (`master_become`, `unclebecome`) are **not** SoT. Use `master_bedroom` / `uncle_bedroom`. Art may stamp a second **1** in the north clearing — only one `pm_attic`.

Kyle greybox places all 11 pins, including pin 9 on the SE road toward the east cliff.

Live markers use only:

1. `pm_attic` — west-inner north of the east loop (central stack)
2. `master_bedroom`
3. `bunker_utility`
4. `basement` — pin 4, slightly west of the stack south end
5. `uncle_bedroom` — east of the central stack
6. `uncle_garage` — south-east of pin 5
7. `family_shed` — far west circular road loop
8. `storm_drain` — south of the shed, west intersection
9. `under_porch_crawl` — SE road toward the east cliff, **no grave**
10. `garden_well` — west of the central stack, between parallel lanes
11. `car_trunk` — south hub three-way junction

Canonical table: [`../L2_child_rng_spawns.csv`](../L2_child_rng_spawns.csv).

## Live Host Match

World: +X east, +Z south, origin = center of the 144×120 heightfield. Families spawn on west outdoor pads; PM on the hilltop courtyard.

`NeighborhoodV05.OUTDOOR_ONLY` is on. `GRAYBOX_NEIGHBORHOOD` is off.
