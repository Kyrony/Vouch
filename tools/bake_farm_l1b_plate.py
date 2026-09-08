#!/usr/bin/env python3
"""Offline authoring bake for the L1b / QA farm plate.

Writes sealed farm_hills.obj + patches HorrorWorld.tscn / neighborhood_v05.gd.
Not imported by the game — Start Match only instantiates the packed scene.
"""

from __future__ import annotations

import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OBJ_PATH = ROOT / "assets/horror/farm/farm_hills.obj"
TSCN_PATH = ROOT / "scenes/Horror/HorrorWorld.tscn"
V05_PATH = ROOT / "scripts/horror/world/neighborhood_v05.gd"

NX = 73
NZ = 61
STEP = 2.0
X0 = -72.0
Z0 = -60.0
VALLEY = 0.08
BED = -0.80
PEAK = 5.0

# World +X east, +Z south. Polylines traced from L1b farm-country + QA v2.
# No L1 cul-de-sac ring, no inner 32 m grid, no shed circle.
PLATE_SPANS: list[tuple[tuple[float, float], tuple[float, float], float]] = [
    # Elevated plateau loop around the hilltop main house (rounded rect).
    ((28.0, -20.0), (52.0, -20.0), 3.0),
    ((52.0, -20.0), (58.0, -14.0), 3.0),
    ((58.0, -14.0), (58.0, 10.0), 3.0),
    ((58.0, 10.0), (52.0, 16.0), 3.0),
    ((52.0, 16.0), (28.0, 16.0), 3.0),
    ((28.0, 16.0), (22.0, 10.0), 3.0),
    ((22.0, 10.0), (22.0, -14.0), 3.0),
    ((22.0, -14.0), (28.0, -20.0), 3.0),
    # West exit from the loop, then the L1b split.
    ((22.0, 0.0), (10.0, 2.0), 3.2),
    # South-west branch to Family House D.
    ((10.0, 2.0), (6.0, 16.0), 2.6),
    ((6.0, 16.0), (6.0, 30.0), 2.6),
    # West trunk past Uncle House (north of the house) to Family House B.
    ((10.0, 2.0), (-2.0, -2.0), 2.6),
    ((-2.0, -2.0), (-16.0, -8.0), 2.6),
    ((-16.0, -8.0), (-38.0, -12.0), 2.4),
    # Second lane south of Uncle House (L1b: house sits between two paths).
    ((22.0, 10.0), (10.0, 10.0), 2.4),
    ((10.0, 10.0), (4.0, 8.0), 2.4),
    # Southern branch from the loop, curving south-west to House D.
    ((28.0, 16.0), (16.0, 22.0), 2.6),
    ((16.0, 22.0), (8.0, 28.0), 2.6),
    ((8.0, 28.0), (6.0, 30.0), 2.4),
    # Northern branch toward Lansis.
    ((22.0, -14.0), (12.0, -24.0), 2.4),
    ((12.0, -24.0), (4.0, -34.0), 2.4),
    ((4.0, -34.0), (0.0, -42.0), 2.2),
    # QA south access: entrance road to the three-way at car_trunk, then the split.
    ((4.0, 42.0), (0.0, 16.0), 3.0),
    ((0.0, 16.0), (6.0, 6.0), 2.8),
    ((6.0, 6.0), (10.0, 2.0), 2.6),
    # Path from Family House B to the Family Shed hill.
    ((-38.0, -12.0), (-44.0, -24.0), 2.2),
    ((-44.0, -24.0), (-50.0, -40.0), 2.2),
]

HILLS = [
    # id, x, z, height, radius, flat_frac
    # Centered on the L1b plateau so the rounded loop sits on the flat top.
    ("pm_plateau", 40.0, -2.0, 5.00, 26.0, 0.84),
    ("shed_nw", -50.0, -40.0, 2.20, 12.0, 0.22),
    ("north_ridge", 6.0, -36.0, 3.80, 15.0, 0.18),
    ("west_pasture", -48.0, 10.0, 2.80, 14.0, 0.16),
    ("sw_field", -36.0, 28.0, 3.00, 14.0, 0.16),
    ("se_pasture", 22.0, 38.0, 2.60, 13.0, 0.16),
    ("east_rise", 64.0, 6.0, 2.00, 10.0, 0.20),
    ("garden_knoll", -10.0, -24.0, 2.20, 11.0, 0.18),
]

L2_XZ = {
    "pm_attic": (30.0, -14.0),
    "master_bedroom": (30.0, -7.0),
    "bunker_utility": (30.0, 0.0),
    "basement": (28.0, 7.0),
    "uncle_bedroom": (50.0, -12.0),
    "uncle_garage": (52.0, -2.0),
    "family_shed": (-50.0, -40.0),
    "storm_drain": (-40.0, -18.0),
    "under_porch_crawl": (50.0, 16.0),
    "garden_well": (16.0, -6.0),
    "car_trunk": (0.0, 16.0),
}

FAMILY_XZ = {
    "A": (-12.0, -7.0, 0.45),
    "B": (-30.0, -12.0, -math.pi / 2.0),
    "C": (18.0, 22.0, math.pi),
    "D": (6.0, 22.0, math.pi),
}

