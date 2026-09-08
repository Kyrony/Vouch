# L2 Child RNG Spawns — Leonardo SoT (eng short ids)

Pin source of truth for Neighborhood Layout v0.5. **Use these `spawn_id` values exactly.** They match `ChildSpawnRNG.SPAWN_IDS`.

Art map labels are deferred. **James verify:** Leonardo legend camelCase (`masterBedroom`, `bunkerUtility`, `underPorchCrawl`, …) is **not** SoT. Do not wire camelCase or long-form ids (`pm_basement`, `bunker_utility_closet`, …).

The farm art sheet **duplicates pin 4** on basement and under-porch. Eng ignores that. **Pin 4 = `basement`** (PM basement). **Pin 9 = `under_porch_crawl`** (House A porch dirt hide). Place markers by `spawn_id`, not by art pin numbers.

All 11 pins are **alive-only**. Pin 9 is an under-porch crawl / dirt hide — no grave wording.

| pin | spawn_id | callout | location_notes |
| --- | --- | --- | --- |
| 1 | `pm_attic` | PM ATTIC | Inside PM mansion attic |
| 2 | `master_bedroom` | PM MASTER BEDROOM | Inside PM mansion master bedroom |
| 3 | `bunker_utility` | PM BUNKER UTILITY CLOSET | Inside PM bunker utility closet |
| 4 | `basement` | PM BASEMENT | Inside PM basement |
| 5 | `uncle_bedroom` | UNCLE BEDROOM | Inside uncle house bedroom |
| 6 | `uncle_garage` | UNCLE GARAGE | Uncle garage structure |
| 7 | `family_shed` | FAMILY SHED | Shed by family houses |
| 8 | `storm_drain` | STORM DRAIN | Street storm drain |
| 9 | `under_porch_crawl` | UNDER-PORCH CRAWL / DIRT HIDE | Under porch crawl / dirt hide — NO grave wording |
| 10 | `garden_well` | GARDEN WELL / CRAWLSPACE | Garden well or crawlspace |
| 11 | `car_trunk` | CAR TRUNK (CURB) | Parked car trunk at curb |

Host RNG picks **one** pin per match. Live farm places a labeled **Spawn Point** box at each eng id on the QA terrain/roads footprint. Pin 9 stays at the House A porch pad when the QA plate omits it. Do not follow mislabeled L2 art numbers.
