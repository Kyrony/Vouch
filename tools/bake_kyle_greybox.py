#!/usr/bin/env python3
"""Offline baker: Kyle T0 greybox SoT → EXR + solid mesh + HorrorWorld.tscn.

Not loaded at runtime. Start Match instantiates the authored packed scene.

Map is 2× in X and Z (4× area) vs the original 144×120 plate, with much
stronger rolling hills, ridges, and saddles so slopes actually read in play.
Layout pads stay the same size; they are spread across the larger country.
"""

from __future__ import annotations

import math
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FARM = ROOT / "assets/horror/farm"
SCENE = ROOT / "scenes/Horror/HorrorWorld.tscn"

# 2× linear → 4× walkable area (288×240 m).
SCALE = 2.0
WIDTH = 193
DEPTH = 161
SPACING = 1.5
SPAN_X = (WIDTH - 1) * SPACING  # 288
SPAN_Z = (DEPTH - 1) * SPACING  # 240
ORIGIN_X = -SPAN_X / 2.0
ORIGIN_Z = -SPAN_Z / 2.0

# Unscaled Kyle plate coords. World XZ = plate * SCALE.
# Cliff rim sits just east of the mansion (mansion east face ~world x=54).
CLIFF_X = 32.0
CLIFF_DROP_M = 12.0
CLIFF_PIT_Y = -18.0
HILL_XZ = (22.0, -8.0)
HILL_PEAK = 13.5
PLATEAU = 3.15
FAMILY_BASE = 2.15

# Layout pads — Family A–D lower west, Uncle+garage north of mansion, PM on hill.
PADS = {
    "FamilyA": {"xz": (-38.0, -18.0), "size": (13.5, 2.6, 11.0), "yaw": 0.0},
    "FamilyB": {"xz": (-38.0, 2.0), "size": (13.5, 2.6, 11.0), "yaw": 0.0},
    "FamilyC": {"xz": (-38.0, 24.0), "size": (13.5, 2.6, 11.0), "yaw": 0.0},
    "FamilyD": {"xz": (-14.0, 24.0), "size": (13.5, 2.6, 11.0), "yaw": 0.0},
    "Uncle": {"xz": (16.0, -28.0), "size": (10.0, 2.7, 8.0), "yaw": 0.0},
    "UncleGarage": {"xz": (28.0, -28.0), "size": (6.4, 2.5, 7.2), "yaw": 0.0},
    "PMMansion": {"xz": (22.0, -6.0), "size": (20.0, 3.2, 16.0), "yaw": 0.0},
}

FAMILY_SPAWNS = [
    ("Outdoor_Family_A", -38.0, -10.5, 0.0),
    ("Outdoor_Family_B", -30.5, 2.0, -math.pi / 2.0),
    ("Outdoor_Family_C", -38.0, 16.5, math.pi),
    ("Outdoor_Family_D", -14.0, 16.5, math.pi),
]
PM_SPAWN = ("Outdoor_PM_Street", 22.0, 1.0, math.pi)

L2_MARKERS = [
    ("pm_attic", 1, 20.0, -16.0),
    ("master_bedroom", 2, 20.0, -8.0),
    ("bunker_utility", 3, 20.0, -1.0),
    ("basement", 4, 16.0, 5.0),
    ("uncle_bedroom", 5, 16.0, -28.0),
    ("uncle_garage", 6, 28.0, -26.0),
    ("family_shed", 7, -52.0, -36.0),
    ("storm_drain", 8, -40.0, -8.0),
    ("under_porch_crawl", 9, 26.0, 18.0),
    ("garden_well", 10, 4.0, -8.0),
    ("car_trunk", 11, 0.0, 20.0),
]

ROADS = [
    ((-60.0, -18.0), (-30.0, -18.0), 2.8),
    ((-38.0, -18.0), (-38.0, 24.0), 2.6),
    ((-38.0, 24.0), (-8.0, 24.0), 2.6),
    ((-14.0, 24.0), (8.0, 6.0), 2.7),
    ((8.0, 6.0), (22.0, -6.0), 2.8),
    ((-38.0, -18.0), (16.0, -28.0), 2.6),
    ((16.0, -28.0), (30.0, -28.0), 2.5),
    ((22.0, -6.0), (22.0, -28.0), 2.5),
    ((22.0, -6.0), (30.0, -6.0), 2.8),
    ((22.0, -6.0), (22.0, 22.0), 2.7),
    ((22.0, 22.0), (30.0, 22.0), 2.8),
    ((8.0, 6.0), (-4.0, 24.0), 2.5),
]

# Playtest pickups sit on the road-facing side of Family A (not inside the pad).
PICKUPS = [
    ("medkit", -38.0, -6.5),
    ("phone", -36.0, -6.0),
    ("bandage", -40.0, -6.0),
    ("battery", -34.5, -7.5),
    ("crowbar", -41.5, -7.5),
    ("keycard", -38.0, -4.8),
    ("energy_drink", -35.5, -4.5),
    ("scissors", -40.5, -4.5),
    ("fuse", -33.5, -5.5),
    ("flare", -42.5, -5.5),
    ("key", -37.0, -3.6),
    ("lockpick", -39.0, -3.6),
    ("painkillers", -36.5, -8.4),
    ("adrenaline", -39.5, -8.4),
]

HILLS = [
    ("mansion_hill", 22.0, -8.0),
    ("family_west", -38.0, 4.0),
    ("uncle_north", 20.0, -28.0),
    ("south_field", -20.0, 32.0),
    ("garden_knoll", 4.0, -10.0),
    ("east_cliff_rim", 30.0, 0.0),
    ("shed_nw", -50.0, -36.0),
    ("west_ridge", -58.0, 8.0),
    ("north_saddle", 4.0, -40.0),
    ("south_bowl", 8.0, 40.0),
    ("east_knoll", 26.0, 28.0),
    ("mid_saddle", -8.0, -4.0),
]


def wx(x: float) -> float:
    return x * SCALE


def wz(z: float) -> float:
    return z * SCALE


