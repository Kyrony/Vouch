# VOUCH neon-horror HUD icons (soft-go)

Wiring reference for the horror HUD / inventory — **not Steam-final art**.

Kyle-locked HUD meters are the live language:

- **Health over stamina** (top-left stack) — `health_bar_empty.png` (horror vial / ECG etch) and `stamina_bar_empty.png` (yellow track). Fill % is **eng-owned** in Godot (`TextureProgressBar` + generated fill from color refs). Do not ship mid/low `*_fill*.png`.
- **No fear bar** and **no side chips** on the live HUD.
- **Top-right** — `signal_empty` / `signal_full` / `signal_weak` / `signal_dead` widget plus `battery_empty.png` (eng-owned fill %). Signal/battery are **not** rail items.
- **Right item rail** — five octagon wells **88×80**. Prefer Kyle-locked K7 overlays in `res://hud/k7_overlays/03_rail_overlays/` (`slot_empty`, `slot_selected`, `slot_empty_selected`). Soft-go `slot_empty.png` / `slot_selected.png` remain fallbacks. Filled = well + `icon_*.png` (or `04_icons/` when those land). Items/consumables only; not a bottom hotbar.
- **K7 phone chrome** — `res://hud/k7_overlays/` PhoneRoot / InteractPrompt overlays sit on functional Controls (`mouse_filter = IGNORE`). Eng owns fills.
- **Phone LED** — yellow smartphone silhouette with LED bloom (camera light only). Stays a device, not a rail well.
- **Interact** — `key_e.png` prompt badge + pickup / missing-child marks

There is **no classic `flashlight.png` / `torch.png` glyph**. Light is the phone’s camera LED. The rail may show `icon_flashlight.png` as an inventory pictogram only.

Menu / controls kit textures live in `assets/horror/ui/` (banner without an X-stick, 9-slice-feel panels, reticles).

Prefer dropping Kyle-locked replacement textures here with the same filenames; `HudIconPack` and `NeonHud` load them when imported. Ornate v2 hearts / pulse / eye glyphs may remain unused.

Diegetic smartphone (`ITEM_DEVICE_SMARTPHONE_01`, inventory id `phone`) lives in `scripts/horror/items/`. Sheet battery numbers (~15%/min LED, ~2%/min passive) are **concept only** — eng-owned tunables are on `PhoneDevice`.
