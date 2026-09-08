#!/usr/bin/env python3
"""Leonardo HUD v3 empty tracks + chips + signal variants.

EMPTY tracks only — Godot owns fill %. Same capsule language for all three
meters. Chips are neon-rim squares with an inner pill. Signal weak/dead are
tinted variants of full. Not Steam-final if Kyle drops replacement PNGs.
"""

from __future__ import annotations

import hashlib
import math
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HUD = ROOT / "assets" / "horror" / "hud"
SOT_DIRS = [
    Path("/workspace/leonardo-hud-kyle-locked"),
    Path("/workspace/leonardo-hud-v3"),
    Path("/workspace/leonardo-hud-pngs"),
]
TEAL = (56, 210, 200)
STAMINA_GOLD = (255, 179, 0)
VIAL_RED = (168, 28, 36)

RED = (255, 56, 82)
CYAN = (56, 230, 255)
VIOLET = (186, 82, 255)
GOLD = (255, 214, 72)
GREEN = (64, 235, 110)
WEAK = (255, 208, 42)
DEAD = (255, 52, 58)


def _chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def write_png(path: Path, pixels: list[list[tuple[int, int, int, int]]]) -> None:
    h = len(pixels)
    w = len(pixels[0])
    raw = b""
    for row in pixels:
        raw += b"\x00"
        for r, g, b, a in row:
            raw += bytes((r, g, b, a))
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + _chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
        + _chunk(b"IDAT", zlib.compress(raw, 9))
        + _chunk(b"IEND", b"")
    )
    print("wrote", path.relative_to(ROOT), f"{w}x{h}")