def world_to_cell(x: float, z: float) -> tuple[float, float]:
    return (x - ORIGIN_X) / SPACING, (z - ORIGIN_Z) / SPACING


def _hash(ix: int, iz: int) -> float:
    n = (ix * 374761393 + iz * 668265263) & 0x7FFFFFFF
    n = (n ^ (n >> 13)) * 1274126177
    return ((n ^ (n >> 16)) & 0x7FFFFFFF) / 2147483647.0


def _value_noise(x: float, z: float) -> float:
    x0 = math.floor(x)
    z0 = math.floor(z)
    tx = x - x0
    tz = z - z0
    sx = tx * tx * (3.0 - 2.0 * tx)
    sz = tz * tz * (3.0 - 2.0 * tz)
    n00 = _hash(int(x0), int(z0))
    n10 = _hash(int(x0) + 1, int(z0))
    n01 = _hash(int(x0), int(z0) + 1)
    n11 = _hash(int(x0) + 1, int(z0) + 1)
    nx0 = n00 * (1.0 - sx) + n10 * sx
    nx1 = n01 * (1.0 - sx) + n11 * sx
    return nx0 * (1.0 - sz) + nx1 * sz


def _fbm(x: float, z: float, octaves: int = 5) -> float:
    total = 0.0
    amp = 1.0
    freq = 1.0
    norm = 0.0
    for _ in range(octaves):
        total += amp * _value_noise(x * freq, z * freq)
        norm += amp
        amp *= 0.5
        freq *= 2.05
    return total / max(norm, 1e-6)


def _bump(x: float, z: float, cx: float, cz: float, radius: float, height: float) -> float:
    d2 = (x - cx) ** 2 + (z - cz) ** 2
    if d2 > radius * radius:
        return 0.0
    t = 1.0 - d2 / (radius * radius)
    return height * (t * t * (3.0 - 2.0 * t))


def _ridge(x: float, z: float, ax: float, az: float, bx: float, bz: float, width: float, height: float) -> float:
    dx, dz = bx - ax, bz - az
    length2 = dx * dx + dz * dz
    if length2 < 1e-6:
        return 0.0
    t = max(0.0, min(1.0, ((x - ax) * dx + (z - az) * dz) / length2))
    px, pz = ax + t * dx, az + t * dz
    d = math.hypot(x - px, z - pz)
    if d >= width:
        return 0.0
    fall = 1.0 - (d / width) ** 2
    return height * fall * fall


def _flatten(h: float, x: float, z: float, cx: float, cz: float, radius: float, target: float, strength: float = 1.0) -> float:
    d = math.hypot(x - cx, z - cz)
    if d >= radius:
        return h
    t = 1.0 - d / radius
    w = (t * t) * strength
    return h * (1.0 - w) + target * w


def height_world(x: float, z: float) -> float:
    """World-space height in metres. x/z are already scaled farm coords."""
    # West fields sit lower; the east plateau climbs into the mansion hill.
    west = 1.0 if x < wx(-8.0) else 0.0
    if x < wx(-8.0):
        west = max(0.0, min(1.0, (wx(-8.0) - x) / wx(24.0)))
    h = FAMILY_BASE * west + PLATEAU * (1.0 - west)

    # Broad rolling countryside (curves, not a flat plate).
    h += (_fbm(x * 0.018, z * 0.018) - 0.45) * 4.8
    h += (_fbm(x * 0.045 + 12.0, z * 0.045 - 7.0, 4) - 0.5) * 2.2
    h += (_fbm(x * 0.09 - 3.0, z * 0.09 + 5.0, 3) - 0.5) * 0.85

    # Named hills / saddles. Radii scale with the larger country.
    h += _bump(x, z, wx(HILL_XZ[0]), wz(HILL_XZ[1]), 38.0, HILL_PEAK - PLATEAU)
    h += _bump(x, z, wx(-36.0), wz(8.0), 24.0, 2.4)
    h += _bump(x, z, wx(8.0), wz(-28.0), 20.0, 3.1)
    h += _bump(x, z, wx(-20.0), wz(32.0), 22.0, 2.6)
    h += _bump(x, z, wx(6.0), wz(-12.0), 16.0, 1.8)
    h += _bump(x, z, wx(-50.0), wz(-36.0), 18.0, 2.8)
    h += _bump(x, z, wx(-58.0), wz(8.0), 22.0, 3.4)
    h += _bump(x, z, wx(4.0), wz(-40.0), 20.0, 2.9)
    h += _bump(x, z, wx(8.0), wz(40.0), 24.0, 2.2)
    h += _bump(x, z, wx(26.0), wz(28.0), 18.0, 2.5)
    h += _bump(x, z, wx(-8.0), wz(-4.0), 16.0, -1.6)  # saddle / dip
    h += _bump(x, z, wx(-22.0), wz(-22.0), 14.0, 1.4)

    # Long ridge + a second crossing fold so the land isn't radial blobs.
    h += _ridge(x, z, wx(-62.0), wz(8.0), wx(18.0), wz(-36.0), 16.0, 3.6)
    h += _ridge(x, z, wx(-48.0), wz(40.0), wx(44.0), wz(10.0), 14.0, 2.4)
    h += _ridge(x, z, wx(-10.0), wz(-44.0), wx(48.0), wz(32.0), 12.0, 2.0)

    # Shallow valley between the family yards and the mansion climb.
    h += _ridge(x, z, wx(-18.0), wz(-22.0), wx(-4.0), wz(18.0), 11.0, -2.2)

    h = max(0.15, h)

    # Soften roads first so pad flatten can win on yards / the hilltop.
    for a, b, r in ROADS:
        ax, az = wx(a[0]), wz(a[1])
        bx, bz = wx(b[0]), wz(b[1])
        dx, dz = bx - ax, bz - az
        length = math.hypot(dx, dz)
        if length < 1.0:
            continue
        steps = max(4, int(length / 4.0))
        for i in range(steps + 1):
            t = i / steps
            rx, rz = ax + dx * t, az + dz * t
            h = _flatten(h, x, z, rx, rz, r * 2.2 + 1.0, h, 0.28)

    # Keep pads / spawns walkable (flatten after sculpting + roads).
    for spec in PADS.values():
        px, pz = wx(spec["xz"][0]), wz(spec["xz"][1])
        sx, _sy, sz = spec["size"]
        radius = max(sx, sz) * 0.72 + 2.0
        if spec is PADS["PMMansion"]:
            target = HILL_PEAK - 0.55
        elif spec["xz"][0] > 0:
            target = PLATEAU + 0.55
        else:
            target = FAMILY_BASE + 0.12
        h = _flatten(h, x, z, px, pz, radius, target, 0.94)

    for _name, sx, sz, _yaw in FAMILY_SPAWNS:
        h = _flatten(h, x, z, wx(sx), wz(sz), 5.5, FAMILY_BASE + 0.18, 0.88)
    h = _flatten(h, x, z, wx(PM_SPAWN[1]), wz(PM_SPAWN[2]), 8.0, HILL_PEAK - 0.7, 0.92)

    cliff_x = wx(CLIFF_X)
    if x >= cliff_x:
        t = min(1.0, (x - cliff_x) / CLIFF_DROP_M)
        fall = t * t
        return h * (1.0 - fall) + CLIFF_PIT_Y * fall
    return max(0.0, min(HILL_PEAK + 1.5, h))