PICKUPS = [
    ("medkit", "medkit", -34.0, -12.0),
    ("phone", "phone", 2.0, 2.0),
    ("bandage", "bandage", 40.0, 2.0),
    ("battery", "battery", -50.0, -40.0),
    ("crowbar", "crowbar", 6.0, 24.0),
    ("keycard", "keycard", 8.0, 8.0),
]


def _hash_noise(ix: int, iz: int) -> float:
    n = (ix * 374761393 + iz * 668265263) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return (n / 4294967295.0) * 2.0 - 1.0


def _hill_contrib(x: float, z: float, cx: float, cz: float, height: float, radius: float, flat: float) -> float:
    dx = x - cx
    dz = z - cz
    d = math.sqrt(dx * dx + dz * dz)
    if d >= radius:
        return 0.0
    t = d / radius
    if t <= flat:
        return height
    u = (t - flat) / max(1e-6, 1.0 - flat)
    return height * (0.5 + 0.5 * math.cos(math.pi * u))


def _road_dist(x: float, z: float) -> tuple[float, float, bool]:
    """Return (distance to nearest plate road, t along span, on_loop)."""
    best = 1e9
    t_best = 0.0
    loop_d = 1e9
    for i, ((ax, az), (bx, bz), r) in enumerate(PLATE_SPANS):
        vx, vz = bx - ax, bz - az
        length2 = vx * vx + vz * vz
        if length2 < 1e-8:
            d = math.hypot(x - ax, z - az)
            t = 0.0
        else:
            t = max(0.0, min(1.0, ((x - ax) * vx + (z - az) * vz) / length2))
            px, pz = ax + t * vx, az + t * vz
            d = math.hypot(x - px, z - pz)
        score = d - (r - 3.0) * 0.15
        if score < best:
            best = score
            t_best = t
        if i < 8:
            loop_d = min(loop_d, d)
    return best, t_best, loop_d < 3.6


def build_heightfield() -> list[list[float]]:
    h = [[VALLEY for _ in range(NX)] for _ in range(NZ)]
    for iz in range(NZ):
        z = Z0 + iz * STEP
        for ix in range(NX):
            x = X0 + ix * STEP
            y = VALLEY
            for _hid, cx, cz, height, radius, flat in HILLS:
                y = max(y, _hill_contrib(x, z, cx, cz, height, radius, flat))
            # Soft rolling variety — deterministic, not a runtime loop.
            y += 0.18 * _hash_noise(ix, iz) * max(0.0, 1.0 - y / PEAK)
            h[iz][ix] = max(VALLEY, min(PEAK, y))

    # Flatten a corridor only along Leonardo roads. Loop stays on the plateau.
    for iz in range(NZ):
        z = Z0 + iz * STEP
        for ix in range(NX):
            x = X0 + ix * STEP
            d, _t, on_loop = _road_dist(x, z)
            if d > 5.2:
                continue
            raw = h[iz][ix]
            if on_loop:
                target = 4.72
            else:
                target = max(VALLEY + 0.04, min(raw, raw * 0.35 + 0.18))
            blend = 1.0 if d < 2.4 else max(0.0, 1.0 - (d - 2.4) / 2.8)
            h[iz][ix] = raw * (1.0 - blend) + target * blend
    return h


def height_at(field: list[list[float]], x: float, z: float) -> float:
    fx = (x - X0) / STEP
    fz = (z - Z0) / STEP
    ix = max(0, min(NX - 2, int(math.floor(fx))))
    iz = max(0, min(NZ - 2, int(math.floor(fz))))
    tx = fx - ix
    tz = fz - iz
    h00 = field[iz][ix]
    h10 = field[iz][ix + 1]
    h01 = field[iz + 1][ix]
    h11 = field[iz + 1][ix + 1]
    return (h00 * (1 - tx) * (1 - tz) + h10 * tx * (1 - tz) + h01 * (1 - tx) * tz + h11 * tx * tz)


def _normal(a: tuple[float, float, float], b: tuple[float, float, float], c: tuple[float, float, float]) -> tuple[float, float, float]:
    ux, uy, uz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
    vx, vy, vz = c[0] - a[0], c[1] - a[1], c[2] - a[2]
    nx = uy * vz - uz * vy
    ny = uz * vx - ux * vz
    nz = ux * vy - uy * vx
    length = math.sqrt(nx * nx + ny * ny + nz * nz) or 1.0
    return (nx / length, ny / length, nz / length)


