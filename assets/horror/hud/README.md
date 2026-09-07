# VOUCH neon-horror HUD icons (soft-go)

Wiring reference for the horror HUD / inventory — **not Steam-final art**.

Leonardo’s v2 pack is the icon language source of truth:

- **Health** — red neon heart + EKG
- **Stamina** — cyan pulse in a segmented ring
- **Fear** — violet glitch-eye
- **Phone LED** — yellow smartphone silhouette with LED bloom (camera light only)
- **Signal** — full (green bars) / weak (yellow bars) / dead (red slash)

There is **no classic flashlight / torch glyph**. Light is the phone’s camera LED.

These PNGs are generated stand-ins so the HUD is readable in-game. A Leonardo redraw may replace every file in this folder before Steam. Prefer dropping replacement textures here with the same filenames; `HudIconPack` and `NeonHud` load them when imported and fall back to procedural neon `Control` drawing if a texture is missing.

Diegetic smartphone (`ITEM_DEVICE_SMARTPHONE_01`, inventory id `phone`) lives in `scripts/horror/items/`. Sheet battery numbers (~15%/min LED, ~2%/min passive) are **concept only** — eng-owned tunables are on `PhoneDevice`.
