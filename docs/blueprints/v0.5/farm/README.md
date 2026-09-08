# Leonardo farm-country layer pack (aligned SoT)

Kyle / Leonardo plates for the **open farm** Host Match. Soft-go: **terrain, roads, and labeled spawn markers only** — no building or mast meshes in the live Start Match world.

| Layer | Plate | What it locks |
| --- | --- | --- |
| **L1 / L1b** | farm-country + QA terrain/roads | Open/hilly footprint, ~80 m scale, west hub + east oval loop, curbs, contour hills. |
| **L2** | QA spawn pins + CSV | 11 alive-only child pins. **Eng short `spawn_id`s are SoT 1:1** — ignore art camelCase / pin-number drift. |
| **L3** | (deferred) | Tower candidates are **not** built into the live farm. |
| **L4** | (deferred) | PM interior rooms are **not** built into the live farm. |

## L2 eng short ids (do not “fix” from the art sheet)

**James verify (locked):** camelCase on Leonardo legends is **not** SoT. Do not wire camelCase or long-form ids. The QA plate may omit **pin 9** — still place `under_porch_crawl` at the House A porch pad.

Live markers use only:

1. `pm_attic` — west-inner north of the east loop
2. `master_bedroom`
3. `bunker_utility`
4. `basement` — pin 4, west-inner south of the loop
5. `uncle_bedroom` — east-inner north
6. `uncle_garage`
7. `family_shed` — far northwest field
8. `storm_drain` — west road junction
9. `under_porch_crawl` — House A porch / dirt hide, **no grave**
10. `garden_well` — field just west of the east loop
11. `car_trunk` — outside the south curve of the east loop

Canonical table: [`../L2_child_rng_spawns.csv`](../L2_child_rng_spawns.csv).

## Live Host Match

World: +X east, +Z south, origin = west farm-road hub. East oval loop is the old PM pad. Families spawn on outdoor pads; PM on the east courtyard pad.

`NeighborhoodV05.OUTDOOR_ONLY` is on. `GRAYBOX_NEIGHBORHOOD` is off.