def write_obj(field: list[list[float]]) -> dict:
    top: list[tuple[float, float, float]] = []
    for iz in range(NZ):
        z = Z0 + iz * STEP
        for ix in range(NX):
            x = X0 + ix * STEP
            top.append((x, field[iz][ix], z))

    # Vertex normals from neighboring tris (upward).
    acc = [[0.0, 0.0, 0.0] for _ in top]

    def add_n(i0: int, i1: int, i2: int) -> None:
        n = _normal(top[i0], top[i1], top[i2])
        for i in (i0, i1, i2):
            acc[i][0] += n[0]
            acc[i][1] += n[1]
            acc[i][2] += n[2]

    top_faces: list[tuple[int, int, int]] = []
    for iz in range(NZ - 1):
        for ix in range(NX - 1):
            a = iz * NX + ix
            b = a + 1
            d = a + NX
            c = d + 1
            # CCW from +Y so geometric normals point up (Godot culls clockwise backs).
            top_faces.append((a, d, c))
            top_faces.append((a, c, b))
            add_n(a, d, c)
            add_n(a, c, b)

    vn_top: list[tuple[float, float, float]] = []
    for nx, ny, nz in acc:
        length = math.sqrt(nx * nx + ny * ny + nz * nz) or 1.0
        vn_top.append((nx / length, ny / length, nz / length))

    up = sum(1 for i0, i1, i2 in top_faces if _normal(top[i0], top[i1], top[i2])[1] >= 0.0)
    down = len(top_faces) - up
    if down:
        raise SystemExit(f"top faces still inverted: up={up} down={down}")

    bot = [(p[0], BED, p[2]) for p in top]
    vn_down = (0.0, -1.0, 0.0)
    vn_out_n = (0.0, 0.0, -1.0)
    vn_out_s = (0.0, 0.0, 1.0)
    vn_out_w = (-1.0, 0.0, 0.0)
    vn_out_e = (1.0, 0.0, 0.0)

    lines = [
        "# Authored Vouch farm heightfield. Baked, not generated at runtime.",
        "# L1b / QA plate: sealed (top + skirts + underside), CCW upward winding.",
        "o FarmHills",
    ]
    for v in top:
        lines.append("v %.4f %.4f %.4f" % v)
    for v in bot:
        lines.append("v %.4f %.4f %.4f" % v)
    for n in vn_top:
        lines.append("vn %.5f %.5f %.5f" % n)
    extra_n = [vn_down, vn_out_n, vn_out_s, vn_out_w, vn_out_e]
    for n in extra_n:
        lines.append("vn %.5f %.5f %.5f" % n)
    n_down = len(vn_top) + 1
    n_n, n_s, n_w, n_e = n_down + 1, n_down + 2, n_down + 3, n_down + 4
    top_count = len(top)

    lines.append("g FarmTop")
    for a, b, c in top_faces:
        lines.append("f %d//%d %d//%d %d//%d" % (a + 1, a + 1, b + 1, b + 1, c + 1, c + 1))

    lines.append("g FarmUnderside")
    for a, b, c in top_faces:
        # Reverse winding + bottom verts so the cap faces downward (outward).
        ba, bb, bc = a + top_count, c + top_count, b + top_count
        lines.append("f %d//%d %d//%d %d//%d" % (ba + 1, n_down, bb + 1, n_down, bc + 1, n_down))

    def skirt(edge: list[int], n_idx: int, outward_from_first: bool) -> None:
        for i in range(len(edge) - 1):
            t0, t1 = edge[i], edge[i + 1]
            b0, b1 = t0 + top_count, t1 + top_count
            if outward_from_first:
                faces = ((t0, t1, b1), (t0, b1, b0))
            else:
                faces = ((t0, b1, t1), (t0, b0, b1))
            for a, b, c in faces:
                lines.append("f %d//%d %d//%d %d//%d" % (a + 1, n_idx, b + 1, n_idx, c + 1, n_idx))

    lines.append("g FarmSkirts")
    north = [ix for ix in range(NX)]
    south = [(NZ - 1) * NX + ix for ix in range(NX)]
    west = [iz * NX for iz in range(NZ)]
    east = [iz * NX + (NX - 1) for iz in range(NZ)]
    # Outward: north (-Z), south (+Z), west (-X), east (+X).
    skirt(north, n_n, False)
    skirt(south, n_s, True)
    skirt(west, n_w, True)
    skirt(east, n_e, False)

    OBJ_PATH.parent.mkdir(parents=True, exist_ok=True)
    OBJ_PATH.write_text("\n".join(lines) + "\n")
    ys = [p[1] for p in top]
    return {
        "faces_up": up,
        "faces_down": down,
        "peak": max(ys),
        "valley": min(ys),
        "verts": len(top) * 2,
        "tris": len(top_faces) * 2 + (NX - 1) * 4 + (NZ - 1) * 4,
    }


def _basis_xz(ax: float, az: float, bx: float, bz: float) -> tuple[float, ...]:
    dx, dz = bx - ax, bz - az
    length = math.hypot(dx, dz) or 1.0
    zx, zz = dx / length, dz / length
    xx, xz = zz, -zx
    return (xx, 0.0, xz, 0.0, 1.0, 0.0, zx, 0.0, zz)


def _fmt_xform(basis: tuple[float, ...], ox: float, oy: float, oz: float) -> str:
    nums = list(basis) + [ox, oy, oz]
    return "Transform3D(" + ", ".join("%.5f" % n for n in nums) + ")"


def _subdivide(span: tuple[tuple[float, float], tuple[float, float], float], max_len: float = 12.0):
    (ax, az), (bx, bz), r = span
    length = math.hypot(bx - ax, bz - az)
    n = max(1, int(math.ceil(length / max_len)))
    out = []
    for i in range(n):
        t0 = i / n
        t1 = (i + 1) / n
        out.append(((ax + (bx - ax) * t0, az + (bz - az) * t0), (ax + (bx - ax) * t1, az + (bz - az) * t1), r))
    return out


