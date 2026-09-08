# VOUCH neon-horror HUD icons (soft-go)

Wiring reference for the horror HUD / inventory — **not Steam-final art**.

Leonardo HUD **v3** is the meter language source of truth:

- **Health / Stamina / Fear** — shared EMPTY neon-rim capsule tracks (`*_bar_empty.png`) plus matching chips. Fill % is **eng-owned** in Godot (`TextureProgressBar` + generated fill). Do not ship mid/low `*_fill*.png`.
- **Chips** — `health_chip.png` (red), `stamina_chip.png` (cyan), `fear_chip.png` (purple)
- **Phone LED** — yellow smartphone silhouette with LED bloom (camera light only)
- **Signal** — full (green bars) / weak (yellow bars) / dead (red slash)
- **Interact** — `key_e.png` prompt badge + pickup / missing-child marks

There is **no classic flashlight / torch glyph**. Light is the phone’s camera LED.

Menu / controls kit textures live in `assets/horror/ui/` (banner without an X-stick, 9-slice-feel panels, reticles).

Prefer dropping Kyle-locked replacement textures here with the same filenames; `HudIconPack` and `NeonHud` load them when imported. Ornate v2 hearts / pulse / eye glyphs may remain unused.

Diegetic smartphone (`ITEM_DEVICE_SMARTPHONE_01`, inventory id `phone`) lives in `scripts/horror/items/`. Sheet battery numbers (~15%/min LED, ~2%/min passive) are **concept only** — eng-owned tunables are on `PhoneDevice`.
