# VOUCH neon-horror HUD icons (soft-go)

Wiring reference for the horror HUD / inventory — **not Steam-final art**.

Kyle-locked HUD meters are the live language:

- **Health over stamina** (top-left stack) — `health_bar_empty.png` (horror vial / ECG etch) and `stamina_bar_empty.png` (yellow track). Fill % is **eng-owned** in Godot (`TextureProgressBar` + generated fill from color refs). Do not ship mid/low `*_fill*.png`.
- **No fear bar** and **no side chips** on the live HUD.
- **Phone LED** — yellow smartphone silhouette with LED bloom (camera light only)
- **Signal** — full (green bars) / weak (yellow bars) / dead (red slash)
- **Interact** — `key_e.png` prompt badge + pickup / missing-child marks

There is **no classic flashlight / torch glyph**. Light is the phone’s camera LED.

Menu / controls kit textures live in `assets/horror/ui/` (banner without an X-stick, 9-slice-feel panels, reticles).

Prefer dropping Kyle-locked replacement textures here with the same filenames; `HudIconPack` and `NeonHud` load them when imported. Ornate v2 hearts / pulse / eye glyphs may remain unused.

Diegetic smartphone (`ITEM_DEVICE_SMARTPHONE_01`, inventory id `phone`) lives in `scripts/horror/items/`. Sheet battery numbers (~15%/min LED, ~2%/min passive) are **concept only** — eng-owned tunables are on `PhoneDevice`.
