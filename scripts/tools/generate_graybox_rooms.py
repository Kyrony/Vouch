#!/usr/bin/env python3
"""Generate perfect axis-aligned sealed graybox Room_XX.tscn files."""

from __future__ import annotations

import math
from pathlib import Path

WALL = 0.12
HEIGHT = 2.4
DOOR_W = 0.85
DOOR_H = 2.05
# Player.tscn CharacterBody3D origin = feet on floor when y=0 (capsule center offset 0.85).
SPAWN_Y = 0.0

ROOMS = [
    ("Room_01", 1, 6.0, 6.0),
    ("Room_02", 2, 7.0, 6.0),
    ("Room_03", 3, 8.0, 6.0),
    ("Room_04", 4, 6.0, 7.0),
    ("Room_05", 5, 7.0, 7.0),
    ("Room_06", 6, 8.0, 7.0),
]

PM = ("Room_PM", 0, 6.0, 6.0)

FLOOR_MAT = "res://assets/materials/graybox_floor.tres"
WALL_MAT = "res://assets/materials/graybox_wall.tres"
SLOT_SCRIPT = "res://scripts/rooms/item_spawn_slot.gd"
ROOM_MAP_SCRIPT = "res://scripts/rooms/room_map.gd"


def _slot_positions(room_id: int, w: float, d: float) -> list[dict]:
    """16 fixed slots — systems only, no baked furniture."""
    hw = w * 0.5 - 0.55
    hd = d * 0.5 - 0.55
    flush = 0.08
    slots: list[dict] = [
        {"pos": (0.0, 0.0, hd - flush), "surface": "wall_floor", "normal": (0, 0, -1)},
        {"pos": (0.0, HEIGHT - 0.12, 0.0), "surface": "ceiling", "normal": (0, -1, 0)},
    ]
    wall_pts = [
        (-hw * 0.5, 1.25, hd - flush, (0, 0, -1)),
        (hw * 0.5, 1.15, hd - flush, (0, 0, -1)),
        (hw - flush, 1.2, 0.0, (-1, 0, 0)),
        (-hw + flush, 1.1, 0.0, (1, 0, 0)),
        (0.0, 1.0, -hd + flush, (0, 0, 1)),
        (hw - flush, 1.35, hd * 0.3, (-1, 0, 0)),
        (-hw + flush, 0.95, -hd * 0.3, (1, 0, 0)),
        (0.0, 1.45, -hd + flush, (0, 0, 1)),
    ]
    for x, y, z, n in wall_pts:
        slots.append({"pos": (x, y, z), "surface": "wall", "normal": n})
    floor_pts = [
        (-1.2, 0.0, -1.0),
        (1.2, 0.0, -1.0),
        (-1.0, 0.0, 1.0),
        (1.0, 0.0, 1.0),
        (-0.5, 0.0, 0.5),
        (0.5, 0.0, -0.5),
    ]
    for x, y, z in floor_pts:
        slots.append({"pos": (x, y, z), "surface": "floor", "normal": (0, 1, 0)})
    return slots[:16]


def _geom_pieces(w: float, d: float, is_pm: bool) -> list[tuple[str, tuple, tuple, str]]:
    hw = w * 0.5
    hd = d * 0.5
    pieces: list[tuple[str, tuple, tuple, str]] = [
        ("Floor", (w, WALL, d), (0, -WALL * 0.5, 0), "floor"),
        ("Ceiling", (w, WALL, d), (0, HEIGHT + WALL * 0.5, 0), "ceil"),
        ("WallNegZ", (w, HEIGHT, WALL), (0, HEIGHT * 0.5, -hd), "wall"),
        ("WallEast", (WALL, HEIGHT, d), (hw, HEIGHT * 0.5, 0), "wall"),
        ("WallWest", (WALL, HEIGHT, d), (-hw, HEIGHT * 0.5, 0), "wall"),
    ]
    if is_pm:
        pieces.append(("WallPosZ", (w, HEIGHT, WALL), (0, HEIGHT * 0.5, hd), "wall"))
        return pieces

    half = w * 0.5
    gap_half = DOOR_W * 0.5
    left_len = half - gap_half
    right_len = left_len
    if left_len > 0.05:
        pieces.append(
            ("WallPosZ_Left", (left_len, HEIGHT, WALL), (-half + left_len * 0.5, HEIGHT * 0.5, hd), "wall")
        )
        pieces.append(
            ("WallPosZ_Right", (right_len, HEIGHT, WALL), (half - right_len * 0.5, HEIGHT * 0.5, hd), "wall")
        )
    header_h = HEIGHT - DOOR_H
    if header_h > 0.05:
        pieces.append(
            ("WallPosZ_Header", (DOOR_W, header_h, WALL), (0, DOOR_H + header_h * 0.5, hd), "wall")
        )
    return pieces


