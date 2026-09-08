#!/usr/bin/env python3
"""Soft-go Kyle item-rail HUD sprites. Not Steam-final — Kyle may redraw."""

from __future__ import annotations

import hashlib
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
HUD = ROOT / "assets" / "horror" / "hud"

WHITE = (236, 238, 242, 255)
GREY = (168, 172, 180, 255)
DIM = (70, 74, 82, 255)
INNER = (48, 50, 56, 255)
BLUE = (80, 190, 255, 255)
AMBER = (250, 184, 30, 255)
KEY_Y = (255, 214, 46, 255)
GUN = (196, 200, 206, 255)
SHOVEL = (196, 150, 78, 255)
CROW = (220, 64, 42, 255)
BAND_W = (244, 244, 246, 255)
BAND_R = (210, 36, 48, 255)
BATT_G = (46, 176, 78, 255)
LOCK = (90, 196, 255, 255)
EV_P = (168, 92, 220, 255)
ROPE = (176, 122, 64, 255)
FUSE = (232, 122, 36, 255)
MED = (36, 168, 86, 255)
FLASH_Y = (255, 214, 46, 255)
FLASH_C = (70, 196, 255, 255)


def blank(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def glow_from(mask_img: Image.Image, color: tuple[int, int, int, int], radius: int) -> Image.Image:
    alpha = mask_img.split()[-1]
    blur = alpha.filter(ImageFilter.GaussianBlur(radius))
    tint = Image.new("RGBA", mask_img.size, color)
    out = Image.new("RGBA", mask_img.size, (0, 0, 0, 0))
    out.paste(tint, (0, 0), blur)
    return out


def octagon_pts(cx: float, cy: float, r: float) -> list[tuple[float, float]]:
    # Regular octagon, flat-top-ish via 22.5° offset so it reads as a cut-corner square.
    pts: list[tuple[float, float]] = []
    for i in range(8):
        a = math.radians(22.5 + i * 45.0)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def draw_octagon(draw: ImageDraw.ImageDraw, cx: float, cy: float, r: float, fill, outline, width: int) -> None:
    pts = octagon_pts(cx, cy, r)
    draw.polygon(pts, fill=fill, outline=outline)
    if width > 1:
        draw.line(pts + [pts[0]], fill=outline, width=width, joint="curve")


def make_well(selected: bool = False) -> Image.Image:
    s = 128
    img = blank(s, s)
    cx = cy = s * 0.5
    rim = BLUE if selected else WHITE
    glow_c = (80, 190, 255, 210) if selected else (220, 224, 232, 160)
    glow = blank(s, s)
    g = ImageDraw.Draw(glow)
    draw_octagon(g, cx, cy, 50, None, rim, 10 if selected else 6)
    img = Image.alpha_composite(img, glow_from(glow, glow_c, 14 if selected else 9))
    if selected:
        img = Image.alpha_composite(img, glow_from(glow, (40, 140, 255, 160), 7))
    d = ImageDraw.Draw(img)
    # Hollow well — dark interior, double rim, corner diamonds.
    draw_octagon(d, cx, cy, 48, (8, 8, 10, 210), rim, 3 if selected else 2)
    draw_octagon(d, cx, cy, 42, None, INNER if not selected else (40, 90, 130, 255), 1)
    for i in range(8):
        a = math.radians(22.5 + i * 45.0)
        # diamonds only on the four cut corners (odd indices)
        if i % 2 == 0:
            continue
        px = cx + 36 * math.cos(a)
        py = cy + 36 * math.sin(a)
        diamond = [(px, py - 3), (px + 3, py), (px, py + 3), (px - 3, py)]
        d.polygon(diamond, fill=GREY if not selected else (120, 190, 230, 255))
    return img


def save(img: Image.Image, stem: str) -> None:
    path = HUD / f"{stem}.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, "PNG")
    write_import(stem)
    print("wrote", path.relative_to(ROOT))


def write_import(stem: str) -> None:
    digest = hashlib.md5(f"horror/hud/{stem}.png".encode()).hexdigest()
    uid = "uid://h" + digest[:11]
    ctex = f"res://.godot/imported/{stem}.png-{digest}.ctex"
    text = f"""[remap]

importer="texture"
type="CompressedTexture2D"
uid="{uid}"
path="{ctex}"
metadata={{
"vram_texture": false
}}

[deps]

source_file="res://assets/horror/hud/{stem}.png"
dest_files=["{ctex}"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""
    (HUD / f"{stem}.png.import").write_text(text)


def icon_canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = blank(128, 128)
    return img, ImageDraw.Draw(img)


def draw_key(d: ImageDraw.ImageDraw) -> None:
    # Horizontal skeleton key, yellow.
    d.ellipse((28, 50, 56, 78), outline=KEY_Y, width=4)
    d.ellipse((34, 56, 50, 72), outline=KEY_Y, width=2)
    d.line((56, 64, 100, 64), fill=KEY_Y, width=5)
    d.line((88, 64, 88, 80), fill=KEY_Y, width=4)
    d.line((96, 64, 96, 76), fill=KEY_Y, width=4)


def draw_firearm(d: ImageDraw.ImageDraw) -> None:
    d.polygon([(30, 58), (96, 58), (100, 66), (70, 66), (62, 86), (48, 86), (54, 66), (30, 66)], fill=GUN)
    d.rectangle((96, 60, 102, 64), fill=(220, 48, 48, 255))  # muzzle pip


def draw_shovel(d: ImageDraw.ImageDraw) -> None:
    d.line((46, 86, 86, 42), fill=SHOVEL, width=6)
    d.polygon([(78, 30), (100, 46), (90, 56), (72, 42)], fill=SHOVEL)
    d.rectangle((40, 84, 52, 96), fill=(150, 110, 60, 255))


def draw_crowbar(d: ImageDraw.ImageDraw) -> None:
    d.line((40, 92, 88, 40), fill=CROW, width=7)
    d.arc((78, 24, 108, 54), 200, 40, fill=CROW, width=7)


def draw_bandage(d: ImageDraw.ImageDraw) -> None:
    d.rounded_rectangle((28, 52, 100, 76), radius=6, fill=BAND_W)
    d.rectangle((58, 52, 70, 76), fill=BAND_R)


def draw_battery_pack(d: ImageDraw.ImageDraw) -> None:
    d.rounded_rectangle((36, 40, 86, 88), radius=6, fill=BATT_G)
    d.rectangle((86, 54, 94, 74), fill=KEY_Y)
    for x in (46, 58, 70):
        d.rectangle((x, 50, x + 6, 78), fill=(20, 80, 36, 220))


def draw_lockpick(d: ImageDraw.ImageDraw) -> None:
    d.line((40, 88, 78, 44), fill=LOCK, width=4)
    d.arc((70, 28, 98, 56), 200, 20, fill=LOCK, width=4)


def draw_evidence(d: ImageDraw.ImageDraw) -> None:
    d.rounded_rectangle((40, 36, 88, 92), radius=3, outline=EV_P, width=4)
    d.rectangle((46, 42, 82, 70), fill=(40, 20, 56, 255))
    d.ellipse((56, 50, 72, 66), fill=KEY_Y)
    d.polygon([(54, 78), (64, 64), (74, 78)], fill=KEY_Y)


def draw_rope(d: ImageDraw.ImageDraw) -> None:
    d.arc((36, 36, 92, 92), 0, 360, fill=ROPE, width=8)
    d.arc((48, 48, 80, 80), 40, 300, fill=ROPE, width=6)
    d.ellipse((58, 58, 70, 70), outline=ROPE, width=3)


def draw_fuse(d: ImageDraw.ImageDraw) -> None:
    d.rounded_rectangle((54, 28, 74, 100), radius=8, fill=FUSE)
    d.line((64, 40, 58, 54, 70, 66, 60, 80, 68, 90), fill=(40, 20, 8, 255), width=3)


def draw_medkit(d: ImageDraw.ImageDraw) -> None:
    d.rounded_rectangle((36, 36, 92, 92), radius=6, fill=MED)
    d.rectangle((58, 46, 70, 82), fill=WHITE)
    d.rectangle((46, 58, 82, 70), fill=WHITE)


def draw_flashlight(d: ImageDraw.ImageDraw) -> None:
    d.rounded_rectangle((28, 54, 78, 74), radius=4, fill=FLASH_Y)
    d.polygon([(78, 50), (96, 46), (96, 82), (78, 78)], fill=FLASH_C)
    d.polygon([(96, 56), (116, 50), (116, 78), (96, 72)], fill=(70, 196, 255, 90))


ICONS = {
    "icon_key": draw_key,
    "icon_firearm": draw_firearm,
    "icon_shovel": draw_shovel,
    "icon_crowbar": draw_crowbar,
    "icon_bandage": draw_bandage,
    "icon_battery_pack": draw_battery_pack,
    "icon_lockpick": draw_lockpick,
    "icon_evidence": draw_evidence,
    "icon_rope": draw_rope,
    "icon_fuse": draw_fuse,
    "icon_medkit": draw_medkit,
    "icon_flashlight": draw_flashlight,
}


def make_signal_empty() -> Image.Image:
    """All-grey 4-bar signal, generated from the locked weak/full language."""
    src = HUD / "signal_weak.png"
    if src.exists():
        im = Image.open(src).convert("RGBA")
        px = im.load()
        w, h = im.size
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a < 16:
                    continue
                # Collapse yellow/green fills to charcoal empty bars.
                if a >= 16:
                    px[x, y] = (58, 60, 68, min(a, 210))
        return im
    img, d = icon_canvas()
    bars = [(36, 78, 50, 96), (56, 64, 70, 96), (76, 50, 90, 96), (96, 36, 110, 96)]
    for box in bars:
        d.rounded_rectangle(box, radius=4, fill=DIM)
    return img


def make_battery_empty() -> Image.Image:
    """Horizontal empty battery shell. Eng owns fill % — no baked charge."""
    w, h = 160, 56
    img = blank(w, h)
    glow = blank(w, h)
    g = ImageDraw.Draw(glow)
    g.rounded_rectangle((8, 10, 136, 46), radius=8, outline=AMBER, width=6)
    g.rectangle((136, 20, 148, 36), outline=AMBER, width=4)
    img = Image.alpha_composite(img, glow_from(glow, (250, 184, 30, 140), 6))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((10, 12, 134, 44), radius=7, outline=AMBER, width=3)
    d.rectangle((134, 21, 146, 35), outline=AMBER, width=3)
    d.rectangle((14, 16, 130, 40), fill=(6, 6, 8, 200))
    return img


def main() -> None:
    save(make_well(False), "slot_empty")
    save(make_well(True), "slot_selected")
    save(make_signal_empty(), "signal_empty")
    save(make_battery_empty(), "battery_empty")
    for stem, fn in ICONS.items():
        img, d = icon_canvas()
        fn(d)
        save(img, stem)


if __name__ == "__main__":
    main()