def build_road_pieces(field: list[list[float]]) -> list[dict]:
    pieces = []
    for span in PLATE_SPANS:
        for (ax, az), (bx, bz), r in _subdivide(span):
            mx, mz = (ax + bx) * 0.5, (az + bz) * 0.5
            length = math.hypot(bx - ax, bz - az)
            y = height_at(field, mx, mz) + 0.06
            pieces.append(
                {
                    "a": (ax, az),
                    "b": (bx, bz),
                    "r": r,
                    "mid": (mx, mz),
                    "len": length + 0.16,
                    "y": y,
                    "basis": _basis_xz(ax, az, bx, bz),
                }
            )
    return pieces


def _yaw_basis(yaw: float) -> tuple[float, ...]:
    c, s = math.cos(yaw), math.sin(yaw)
    return (c, 0.0, s, 0.0, 1.0, 0.0, -s, 0.0, c)


def generate_tscn(field: list[list[float]], pieces: list[dict]) -> None:
    heights = [field[iz][ix] for iz in range(NZ) for ix in range(NX)]
    peak = max(heights)
    valley = min(heights)
    map_csv = ", ".join("%.3f" % y for y in heights)

    lines: list[str] = []
    lines.append("[gd_scene load_steps=200 format=3]")
    lines.append("")
    lines.append('[ext_resource type="Script" path="res://scripts/horror/horror_world.gd" id="1"]')
    lines.append('[ext_resource type="PackedScene" path="res://scenes/Horror/WorldPickup.tscn" id="2"]')
    lines.append('[ext_resource type="Script" path="res://scripts/interactables/escape_zone.gd" id="3"]')
    lines.append('[ext_resource type="ArrayMesh" path="res://assets/horror/farm/farm_hills.obj" id="4"]')
    lines.append("")
    lines.append('[sub_resource type="Environment" id="EnvFarm"]')
    lines.append("background_mode = 1")
    lines.append("background_color = Color(0.55, 0.68, 0.82, 1)")
    lines.append("ambient_light_source = 2")
    lines.append("ambient_light_color = Color(0.55, 0.6, 0.58, 1)")
    lines.append("ambient_light_energy = 0.7")
    lines.append("fog_enabled = false")
    lines.append("")
    lines.append('[sub_resource type="StandardMaterial3D" id="Mat_grass"]')
    lines.append("cull_mode = 2")
    lines.append("albedo_color = Color(0.3, 0.46, 0.22, 1)")
    lines.append("roughness = 0.92")
    lines.append("")
    lines.append('[sub_resource type="StandardMaterial3D" id="Mat_soil"]')
    lines.append("cull_mode = 2")
    lines.append("albedo_color = Color(0.38, 0.28, 0.18, 1)")
    lines.append("roughness = 0.95")
    lines.append("")
    lines.append('[sub_resource type="StandardMaterial3D" id="Mat_asphalt"]')
    lines.append("cull_mode = 2")
    lines.append("albedo_color = Color(0.11, 0.11, 0.13, 1)")
    lines.append("roughness = 0.92")
    lines.append("")
    lines.append('[sub_resource type="StandardMaterial3D" id="Mat_curb"]')
    lines.append("cull_mode = 2")
    lines.append("albedo_color = Color(0.68, 0.66, 0.6, 1)")
    lines.append("roughness = 0.92")
    lines.append("")
    lines.append('[sub_resource type="StandardMaterial3D" id="Mat_paint"]')
    lines.append("cull_mode = 2")
    lines.append("albedo_color = Color(0.82, 0.72, 0.28, 1)")
    lines.append("roughness = 0.92")
    lines.append("")
    lines.append('[sub_resource type="StandardMaterial3D" id="Mat_dirt"]')
    lines.append("cull_mode = 2")
    lines.append("albedo_color = Color(0.46, 0.33, 0.2, 1)")
    lines.append("roughness = 0.92")
    lines.append("")
    lines.append('[sub_resource type="StandardMaterial3D" id="Mat_pin"]')
    lines.append("albedo_color = Color(0.92, 0.82, 0.18, 1)")
    lines.append("roughness = 0.92")
    lines.append("emission_enabled = true")
    lines.append("emission = Color(0.92, 0.82, 0.18, 1)")
    lines.append("emission_energy_multiplier = 0.55")
    lines.append("")
    lines.append('[sub_resource type="StandardMaterial3D" id="Mat_base"]')
    lines.append("albedo_color = Color(0.95, 0.35, 0.18, 1)")
    lines.append("roughness = 0.92")
    lines.append("emission_enabled = true")
    lines.append("emission = Color(0.95, 0.35, 0.18, 1)")
    lines.append("emission_energy_multiplier = 0.55")
    lines.append("")
    lines.append('[sub_resource type="StandardMaterial3D" id="Mat_crawl"]')
    lines.append("albedo_color = Color(0.25, 0.85, 0.95, 1)")
    lines.append("roughness = 0.92")
    lines.append("emission_enabled = true")
    lines.append("emission = Color(0.25, 0.85, 0.95, 1)")
    lines.append("emission_energy_multiplier = 0.55")
    lines.append("")
    lines.append('[sub_resource type="StandardMaterial3D" id="Mat_siding"]')
    lines.append("albedo_color = Color(0.42, 0.36, 0.32, 1)")
    lines.append("roughness = 0.88")
    lines.append("")
    lines.append('[sub_resource type="StandardMaterial3D" id="Mat_roof"]')
    lines.append("albedo_color = Color(0.18, 0.16, 0.16, 1)")
    lines.append("roughness = 0.9")
    lines.append("")
    lines.append('[sub_resource type="StandardMaterial3D" id="Mat_trim"]')
    lines.append("albedo_color = Color(0.55, 0.5, 0.44, 1)")
    lines.append("roughness = 0.86")
    lines.append("")

    house = [
        ("Box_house_core", "Sh_house_core", 14, 4.2, 10, "Mat_siding"),
        ("Box_house_wing", "Sh_house_wing", 8, 3.6, 8, "Mat_siding"),
        ("Box_house_east", "Sh_house_east", 8, 3.4, 7, "Mat_siding"),
        ("Box_house_roof", "Sh_house_roof", 15.2, 0.7, 11.2, "Mat_roof"),
        ("Box_house_chimney", "Sh_house_chimney", 1.2, 2.4, 1.2, "Mat_trim"),
        ("Box_house_porch", "Sh_house_porch", 6.5, 0.35, 3.2, "Mat_trim"),
    ]
    for mesh_id, shape_id, sx, sy, sz, mat in house:
        lines.append('[sub_resource type="BoxMesh" id="%s"]' % mesh_id)
        lines.append("size = Vector3(%s, %s, %s)" % (sx, sy, sz))
        lines.append('material = SubResource("%s")' % mat)
        lines.append("")
        lines.append('[sub_resource type="BoxShape3D" id="%s"]' % shape_id)
        lines.append("size = Vector3(%s, %s, %s)" % (sx, sy, sz))
        lines.append("")

    lines.append('[sub_resource type="HeightMapShape3D" id="Sh_terrain"]')
    lines.append("map_width = %d" % NX)
    lines.append("map_depth = %d" % NZ)
    lines.append("map_data = PackedFloat32Array(%s)" % map_csv)
    lines.append("")
    lines.append('[sub_resource type="BoxShape3D" id="Sh_terrain_bed"]')
    lines.append("size = Vector3(146, 1.2, 122)")
    lines.append("")
    lines.append('[sub_resource type="BoxMesh" id="Box_courtyard"]')
    lines.append("size = Vector3(14, 0.12, 10)")
    lines.append('material = SubResource("Mat_asphalt")')
    lines.append("")
    lines.append('[sub_resource type="BoxShape3D" id="Sh_courtyard"]')
    lines.append("size = Vector3(14, 0.12, 10)")
    lines.append("")
    lines.append('[sub_resource type="BoxMesh" id="Box_shedpad"]')
    lines.append("size = Vector3(6.4, 0.12, 6.4)")
    lines.append('material = SubResource("Mat_asphalt")')
    lines.append("")
    lines.append('[sub_resource type="BoxShape3D" id="Sh_shedpad"]')
    lines.append("size = Vector3(6.4, 0.12, 6.4)")
    lines.append("")
    lines.append('[sub_resource type="BoxMesh" id="Box_field_a"]')
    lines.append("size = Vector3(18, 0.04, 14)")
    lines.append('material = SubResource("Mat_dirt")')
    lines.append("")
    lines.append('[sub_resource type="BoxMesh" id="Box_field_b"]')
    lines.append("size = Vector3(16, 0.04, 12)")
    lines.append('material = SubResource("Mat_dirt")')
    lines.append("")
    lines.append('[sub_resource type="BoxMesh" id="Box_pin"]')
    lines.append("size = Vector3(0.95, 1.55, 0.95)")
    lines.append('material = SubResource("Mat_pin")')
    lines.append("")
    lines.append('[sub_resource type="BoxMesh" id="Box_pinbase"]')
    lines.append("size = Vector3(0.95, 1.55, 0.95)")
    lines.append('material = SubResource("Mat_base")')
    lines.append("")
    lines.append('[sub_resource type="BoxMesh" id="Box_pincrawl"]')
    lines.append("size = Vector3(0.95, 1.55, 0.95)")
    lines.append('material = SubResource("Mat_crawl")')
    lines.append("")
    lines.append('[sub_resource type="BoxMesh" id="Box_painth"]')
    lines.append("size = Vector3(0.16, 0.03, 1.4)")
    lines.append('material = SubResource("Mat_paint")')
    lines.append("")
    lines.append('[sub_resource type="BoxShape3D" id="Sh_escape"]')
    lines.append("size = Vector3(6, 3.2, 6)")
    lines.append("")

    for i, p in enumerate(pieces):
        w = p["r"] * 2.0
        clen = p["len"]
        lines.append('[sub_resource type="BoxMesh" id="Box_rd%d"]' % i)
        lines.append("size = Vector3(%.3f, 0.12, %.3f)" % (w, clen))
        lines.append('material = SubResource("Mat_asphalt")')
        lines.append("")
        lines.append('[sub_resource type="BoxShape3D" id="Sh_rd%d"]' % i)
        lines.append("size = Vector3(%.3f, 0.12, %.3f)" % (w, clen))
        lines.append("")
        lines.append('[sub_resource type="BoxMesh" id="Box_cb%d"]' % i)
        lines.append("size = Vector3(0.22, 0.18, %.3f)" % (clen - 0.05))
        lines.append('material = SubResource("Mat_curb")')
        lines.append("")

    lines.append('[node name="HorrorWorld" type="Node3D"]')
    lines.append('script = ExtResource("1")')
    lines.append("")
    lines.append('[node name="FarmSky" type="WorldEnvironment" parent="."]')
    lines.append('environment = SubResource("EnvFarm")')
    lines.append("")
    lines.append('[node name="Outdoor" type="Node3D" parent="."]')
    lines.append("")
    lines.append('[node name="Terrain" type="StaticBody3D" parent="Outdoor"]')
    lines.append("collision_layer = 1")
    lines.append("collision_mask = 0")
    lines.append("metadata/span_x = 144.0")
    lines.append("metadata/span_z = 120.0")
    lines.append("metadata/hill_count = %d" % len(HILLS))
    lines.append("metadata/authored_heightfield = true")
    lines.append("metadata/solid_mesh = true")
    lines.append('metadata/winding = "ccw_up"')
    lines.append("metadata/has_underside = true")
    lines.append("metadata/has_skirts = true")
    lines.append('metadata/plate = "l1b_qa_v2"')
    lines.append("metadata/peak_y = %.3f" % peak)
    lines.append("metadata/valley_y = %.3f" % valley)
    lines.append("")
    lines.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="Outdoor/Terrain"]')
    lines.append('mesh = ExtResource("4")')
    lines.append('material_override = SubResource("Mat_grass")')
    lines.append("cast_shadow = 1")
    lines.append("")
    lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="Outdoor/Terrain"]')
    lines.append("transform = Transform3D(2, 0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0)")
    lines.append('shape = SubResource("Sh_terrain")')
    lines.append("")
    lines.append('[node name="Bed" type="CollisionShape3D" parent="Outdoor/Terrain"]')
    lines.append("transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.6, 0)")
    lines.append('shape = SubResource("Sh_terrain_bed")')
    lines.append("")
    lines.append('[node name="Hills" type="Node3D" parent="Outdoor"]')
    lines.append("metadata/hill_count = %d" % len(HILLS))
    lines.append('metadata/variety = "rolling_authored"')
    lines.append("")
    for hid, cx, cz, height, _radius, _flat in HILLS:
        hy = height_at(field, cx, cz)
        lines.append('[node name="Hill_%s" type="Marker3D" parent="Outdoor/Hills"]' % hid)
        lines.append("position = Vector3(%.3f, %.3f, %.3f)" % (cx, hy, cz))
        lines.append('metadata/hill_id = "%s"' % hid)
        lines.append("")

    lines.append('[node name="Roads" type="Node3D" parent="Outdoor"]')
    lines.append('metadata/plate = "l1b_qa_v2"')
    lines.append('metadata/network = "leonardo_farm"')
    lines.append("metadata/no_arbitrary_loops = true")
    lines.append("")

    court_y = height_at(field, 40.0, 2.0) + 0.07
    shed_y = height_at(field, -50.0, -40.0) + 0.07
    lines.append('[node name="CourtyardPad" type="StaticBody3D" parent="Outdoor/Roads"]')
    lines.append("transform = %s" % _fmt_xform((1, 0, 0, 0, 1, 0, 0, 0, 1), 40.0, court_y, 2.0))
    lines.append("collision_layer = 1")
    lines.append("collision_mask = 0")
    lines.append("")
    lines.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="Outdoor/Roads/CourtyardPad"]')
    lines.append('mesh = SubResource("Box_courtyard")')
    lines.append("")
    lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="Outdoor/Roads/CourtyardPad"]')
    lines.append('shape = SubResource("Sh_courtyard")')
    lines.append("")
    lines.append('[node name="ShedPad" type="StaticBody3D" parent="Outdoor/Roads"]')
    lines.append("transform = %s" % _fmt_xform((1, 0, 0, 0, 1, 0, 0, 0, 1), -50.0, shed_y, -40.0))
    lines.append("collision_layer = 1")
    lines.append("collision_mask = 0")
    lines.append("")
    lines.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="Outdoor/Roads/ShedPad"]')
    lines.append('mesh = SubResource("Box_shedpad")')
    lines.append("")
    lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="Outdoor/Roads/ShedPad"]')
    lines.append('shape = SubResource("Sh_shedpad")')
    lines.append("")

    for i, p in enumerate(pieces):
        name = "Lane_%02d" % i
        xx, xz = p["basis"][0], p["basis"][2]
        curb_off = p["r"] + 0.14
        lines.append('[node name="%s" type="StaticBody3D" parent="Outdoor/Roads"]' % name)
        lines.append("transform = %s" % _fmt_xform(p["basis"], p["mid"][0], p["y"], p["mid"][1]))
        lines.append("collision_layer = 1")
        lines.append("collision_mask = 0")
        lines.append("")
        lines.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="Outdoor/Roads/%s"]' % name)
        lines.append('mesh = SubResource("Box_rd%d")' % i)
        lines.append("")
        lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="Outdoor/Roads/%s"]' % name)
        lines.append('shape = SubResource("Sh_rd%d")' % i)
        lines.append("")
        for side, sign in (("L", 1.0), ("R", -1.0)):
            cname = "Curb_%02d%s" % (i, side)
            cx = p["mid"][0] + xx * curb_off * sign
            cz = p["mid"][1] + xz * curb_off * sign
            lines.append('[node name="%s" type="StaticBody3D" parent="Outdoor/Roads"]' % cname)
            lines.append("transform = %s" % _fmt_xform(p["basis"], cx, p["y"] + 0.04, cz))
            lines.append("collision_layer = 0")
            lines.append("collision_mask = 0")
            lines.append("")
            lines.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="Outdoor/Roads/%s"]' % cname)
            lines.append('mesh = SubResource("Box_cb%d")' % i)
            lines.append("")

    paint_i = 0
    for i, p in enumerate(pieces):
        steps = max(1, int(p["len"] / 3.2))
        ax, az = p["a"]
        bx, bz = p["b"]
        for s in range(steps):
            t = (s + 0.5) / steps
            px = ax + (bx - ax) * t
            pz = az + (bz - az) * t
            py = height_at(field, px, pz) + 0.13
            lines.append('[node name="Paint_%02d" type="MeshInstance3D" parent="Outdoor/Roads"]' % paint_i)
            lines.append("transform = %s" % _fmt_xform(p["basis"], px, py, pz))
            lines.append('mesh = SubResource("Box_painth")')
            lines.append("")
            paint_i += 1

    field_west_y = height_at(field, -38.0, 24.0) + 0.03
    field_east_y = height_at(field, 8.0, 32.0) + 0.03
    lines.append('[node name="Fields" type="Node3D" parent="Outdoor"]')
    lines.append("")
    lines.append('[node name="FieldWest" type="MeshInstance3D" parent="Outdoor/Fields"]')
    lines.append("transform = %s" % _fmt_xform((1, 0, 0, 0, 1, 0, 0, 0, 1), -38.0, field_west_y, 24.0))
    lines.append('mesh = SubResource("Box_field_a")')
    lines.append("")
    lines.append('[node name="FieldSouth" type="MeshInstance3D" parent="Outdoor/Fields"]')
    lines.append("transform = %s" % _fmt_xform((1, 0, 0, 0, 1, 0, 0, 0, 1), 8.0, field_east_y, 32.0))
    lines.append('mesh = SubResource("Box_field_b")')
    lines.append("")

    lines.append('[node name="PlayerSpawns" type="Node3D" parent="Outdoor"]')
    lines.append("")
    for letter, (fx, fz, yaw) in FAMILY_XZ.items():
        fy = height_at(field, fx, fz) + 0.14
        lines.append('[node name="Outdoor_Family_%s" type="Marker3D" parent="Outdoor/PlayerSpawns" groups=["outdoor_player_spawns"]]' % letter)
        lines.append("transform = %s" % _fmt_xform(_yaw_basis(yaw), fx, fy, fz))
        lines.append("")

    pm_y = height_at(field, 40.0, 2.0) + 0.14
    lines.append('[node name="Outdoor_PM_Street" type="Marker3D" parent="Outdoor" groups=["outdoor_player_spawns"]]')
    lines.append("transform = %s" % _fmt_xform(_yaw_basis(-math.pi / 2.0), 40.0, pm_y, 2.0))
    lines.append("")

    lines.append('[node name="HorrorEscapeZone" type="Area3D" parent="Outdoor"]')
    lines.append("transform = %s" % _fmt_xform((1, 0, 0, 0, 1, 0, 0, 0, 1), -62.0, 0.62, 12.0))
    lines.append("collision_layer = 0")
    lines.append("collision_mask = 4")
    lines.append('script = ExtResource("3")')
    lines.append("metadata/soft_gated = true")
    lines.append("")
    lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="Outdoor/HorrorEscapeZone"]')
    lines.append('shape = SubResource("Sh_escape")')
    lines.append("")
    lines.append('[node name="OutdoorFill" type="OmniLight3D" parent="Outdoor"]')
    lines.append("transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 16, 6)")
    lines.append("light_color = Color(0.72, 0.78, 0.88, 1)")
    lines.append("light_energy = 0.58")
    lines.append("omni_range = 90.0")
    lines.append("")
    house_y = height_at(field, 40.0, -6.0)
    lines.append('[node name="MainHouse" type="Node3D" parent="Outdoor"]')
    lines.append("transform = %s" % _fmt_xform((1, 0, 0, 0, 1, 0, 0, 0, 1), 40.0, house_y, -6.0))
    lines.append("metadata/on_hilltop = true")
    lines.append('metadata/role = "pm_farmhouse"')
    lines.append("")
    for name, mesh, shape, tx, ty, tz in (
        ("Core", "Box_house_core", "Sh_house_core", 0.0, 2.1, 0.0),
        ("WingN", "Box_house_wing", "Sh_house_wing", -1.5, 1.8, -7.5),
        ("WingE", "Box_house_east", "Sh_house_east", 9.0, 1.7, 0.6),
        ("Roof", "Box_house_roof", "Sh_house_roof", 0.0, 4.55, 0.0),
        ("Chimney", "Box_house_chimney", "Sh_house_chimney", -4.2, 5.6, -2.4),
        ("Porch", "Box_house_porch", "Sh_house_porch", 0.0, 0.18, 6.2),
    ):
        lines.append('[node name="%s" type="StaticBody3D" parent="Outdoor/MainHouse"]' % name)
        lines.append("transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %.3f, %.3f, %.3f)" % (tx, ty, tz))
        lines.append("collision_layer = 1")
        lines.append("collision_mask = 0")
        lines.append("")
        lines.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="Outdoor/MainHouse/%s"]' % name)
        lines.append('mesh = SubResource("%s")' % mesh)
        lines.append("")
        lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="Outdoor/MainHouse/%s"]' % name)
        lines.append('shape = SubResource("%s")' % shape)
        lines.append("")

    lines.append('[node name="L2SpawnMarkers" type="Node3D" parent="."]')
    lines.append("")
    pin_by = {
        "pm_attic": 1,
        "master_bedroom": 2,
        "bunker_utility": 3,
        "basement": 4,
        "uncle_bedroom": 5,
        "uncle_garage": 6,
        "family_shed": 7,
        "storm_drain": 8,
        "under_porch_crawl": 9,
        "garden_well": 10,
        "car_trunk": 11,
    }
    box_mesh = {
        "basement": "Box_pinbase",
        "under_porch_crawl": "Box_pincrawl",
    }
    for sid, (sx, sz) in L2_XZ.items():
        sy = height_at(field, sx, sz) + 0.12
        site = "SpawnPoint_%s" % sid
        lines.append('[node name="%s" type="Node3D" parent="L2SpawnMarkers"]' % site)
        lines.append("transform = %s" % _fmt_xform((1, 0, 0, 0, 1, 0, 0, 0, 1), sx, sy, sz))
        lines.append("")
        lines.append('[node name="ChildSpawn_%s" type="Marker3D" parent="L2SpawnMarkers/%s" groups=["child_spawn_points"]]' % (sid, site))
        lines.append('metadata/spawn_id = "%s"' % sid)
        lines.append("metadata/l2_pin = %d" % pin_by[sid])
        lines.append('metadata/visible_label = "Spawn Point"')
        lines.append("")
        lines.append('[node name="Box" type="MeshInstance3D" parent="L2SpawnMarkers/%s"]' % site)
        lines.append("transform = Transform3D(1.00000, 0, 0.00000, 0, 1, 0, -0.00000, 0, 1.00000, 0.000, 0.775, 0.000)")
        lines.append('mesh = SubResource("%s")' % box_mesh.get(sid, "Box_pin"))
        lines.append("")
        lines.append('[node name="Label" type="Label3D" parent="L2SpawnMarkers/%s"]' % site)
        lines.append("transform = Transform3D(1.00000, 0, 0.00000, 0, 1, 0, -0.00000, 0, 1.00000, 0.000, 2.100, 0.000)")
        lines.append('text = "Spawn Point"')
        lines.append("font_size = 42")
        lines.append("outline_size = 10")
        lines.append("billboard = 1")
        lines.append("no_depth_test = true")
        lines.append("")
        lines.append('[node name="SpawnId" type="Label3D" parent="L2SpawnMarkers/%s"]' % site)
        lines.append("transform = Transform3D(1.00000, 0, 0.00000, 0, 1, 0, -0.00000, 0, 1.00000, 0.000, 1.770, 0.000)")
        lines.append('text = "%s"' % sid)
        lines.append("font_size = 22")
        lines.append("outline_size = 8")
        lines.append("billboard = 1")
        lines.append("no_depth_test = true")
        lines.append("")

    lines.append('[node name="Pickups" type="Node3D" parent="."]')
    lines.append("")
    for name, item, px, pz in PICKUPS:
        py = height_at(field, px, pz) + 0.14
        lines.append('[node name="Pickup_%s" parent="Pickups" instance=ExtResource("2")]' % name)
        lines.append("transform = %s" % _fmt_xform((1, 0, 0, 0, 1, 0, 0, 0, 1), px, py, pz))
        lines.append('item_id = "%s"' % item)
        lines.append("")

    body = "\n".join(lines) + "\n"
    ext = body.count("[ext_resource")
    sub = body.count("[sub_resource")
    body = body.replace(
        "[gd_scene load_steps=200 format=3]",
        "[gd_scene load_steps=%d format=3]" % (ext + sub + 1),
        1,
    )
    TSCN_PATH.write_text(body)


