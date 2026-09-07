# Neighborhood Layout v0.5 (Leonardo, production look)

Kyle locked these sheets as the graybox production look. Eng traces in this folder match the Godot factory in `scripts/horror/`.

| Sheet | File | What it locks |
| --- | --- | --- |
| Master | `master.png` | Whole neighborhood. **No escape routes** on the sheet — field exit stays soft-gated. |
| L1 Base Architecture | `L1-base.png` | Houses A–D around the cul-de-sac, uncle + garage, large PM mansion **east**, roads/curbs, ~40 m scale. |
| L2 Child RNG Spawns | `L2-source-of-truth.png`, `L2-spawns.png` | 11 alive-only pins. **SoT is the table**, not dirty L2 map labels. |
| L3 Towers & Service | `L3-towers.png` | Many mast candidates; **3 active / match**; **1 always near the PM mansion**; service / weak / dead phone radii. |
| L4 PM Interior | `L4-pm-interior.png` | Attic, master bedroom, study, kitchen, dining, living, bathroom, hallway, stairwell, basement, bunker, utility closet + ducts. |
| HUD icon pack (soft-go) | wired in `assets/horror/hud/` | Leonardo v2 neon-horror HUD: heart / cyan pulse / violet glitch-eye / **phone LED** (not a torch) / signal full-weak-dead. Wiring ref — Leonardo redraw may replace textures before Steam. |
| Smartphone item (soft-go) | `ITEM_DEVICE_SMARTPHONE_01` | Graphite/gold phone; camera LED is the only flashlight. Sheet drain (~15%/min LED, ~2%/min passive) is concept only — eng tunables live on `PhoneDevice`. |

## L2 source of truth

Canonical pin list: [`L2_child_rng_spawns.csv`](L2_child_rng_spawns.csv) / [`L2_child_rng_spawns.md`](L2_child_rng_spawns.md).

`spawn_id` values are the locked **eng short ids** (`pm_attic`, `master_bedroom`, `bunker_utility`, `basement`, `garden_well`, `car_trunk`, …). Callouts are human labels only.

L2 art map labels are deferred. Dirty pin# / label mismatches are not used for world markers.

## Escape

Master sheet draws **no escape routes**. The graybox keeps a soft-gated, unmarked west-yard zone (`HorrorEscapeZone`, `soft_gated` meta). No signage.
