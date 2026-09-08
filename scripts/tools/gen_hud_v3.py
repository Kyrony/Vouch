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


def chip(name: str, color: tuple[int, int, int]) -> None:
    s = 64
    c = Canvas(s, s)
    c.fill_round_rect(8, 8, 56, 56, 12, (8, 8, 11), 0.94)
    c.stroke_round_rect(8, 8, 56, 56, 12, color, 6.0, 0.4)
    c.stroke_round_rect(8, 8, 56, 56, 12, color, 2.6, 1.0)
    c.stroke_round_rect(18, 26, 46, 38, 7, color, 2.0, 0.95)
    write_import(c.save(name))


def phone_led() -> None:
    c = Canvas(128, 128)
    c.fill_round_rect(44, 18, 84, 110, 16, (10, 10, 16), 0.96)
    c.stroke_round_rect(44, 18, 84, 110, 16, GOLD, 6.5, 0.4)
    c.stroke_round_rect(44, 18, 84, 110, 16, GOLD, 2.6, 1.0)
    c.fill_round_rect(54, 28, 74, 38, 6, GOLD, 0.95)
    c.glow_dot(64, 33, (255, 255, 210), 5, 1.0)
    write_import(c.save("phone_led.png"))


def _signal_bars(c: Canvas, lit: int, on: tuple[int, int, int], off: tuple[int, int, int], off_a: float) -> None:
    heights = (28, 40, 52, 66)
    for i, h in enumerate(heights):
        x0 = 28 + i * 20
        y1 = 100
        y0 = y1 - h
        col = on if i < lit else off
        a = 0.95 if i < lit else off_a
        c.fill_round_rect(x0, y0, x0 + 12, y1, 4, col, a)
        if i < lit:
            c.stroke_round_rect(x0, y0, x0 + 12, y1, 4, col, 2.2, 0.55)


def signal_full() -> None:
    c = Canvas(128, 128)
    _signal_bars(c, 4, GREEN, (30, 40, 32), 0.2)
    write_import(c.save("signal_full.png"))


def signal_weak() -> None:
    c = Canvas(128, 128)
    _signal_bars(c, 2, WEAK, (50, 42, 28), 0.28)
    write_import(c.save("signal_weak.png"))


def signal_dead() -> None:
    c = Canvas(128, 128)
    _signal_bars(c, 0, DEAD, (62, 32, 34), 0.32)
    c.stroke_round_rect(30, 30, 98, 98, 34, DEAD, 3.4, 1.0)
    c.line(42, 42, 86, 86, DEAD, 3.2, 1.0)
    write_import(c.save("signal_dead.png"))


def main() -> None:
    HUD.mkdir(parents=True, exist_ok=True)
    empty_bar("health_bar_empty.png", RED)
    empty_bar("stamina_bar_empty.png", CYAN)
    empty_bar("fear_bar_empty.png", VIOLET)
    chip("health_chip.png", RED)
    chip("stamina_chip.png", CYAN)
    chip("fear_chip.png", VIOLET)
    phone_led()
    signal_full()
    signal_weak()
    signal_dead()
    print("ok")


if __name__ == "__main__":
    main()