def patch_v05() -> None:
    text = V05_PATH.read_text()
    block = ["const ROAD_SPANS: Array[Dictionary] = ["]
    for (ax, az), (bx, bz), r in PLATE_SPANS:
        block.append('\t{"a": Vector2(%.1f, %.1f), "b": Vector2(%.1f, %.1f), "r": %.1f},' % (ax, az, bx, bz, r))
    block.append("]")
    new = "\n".join(block)
    text2, n = re.subn(
        r"const ROAD_SPANS: Array\[Dictionary\] = \[.*?\]",
        new,
        text,
        count=1,
        flags=re.S,
    )
    if n != 1:
        raise SystemExit("failed to patch ROAD_SPANS")
    text2 = text2.replace(
        "## Authored road spans baked into HorrorWorld.tscn (data SoT only).\n## West hub + family lanes, plus the east oval loop from the QA plate.",
        "## Authored road spans baked into HorrorWorld.tscn (data SoT only).\n## L1b / QA v2 Leonardo network only — plateau loop + drawn branches.",
    )
    V05_PATH.write_text(text2)


def main() -> None:
    field = build_heightfield()
    stats = write_obj(field)
    pieces = build_road_pieces(field)
    generate_tscn(field, pieces)
    patch_v05()
    print(
        "baked farm plate verts=%d peak=%.2f valley=%.2f faces_up=%d lanes=%d"
        % (stats["verts"], stats["peak"], stats["valley"], stats["faces_up"], len(pieces))
    )


if __name__ == "__main__":
    main()
