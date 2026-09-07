#!/usr/bin/env python3
"""Soft-go Leonardo UI pack stand-ins. Not Steam-final — Leonardo may redraw."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
UI = ROOT / "assets" / "horror" / "ui"
HUD = ROOT / "assets" / "horror" / "hud"
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT_REG = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

YELLOW = (255, 217, 46, 255)
RED = (235, 41, 46, 255)
CYAN = (56, 235, 255, 255)
VIOLET = (186, 82, 255, 255)
WHITE = (236, 238, 242, 255)
STONE = (226, 222, 214, 255)
GREY = (140, 146, 156, 255)


def font(size: int, bold: bool = True) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT if bold else FONT_REG, size)


def blank(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def glow_layer(base: Image.Image, color: tuple[int, int, int, int], radius: int = 8) -> Image.Image:
    mask = Image.new("L", base.size, 0)
    mask.paste(base.split()[-1], (0, 0))
    blur = mask.filter(ImageFilter.GaussianBlur(radius))
    out = Image.new("RGBA", base.size, (0, 0, 0, 0))
    tint = Image.new("RGBA", base.size, color)
    out.paste(tint, (0, 0), blur)
    return out


def draw_v(draw: ImageDraw.ImageDraw, cx: int, cy: int, h: int, color: tuple, width: int) -> None:
    """Banner V only — two arms, no crossbar, no X, no stick through the letter."""
    half = int(h * 0.42)
    top_l = (cx - half, cy - h // 2)
    top_r = (cx + half, cy - h // 2)
    bot = (cx, cy + h // 2)
    draw.line([top_l, bot], fill=color, width=width)
    draw.line([top_r, bot], fill=color, width=width)


def save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, "PNG")
    print("wrote", path.relative_to(ROOT))


def banner_vouch() -> None:
    w, h = 760, 220
    img = blank(w, h)
    glow = blank(w, h)
    g = ImageDraw.Draw(glow)
    draw_v(g, 88, 128, 150, YELLOW, 22)
    img = Image.alpha_composite(img, glow_layer(glow, (255, 210, 40, 180), 14))
    img = Image.alpha_composite(img, glow_layer(glow, (255, 40, 40, 90), 6))
    d = ImageDraw.Draw(img)
    draw_v(d, 88, 128, 150, YELLOW, 18)
    draw_v(d, 88, 128, 142, RED, 10)
    # Inner core only — never a horizontal stick / puppet X through the V.
    letters = [("O", 200), ("U", 320), ("C", 440), ("H", 560)]
    fnt = font(92)
    for ch, x in letters:
        # Puppet string hangs from the top rail to the letter. Strings only — no cross-stick.
        d.line([(x + 28, 8), (x + 28, 72)], fill=WHITE, width=2)
        d.ellipse((x + 24, 4, x + 32, 12), fill=WHITE)
        d.text((x, 78), ch, font=fnt, fill=STONE)
    save(img, UI / "banner_vouch.png")


def preview_gate() -> None:
    w, h = 420, 180
    img = Image.new("RGBA", (w, h), (8, 8, 12, 255))
    d = ImageDraw.Draw(img)
    for i in range(h):
        fog = int(18 + i * 0.12)
        d.line([(0, i), (w, i)], fill=(fog, fog + 2, fog + 6, 255))
    d.polygon([(40, 170), (90, 70), (130, 170)], fill=(12, 14, 16, 255))
    d.polygon([(300, 170), (360, 50), (410, 170)], fill=(10, 12, 14, 255))
    d.rectangle((150, 70, 280, 170), fill=(18, 16, 20, 255))
    d.polygon([(140, 78), (215, 28), (290, 78)], fill=(22, 18, 20, 255))
    d.rectangle((188, 110, 242, 170), fill=(8, 8, 10, 255))
    d.rectangle((188, 110, 242, 170), outline=(90, 20, 22, 255), width=2)
    fog = Image.new("RGBA", (w, h), (40, 42, 48, 70))
    img = Image.alpha_composite(img, fog)
    save(img, UI / "preview_gate.png")


def icon(name: str, drawer, size: int = 64, dest: Path | None = None) -> None:
    img = blank(size, size)
    drawer(ImageDraw.Draw(img), size)
    save(img, (dest or UI) / f"{name}.png")


def icon_play(d: ImageDraw.ImageDraw, s: int) -> None:
    d.polygon([(18, 12), (18, s - 12), (s - 12, s // 2)], fill=YELLOW)


def icon_join(d: ImageDraw.ImageDraw, s: int) -> None:
    d.ellipse((10, 10, 28, 28), outline=WHITE, width=3)
    d.ellipse((26, 10, 44, 28), outline=WHITE, width=3)
    d.arc((6, 30, 32, 56), 200, 340, fill=WHITE, width=3)
    d.arc((22, 30, 50, 56), 200, 340, fill=WHITE, width=3)


def icon_settings(d: ImageDraw.ImageDraw, s: int) -> None:
    c = s // 2
    d.ellipse((c - 8, c - 8, c + 8, c + 8), outline=YELLOW, width=3)
    for i in range(8):
        a = i * math.tau / 8
        x1 = c + math.cos(a) * 12
        y1 = c + math.sin(a) * 12
        x2 = c + math.cos(a) * 20
        y2 = c + math.sin(a) * 20
        d.line([(x1, y1), (x2, y2)], fill=YELLOW, width=4)


def icon_quit(d: ImageDraw.ImageDraw, s: int) -> None:
    d.rounded_rectangle((14, 12, 50, 52), radius=4, outline=WHITE, width=3)
    d.line([(32, 20), (32, 40)], fill=RED, width=4)
    d.polygon([(32, 16), (44, 28), (32, 28)], fill=RED)


def key_badge(label: str, border: tuple, name: str) -> None:
    img = blank(56, 56)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((4, 4, 52, 52), radius=8, outline=border, width=3)
    d.ellipse((40, 8, 48, 16), fill=border)
    fnt = font(22)
    bbox = d.textbbox((0, 0), label, font=fnt)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    d.text(((56 - tw) / 2, (56 - th) / 2 - 2), label, font=fnt, fill=WHITE)
    save(img, UI / f"{name}.png")
    save(img, HUD / f"{name}.png")


def reticle() -> None:
    img = blank(64, 64)
    d = ImageDraw.Draw(img)
    d.line([(32, 10), (32, 24)], fill=WHITE, width=2)
    d.line([(32, 40), (32, 54)], fill=WHITE, width=2)
    d.line([(10, 32), (24, 32)], fill=WHITE, width=2)
    d.line([(40, 32), (54, 32)], fill=WHITE, width=2)
    d.ellipse((30, 30, 34, 34), fill=WHITE)
    save(img, UI / "reticle_white.png")


def signal_bars() -> None:
    img = blank(80, 56)
    d = ImageDraw.Draw(img)
    cols = [YELLOW, (255, 170, 40, 255), (255, 90, 40, 255), RED]
    for i, col in enumerate(cols):
        h = 14 + i * 8
        x = 10 + i * 16
        d.rectangle((x, 46 - h, x + 10, 46), fill=col)
    save(img, UI / "signal_bars.png")


def interact_e(d: ImageDraw.ImageDraw, s: int) -> None:
    d.rounded_rectangle((8, 8, s - 8, s - 8), radius=6, outline=YELLOW, width=3)
    d.rounded_rectangle((12, 12, s - 12, s - 12), fill=(20, 16, 8, 230))
    fnt = font(28)
    d.text((22, 14), "E", font=fnt, fill=YELLOW)


def pickup_use(d: ImageDraw.ImageDraw, s: int) -> None:
    d.polygon([(16, 40), (16, 22), (24, 18), (28, 28), (36, 20), (40, 30), (28, 44)], outline=YELLOW, width=2)
    d.rectangle((40, 36, 54, 50), outline=YELLOW, width=2)
    d.line([(30, 36), (42, 42)], fill=YELLOW, width=1)


def missing_child(d: ImageDraw.ImageDraw, s: int) -> None:
    d.ellipse((22, 10, 42, 30), outline=YELLOW, width=3)
    d.arc((16, 30, 48, 58), 200, 340, fill=YELLOW, width=3)
    d.polygon([(48, 14), (60, 10), (60, 22)], outline=YELLOW, width=2)
    d.line([(54, 12), (54, 20)], fill=YELLOW, width=2)


def door_open(d: ImageDraw.ImageDraw, s: int) -> None:
    d.rectangle((16, 10, 36, 54), outline=CYAN, width=3)
    d.polygon([(36, 10), (50, 16), (50, 50), (36, 54)], outline=CYAN, width=3)
    d.ellipse((42, 30, 46, 36), fill=CYAN)


def hide_porch(d: ImageDraw.ImageDraw, s: int) -> None:
    d.rectangle((8, 22, 56, 28), fill=VIOLET)
    d.line([(12, 22), (12, 50)], fill=VIOLET, width=3)
    d.line([(52, 22), (52, 50)], fill=VIOLET, width=3)
    d.ellipse((28, 32, 38, 42), outline=VIOLET, width=2)
    d.line([(33, 42), (26, 54)], fill=VIOLET, width=2)
    d.line([(33, 42), (40, 54)], fill=VIOLET, width=2)


def menu_pause(d: ImageDraw.ImageDraw, s: int) -> None:
    d.rectangle((16, 16, 48, 22), fill=RED)
    d.rectangle((16, 29, 48, 35), fill=RED)
    d.rectangle((16, 42, 48, 48), fill=RED)


def panel_slice(name: str, border: tuple) -> None:
    s = 48
    img = Image.new("RGBA", (s, s), (12, 10, 14, 230))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, s - 1, s - 1), outline=border, width=2)
    save(img, UI / f"{name}.png")


def atmosphere() -> None:
    w, h = 1280, 720
    img = Image.new("RGBA", (w, h), (6, 6, 10, 255))
    d = ImageDraw.Draw(img)
    for i in range(h):
        t = i / h
        col = (int(6 + t * 10), int(6 + t * 8), int(10 + t * 6), 255)
        d.line([(0, i), (w, i)], fill=col)
    # Distant mansion mass on the right/center.
    d.polygon([(620, 520), (760, 220), (980, 220), (1120, 520)], fill=(10, 9, 12, 255))
    d.rectangle((780, 260, 960, 520), fill=(12, 10, 14, 255))
    d.polygon([(760, 270), (870, 160), (980, 270)], fill=(14, 11, 14, 255))
    for x in range(800, 950, 36):
        d.rectangle((x, 320, x + 16, 350), fill=(40, 8, 10, 255))
    d.rectangle((860, 430, 900, 520), fill=(8, 7, 9, 255))
    for x, top in [(180, 340), (280, 300), (400, 360), (1180, 280)]:
        d.polygon([(x, 520), (x + 30, top), (x + 60, 520)], fill=(8, 9, 10, 255))
    fog = Image.new("RGBA", (w, h), (20, 20, 24, 0))
    fd = ImageDraw.Draw(fog)
    for i in range(180):
        a = int(10 + i * 0.4)
        fd.rectangle((0, 520 - i, w, 520 - i + 2), fill=(28, 28, 32, a))
    img = Image.alpha_composite(img, fog)
    save(img, UI / "menu_atmosphere.png")


def main() -> None:
    banner_vouch()
    preview_gate()
    atmosphere()
    icon("icon_play", icon_play)
    icon("icon_join", icon_join)
    icon("icon_settings", icon_settings)
    icon("icon_quit", icon_quit)
    icon("key_e", interact_e, dest=HUD)
    icon("key_e", interact_e, dest=UI)
    icon("pickup_use", pickup_use, dest=HUD)
    icon("missing_child", missing_child, dest=HUD)
    icon("door_open", door_open, dest=HUD)
    icon("hide_porch", hide_porch, dest=HUD)
    icon("menu_pause", menu_pause, dest=HUD)
    icon("settings_gear", icon_settings, dest=HUD)
    key_badge("E", YELLOW, "key_e_prompt")
    key_badge("Esc", YELLOW, "key_esc")
    key_badge("Tab", GREY, "key_tab")
    reticle()
    signal_bars()
    panel_slice("panel_default", GREY)
    panel_slice("panel_focus", YELLOW)
    panel_slice("panel_alert", RED)
    print("ok")


if __name__ == "__main__":
    main()
