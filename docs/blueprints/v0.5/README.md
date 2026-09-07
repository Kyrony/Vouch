# Neighborhood Layout v0.5 (Leonardo, production look)

Kyle locked these sheets as the graybox production look. Eng traces in this folder match the Godot factory in `scripts/horror/`.

| Sheet | File | What it locks |
| --- | --- | --- |
| Master | `master.png` | Whole neighborhood. **No escape routes** on the sheet — field exit stays soft-gated. |
| L1 Base Architecture | `L1-base.png` | Houses A–D around the cul-de-sac, uncle + garage, large PM mansion **east**, roads/curbs, ~40 m scale. |
| L2 Child RNG Spawns | `L2-source-of-truth.png`, `L2-spawns.png` | 11 alive-only pins. **SoT is the table**, not dirty L2 map labels. |
| L3 Towers & Service | `L3-towers.png` | Many mast candidates; **3 active / match**; **1 always near the PM mansion**; service / weak / dead phone radii. |
| L4 PM Interior | `L4-pm-interior.png` | Attic, master bedroom, study, kitchen, dining, living, bathroom, hallway, stairwell, basement, bunker, utility closet + ducts. |

## L2 source of truth

Canonical pin list: [`L2_child_rng_spawns.csv`](L2_child_rng_spawns.csv) / [`L2_child_rng_spawns.md`](L2_child_rng_spawns.md).

`spawn_id` values are the **eng short ids** from PR #23 (`pm_attic`, `master_bedroom`, `bunker_utility`, `basement`, …). Callouts are human labels only.

Earlier Leonardo L2 art had pin# / label mismatches. Those dirty numbers are not used for world markers.

## Escape

Master sheet draws **no escape routes**. The graybox keeps a soft-gated, unmarked west-yard zone (`HorrorEscapeZone`, `soft_gated` meta). No signage.