def generate_room(name: str, room_id: int, w: float, d: float, is_pm: bool) -> str:
    hd = d * 0.5
    geom = _geom_pieces(w, d, is_pm)
    load_steps = 4 + len(geom) * 2

    parts: list[str] = [
        f"[gd_scene load_steps={load_steps} format=3]",
        "",
        f'[ext_resource type="Script" path="{ROOM_MAP_SCRIPT}" id="1"]',
        f'[ext_resource type="Material" path="{WALL_MAT}" id="2"]',
        f'[ext_resource type="Material" path="{FLOOR_MAT}" id="3"]',
        f'[ext_resource type="Script" path="{SLOT_SCRIPT}" id="4"]',
        "",
    ]

    node_lines: list[str] = []
    for idx, (piece_name, size, pos, kind) in enumerate(geom):
        mesh_id = f"BoxMesh_{idx}"
        shape_id = f"BoxShape_{idx}"
        sx, sy, sz = size
        px, py, pz = pos
        parts.extend(
            [
                f'[sub_resource type="BoxMesh" id="{mesh_id}"]',
                f"size = Vector3({sx}, {sy}, {sz})",
                "",
                f'[sub_resource type="BoxShape3D" id="{shape_id}"]',
                f"size = Vector3({sx}, {sy}, {sz})",
                "",
            ]
        )
        mat_ext = "3" if kind == "floor" else "2"
        node_lines.append(f'[node name="{piece_name}" type="StaticBody3D" parent="Geometry"]')
        node_lines.append(f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {px}, {py}, {pz})")
        node_lines.append("")
        node_lines.append(f'[node name="MeshInstance3D" type="MeshInstance3D" parent="Geometry/{piece_name}"]')
        node_lines.append(f'mesh = SubResource("{mesh_id}")')
        node_lines.append(f"surface_material_override/0 = ExtResource(\"{mat_ext}\")")
        node_lines.append("")
        node_lines.append(f'[node name="CollisionShape3D" type="CollisionShape3D" parent="Geometry/{piece_name}"]')
        node_lines.append(f'shape = SubResource("{shape_id}")')
        node_lines.append("")

    parts.extend(
        [
            f'[node name="{name}" type="Node3D"]',
            'script = ExtResource("1")',
            f"room_id = {room_id}",
        ]
    )
    if is_pm:
        parts.append("is_puppet_master = true")
    parts.extend(
        [
            "",
            '[node name="Geometry" type="Node3D" parent="."]',
            "",
        ]
    )
    parts.extend(node_lines)
    parts.extend(
        [
            '[node name="PlayerSpawn" type="Marker3D" parent="."]',
            f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, {SPAWN_Y}, 0)",
            "",
        ]
    )

    if not is_pm:
        door_y = DOOR_H * 0.5
        escape_z = hd - WALL * 0.5
        attach_z = hd + WALL * 0.5
        parts.extend(
            [
                '[node name="EscapeDoor" type="Marker3D" parent="."]',
                f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, {door_y}, {escape_z})",
                "",
                '[node name="EscapeAttach" type="Marker3D" parent="."]',
                f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, {door_y}, {attach_z})",
                "",
            ]
        )

    parts.extend(['[node name="ItemSpawns" type="Node3D" parent="."]', ""])
    for i, slot in enumerate(_slot_positions(room_id if room_id > 0 else 99, w, d), start=1):
        px, py, pz = slot["pos"]
        nx, ny, nz = slot["normal"]
        surface = slot["surface"]
        rot_y = math.atan2(nx, nz)
        rot_x = math.pi if surface == "ceiling" else 0.0
        parts.append(f'[node name="Slot_{i:02d}" type="Marker3D" parent="ItemSpawns"]')
        parts.append('script = ExtResource("4")')
        parts.append(f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {px}, {py}, {pz})")
        if rot_x != 0.0 or rot_y != 0.0:
            parts.append(f"rotation = Vector3({rot_x}, {rot_y}, 0)")
        parts.append(f"slot_index = {i}")
        parts.append(f'surface_kind = "{surface}"')
        parts.append(f"wall_normal = Vector3({nx}, {ny}, {nz})")
        parts.append("")

    return "\n".join(parts)


def main() -> None:
    out_dir = Path(__file__).resolve().parents[2] / "scenes" / "Rooms"
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, rid, w, d in ROOMS:
        path = out_dir / f"{name}.tscn"
        path.write_text(generate_room(name, rid, w, d, is_pm=False), encoding="utf-8")
        print(f"Wrote {path}")
    pm_name, pm_id, pm_w, pm_d = PM
    pm_path = out_dir / f"{pm_name}.tscn"
    pm_path.write_text(generate_room(pm_name, pm_id, pm_w, pm_d, is_pm=True), encoding="utf-8")
    print(f"Wrote {pm_path}")


if __name__ == "__main__":
    main()