def height_at_cell(ix: float, iz: float) -> float:
    x = ORIGIN_X + ix * SPACING
    z = ORIGIN_Z + iz * SPACING
    return height_world(x, z)


def sample(x: float, z: float) -> float:
    fx, fz = world_to_cell(x, z)
    x0 = min(WIDTH - 2, max(0, int(math.floor(fx))))
    z0 = min(DEPTH - 2, max(0, int(math.floor(fz))))
    tx = fx - x0
    tz = fz - z0
    h00 = height_at_cell(x0, z0)
    h10 = height_at_cell(x0 + 1, z0)
    h01 = height_at_cell(x0, z0 + 1)
    h11 = height_at_cell(x0 + 1, z0 + 1)
    return (h00 * (1 - tx) + h10 * tx) * (1 - tz) + (h01 * (1 - tx) + h11 * tx) * tz


def build_grid() -> list[float]:
    return [height_at_cell(ix, iz) for iz in range(DEPTH) for ix in range(WIDTH)]


def write_exr(path: Path, grid: list[float]) -> None:
    """RGB FLOAT uncompressed OpenEXR. Offline SoT; collision is baked into the scene."""
    channels = b"".join(
        name + b"\x00" + struct.pack("<iB3sii", 2, 0, b"\x00\x00\x00", 1, 1)
        for name in (b"B", b"G", b"R")
    ) + b"\x00"

    def attr(name: bytes, typ: bytes, val: bytes) -> bytes:
        return name + b"\x00" + typ + b"\x00" + struct.pack("<I", len(val)) + val

    header = b"v/1\x01" + struct.pack("<I", 2)
    header += attr(b"channels", b"chlist", channels)
    header += attr(b"compression", b"compression", b"\x00")
    box = struct.pack("<iiii", 0, 0, WIDTH - 1, DEPTH - 1)
    header += attr(b"dataWindow", b"box2i", box)
    header += attr(b"displayWindow", b"box2i", box)
    header += attr(b"lineOrder", b"lineOrder", b"\x00")
    header += attr(b"pixelAspectRatio", b"float", struct.pack("<f", 1.0))
    header += attr(b"screenWindowCenter", b"v2f", struct.pack("<ff", 0.0, 0.0))
    header += attr(b"screenWindowWidth", b"float", struct.pack("<f", 1.0))
    header += b"\x00"

    scanlines: list[bytes] = []
    for y in range(DEPTH):
        row = grid[y * WIDTH : (y + 1) * WIDTH]
        raw = bytearray()
        raw += struct.pack("<i", y)
        raw += struct.pack("<i", WIDTH * 3 * 4)
        for _ch in range(3):
            for h in row:
                raw += struct.pack("<f", h)
        scanlines.append(bytes(raw))

    running = len(header) + 8 * DEPTH
    table = bytearray()
    blob = bytearray()
    for packed in scanlines:
        table += struct.pack("<Q", running)
        blob += packed
        running += len(packed)
    path.write_bytes(header + bytes(table) + bytes(blob))
    print(f"wrote {path} bytes={path.stat().st_size}")


def write_obj(path: Path, grid: list[float]) -> None:
    """Solid terrain: CCW-up top, underside cap, side skirts."""
    bed = -0.45
    verts_top: list[tuple[float, float, float]] = []
    for iz in range(DEPTH):
        for ix in range(WIDTH):
            x = ORIGIN_X + ix * SPACING
            z = ORIGIN_Z + iz * SPACING
            verts_top.append((x, grid[iz * WIDTH + ix], z))
    verts_bot = [(x, bed, z) for x, _y, z in verts_top]

    def vid(ix: int, iz: int, bot: bool = False) -> int:
        idx = iz * WIDTH + ix
        return idx + 1 + (WIDTH * DEPTH if bot else 0)

    faces: list[tuple[int, int, int]] = []
    for iz in range(DEPTH - 1):
        for ix in range(WIDTH - 1):
            a, b, c, d = vid(ix, iz), vid(ix + 1, iz), vid(ix, iz + 1), vid(ix + 1, iz + 1)
            faces.append((a, c, b))
            faces.append((b, c, d))
            a2, b2, c2, d2 = vid(ix, iz, True), vid(ix + 1, iz, True), vid(ix, iz + 1, True), vid(ix + 1, iz + 1, True)
            faces.append((a2, b2, c2))
            faces.append((b2, d2, c2))

    def skirt(a_top: int, b_top: int, a_bot: int, b_bot: int) -> None:
        faces.append((a_top, a_bot, b_top))
        faces.append((b_top, a_bot, b_bot))

    for ix in range(WIDTH - 1):
        skirt(vid(ix, 0), vid(ix + 1, 0), vid(ix, 0, True), vid(ix + 1, 0, True))
        skirt(vid(ix + 1, DEPTH - 1), vid(ix, DEPTH - 1), vid(ix + 1, DEPTH - 1, True), vid(ix, DEPTH - 1, True))
    for iz in range(DEPTH - 1):
        skirt(vid(0, iz + 1), vid(0, iz), vid(0, iz + 1, True), vid(0, iz, True))
        skirt(vid(WIDTH - 1, iz), vid(WIDTH - 1, iz + 1), vid(WIDTH - 1, iz, True), vid(WIDTH - 1, iz + 1, True))

    lines = [
        "# Kyle T0 greybox heightfield (4x area, rolling hills). Baked, not generated at runtime.",
        "o KyleFarmTerrain",
    ]
    for v in verts_top + verts_bot:
        lines.append("v %.4f %.4f %.4f" % v)
    for a, b, c in faces:
        lines.append("f %d %d %d" % (a, b, c))
    path.write_text("\n".join(lines) + "\n")
    print(f"wrote {path} verts={len(verts_top)*2} faces={len(faces)}")