def write_import(png: Path) -> None:
    rel = f"res://assets/horror/hud/{png.name}"
    digest = hashlib.md5(rel.encode()).hexdigest()
    dest = f"res://.godot/imported/{png.name}-{digest}.ctex"
    uid = "uid://h3" + hashlib.md5(rel.encode()).hexdigest()[:10]
    text = f"""[remap]

importer="texture"
type="CompressedTexture2D"
uid="{uid}"
path="{dest}"
metadata={{
"vram_texture": false
}}

[deps]

source_file="{rel}"
dest_files=["{dest}"]

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
    png.with_suffix(".png.import").write_text(text)
    print("wrote", png.with_suffix(".png.import").relative_to(ROOT))


class Canvas:
    def __init__(self, w: int, h: int) -> None:
        self.w = w
        self.h = h
        self.px = [[(0, 0, 0, 0) for _ in range(w)] for _ in range(h)]

    def blend(self, x: int, y: int, r: int, g: int, b: int, a: float) -> None:
        if not (0 <= x < self.w and 0 <= y < self.h) or a <= 0:
            return
        or_, og, ob, oa = self.px[y][x]
        src_a = max(0.0, min(1.0, a))
        dst_a = oa / 255.0
        out_a = src_a + dst_a * (1.0 - src_a)
        if out_a <= 0:
            return

        def mix(s: int, d: int) -> int:
            return int(round((s * src_a + d * dst_a * (1.0 - src_a)) / out_a))

        self.px[y][x] = (mix(r, or_), mix(g, og), mix(b, ob), int(round(out_a * 255)))

    def glow_dot(self, x: float, y: float, color: tuple[int, int, int], radius: float, alpha: float = 1.0) -> None:
        r0 = int(math.ceil(radius))
        xi, yi = int(round(x)), int(round(y))
        for dy in range(-r0, r0 + 1):
            for dx in range(-r0, r0 + 1):
                d = math.hypot(dx + (xi - x), dy + (yi - y))
                if d > radius:
                    continue
                t = 1.0 - d / radius
                self.blend(xi + dx, yi + dy, color[0], color[1], color[2], alpha * (t**1.55))

    def line(self, x0: float, y0: float, x1: float, y1: float, color: tuple[int, int, int], width: float = 2.2, alpha: float = 1.0) -> None:
        steps = max(2, int(math.hypot(x1 - x0, y1 - y0) * 2.2))
        for i in range(steps + 1):
            t = i / steps
            self.glow_dot(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, color, width, alpha)

    def fill_round_rect(self, x0: float, y0: float, x1: float, y1: float, radius: float, color: tuple[int, int, int], alpha: float) -> None:
        minx, maxx = int(math.floor(x0)), int(math.ceil(x1))
        miny, maxy = int(math.floor(y0)), int(math.ceil(y1))
        cx = (x0 + x1) * 0.5
        cy = (y0 + y1) * 0.5
        hw = (x1 - x0) * 0.5
        hh = (y1 - y0) * 0.5
        r = min(radius, hw, hh)
        for y in range(miny, maxy + 1):
            for x in range(minx, maxx + 1):
                dx = max(abs(x - cx) - (hw - r), 0.0)
                dy = max(abs(y - cy) - (hh - r), 0.0)
                if dx * dx + dy * dy <= r * r + 0.35:
                    self.blend(x, y, color[0], color[1], color[2], alpha)

    def stroke_round_rect(self, x0: float, y0: float, x1: float, y1: float, radius: float, color: tuple[int, int, int], width: float, alpha: float = 1.0) -> None:
        minx, maxx = int(math.floor(x0 - width)), int(math.ceil(x1 + width))
        miny, maxy = int(math.floor(y0 - width)), int(math.ceil(y1 + width))
        cx = (x0 + x1) * 0.5
        cy = (y0 + y1) * 0.5
        hw = (x1 - x0) * 0.5
        hh = (y1 - y0) * 0.5
        r = min(radius, hw, hh)
        inner = max(0.4, width * 0.35)
        outer = width
        for y in range(miny, maxy + 1):
            for x in range(minx, maxx + 1):
                dx = max(abs(x - cx) - (hw - r), 0.0)
                dy = max(abs(y - cy) - (hh - r), 0.0)
                d = math.hypot(dx, dy) - r
                ad = abs(d)
                if ad <= outer:
                    t = 1.0 - ad / outer
                    glow = 0.35 + 0.65 * (t**1.2)
                    if ad <= inner:
                        glow = 1.0
                    self.blend(x, y, color[0], color[1], color[2], alpha * glow)

    def save(self, name: str) -> Path:
        path = HUD / name
        write_png(path, self.px)
        return path


def health_vial_empty() -> None:
    """Horror-vial empty track: dark red rim, ECG etch, crack, drip."""
    if copy_sot("health_bar_empty.png"):
        return
    w, h = 640, 52
    c = Canvas(w, h)
    x0, y0, x1, y1 = 14.0, 12.0, 626.0, 42.0
    c.fill_round_rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, 5, (10, 8, 10), 0.96)
    c.stroke_round_rect(x0, y0, x1, y1, 5, VIAL_RED, 4.5, 0.35)
    c.stroke_round_rect(x0, y0, x1, y1, 5, VIAL_RED, 1.6, 1.0)
    # Faint ECG through the empty well.
    mid_y = (y0 + y1) * 0.5
    x = x0 + 10
    pts = []
    while x < x1 - 10:
        pts.extend([(x, mid_y), (x + 8, mid_y), (x + 12, mid_y - 7), (x + 16, mid_y + 8), (x + 20, mid_y - 3), (x + 26, mid_y)])
        x += 32
    for a, b in zip(pts, pts[1:]):
        if a[0] < x1 - 8 and b[0] < x1 - 8:
            c.line(a[0], a[1], b[0], b[1], (110, 22, 28), 1.15, 0.55)
    # Teal mount above top-left + V crack.
    c.fill_round_rect(16, 4, 34, 10, 1, TEAL, 0.95)
    c.line(22, 12, 28, 18, (190, 190, 195), 1.4, 0.9)
    c.line(28, 18, 34, 12, (190, 190, 195), 1.4, 0.9)
    # Bottom-center drip + bottom-right slash.
    c.line(320, 42, 316, 48, VIAL_RED, 1.6, 1.0)
    c.line(320, 42, 324, 48, VIAL_RED, 1.6, 1.0)
    c.line(600, 38, 620, 48, VIAL_RED, 1.8, 0.95)
    c.line(608, 48, 624, 48, VIAL_RED, 1.4, 0.9)
    write_import(c.save("health_bar_empty.png"))


def stamina_yellow_empty() -> None:
    """Yellow empty track with tick notches and red/cyan corner tabs."""
    if copy_sot("stamina_bar_empty.png"):
        return
    w, h = 640, 52
    c = Canvas(w, h)
    x0, y0, x1, y1 = 14.0, 12.0, 626.0, 42.0
    c.fill_round_rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, 5, (8, 8, 8), 0.96)
    c.stroke_round_rect(x0, y0, x1, y1, 5, STAMINA_GOLD, 4.2, 0.32)
    c.stroke_round_rect(x0, y0, x1, y1, 5, STAMINA_GOLD, 1.6, 1.0)
    ticks = 25
    for i in range(1, ticks):
        x = x0 + 8 + (x1 - x0 - 16) * i / ticks
        c.line(x, y0 + 6, x, y1 - 6, (70, 70, 74), 0.8, 0.45)
    c.fill_round_rect(16, 4, 34, 10, 1, RED, 0.95)
    c.fill_round_rect(606, 44, 624, 50, 1, CYAN, 0.95)
    write_import(c.save("stamina_bar_empty.png"))


def empty_bar(name: str, color: tuple[int, int, int]) -> None:
    w, h = 640, 72
    c = Canvas(w, h)
    pad = 10.0
    x0, y0, x1, y1 = pad, pad, w - pad, h - pad
    rad = (y1 - y0) * 0.5
    tint = tuple(int(ch * 0.16) for ch in color)
    c.fill_round_rect(x0 + 3, y0 + 3, x1 - 3, y1 - 3, rad - 3, (8, 8, 10), 0.96)
    c.fill_round_rect(x0 + 5, y0 + 5, x1 - 4, y1 - 4, rad - 5, tint, 0.22)
    c.stroke_round_rect(x0, y0, x1, y1, rad, color, 7.5, 0.38)
    c.stroke_round_rect(x0, y0, x1, y1, rad, color, 3.4, 1.0)
    inner = tuple(max(0, ch - 70) for ch in color)
    c.stroke_round_rect(x0 + 3, y0 + 3, x1 - 3, y1 - 3, rad - 3, inner, 1.6, 0.7)
    write_import(c.save(name))


def copy_sot(name: str) -> bool:
    """Prefer Kyle-locked bytes. Never invent a substitute when SoT is on disk."""
    for folder in SOT_DIRS:
        src = folder / name
        if src.is_file() and src.stat().st_size > 32:
            dest = HUD / name
            dest.write_bytes(src.read_bytes())
            if not dest.with_suffix(".png.import").exists():
                write_import(dest)
            print("copied SoT", src, "->", dest.relative_to(ROOT), dest.stat().st_size)
            return True
    return False


def chip(name: str, color: tuple[int, int, int]) -> None:
    if copy_sot(name):
        return
    # Pixel-art squircle + inner pill — locked v3 shape language.
    s = 64
    c = Canvas(s, s)
    c.fill_round_rect(10, 10, 54, 54, 14, (8, 10, 20), 0.98)
    c.stroke_round_rect(10, 10, 54, 54, 14, color, 5.5, 0.32)
    c.stroke_round_rect(10, 10, 54, 54, 14, color, 1.45, 1.0)
    c.stroke_round_rect(20, 28, 44, 36, 5, color, 1.45, 1.0)
    write_import(c.save(name))


def phone_led() -> None:
    if copy_sot("phone_led.png"):
        return
    c = Canvas(128, 128)
    c.fill_round_rect(44, 18, 84, 110, 16, (10, 10, 16), 0.96)
    c.stroke_round_rect(44, 18, 84, 110, 16, GOLD, 6.5, 0.4)
    c.stroke_round_rect(44, 18, 84, 110, 16, GOLD, 2.6, 1.0)
    c.fill_round_rect(54, 28, 74, 38, 6, GOLD, 0.95)
    c.glow_dot(64, 33, (255, 255, 210), 5, 1.0)
    write_import(c.save("phone_led.png"))


def _signal_bars(c: Canvas, lit: int, on: tuple[int, int, int], off: tuple[int, int, int], off_a: float) -> None:
    heights = (28, 42, 56, 72)
    for i, h in enumerate(heights):
        x0 = 26 + i * 20
        y1 = 104
        y0 = y1 - h
        col = on if i < lit else off
        a = 0.96 if i < lit else off_a
        c.fill_round_rect(x0, y0, x0 + 13, y1, 6, col, a)
        if i < lit:
            c.stroke_round_rect(x0, y0, x0 + 13, y1, 6, col, 2.4, 0.5)


def signal_full() -> None:
    if copy_sot("signal_full.png"):
        return
    c = Canvas(128, 128)
    _signal_bars(c, 4, GREEN, (30, 40, 32), 0.2)
    write_import(c.save("signal_full.png"))


def signal_weak() -> None:
    if copy_sot("signal_weak.png"):
        return
    c = Canvas(128, 128)
    _signal_bars(c, 2, WEAK, (46, 46, 50), 0.55)
    write_import(c.save("signal_weak.png"))


def signal_dead() -> None:
    if copy_sot("signal_dead.png"):
        return
    c = Canvas(128, 128)
    _signal_bars(c, 0, DEAD, (36, 40, 48), 0.7)
    # Neon pink/red X over dim bars (locked dead state).
    c.line(38, 38, 90, 90, (255, 72, 110), 3.6, 1.0)
    c.line(90, 38, 38, 90, (255, 72, 110), 3.6, 1.0)
    write_import(c.save("signal_dead.png"))


def main() -> None:
    HUD.mkdir(parents=True, exist_ok=True)
    health_vial_empty()
    stamina_yellow_empty()
    print("ok")


if __name__ == "__main__":
    main()
