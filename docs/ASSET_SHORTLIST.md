# Asset shortlist (friends-MVP → art pass)

Candidate third-party kits for a future art pass. **Do not import any pack
into this repo until Lauren clears license + redistribution.**

Current friends-MVP uses **pure Godot graybox primitives** only
(`scenes/Rooms/Room_01.tscn` … `Room_06.tscn`, `Room_PM.tscn`).

## Cleared for research (not yet imported)

| Kit | Author | License | URL | Notes |
| --- | --- | --- | --- | --- |
| **Space Station Kit** | Kenney | **CC0 1.0** (public domain) | https://kenney.nl/assets/space-station-kit | Modular sci-fi blocks; commercial OK; credit appreciated not required. Safe redistribution if we ship `.license` / Kenney credit in README. |
| **Building Kit** | Kenney | **CC0 1.0** | https://kenney.nl/assets/building-kit | Residential/industrial walls, doors, floors. Good match for bunker interiors post-graybox. |
| **Modular Sci-Fi Pack** | Quaternius | **CC0** | https://quaternius.com/packs/scifi.html | Low-poly modular corridors/rooms; CC0 on site. Verify exact pack page before import. |
| **Ultimate Modular Sci-Fi Pack** | Quaternius | **CC0** | https://quaternius.com/packs/ultimatemodularscifipack.html | Larger set; same CC0 policy — confirm per-download page. |

## Do **not** ship without clearance

| Source | Risk |
| --- | --- |
| Random **itch.io** “free” packs | Often “personal use only”, no redistribution, or NC licenses hidden in README. |
| **Sketchfab** / **TurboSquid** freebies | Usually non-commercial or no-derivatives. |
| **Unity Asset Store** ports | License does not transfer to Godot redistribution. |
| **Epic Megascans / Fab** | Engine-specific terms; not automatic for standalone Godot export. |

## Import checklist (when Lauren approves a kit)

1. Download from official author page only; save `LICENSE` or CC0 statement in `assets/third_party/<kit>/LICENSE.txt`.
2. Record author, version, and date in this file.
3. Prefer `.glb` / `.gltf`; keep collision as simple boxes where possible (match friends-MVP rule: mesh ≈ collision).
4. No binary blobs in git without LFS if >5 MB; document import steps in README.
5. Re-run headless smokes (`VOUCH_ROOM_SPAWN_TEST`, `VOUCH_PLAYABLE_LOOP_TEST`) after swapping graybox meshes.

## Status

- **2026-09-07:** Graybox hand-sealed rooms merged for friends-MVP; all kits above are **pending Lauren clearance before import**.