def xf(
    x: float,
    y: float,
    z: float,
    yaw: float = 0.0,
    pitch: float = 0.0,
    scale: tuple[float, float, float] | None = None,
) -> str:
    sx, sy, sz = scale if scale is not None else (1.0, 1.0, 1.0)
    cy, syaw = math.cos(yaw), math.sin(yaw)
    cp, sp = math.cos(pitch), math.sin(pitch)
    xax, xay, xaz = cy * sx, 0.0, -syaw * sx
    yax, yay, yaz = syaw * sp * sy, cp * sy, cy * sp * sy
    zax, zay, zaz = syaw * cp * sz, -sp * sz, cy * cp * sz
    return "Transform3D(%.5f, %.5f, %.5f, %.5f, %.5f, %.5f, %.5f, %.5f, %.5f, %.3f, %.3f, %.3f)" % (
        xax, yax, zax, xay, yay, zay, xaz, yaz, zaz, x, y, z,
    )


def write_scene(grid: list[float]) -> None:
    peak = max(grid)
    valley = min(grid)
    map_csv = ", ".join("%.3f" % h for h in grid)

    lines: list[str] = []
    lines.append("[gd_scene load_steps=48 format=3]")
    lines.append("")
    lines.append('[ext_resource type="Script" path="res://scripts/horror/horror_world.gd" id="1"]')
    lines.append('[ext_resource type="PackedScene" path="res://scenes/Horror/WorldPickup.tscn" id="2"]')
    lines.append('[ext_resource type="Script" path="res://scripts/interactables/escape_zone.gd" id="3"]')
    lines.append('[ext_resource type="ArrayMesh" path="res://assets/horror/farm/kyle_farm_terrain.obj" id="4"]')
    lines.append('[ext_resource type="Texture2D" path="res://assets/horror/farm/grass_dirt_tile.png" id="5"]')
    lines.append("")
    lines.append('[sub_resource type="Environment" id="EnvFarm"]')
    lines.append("background_mode = 1")
    lines.append("background_color = Color(0.72, 0.38, 0.22, 1)")
    lines.append("ambient_light_source = 2")
    lines.append("ambient_light_color = Color(0.58, 0.34, 0.22, 1)")
    lines.append("ambient_light_energy = 0.55")
    lines.append("fog_enabled = true")
    lines.append("fog_light_color = Color(0.58, 0.52, 0.62, 1)")
    lines.append("fog_density = 0.012")
    lines.append("fog_aerial_perspective = 0.35")
    lines.append("fog_sky_affect = 0.55")
    lines.append("fog_height = -6.0")
    lines.append("fog_height_density = 0.28")
    lines.append("volumetric_fog_enabled = true")
    lines.append("volumetric_fog_density = 0.007")
    lines.append("volumetric_fog_albedo = Color(0.62, 0.56, 0.68, 1)")
    lines.append("volumetric_fog_emission = Color(0.12, 0.10, 0.16, 1)")
    lines.append("volumetric_fog_length = 96.0")
    lines.append("")
    lines.append('[sub_resource type="StandardMaterial3D" id="Mat_grass"]')
    lines.append("albedo_color = Color(0.42, 0.50, 0.24, 1)")
    lines.append('albedo_texture = ExtResource("5")')
    lines.append("roughness = 0.86")
    lines.append("metallic = 0.0")
    lines.append("cull_mode = 2")
    lines.append("uv1_scale = Vector3(0.14, 0.14, 0.14)")
    lines.append("uv1_triplanar = true")
    lines.append("uv1_world_triplanar = true")
    lines.append("emission_enabled = true")
    lines.append("emission = Color(0.16, 0.20, 0.09, 1)")
    lines.append("emission_energy_multiplier = 0.22")
    lines.append("")

    mats = {
        "Mat_asphalt": (0.11, 0.11, 0.13),
        "Mat_pad": (0.55, 0.55, 0.52),
        "Mat_mansion": (0.42, 0.36, 0.32),
        "Mat_pin": (0.92, 0.82, 0.18),
        "Mat_base": (0.95, 0.35, 0.18),
        "Mat_crawl": (0.25, 0.85, 0.95),
        "Mat_field": (0.34, 0.48, 0.24),
        "Mat_cliff": (0.36, 0.35, 0.34),
        "Mat_fogrock": (0.32, 0.31, 0.34),
    }
    for mid, (r, g, b) in mats.items():
        lines.append(f'[sub_resource type="StandardMaterial3D" id="{mid}"]')
        lines.append(f"albedo_color = Color({r}, {g}, {b}, 1)")
        lines.append("roughness = 0.92")
        if mid in ("Mat_pin", "Mat_base", "Mat_crawl"):
            lines.append("emission_enabled = true")
            lines.append(f"emission = Color({r}, {g}, {b}, 1)")
            lines.append("emission_energy_multiplier = 0.55")
        lines.append("")

    lines.append('[sub_resource type="HeightMapShape3D" id="Sh_terrain"]')
    lines.append(f"map_width = {WIDTH}")
    lines.append(f"map_depth = {DEPTH}")
    lines.append(f"map_data = PackedFloat32Array({map_csv})")
    lines.append("")
    lines.append('[sub_resource type="BoxShape3D" id="Sh_bed"]')
    lines.append(f"size = Vector3({SPAN_X:.0f}, 0.8, {SPAN_Z:.0f})")
    lines.append("")
    lines.append('[sub_resource type="BoxMesh" id="Box_pin"]')
    lines.append("size = Vector3(1.1, 1.55, 1.1)")
    lines.append('material = SubResource("Mat_pin")')
    lines.append("")
    lines.append('[sub_resource type="BoxMesh" id="Box_pinbase"]')
    lines.append("size = Vector3(1.1, 1.55, 1.1)")
    lines.append('material = SubResource("Mat_base")')
    lines.append("")
    lines.append('[sub_resource type="BoxMesh" id="Box_pincrawl"]')
    lines.append("size = Vector3(1.1, 1.55, 1.1)")
    lines.append('material = SubResource("Mat_crawl")')
    lines.append("")
    lines.append('[sub_resource type="BoxShape3D" id="Sh_escape"]')
    lines.append("size = Vector3(8, 2.4, 8)")
    lines.append("")
    lines.append('[sub_resource type="BoxMesh" id="Box_field_a"]')
    lines.append("size = Vector3(40, 0.06, 32)")
    lines.append('material = SubResource("Mat_field")')
    lines.append("")
    lines.append('[sub_resource type="BoxMesh" id="Box_field_b"]')
    lines.append("size = Vector3(32, 0.06, 26)")
    lines.append('material = SubResource("Mat_field")')
    lines.append("")
    lines.append('[sub_resource type="BoxMesh" id="Box_road_unit"]')
    lines.append("size = Vector3(1, 1, 1)")
    lines.append('material = SubResource("Mat_asphalt")')
    lines.append("")
    lines.append('[sub_resource type="BoxShape3D" id="Sh_road_unit"]')
    lines.append("size = Vector3(1, 1, 1)")
    lines.append("")
    lines.append('[sub_resource type="BoxMesh" id="Box_cliff_wall"]')
    lines.append("size = Vector3(1, 1, 1)")
    lines.append('material = SubResource("Mat_cliff")')
    lines.append("")
    lines.append('[sub_resource type="BoxShape3D" id="Sh_cliff_wall"]')
    lines.append("size = Vector3(1, 1, 1)")
    lines.append("")
    lines.append('[sub_resource type="FogMaterial" id="Fog_cliff"]')
    lines.append("density = 0.42")
    lines.append("albedo = Color(0.62, 0.58, 0.68, 1)")
    lines.append("emission = Color(0.14, 0.12, 0.18, 1)")
    lines.append("height_falloff = 0.35")
    lines.append("")

    for name, spec in PADS.items():
        sx, sy, sz = spec["size"]
        mid = "Mat_mansion" if name == "PMMansion" else "Mat_pad"
        lines.append(f'[sub_resource type="BoxMesh" id="Box_pad_{name}"]')
        lines.append(f"size = Vector3({sx}, {sy}, {sz})")
        lines.append(f'material = SubResource("{mid}")')
        lines.append("")
        lines.append(f'[sub_resource type="BoxShape3D" id="Sh_pad_{name}"]')
        lines.append(f"size = Vector3({sx}, {sy}, {sz})")
        lines.append("")

    lines.append('[node name="HorrorWorld" type="Node3D"]')
    lines.append('script = ExtResource("1")')
    lines.append("")
    lines.append('[node name="FarmSky" type="WorldEnvironment" parent="."]')
    lines.append('environment = SubResource("EnvFarm")')
    lines.append("")
    lines.append('[node name="SunMoon" type="DirectionalLight3D" parent="."]')
    lines.append("transform = Transform3D(1, 0, 0, 0, 0.978, 0.208, 0, -0.208, 0.978, 0, 36, 0)")
    lines.append("light_color = Color(1, 0.55, 0.28, 1)")
    lines.append("light_energy = 0.88")
    lines.append("shadow_enabled = true")
    lines.append("")
    lines.append('[node name="Outdoor" type="Node3D" parent="."]')
    lines.append("")
    lines.append('[node name="Terrain" type="StaticBody3D" parent="Outdoor"]')
    lines.append("collision_layer = 1")
    lines.append("collision_mask = 0")
    lines.append(f"metadata/span_x = {SPAN_X:.1f}")
    lines.append(f"metadata/span_z = {SPAN_Z:.1f}")
    lines.append("metadata/authored_heightfield = true")
    lines.append("metadata/solid_mesh = true")
    lines.append("metadata/underside = true")
    lines.append('metadata/winding = "ccw_up"')
    lines.append('metadata/sot = "kyle_T0"')
    lines.append(f"metadata/peak_y = {peak:.3f}")
    lines.append(f"metadata/valley_y = {valley:.3f}")
    lines.append(f"metadata/map_width = {WIDTH}")
    lines.append(f"metadata/map_depth = {DEPTH}")
    lines.append("metadata/cell_m = 1.5")
    lines.append("metadata/area_scale = 4.0")
    lines.append(f"metadata/cliff_x = {wx(CLIFF_X):.1f}")
    lines.append("")
    lines.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="Outdoor/Terrain"]')
    lines.append("mesh = ExtResource(\"4\")")
    lines.append("material_override = SubResource(\"Mat_grass\")")
    lines.append("")
    lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="Outdoor/Terrain"]')
    lines.append(f"transform = Transform3D({SPACING}, 0, 0, 0, 1, 0, 0, 0, {SPACING}, 0, 0, 0)")
    lines.append("shape = SubResource(\"Sh_terrain\")")
    lines.append("")
    lines.append('[node name="Bed" type="CollisionShape3D" parent="Outdoor/Terrain"]')
    lines.append("transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.85, 0)")
    lines.append("shape = SubResource(\"Sh_bed\")")
    lines.append("")

    lines.append('[node name="Hills" type="Node3D" parent="Outdoor"]')
    lines.append(f"metadata/hill_count = {len(HILLS)}")
    lines.append('metadata/variety = "rolling_t0"')
    lines.append("")
    for hid, hx, hz in HILLS:
        hy = sample(wx(hx), wz(hz))
        lines.append(f'[node name="Hill_{hid}" type="Marker3D" parent="Outdoor/Hills"]')
        lines.append(f"position = Vector3({wx(hx):.3f}, {hy:.3f}, {wz(hz):.3f})")
        lines.append(f'metadata/hill_id = "{hid}"')
        lines.append("")

    lines.append('[node name="Roads" type="Node3D" parent="Outdoor"]')
    lines.append('metadata/plate = "kyle_greybox"')
    lines.append('metadata/draped = true')
    lines.append("")
    for i, (a, b, r) in enumerate(ROADS):
        ax, az = wx(a[0]), wz(a[1])
        bx, bz = wx(b[0]), wz(b[1])
        dx, dz = bx - ax, bz - az
        length = math.hypot(dx, dz)
        nseg = max(1, int(round(length / 3.0)))
        name = f"Lane_{i:02d}"
        lines.append(f'[node name="{name}" type="Node3D" parent="Outdoor/Roads"]')
        lines.append("")
        for s in range(nseg):
            t0 = s / nseg
            t1 = (s + 1) / nseg
            x0, z0 = ax + dx * t0, az + dz * t0
            x1, z1 = ax + dx * t1, az + dz * t1
            y0 = sample(x0, z0)
            y1 = sample(x1, z1)
            mx, mz = (x0 + x1) * 0.5, (z0 + z1) * 0.5
            my = (y0 + y1) * 0.5 + 0.06
            seg_xz = max(0.4, math.hypot(x1 - x0, z1 - z0))
            yaw = math.atan2(x1 - x0, z1 - z0)
            pitch = math.atan2(y0 - y1, seg_xz)
            seg = f"Seg_{s:02d}"
            lines.append(f'[node name="{seg}" type="StaticBody3D" parent="Outdoor/Roads/{name}"]')
            lines.append(f"transform = {xf(mx, my, mz, yaw, pitch, (r * 2.0, 0.12, seg_xz))}")
            lines.append("collision_layer = 1")
            lines.append("collision_mask = 0")
            lines.append("")
            lines.append(f'[node name="MeshInstance3D" type="MeshInstance3D" parent="Outdoor/Roads/{name}/{seg}"]')
            lines.append('mesh = SubResource("Box_road_unit")')
            lines.append("")
            lines.append(f'[node name="CollisionShape3D" type="CollisionShape3D" parent="Outdoor/Roads/{name}/{seg}"]')
            lines.append('shape = SubResource("Sh_road_unit")')
            lines.append("")

    lines.append('[node name="Pads" type="Node3D" parent="Outdoor"]')
    lines.append('metadata/sot = "kyle_greybox_layout"')
    lines.append("")
    for name, spec in PADS.items():
        px, pz = wx(spec["xz"][0]), wz(spec["xz"][1])
        sx, sy, sz = spec["size"]
        py = sample(px, pz) + sy / 2.0
        if name == "PMMansion":
            continue
        lines.append(f'[node name="Pad_{name}" type="StaticBody3D" parent="Outdoor/Pads"]')
        lines.append(f"transform = {xf(px, py, pz, spec['yaw'])}")
        lines.append("collision_layer = 1")
        lines.append("collision_mask = 0")
        lines.append("")
        lines.append(f'[node name="MeshInstance3D" type="MeshInstance3D" parent="Outdoor/Pads/Pad_{name}"]')
        lines.append(f"mesh = SubResource(\"Box_pad_{name}\")")
        lines.append("")
        lines.append(f'[node name="CollisionShape3D" type="CollisionShape3D" parent="Outdoor/Pads/Pad_{name}"]')
        lines.append(f"shape = SubResource(\"Sh_pad_{name}\")")
        lines.append("")

    lines.append('[node name="Fields" type="Node3D" parent="Outdoor"]')
    lines.append("")
    fy = sample(wx(-38.0), wz(36.0)) + 0.03
    lines.append('[node name="FieldWest" type="MeshInstance3D" parent="Outdoor/Fields"]')
    lines.append(f"transform = {xf(wx(-38.0), fy, wz(36.0))}")
    lines.append("mesh = SubResource(\"Box_field_a\")")
    lines.append("")
    fy2 = sample(wx(8.0), wz(36.0)) + 0.03
    lines.append('[node name="FieldEast" type="MeshInstance3D" parent="Outdoor/Fields"]')
    lines.append(f"transform = {xf(wx(8.0), fy2, wz(36.0))}")
    lines.append("mesh = SubResource(\"Box_field_b\")")
    lines.append("")

    lines.append('[node name="PlayerSpawns" type="Node3D" parent="Outdoor"]')
    lines.append("")
    for name, sx, sz, yaw in FAMILY_SPAWNS:
        sy = sample(wx(sx), wz(sz)) + 0.14
        lines.append(f'[node name="{name}" type="Marker3D" parent="Outdoor/PlayerSpawns" groups=["outdoor_player_spawns"]]')
        lines.append(f"transform = {xf(wx(sx), sy, wz(sz), yaw)}")
        lines.append("")
    pmx, pmz = wx(PM_SPAWN[1]), wz(PM_SPAWN[2])
    pmy = sample(pmx, pmz) + 0.14
    lines.append('[node name="Outdoor_PM_Street" type="Marker3D" parent="Outdoor" groups=["outdoor_player_spawns"]]')
    lines.append(f"transform = {xf(pmx, pmy, pmz, PM_SPAWN[3])}")
    lines.append("")

    ex, ez = wx(-58.0), wz(12.0)
    ey = sample(ex, ez) + 0.6
    lines.append('[node name="HorrorEscapeZone" type="Area3D" parent="Outdoor"]')
    lines.append(f"transform = {xf(ex, ey, ez)}")
    lines.append("collision_layer = 0")
    lines.append("collision_mask = 4")
    lines.append('script = ExtResource("3")')
    lines.append("metadata/soft_gated = true")
    lines.append("")
    lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="Outdoor/HorrorEscapeZone"]')
    lines.append("shape = SubResource(\"Sh_escape\")")
    lines.append("")
    lines.append('[node name="OutdoorFill" type="OmniLight3D" parent="Outdoor"]')
    lines.append("transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 28, 8)")
    lines.append("light_color = Color(0.72, 0.78, 0.88, 1)")
    lines.append("light_energy = 0.72")
    lines.append("omni_range = 160.0")
    lines.append("")

    cliff_x = wx(CLIFF_X)
    lines.append('[node name="EastCliff" type="Node3D" parent="Outdoor"]')
    lines.append(f"metadata/rim_x = {cliff_x:.1f}")
    lines.append('metadata/greybox = "steep_fog_cliff"')
    lines.append("")
    slab_i = 0
    zpos = ORIGIN_Z + 10.0
    while zpos < ORIGIN_Z + SPAN_Z - 10.0:
        rim_y = sample(cliff_x - 1.2, zpos)
        cx = cliff_x + 3.5
        cy = rim_y - 8.5
        wall = f"CliffWall_{slab_i:02d}"
        lines.append(f'[node name="{wall}" type="StaticBody3D" parent="Outdoor/EastCliff"]')
        lines.append(f"transform = {xf(cx, cy, zpos, 0.0, 0.42, (7.5, 22.0, 16.0))}")
        lines.append("collision_layer = 1")
        lines.append("collision_mask = 0")
        lines.append("")
        lines.append(f'[node name="MeshInstance3D" type="MeshInstance3D" parent="Outdoor/EastCliff/{wall}"]')
        lines.append('mesh = SubResource("Box_cliff_wall")')
        lines.append("")
        lines.append(f'[node name="CollisionShape3D" type="CollisionShape3D" parent="Outdoor/EastCliff/{wall}"]')
        lines.append('shape = SubResource("Sh_cliff_wall")')
        lines.append("")
        # Rim boulder so the drop reads as a lip, not a seam.
        if slab_i % 2 == 0:
            rock = f"CliffRock_{slab_i:02d}"
            rx = cliff_x - 1.4
            ry = sample(rx, zpos) + 0.9
            lines.append(f'[node name="{rock}" type="StaticBody3D" parent="Outdoor/EastCliff"]')
            lines.append(f"transform = {xf(rx, ry, zpos, 0.35 * slab_i, 0.15, (3.2, 2.4, 4.6))}")
            lines.append("collision_layer = 1")
            lines.append("collision_mask = 0")
            lines.append("")
            lines.append(f'[node name="MeshInstance3D" type="MeshInstance3D" parent="Outdoor/EastCliff/{rock}"]')
            lines.append('mesh = SubResource("Box_cliff_wall")')
            lines.append("")
            lines.append(f'[node name="CollisionShape3D" type="CollisionShape3D" parent="Outdoor/EastCliff/{rock}"]')
            lines.append('shape = SubResource("Sh_cliff_wall")')
            lines.append("")
        slab_i += 1
        zpos += 15.0
    lines.append('[node name="CliffFog" type="FogVolume" parent="Outdoor/EastCliff"]')
    lines.append(f"transform = {xf(cliff_x + 42.0, -6.0, 0.0)}")
    lines.append("size = Vector3(88, 48, 248)")
    lines.append('material = SubResource("Fog_cliff")')
    lines.append("")

    mx, mz = wx(PADS["PMMansion"]["xz"][0]), wz(PADS["PMMansion"]["xz"][1])
    msy = PADS["PMMansion"]["size"][1]
    my = sample(mx, mz)
    lines.append('[node name="MainHouse" type="Node3D" parent="Outdoor"]')
    lines.append(f"transform = {xf(mx, my, mz)}")
    lines.append("metadata/on_hilltop = true")
    lines.append('metadata/role = "pm_farmhouse"')
    lines.append('metadata/sot = "kyle_greybox"')
    lines.append("")
    lines.append('[node name="Core" type="StaticBody3D" parent="Outdoor/MainHouse"]')
    lines.append(f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, {msy/2.0:.3f}, 0)")
    lines.append("collision_layer = 1")
    lines.append("collision_mask = 0")
    lines.append("")
    lines.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="Outdoor/MainHouse/Core"]')
    lines.append("mesh = SubResource(\"Box_pad_PMMansion\")")
    lines.append("")
    lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="Outdoor/MainHouse/Core"]')
    lines.append("shape = SubResource(\"Sh_pad_PMMansion\")")
    lines.append("")

    lines.append('[node name="L2SpawnMarkers" type="Node3D" parent="."]')
    lines.append("")
    for sid, pin, lx, lz in L2_MARKERS:
        ly = sample(wx(lx), wz(lz)) + 0.12
        box = "Box_pincrawl" if sid == "under_porch_crawl" else ("Box_pinbase" if sid == "basement" else "Box_pin")
        site = f"SpawnPoint_{sid}"
        lines.append(f'[node name="{site}" type="Node3D" parent="L2SpawnMarkers"]')
        lines.append(f"transform = {xf(wx(lx), ly, wz(lz))}")
        lines.append("")
        lines.append(f'[node name="ChildSpawn_{sid}" type="Marker3D" parent="L2SpawnMarkers/{site}" groups=["child_spawn_points"]]')
        lines.append(f'metadata/spawn_id = "{sid}"')
        lines.append(f"metadata/l2_pin = {pin}")
        lines.append('metadata/visible_label = "Spawn Point"')
        lines.append("")
        lines.append(f'[node name="Box" type="MeshInstance3D" parent="L2SpawnMarkers/{site}"]')
        lines.append("transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.775, 0)")
        lines.append(f"mesh = SubResource(\"{box}\")")
        lines.append("")
        lines.append(f'[node name="Label" type="Label3D" parent="L2SpawnMarkers/{site}"]')
        lines.append("transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 2.100, 0)")
        lines.append('text = "Spawn Point"')
        lines.append("font_size = 42")
        lines.append("outline_size = 10")
        lines.append("billboard = 1")
        lines.append("no_depth_test = true")
        lines.append("")
        lines.append(f'[node name="SpawnId" type="Label3D" parent="L2SpawnMarkers/{site}"]')
        lines.append("transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.770, 0)")
        lines.append(f'text = "{sid}"')
        lines.append("font_size = 22")
        lines.append("outline_size = 8")
        lines.append("billboard = 1")
        lines.append("no_depth_test = true")
        lines.append("")

    lines.append('[node name="Pickups" type="Node3D" parent="."]')
    lines.append("")
    for item, px, pz in PICKUPS:
        py = sample(wx(px), wz(pz)) + 0.35
        lines.append(f'[node name="Pickup_{item}" parent="Pickups" instance=ExtResource("2")]')
        lines.append(f"transform = {xf(wx(px), py, wz(pz))}")
        lines.append(f'item_id = "{item}"')
        lines.append("")

    SCENE.write_text("\n".join(lines) + "\n")
    print(f"wrote {SCENE} peak={peak:.3f} valley={valley:.3f} span={SPAN_X:.0f}x{SPAN_Z:.0f}")
    print("family_spawns", [(n, sample(wx(x), wz(z)) + 0.14) for n, x, z, _ in FAMILY_SPAWNS])
    print("pm_spawn_y", pmy, "mansion_y", my)


