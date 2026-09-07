#!/usr/bin/env python3
"""Generate soft-go neon-horror HUD glyphs matching Leonardo's v2 pack.

PHONE LED is a yellow smartphone silhouette with LED glow — never a torch.
These PNGs are wiring refs; Leonardo may redraw before Steam.
"""

from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path

W = 128
OUT = Path(__file__).resolve().parents[2] / "assets" / "horror" / "hud"


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


class Canvas:
    def __init__(self, n: int = W) -> None:
        self.n = n
        self.px = [[(0, 0, 0, 0) for _ in range(n)] for _ in range(n)]

    def blend(self, x: int, y: int, r: int, g: int, b: int, a: float) -> None:
        if not (0 <= x < self.n and 0 <= y < self.n) or a <= 0:
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
                self.blend(xi + dx, yi + dy, color[0], color[1], color[2], alpha * (t ** 1.6))

    def line(self, x0: float, y0: float, x1: float, y1: float, color: tuple[int, int, int], width: float = 2.2, alpha: float = 1.0) -> None:
        steps = max(2, int(math.hypot(x1 - x0, y1 - y0) * 2))
        for i in range(steps + 1):
            t = i / steps
            self.glow_dot(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, color, width, alpha)

    def polyline(self, pts: list[tuple[float, float]], color: tuple[int, int, int], width: float = 2.2) -> None:
        for a, b in zip(pts, pts[1:]):
            self.line(a[0], a[1], b[0], b[1], color, width)

    def fill_poly(self, pts: list[tuple[float, float]], color: tuple[int, int, int], alpha: float = 0.85) -> None:
        if len(pts) < 3:
            return
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        minx, maxx = int(min(xs)), int(max(xs))
        miny, maxy = int(min(ys)), int(max(ys))
        for y in range(miny, maxy + 1):
            hits: list[float] = []
            for i, (x1, y1) in enumerate(pts):
                x2, y2 = pts[(i + 1) % len(pts)]
                if (y1 <= y < y2) or (y2 <= y < y1):
                    hits.append(x1 + (x2 - x1) * (y - y1) / (y2 - y1 + 1e-6))
            hits.sort()
            for a, b in zip(hits[0::2], hits[1::2]):
                for x in range(int(a), int(b) + 1):
                    self.blend(x, y, color[0], color[1], color[2], alpha)

    def ring(self, cx: float, cy: float, radius: float, color: tuple[int, int, int], width: float = 3.0, segs: int = 4, gap: float = 0.18) -> None:
        for s in range(segs):
            a0 = s * (math.tau / segs) + gap
            a1 = (s + 1) * (math.tau / segs) - gap
            pts = []
            steps = 14
            for i in range(steps + 1):
                a = a0 + (a1 - a0) * i / steps
                pts.append((cx + math.cos(a) * radius, cy + math.sin(a) * radius))
            self.polyline(pts, color, width)

    def save(self, name: str) -> None:
        write_png(OUT / name, self.px)


RED = (255, 48, 72)
CYAN = (56, 230, 255)
VIOLET = (186, 82, 255)
GOLD = (255, 210, 48)
GREEN = (64, 235, 96)
WEAK = (255, 208, 42)
DEAD = (255, 46, 52)


def heart() -> None:
    c = Canvas()
    cx, cy, s = 64.0, 58.0, 2.05
    pts = []
    for i in range(48):
        t = i * math.tau / 48.0
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((cx + x * s, cy - y * s))
    c.fill_poly(pts, RED, 0.55)
    c.polyline(pts + [pts[0]], RED, 2.6)
    ekg = [(28, 62), (42, 62), (50, 48), (58, 78), (66, 40), (74, 70), (82, 62), (100, 62)]
    c.polyline(ekg, (255, 180, 190), 2.0)
    for x, h in ((52, 18), (64, 24), (76, 16)):
        c.line(x, 96, x + 2, 96 + h, RED, 2.0, 0.7)
    c.save("health_heart.png")


def stamina() -> None:
    c = Canvas()
    c.ring(64, 64, 38, CYAN, 3.2, 4, 0.22)
    wave = []
    for i in range(28):
        x = 30 + i * 2.4
        y = 64 + math.sin(i * 0.55) * 14
        wave.append((x, y))
    c.polyline(wave, CYAN, 2.6)
    c.save("stamina_pulse.png")


def fear() -> None:
    c = Canvas()
    # almond eye
    eye = [(20, 64), (40, 42), (64, 36), (88, 42), (108, 64), (88, 86), (64, 92), (40, 86)]
    c.fill_poly(eye, VIOLET, 0.28)
    c.polyline(eye + [eye[0]], VIOLET, 2.4)
    for a in range(16):
        ang = a * math.tau / 16
        c.glow_dot(64 + math.cos(ang) * 14, 64 + math.sin(ang) * 16, VIOLET, 2.4, 0.9)
    c.glow_dot(64, 64, (40, 10, 60), 10, 0.95)
    c.glow_dot(64, 64, (230, 210, 255), 4, 1.0)
    for y, a in ((50, 0.95), (64, 1.0), (78, 0.85)):
        c.line(24, y, 104, y, (220, 160, 255), 1.6, a)
    c.save("fear_eye.png")


