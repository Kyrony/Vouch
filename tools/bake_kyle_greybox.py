#!/usr/bin/env python3
"""Offline baker: Kyle T0 greybox SoT → EXR + solid mesh + HorrorWorld.tscn.

Not loaded at runtime. Start Match instantiates the authored packed scene.
"""

from __future__ import annotations

import math
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FARM = ROOT / "assets/horror/farm"
SCENE = ROOT / "scenes/Horror/HorrorWorld.tscn"

WIDTH = 97
DEPTH = 81
SPACING = 1.5
SPAN_X = (WIDTH - 1) * SPACING  # 144
SPAN_Z = (DEPTH - 1) * SPACING  # 120
ORIGIN_X = -SPAN_X / 2.0
ORIGIN_Z = -SPAN_Z / 2.0
CLIFF_X = 54.0
HILL_XZ = (22.0, -8.0)
HILL_PEAK = 4.5
PLATEAU = 1.15
FAMILY_BASE = 0.85

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

# Family outdoor spawns sit on the road-facing edge of each pad.
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
    ("under_porch_crawl", 9, 42.0, 18.0),
    ("garden_well", 10, 4.0, -8.0),
    ("car_trunk", 11, 0.0, 20.0),
]

# Road centerlines (a → b, half-width). Kyle layout connectors.
ROADS = [
    ((-60.0, -18.0), (-30.0, -18.0), 2.6),  # west from A
    ((-38.0, -18.0), (-38.0, 24.0), 2.4),  # A–B–C
    ((-38.0, 24.0), (-8.0, 24.0), 2.4),  # C–D
    ((-14.0, 24.0), (8.0, 6.0), 2.5),  # D toward mansion
    ((8.0, 6.0), (22.0, -6.0), 2.6),  # junction to mansion
    ((-38.0, -18.0), (16.0, -28.0), 2.4),  # A to Uncle
    ((16.0, -28.0), (30.0, -28.0), 2.3),  # Uncle to garage
    ((22.0, -6.0), (22.0, -28.0), 2.3),  # mansion north to uncle
    ((22.0, -6.0), (50.0, -6.0), 2.6),  # mansion east toward cliff
    ((22.0, -6.0), (22.0, 22.0), 2.5),  # mansion south
    ((22.0, 22.0), (50.0, 22.0), 2.6),  # south then east to cliff
    ((8.0, 6.0), (-4.0, 24.0), 2.3),  # west spur near D
]

PICKUPS = [
    ("medkit", -34.0, -12.0),
    ("phone", 2.0, 2.0),
    ("bandage", 22.0, 4.0),
    ("battery", -50.0, -36.0),
    ("crowbar", -14.0, 20.0),
    ("keycard", 16.0, -24.0),
]

HILLS = [
    ("mansion_hill", 22.0, -8.0),
    ("family_west", -38.0, 4.0),
    ("uncle_north", 20.0, -28.0),
    ("south_field", -20.0, 32.0),
    ("garden_knoll", 4.0, -10.0),
    ("east_cliff_rim", 50.0, 0.0),
    ("shed_nw", -50.0, -36.0),
]


def world_to_cell(x: float, z: float) -> tuple[float, float]:
    return (x - ORIGIN_X) / SPACING, (z - ORIGIN_Z) / SPACING


def height_at_cell(ix: float, iz: float) -> float:
    x = ORIGIN_X + ix * SPACING
    z = ORIGIN_Z + iz * SPACING
    return height_world(x, z)


def _bump(x: float, z: float, cx: float, cz: float, radius: float, height: float) -> float:
    d2 = (x - cx) ** 2 + (z - cz) ** 2
    if d2 > radius * radius:
        return 0.0
    t = 1.0 - d2 / (radius * radius)
    return height * (t * t)


