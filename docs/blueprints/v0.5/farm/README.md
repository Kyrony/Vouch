# Leonardo farm-country layer pack (aligned SoT)

Kyle / Leonardo aligned plates for the **graybox farm** Host Match. Soft-go graybox only — walls/floors/doors, not Steam-final art.

Drop the aligned PNGs here as `L1-farm.png` … `L4-farm.png` when checking them into git. Eng follows the locks below even when art labels drift.

| Layer | Plate | What it locks |
| --- | --- | --- |
| **L1** | `L1-farm.png` | Open/hilly footprints, ~80 m scale bar, spaced rural houses + east PM mansion, roads/curbs, contour hills. Godot graybox walls/floors. v0.5 + Kyle farm pivot. |
| **L2** | `L2-farm.png` | 11 alive-only child pins. **Eng short `spawn_id`s are SoT 1:1** — ignore art camelCase / pin-number drift. |
| **L3** | `L3-farm.png` | Many tower candidates; **3 active / match**; **1 near PM**; service / weak / dead radii. |
| **L4** | `L4-farm.png` | PM interior + ducts: attic, master, study, kitchen, dining, living, bath, hallway, stairwell, basement, bunker, utility closet. |

Family-house modular kit (13.5×11 m, porch crawl on A) and PM bunker + utility closet kit still dress the graybox shells.

## L2 eng short ids (do not “fix” from the art sheet)

**James verify (locked):** camelCase on the Leonardo L2 legend is **not** SoT. Do not wire camelCase or long-form ids. The art map duplicates **pin 4** on basement and under-porch — that is art drift. Eng places by `spawn_id`: pin 4 = `basement`, pin 9 = `under_porch_crawl`.

Live markers use only:

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
