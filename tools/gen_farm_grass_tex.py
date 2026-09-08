#!/usr/bin/env python3
"""Offline tiled grass/dirt albedo for Kyle's farm mesh. Not menu art."""

from __future__ import annotations

import hashlib
import math
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "horror" / "farm" / "grass_dirt_tile.png"
SIZE = 512


def _h(x: int, y: int, salt: int) -> float:
    raw = hashlib.md5(f"{salt}:{x}:{y}".encode()).digest()
    return raw[0] / 255.0


def _vnoise(x: float, y: float, salt: int, period: int) -> float:
    x0 = int(math.floor(x))
    y0 = int(math.floor(y))
    fx = x - x0
    fy = y - y0
    sx = fx * fx * (3.0 - 2.0 * fx)
    sy = fy * fy * (3.0 - 2.0 * fy)
    n00 = _h(x0 % period, y0 % period, salt)
    n10 = _h((x0 + 1) % period, y0 % period, salt)
    n01 = _h(x0 % period, (y0 + 1) % period, salt)
    n11 = _h((x0 + 1) % period, (y0 + 1) % period, salt)
    return (n00 * (1 - sx) + n10 * sx) * (1 - sy) + (n01 * (1 - sx) + n11 * sx) * sy


def _fbm(u: float, v: float, salt: int, base_period: int, octaves: int = 5) -> float:
    ## u,v in 0..1. Integer base_period keeps the tile seamless.
    amp = 0.5
    period = base_period
    total = 0.0
    norm = 0.0
    for i in range(octaves):
        total += amp * _vnoise(u * period, v * period, salt + i * 17, period)
        norm += amp
        amp *= 0.5
        period *= 2
    return total / norm


def _lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    pix = bytearray(SIZE * SIZE * 3)
    for y in range(SIZE):
        for x in range(SIZE):
            u = x / float(SIZE)
            v = y / float(SIZE)
            # Seamless wrap via 4-corner blend on a torus.
            n = _fbm(u, v, 3, 8)
            n2 = _fbm(u, v, 41, 16)
            clump = _fbm(u, v, 90, 5)
            dirt = _fbm(u, v, 7, 10)
            # Blade-ish high-frequency streak.
            blade = _vnoise(u * 64.0, v * 32.0, 21, 64)
            grass_w = 0.42 + n * 0.38 + clump * 0.20
            dirt_w = max(0.0, dirt - 0.55) * 1.8
            # Olive grass + dry dirt mix. Stay muted so Mat_grass tint can sit on top.
            g_r = _lerp(58, 92, n) + blade * 18.0
            g_g = _lerp(78, 118, n2) + blade * 14.0
            g_b = _lerp(28, 48, n)
            d_r = _lerp(72, 102, dirt)
            d_g = _lerp(58, 78, dirt)
            d_b = _lerp(32, 44, dirt)
            t = min(1.0, max(0.0, dirt_w))
            r = _lerp(g_r, d_r, t) * (0.86 + grass_w * 0.18)
            g = _lerp(g_g, d_g, t) * (0.86 + grass_w * 0.18)
            b = _lerp(g_b, d_b, t) * (0.86 + grass_w * 0.14)
            i = (y * SIZE + x) * 3
            pix[i] = int(max(0, min(255, r)))
            pix[i + 1] = int(max(0, min(255, g)))
            pix[i + 2] = int(max(0, min(255, b)))
    img = Image.frombytes("RGB", (SIZE, SIZE), bytes(pix))
    img = img.filter(ImageFilter.GaussianBlur(radius=0.45))
    img.save(OUT, "PNG", optimize=True)
    print(f"wrote {OUT} {OUT.stat().st_size} bytes {img.size}")


if __name__ == "__main__":
    main()