def height_world(x: float, z: float) -> float:
    # East cliff / steep drop — black strip on the T0 preview.
    if x >= CLIFF_X + 8.0:
        return 0.0
    if x >= CLIFF_X:
        t = (x - CLIFF_X) / 8.0
        edge = 1.0 - t * t
    else:
        edge = 1.0

    h = FAMILY_BASE if x < -8.0 else PLATEAU
    h += _bump(x, z, HILL_XZ[0], HILL_XZ[1], 26.0, HILL_PEAK - PLATEAU)
    h += _bump(x, z, -36.0, 8.0, 16.0, 0.35)
    h += _bump(x, z, 8.0, -28.0, 12.0, 0.45)
    h += _bump(x, z, -20.0, 30.0, 14.0, 0.30)
    h += _bump(x, z, 6.0, -12.0, 10.0, 0.25)
    h += _bump(x, z, -50.0, -36.0, 10.0, 0.40)
    h *= edge
    return max(0.0, min(HILL_PEAK, h))


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
    """RGB FLOAT uncompressed OpenEXR (97×81). Offline SoT; collision is baked into the scene."""
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
            # CCW from +Y
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
        "# Kyle T0 greybox heightfield. Baked, not generated at runtime.",
        "o KyleFarmTerrain",
    ]
    for v in verts_top + verts_bot:
        lines.append("v %.4f %.4f %.4f" % v)
    for a, b, c in faces:
        lines.append("f %d %d %d" % (a, b, c))
    path.write_text("\n".join(lines) + "\n")
    print(f"wrote {path} verts={len(verts_top)*2} faces={len(faces)}")


def xf(x: float, y: float, z: float, yaw: float = 0.0) -> str:
    c, s = math.cos(yaw), math.sin(yaw)
    return "Transform3D(%.5f, 0, %.5f, 0, 1, 0, %.5f, 0, %.5f, %.3f, %.3f, %.3f)" % (
        c, s, -s, c, x, y, z,
    )


