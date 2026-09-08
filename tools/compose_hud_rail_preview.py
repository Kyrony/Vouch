#!/usr/bin/env python3
"""Compose a 1280×720 HUD plate from the wired Kyle assets (smoke layout)."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
HUD = ROOT / "assets" / "horror" / "hud"
OUT = Path("/tmp/vouch_hud_rail_preview.png")


def load(stem: str) -> Image.Image:
    return Image.open(HUD / f"{stem}.png").convert("RGBA")


def paste(base: Image.Image, src: Image.Image, xy: tuple[int, int], size: tuple[int, int] | None = None) -> None:
    im = src if size is None else src.resize(size, Image.Resampling.LANCZOS)
    base.alpha_composite(im, dest=xy)


def main() -> None:
    plate = Image.new("RGBA", (1280, 720), (6, 5, 8, 255))
    # faint grid so the plate reads as a HUD mock
    d = ImageDraw.Draw(plate)
    for x in range(0, 1280, 40):
        d.line([(x, 0), (x, 720)], fill=(18, 18, 22, 255), width=1)
    for y in range(0, 720, 40):
        d.line([(0, y), (1280, y)], fill=(18, 18, 22, 255), width=1)

    health = load("health_bar_empty")
    stamina = load("stamina_bar_empty")
    paste(plate, health, (16, 18), (280, 28))
    paste(plate, stamina, (16, 50), (280, 28))

    signal = load("signal_weak")
    battery = load("battery_empty")
    paste(plate, signal, (1148, 12), (56, 44))
    paste(plate, battery, (1112, 58), (140, 42))

    items = ["icon_key", "icon_firearm", "icon_crowbar", None, None]
    well = load("slot_empty")
    selected = load("slot_selected")
    y = 120
    for i, stem in enumerate(items):
        slot = selected if i == 2 else well
        paste(plate, slot, (1192, y), (72, 72))
        if stem:
            icon = load(stem)
            paste(plate, icon, (1204, y + 12), (48, 48))
        y += 72 + 18

    # center reticle
    d.line([(640, 350), (640, 358)], fill=(230, 230, 230, 180), width=2)
    d.line([(640, 362), (640, 370)], fill=(230, 230, 230, 180), width=2)
    d.line([(630, 360), (638, 360)], fill=(230, 230, 230, 180), width=2)
    d.line([(642, 360), (650, 360)], fill=(230, 230, 230, 180), width=2)

    plate.filter(ImageFilter.SMOOTH)
    plate.save(OUT, "PNG")
    print("wrote", OUT, plate.size)


if __name__ == "__main__":
    main()
