# Neighborhood Layout v0.5 (Leonardo, production look)

Kyle locked these sheets as the graybox production look. Eng traces in this folder match the Godot factory in `scripts/horror/`.

| Sheet | File | What it locks |
| --- | --- | --- |
| Master | `master.png` | Whole neighborhood. **No escape routes** on the sheet — field exit stays soft-gated. |
| L1 Base Architecture | `L1-base.png` | Original tight cul-de-sac plate (superseded for layout). |
| L1 Farm (aligned pack) | [`farm/L1-farm.png`](farm/L1-farm.png) | **Layout SoT.** Open/hilly footprints, ~80 m scale, spaced houses + east PM mansion. See [`farm/README.md`](farm/README.md). |
| L2 Child RNG (aligned pack) | [`farm/L2-farm.png`](farm/L2-farm.png) | 11 alive-only pins. **Eng short ids 1:1** — ignore art camelCase / number drift. |
| L3 Towers (aligned pack) | [`farm/L3-farm.png`](farm/L3-farm.png) | Many candidates; **3 active / match**; **1 near PM**; service / weak / dead. |
| L4 PM Interior (aligned pack) | [`farm/L4-farm.png`](farm/L4-farm.png) | Attic, master, study, kitchen, dining, living, bath, hallway, stairwell, basement, bunker, utility closet + ducts. |
| HUD icon pack (soft-go) | wired in `assets/horror/hud/` | Leonardo v2 neon-horror HUD: heart / cyan pulse / violet glitch-eye / **phone LED** (not a torch) / signal full-weak-dead. Wiring ref — Leonardo redraw may replace textures before Steam. |
| Smartphone item (soft-go) | `ITEM_DEVICE_SMARTPHONE_01` | Graphite/gold phone; camera LED is the only flashlight. Sheet drain (~15%/min LED, ~2%/min passive) is concept only — eng tunables live on `PhoneDevice`. |
| Family house kit (soft-go) | porch / under-porch crawl | Raised porch, foundation, stairs, shed module. Pin 9 `under_porch_crawl` is a readable low crawl under house A. Live graybox is the **13.5×11 m** kit plan on L1b parcels. No grave wording. |
| PM bunker kit (soft-go) | bunker + utility closet | Sealed concrete, pipes, shelves, workbench, red/yellow neon + fluorescent. Pin 3 `bunker_utility` stays in `UtilityCloset`. No gore, no guns. |

## L2 source of truth

Canonical pin list: [`L2_child_rng_spawns.csv`](L2_child_rng_spawns.csv) / [`L2_child_rng_spawns.md`](L2_child_rng_spawns.md).

`spawn_id` values are the locked **eng short ids** (`pm_attic`, `master_bedroom`, `bunker_utility`, `basement`, `garden_well`, `car_trunk`, …). Callouts are human labels only. CamelCase art legend and long-form ids are rejected.

L2 art map labels and **duplicate art pin 4** (basement + under-porch) are not source of truth. Pin 4 = `basement`. Pin 9 = `under_porch_crawl`.

## Escape

Master sheet draws **no escape routes**. The graybox keeps a soft-gated, unmarked west-yard zone (`HorrorEscapeZone`, `soft_gated` meta). No signage.

L1b farm (eng): open heightfield + farm lanes / east oval loop / west shed loop + hills. Host Match is **terrain + roads + 11 labeled Spawn Point markers** — no house / bunker / mast meshes. Families spawn on outdoor pads; PM on the east courtyard pad. L2 `spawn_id` list is unchanged. `OUTDOOR_ONLY` is on. QA v2 places pin 9 `under_porch_crawl` on the SE road bend.