def write_import(obj_path: Path) -> None:
    imp = obj_path.with_suffix(".obj.import")
    imp.write_text(
        "\n".join(
            [
                "[remap]",
                "",
                'importer="wavefront_obj"',
                "importer_version=1",
                'type="Mesh"',
                'uid="uid://kylefarmterrain01"',
                'path="res://.godot/imported/kyle_farm_terrain.obj-kyle01.mesh"',
                "",
                "[deps]",
                "",
                'files=["res://.godot/imported/kyle_farm_terrain.obj-kyle01.mesh"]',
                "",
                f'source_file="res://assets/horror/farm/{obj_path.name}"',
                'dest_files=["res://.godot/imported/kyle_farm_terrain.obj-kyle01.mesh"]',
                "",
                "[params]",
                "",
                "generate_tangents=true",
                "scale_mesh=Vector3(1, 1, 1)",
                "offset_mesh=Vector3(0, 0, 0)",
                "optimize_mesh=true",
                "force_disable_mesh_compression=false",
                "",
            ]
        )
    )


def write_exr_import(exr_path: Path) -> None:
    imp = exr_path.with_suffix(".exr.import")
    imp.write_text(
        "\n".join(
            [
                "[remap]",
                "",
                'importer="texture"',
                'type="CompressedTexture2D"',
                'uid="uid://kylet0height193x161"',
                "",
                "[deps]",
                "",
                f'source_file="res://assets/horror/farm/{exr_path.name}"',
                "",
                "[params]",
                "",
                "compress/mode=0",
                "mipmaps/generate=false",
                "",
            ]
        )
    )


