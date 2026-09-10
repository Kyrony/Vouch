# K7 diegetic phone HUD overlays

Kyle-locked Leonardo pack. **Exact PNG bytes** — do not regenerate or redraw.

If a Cloud Agent import is missing files under these folders, the attachment bytes failed to land — drop the locked PNGs here and run `python3 tools/write_k7_overlay_imports.py`. Do not invent stand-in art.

## Still needed from Kyle (isolated RGBA cuts)

The live HUD is code-drawn from Phone Chrome v2 so the ECG can animate. Drop **transparent PNGs with no callout labels / captions** into the folders below (lossless RGBA, mipmaps off). Do **not** send the labeled mock as a live overlay — it would freeze the waveform.

**01_phone_overlays/** (cut from chrome v2, no side notes):
- `phone_frame.png` — bezel only, transparent screen hole
- `island_notch.png` — Dynamic Island
- `phone_notch.png` — fallback notch if island is separate
- `status_bar.png` — time / signal / battery chrome
- `bottom_nav.png` — GRID / ECG / PROFILE / SETTINGS icons (GRID active underline OK)
- `flashlight_on.png` / `flashlight_off.png` — Material pill switch only
- Optional: `camera_rear.png` / `camera_front.png` dual-lens chips (camera + person glyphs)

**02_bars_overlays/**:
- `ecg_panel_chrome.png` — panel around the waveform, empty of any baked ECG line
- `stamina_track_empty.png` + `stamina_segment.png` — yellow pips
- `signal_track_empty.png` + `signal_segment.png` — green bars

Until those land, Godot draws the chrome. `PHONE_CHROME_V2.png` stays as the artist reference only.

## Layout

| Folder | Contents |
| --- | --- |
| `01_phone_overlays/` | `phone_frame`, `island_notch`, `phone_notch`, `status_bar`, `bottom_nav`, `flashlight_on`, `flashlight_off` |
| `02_bars_overlays/` | `ecg_panel_chrome`, `stamina_track_empty` + `stamina_segment`, `signal_track_empty` + `signal_segment` |
| `03_rail_overlays/` | `slot_empty`, `slot_selected`, `slot_empty_selected`, `rail_all_empty`, `rail_example_filled`, `bevel_detail` — wells **88×80** |
| `04_icons/64/` and `04_icons/128/` | Neon item icons (follow-up if not in this drop): key, firearm, shovel, crowbar, bandage, battery_pack, lockpick, evidence, rope, fuse, medkit, flashlight |
| `05_interact_overlays/` | `interact_prompt`, `interact_prompt_hold` |
| `PHONE_CHROME_V2.png` | Kyle phone chrome reference (camera / flashlight / nav). Live HUD is built in Godot so ECG can animate. |

## Godot 4.3 import

Per-file `.import`:

- **Keep RGBA** — `compress/mode=0` (lossless)
- **Mipmaps off** — `mipmaps/generate=false`
- **Detect 3D off** — `detect_3d/compress_to=0` so the editor cannot flip these to VRAM + mipmaps
- **Filter Linear** — Godot 4 does not store canvas filter in `.import`. Overlay `TextureRect`s set `texture_filter = TEXTURE_FILTER_LINEAR`. Project default canvas filter is Linear.

Regenerate sidecars with `python3 tools/write_k7_overlay_imports.py`.

## Wiring

Overlays are `TextureRect`s with `mouse_filter = IGNORE` on top of functional Controls. Eng owns fills, inventory, and input. No camera switch.

- **PhoneRoot** — diegetic phone HUD (chrome v2 layout). Holstered bottom-left; hold E with phone in-hand inspects it full-screen. ECG is a lead-II heartbeat then isoelectric flatline. Rear/Front camera chips are visual only.
- **ItemRail** — right-edge 5 octagon wells 88×80, hooked to `PlayerInventory` via `NeonHud.set_hotbar`
- **InteractPrompt** — phone-toast tap + hold; `Player._set_interact_prompt` / destroy-hold
