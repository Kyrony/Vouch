# L2 Child RNG Spawns — Leonardo SoT (eng short ids)

Pin source of truth for Neighborhood Layout v0.5. **Use these `spawn_id` values exactly.** They match PR #23 / `ChildSpawnRNG.SPAWN_IDS`.

Do **not** rename to long-form ids (`pm_master_bedroom`, `pm_bunker_utility_closet`, `garden_well_crawlspace`, `car_trunk_curb`). Dirty L2 map callouts (e.g. YUJA BASEMENT, under-porch on the wrong pin) are not source of truth.

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

Host RNG picks **one** pin per match. Place markers on the matching L1 / L4 rooms, not on mislabeled L2 art numbers.