def _slope_stats(grid: list[float]) -> tuple[float, float, int]:
    """Mean |grad|, max |grad| (m per cell), and count of local maxima."""
    grads: list[float] = []
    peaks = 0
    for iz in range(1, DEPTH - 1):
        for ix in range(1, WIDTH - 1):
            h = grid[iz * WIDTH + ix]
            dx = grid[iz * WIDTH + ix + 1] - grid[iz * WIDTH + ix - 1]
            dz = grid[(iz + 1) * WIDTH + ix] - grid[(iz - 1) * WIDTH + ix]
            grads.append(math.hypot(dx, dz) / (2.0 * SPACING))
            if (
                h > grid[iz * WIDTH + ix - 1]
                and h > grid[iz * WIDTH + ix + 1]
                and h > grid[(iz - 1) * WIDTH + ix]
                and h > grid[(iz + 1) * WIDTH + ix]
            ):
                peaks += 1
    mean_g = sum(grads) / len(grads)
    return mean_g, max(grads), peaks


def main() -> None:
    FARM.mkdir(parents=True, exist_ok=True)
    grid = build_grid()
    peak, valley = max(grid), min(grid)
    mean_g, max_g, peaks = _slope_stats(grid)
    print(f"grid {WIDTH}x{DEPTH} span={SPAN_X:.0f}x{SPAN_Z:.0f} min={valley:.3f} max={peak:.3f}")
    print(f"contrast={peak - valley:.3f} mean_slope={mean_g:.3f} max_slope={max_g:.3f} local_maxima={peaks}")
    hx, hz = world_to_cell(wx(HILL_XZ[0]), wz(HILL_XZ[1]))
    print(f"hill_cell=({hx:.1f},{hz:.1f}) hill_h={height_world(wx(HILL_XZ[0]), wz(HILL_XZ[1])):.3f}")
    print(f"familyA_h={height_world(wx(-38), wz(-18)):.3f} cliff_rim={height_world(wx(CLIFF_X), 0):.3f} cliff_pit={height_world(wx(CLIFF_X) + 14.0, 0):.3f}")
    if SPAN_X < 250 or SPAN_Z < 200:
        raise SystemExit("farm span is not 4x area")
    if peak - valley < 8.0:
        raise SystemExit("height contrast too low — need rolling hills")
    if peaks < 12:
        raise SystemExit("not enough local maxima for curved terrain")
    if height_world(wx(CLIFF_X) + 14.0, 0.0) > -8.0:
        raise SystemExit("east cliff is not a steep drop")
    old_exr = FARM / "kyle_T0_height_97x81.exr"
    if old_exr.exists():
        old_exr.unlink()
    old_imp = FARM / "kyle_T0_height_97x81.exr.import"
    if old_imp.exists():
        old_imp.unlink()
    exr = FARM / "kyle_T0_height_193x161.exr"
    write_exr(exr, grid)
    write_exr_import(exr)
    obj = FARM / "kyle_farm_terrain.obj"
    write_obj(obj, grid)
    write_import(obj)
    write_scene(grid)
    noisy = FARM / "kyle_height_preview_NOISY_do_not_import.png"
    if noisy.exists():
        raise SystemExit("refusing to keep noisy height preview")


if __name__ == "__main__":
    main()
