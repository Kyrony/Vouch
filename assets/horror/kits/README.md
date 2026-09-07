# Leonardo environment kits (soft-go graybox)

Wiring graybox aligned to Lauren-cleared Leonardo boards. **Not Steam-final art.**
A Blender/GLB kitbash + disclosure pass may replace these primitives later.

## Family house — porch / under-porch crawl

Kit language: 1-story suburban, raised porch, foundation pillars, stairs, shed
module, desaturated night + magenta porch mood.

- Kit floor plan target: **~13.5 × 11 m** (bedroom at front-right).
- Live v0.5 footprint stays `FAMILY_HOUSE_SIZE` (8 × 6.5 m) so the ~40 m
  cul-de-sac ring still fits. Interior rooms follow the kit plan at that scale.
- Pin 9 `under_porch_crawl` is a dark low volume under house A’s porch
  (`FamilyHouse_A/UnderPorchCrawl`). **No grave wording.**
- Nearby `ShedModule` on each house is dressing only. The L2 `family_shed`
  pin remains `Outdoor/FamilyShed`.

## PM bunker + utility closet

Kit language: sealed stained concrete, industrial pipes/shelves/workbench,
red + yellow neon strips, old fluorescent tubes.

- Lives under `PMMansion/Bunker` (L4 names unchanged).
- Pin 3 `bunker_utility` stays inside `UtilityCloset`.
- No gore pile. No guns.

Eng short L2 SoT ids are unchanged (`under_porch_crawl`, `bunker_utility`, …).