def write_scene(grid: list[float]) -> None:
    peak = max(grid)
    valley = min(grid)
    map_csv = ", ".join("%.3f" % h for h in grid)

    lines: list[str] = []
    lines.append("[gd_scene load_steps=40 format=3]")
    lines.append("")
    lines.append('[ext_resource type="Script" path="res://scripts/horror/horror_world.gd" id="1"]')
    lines.append('[ext_resource type="PackedScene" path="res://scenes/Horror/WorldPickup.tscn" id="2"]')
    lines.append('[ext_resource type="Script" path="res://scripts/interactables/escape_zone.gd" id="3"]')
    lines.append('[ext_resource type="ArrayMesh" path="res://assets/horror/farm/kyle_farm_terrain.obj" id="4"]')
    lines.append("")
    lines.append('[sub_resource type="Environment" id="EnvFarm"]')
    lines.append("background_mode = 1")
    lines.append("background_color = Color(0.55, 0.68, 0.82, 1)")
    lines.append("ambient_light_source = 2")
    lines.append("ambient_light_color = Color(0.55, 0.6, 0.58, 1)")
    lines.append("ambient_light_energy = 0.7")
    lines.append("")
    mats = {
        "Mat_grass": (0.30, 0.46, 0.22),
        "Mat_asphalt": (0.11, 0.11, 0.13),
        "Mat_pad": (0.55, 0.55, 0.52),
        "Mat_mansion": (0.42, 0.36, 0.32),
        "Mat_pin": (0.92, 0.82, 0.18),
        "Mat_base": (0.95, 0.35, 0.18),
        "Mat_crawl": (0.25, 0.85, 0.95),
        "Mat_field": (0.34, 0.48, 0.24),
    }
    for mid, (r, g, b) in mats.items():
        lines.append(f'[sub_resource type="StandardMaterial3D" id="{mid}"]')
        lines.append(f"albedo_color = Color({r}, {g}, {b}, 1)")
        lines.append("roughness = 0.92")
        if mid == "Mat_grass":
            lines.append("cull_mode = 2")
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
    lines.append("size = Vector3(144, 0.8, 120)")
    lines.append("")
    lines.append('[sub_resource type="BoxMesh" id="Box_pin"]')
    lines.append("size = Vector3(1.1, 1.55, 1.1)")
    lines.append("material = SubResource(\"Mat_pin\")")
    lines.append("")
    lines.append('[sub_resource type="BoxMesh" id="Box_pinbase"]')
    lines.append("size = Vector3(1.1, 1.55, 1.1)")
    lines.append("material = SubResource(\"Mat_base\")")
    lines.append("")
    lines.append('[sub_resource type="BoxMesh" id="Box_pincrawl"]')
    lines.append("size = Vector3(1.1, 1.55, 1.1)")
    lines.append("material = SubResource(\"Mat_crawl\")")
    lines.append("")
    lines.append('[sub_resource type="BoxShape3D" id="Sh_escape"]')
    lines.append("size = Vector3(8, 2.4, 8)")
    lines.append("")
    lines.append('[sub_resource type="BoxMesh" id="Box_field_a"]')
    lines.append("size = Vector3(28, 0.06, 22)")
    lines.append("material = SubResource(\"Mat_field\")")
    lines.append("")
    lines.append('[sub_resource type="BoxMesh" id="Box_field_b"]')
    lines.append("size = Vector3(22, 0.06, 18)")
    lines.append("material = SubResource(\"Mat_field\")")
    lines.append("")

    # Per-pad / road mesh resources
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

    for i, (a, b, r) in enumerate(ROADS):
        ax, az = a
        bx, bz = b
        length = math.hypot(bx - ax, bz - az)
        lines.append(f'[sub_resource type="BoxMesh" id="Box_rd{i}"]')
        lines.append(f"size = Vector3({r * 2:.3f}, 0.10, {length:.3f})")
        lines.append('material = SubResource("Mat_asphalt")')
        lines.append("")
        lines.append(f'[sub_resource type="BoxShape3D" id="Sh_rd{i}"]')
        lines.append(f"size = Vector3({r * 2:.3f}, 0.10, {length:.3f})")
        lines.append("")

    # Nodes
    lines.append('[node name="HorrorWorld" type="Node3D"]')
    lines.append('script = ExtResource("1")')
    lines.append("")
    lines.append('[node name="FarmSky" type="WorldEnvironment" parent="."]')
    lines.append("environment = SubResource(\"EnvFarm\")")
    lines.append("")
    lines.append('[node name="Outdoor" type="Node3D" parent="."]')
    lines.append("")
    lines.append('[node name="Terrain" type="StaticBody3D" parent="Outdoor"]')
    lines.append("collision_layer = 1")
    lines.append("collision_mask = 0")
    lines.append("metadata/span_x = 144.0")
    lines.append("metadata/span_z = 120.0")
    lines.append("metadata/authored_heightfield = true")
    lines.append("metadata/solid_mesh = true")
    lines.append("metadata/underside = true")
    lines.append('metadata/winding = "ccw_up"')
    lines.append('metadata/sot = "kyle_T0"')
    lines.append(f"metadata/peak_y = {peak:.3f}")
    lines.append(f"metadata/valley_y = {valley:.3f}")
    lines.append("metadata/map_width = 97")
    lines.append("metadata/map_depth = 81")
    lines.append("metadata/cell_m = 1.5")
    lines.append("")
    lines.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="Outdoor/Terrain"]')
    lines.append("mesh = ExtResource(\"4\")")
    lines.append("material_override = SubResource(\"Mat_grass\")")
    lines.append("")
    lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="Outdoor/Terrain"]')
    lines.append("transform = Transform3D(1.5, 0, 0, 0, 1, 0, 0, 0, 1.5, 0, 0, 0)")
    lines.append("shape = SubResource(\"Sh_terrain\")")
    lines.append("")
    lines.append('[node name="Bed" type="CollisionShape3D" parent="Outdoor/Terrain"]')
    lines.append("transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.85, 0)")
    lines.append("shape = SubResource(\"Sh_bed\")")
    lines.append("")

    lines.append('[node name="Hills" type="Node3D" parent="Outdoor"]')
    lines.append(f"metadata/hill_count = {len(HILLS)}")
    lines.append('metadata/variety = "kyle_t0"')
    lines.append("")
    for hid, hx, hz in HILLS:
        hy = sample(hx, hz)
        lines.append(f'[node name="Hill_{hid}" type="Marker3D" parent="Outdoor/Hills"]')
        lines.append(f"position = Vector3({hx:.3f}, {hy:.3f}, {hz:.3f})")
        lines.append(f'metadata/hill_id = "{hid}"')
        lines.append("")

    lines.append('[node name="Roads" type="Node3D" parent="Outdoor"]')
    lines.append('metadata/plate = "kyle_greybox"')
    lines.append("")
    for i, (a, b, _r) in enumerate(ROADS):
        ax, az = a
        bx, bz = b
        mx, mz = (ax + bx) / 2.0, (az + bz) / 2.0
        my = sample(mx, mz) + 0.05
        yaw = math.atan2(bx - ax, bz - az)
        name = f"Lane_{i:02d}"
        lines.append(f'[node name="{name}" type="StaticBody3D" parent="Outdoor/Roads"]')
        lines.append(f"transform = {xf(mx, my, mz, yaw)}")
        lines.append("collision_layer = 1")
        lines.append("collision_mask = 0")
        lines.append("")
        lines.append(f'[node name="MeshInstance3D" type="MeshInstance3D" parent="Outdoor/Roads/{name}"]')
        lines.append(f"mesh = SubResource(\"Box_rd{i}\")")
        lines.append("")
        lines.append(f'[node name="CollisionShape3D" type="CollisionShape3D" parent="Outdoor/Roads/{name}"]')
        lines.append(f"shape = SubResource(\"Sh_rd{i}\")")
        lines.append("")

    lines.append('[node name="Pads" type="Node3D" parent="Outdoor"]')
    lines.append('metadata/sot = "kyle_greybox_layout"')
    lines.append("")
    for name, spec in PADS.items():
        px, pz = spec["xz"]
        sx, sy, sz = spec["size"]
        py = sample(px, pz) + sy / 2.0
        if name == "PMMansion":
            # MainHouse is the hilltop mansion pad (validation name).
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
    fy = sample(-38.0, 36.0) + 0.03
    lines.append('[node name="FieldWest" type="MeshInstance3D" parent="Outdoor/Fields"]')
    lines.append(f"transform = {xf(-38.0, fy, 36.0)}")
    lines.append("mesh = SubResource(\"Box_field_a\")")
    lines.append("")
    fy2 = sample(8.0, 36.0) + 0.03
    lines.append('[node name="FieldEast" type="MeshInstance3D" parent="Outdoor/Fields"]')
    lines.append(f"transform = {xf(8.0, fy2, 36.0)}")
    lines.append("mesh = SubResource(\"Box_field_b\")")
    lines.append("")

    lines.append('[node name="PlayerSpawns" type="Node3D" parent="Outdoor"]')
    lines.append("")
    for name, sx, sz, yaw in FAMILY_SPAWNS:
        sy = sample(sx, sz) + 0.14
        lines.append(f'[node name="{name}" type="Marker3D" parent="Outdoor/PlayerSpawns" groups=["outdoor_player_spawns"]]')
        lines.append(f"transform = {xf(sx, sy, sz, yaw)}")
        lines.append("")
    pmx, pmz = PM_SPAWN[1], PM_SPAWN[2]
    pmy = sample(pmx, pmz) + 0.14
    lines.append('[node name="Outdoor_PM_Street" type="Marker3D" parent="Outdoor" groups=["outdoor_player_spawns"]]')
    lines.append(f"transform = {xf(pmx, pmy, pmz, PM_SPAWN[3])}")
    lines.append("")

    ex, ez = -58.0, 12.0
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
    lines.append("transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 16, 6)")
    lines.append("light_color = Color(0.72, 0.78, 0.88, 1)")
    lines.append("light_energy = 0.58")
    lines.append("omni_range = 90.0")
    lines.append("")

    mx, mz = PADS["PMMansion"]["xz"]
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
        ly = sample(lx, lz) + 0.12
        box = "Box_pincrawl" if sid == "under_porch_crawl" else ("Box_pinbase" if sid == "basement" else "Box_pin")
        site = f"SpawnPoint_{sid}"
        lines.append(f'[node name="{site}" type="Node3D" parent="L2SpawnMarkers"]')
        lines.append(f"transform = {xf(lx, ly, lz)}")
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
        py = sample(px, pz) + 0.12
        lines.append(f'[node name="Pickup_{item}" parent="Pickups" instance=ExtResource("2")]')
        lines.append(f"transform = {xf(px, py, pz)}")
        lines.append(f'item_id = "{item}"')
        lines.append("")

    SCENE.write_text("\n".join(lines) + "\n")
    print(f"wrote {SCENE} peak={peak:.3f} valley={valley:.3f}")
    print("family_spawns", [(n, sample(x, z) + 0.14) for n, x, z, _ in FAMILY_SPAWNS])
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
                'uid="uid://kylet0height97x81"',
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


def main() -> None:
    FARM.mkdir(parents=True, exist_ok=True)
    grid = build_grid()
    print(f"grid {WIDTH}x{DEPTH} min={min(grid):.3f} max={max(grid):.3f}")
    hx, hz = world_to_cell(*HILL_XZ)
    print(f"hill_cell=({hx:.1f},{hz:.1f}) hill_h={height_world(*HILL_XZ):.3f}")
    print(f"familyA_h={height_world(-38, -18):.3f} cliff_h={height_world(70, 0):.3f}")
    exr = FARM / "kyle_T0_height_97x81.exr"
    write_exr(exr, grid)
    obj = FARM / "kyle_farm_terrain.obj"
    write_obj(obj, grid)
    write_scene(grid)
    noisy = FARM / "kyle_height_preview_NOISY_do_not_import.png"
    if noisy.exists():
        raise SystemExit("refusing to keep noisy height preview")


if __name__ == "__main__":
    main()
