#!/usr/bin/env python3
"""Headless K7 overlay + wiring checks (no Godot required)."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HUD = ROOT / "scripts" / "horror" / "ui" / "neon_hud.gd"
PLAYER = ROOT / "scripts" / "player.gd"
OVERLAYS = ROOT / "hud" / "k7_overlays"

REQUIRED = [
    "IMPORT_BLUEPRINT.png",
    "01_phone_overlays/phone_frame.png",
    "01_phone_overlays/island_notch.png",
    "01_phone_overlays/phone_notch.png",
    "01_phone_overlays/status_bar.png",
    "01_phone_overlays/bottom_nav.png",
    "01_phone_overlays/flashlight_on.png",
    "01_phone_overlays/flashlight_off.png",
    "02_bars_overlays/ecg_panel_chrome.png",
    "02_bars_overlays/stamina_track_empty.png",
    "02_bars_overlays/stamina_segment.png",
    "02_bars_overlays/signal_track_empty.png",
    "02_bars_overlays/signal_segment.png",
    "03_rail_overlays/slot_empty.png",
    "03_rail_overlays/slot_selected.png",
    "03_rail_overlays/slot_empty_selected.png",
    "03_rail_overlays/rail_all_empty.png",
    "03_rail_overlays/rail_example_filled.png",
    "03_rail_overlays/bevel_detail.png",
    "05_interact_overlays/interact_prompt.png",
    "05_interact_overlays/interact_prompt_hold.png",
]

ICONS = [
    "key", "firearm", "shovel", "crowbar", "bandage", "battery_pack",
    "lockpick", "evidence", "rope", "fuse", "medkit", "flashlight",
]


def main() -> int:
    src = HUD.read_text()
    player = PLAYER.read_text()
    errors: list[str] = []
    for needle in (
        'name = "PhoneRoot"',
        'name = "ItemRail"',
        'name = "InteractPrompt"',
        "SLOT_PX := 88",
        "SLOT_H := 80",
        "MOUSE_FILTER_IGNORE",
        "TEXTURE_FILTER_LINEAR",
        "set_interact_hold",
    ):
        if needle not in src:
            errors.append(f"neon_hud.gd missing {needle}")
    if "set_hotbar" not in src:
        errors.append("neon_hud.gd lost set_hotbar inventory hook")
    if "set_interact_prompt" not in player or "HOLD [F] · DESTROY" not in player:
        errors.append("player.gd must drive InteractPrompt + hold")
    if "_build_horror_hud" not in player or "neon_hud.gd" not in player:
        errors.append("player.gd must instantiate NeonHud in-match")
    missing = [rel for rel in REQUIRED if not (OVERLAYS / rel).is_file()]
    present = [rel for rel in REQUIRED if (OVERLAYS / rel).is_file()]
    missing_icons = []
    for stem in ICONS:
        if not (OVERLAYS / "04_icons/64" / f"{stem}.png").is_file() and not (
            OVERLAYS / "04_icons/128" / f"{stem}.png"
        ).is_file():
            missing_icons.append(stem)
    for rel in present:
        sidecar = OVERLAYS / f"{rel}.import"
        if not sidecar.is_file():
            errors.append(f"{rel}.import missing")
            continue
        txt = sidecar.read_text()
        if "mipmaps/generate=false" not in txt:
            errors.append(f"{rel}.import mipmaps not off")
        if "compress/mode=0" not in txt:
            errors.append(f"{rel}.import not lossless RGBA")
    print("K7 overlays present:", len(present), "/", len(REQUIRED))
    if missing:
        print("MISSING overlay PNGs (do not invent art):")
        for rel in missing:
            print("  -", rel)
    if missing_icons:
        print("MISSING 04_icons (follow-up):", ", ".join(missing_icons))
    if errors:
        print("WIRING ERRORS:")
        for err in errors:
            print("  -", err)
        return 1
    print("K7 wiring OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
