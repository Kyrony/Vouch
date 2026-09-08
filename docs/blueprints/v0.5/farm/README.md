# Leonardo farm-country layer pack (aligned SoT)

Kyle / Leonardo aligned plates for the **graybox farm** Host Match. Soft-go graybox only — walls/floors/doors, not Steam-final art.

If the PNG plates are in this folder, they are the visual SoT. Eng still follows the locks below when art labels drift.

| Layer | Plate | What it locks |
| --- | --- | --- |
| **L1** | `L1-farm.png` | Open/hilly footprints, ~80 m scale bar, spaced rural houses + east PM mansion, roads/curbs, contour hills. Godot graybox walls/floors. v0.5 + Kyle farm pivot. |
| **L2** | `L2-farm.png` | 11 alive-only child pins. **Eng short `spawn_id`s are SoT 1:1** — ignore art camelCase / pin-number drift. |
| **L3** | `L3-farm.png` | Many tower candidates; **3 active / match**; **1 near PM**; service / weak / dead radii. |
| **L4** | `L4-farm.png` | PM interior + ducts: attic, master, study, kitchen, dining, living, bath, hallway, stairwell, basement, bunker, utility closet. |

Family-house modular kit (13.5×11 m, porch crawl on A) and PM bunker + utility closet kit still dress the graybox shells.

## L2 eng short ids (do not “fix” from the art sheet)

Art may show `masterBedroom`, `bunkerUtility`, `underPorchCrawl`, or shuffled pin numbers. Live markers use only:

1. `pm_attic`
2. `master_bedroom`
3. `bunker_utility`
4. `basement`
5. `uncle_bedroom`
6. `uncle_garage`
7. `family_shed`
8. `storm_drain`
9. `under_porch_crawl` — dirt hide, **no grave**
10. `garden_well`
11. `car_trunk`

Canonical table: [`../L2_child_rng_spawns.csv`](../L2_child_rng_spawns.csv).

## L1 farm parcels (eng)

World: +X east, +Z south, origin = hub between A / B / D. Long drive east to the PM. Courtyard is **south** of the mansion (front door +Z). Uncle garage is **east** of the mansion. House C sits **south** of the PM approach. House A is at the junction, B west of A.

`NeighborhoodV05.OUTDOOR_ONLY` is off. Families spawn on porches; PM on the courtyard / foyer with a walkable door.