def phone_led() -> None:
    """Yellow smartphone + LED bloom. Not a handheld torch."""
    c = Canvas()
    body = [(46, 22), (82, 22), (88, 30), (88, 100), (82, 108), (46, 108), (40, 100), (40, 30)]
    c.fill_poly(body, (36, 28, 18), 0.95)
    c.polyline(body + [body[0]], GOLD, 2.8)
    c.line(50, 28, 78, 28, GOLD, 1.4, 0.6)
    # LED at top-right of body
    c.glow_dot(80, 34, GOLD, 10, 1.0)
    c.glow_dot(80, 34, (255, 255, 220), 4, 1.0)
    for ang, length in ((-0.7, 34), (-0.35, 38), (0.0, 32), (0.3, 28)):
        c.line(80, 34, 80 + math.cos(ang) * length, 34 + math.sin(ang) * length, GOLD, 2.2, 0.7)
    c.save("phone_led.png")


def signal_full() -> None:
    c = Canvas()
    for i, h in enumerate((22, 34, 46, 58, 70)):
        x = 22 + i * 18
        y = 96 - h
        c.fill_poly([(x, y), (x + 12, y), (x + 12, 96), (x, 96)], GREEN, 0.9)
    c.save("signal_full.png")


def signal_weak() -> None:
    c = Canvas()
    for i, h in enumerate((22, 34, 46, 58, 70)):
        x = 22 + i * 18
        y = 96 - h
        on = i < 2
        col = WEAK if on else (70, 62, 40)
        c.fill_poly([(x, y), (x + 12, y), (x + 12, 96), (x, 96)], col, 0.9 if on else 0.35)
    c.save("signal_weak.png")


def signal_dead() -> None:
    c = Canvas()
    for i, h in enumerate((22, 34, 46, 58, 70)):
        x = 22 + i * 18
        y = 96 - h
        c.fill_poly([(x, y), (x + 12, y), (x + 12, 96), (x, 96)], (70, 40, 42), 0.28)
    c.ring(64, 56, 28, DEAD, 3.4, 1, 0.0)
    c.line(46, 40, 82, 76, DEAD, 3.4)
    c.save("signal_dead.png")


def ability() -> None:
    c = Canvas()
    c.ring(64, 64, 42, GOLD, 3.4, 4, 0.2)
    # skull
    c.fill_poly([(48, 40), (80, 40), (86, 58), (78, 78), (50, 78), (42, 58)], GOLD, 0.35)
    c.polyline([(48, 40), (80, 40), (86, 58), (78, 78), (50, 78), (42, 58), (48, 40)], GOLD, 2.2)
    c.glow_dot(54, 56, GOLD, 5, 0.9)
    c.glow_dot(74, 56, GOLD, 5, 0.9)
    c.line(56, 84, 56, 96, GOLD, 2.2)
    c.line(64, 84, 64, 98, GOLD, 2.2)
    c.line(72, 84, 72, 96, GOLD, 2.2)
    c.save("ability_skull.png")


def supply() -> None:
    c = Canvas()
    kit = [(28, 40), (100, 40), (104, 48), (104, 92), (28, 92), (24, 48)]
    c.fill_poly(kit, RED, 0.4)
    c.polyline(kit + [kit[0]], RED, 2.6)
    c.line(64, 50, 64, 82, RED, 4.0)
    c.line(48, 66, 80, 66, RED, 4.0)
    c.line(44, 96, 44, 114, RED, 2.0, 0.7)
    c.line(64, 96, 64, 118, RED, 2.0, 0.7)
    c.save("supply_kit.png")


def hide() -> None:
    c = Canvas()
    for x, y in ((22, 22), (106, 22), (22, 106), (106, 106)):
        s = 1 if x < 64 else -1
        t = 1 if y < 64 else -1
        c.line(x, y, x + 16 * s, y, CYAN, 2.4)
        c.line(x, y, x, y + 16 * t, CYAN, 2.4)
    # crouch silhouette
    c.glow_dot(64, 48, CYAN, 8, 0.9)
    c.line(64, 54, 64, 78, CYAN, 3.0)
    c.line(64, 78, 48, 96, CYAN, 2.6)
    c.line(64, 78, 80, 88, CYAN, 2.6)
    c.line(64, 62, 46, 70, CYAN, 2.4)
    c.save("hide_stealth.png")


def panic() -> None:
    c = Canvas()
    c.ring(64, 60, 36, VIOLET, 3.0, 1, 0.0)
    jagged = [(32, 60), (42, 48), (50, 78), (58, 36), (66, 88), (74, 40), (84, 72), (96, 58)]
    c.polyline(jagged, VIOLET, 2.6)
    c.line(50, 96, 50, 116, VIOLET, 2.0, 0.7)
    c.line(64, 96, 64, 118, VIOLET, 2.0, 0.7)
    c.save("panic_warning.png")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    heart()
    stamina()
    fear()
    phone_led()
    signal_full()
    signal_weak()
    signal_dead()
    ability()
    supply()
    hide()
    panic()
    print(f"wrote HUD icons -> {OUT}")


if __name__ == "__main__":
    main()
