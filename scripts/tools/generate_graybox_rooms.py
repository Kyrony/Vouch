#!/usr/bin/env python3
"""Generate hand-sealed graybox Room_XX.tscn files (friends-MVP set)."""

from __future__ import annotations

import math
from pathlib import Path

WALL = 0.12
HEIGHT = 2.4
DOOR_W = 0.85
DOOR_H = 2.05

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
    """Mirror GrayboxLayouts._slot_layout deterministically."""
    rng_seed = room_id * 104729 + 17
    # Simple LCG matching Godot's seed behavior enough for fixed positions
    state = rng_seed & 0xFFFFFFFF

    def randf() -> float:
        nonlocal state
        state = (state * 1664525 + 1013904223) & 0xFFFFFFFF
        return state / 0xFFFFFFFF

    hw = w * 0.5 - 0.5
    hd = d * 0.5 - 0.5
    flush = 0.08
    slots: list[dict] = []

    slots.append(
        {
            "pos": (randf() * hw * 0.7 - hw * 0.35, 0.0, hd - flush),
            "surface": "wall_floor",
            "normal": (0, 0, -1),
        }
    )
    slots.append(
        {
            "pos": (
                randf() * hw * 0.5 - hw * 0.25,
                HEIGHT - 0.12,
                randf() * hd * 0.5 - hd * 0.25,
            ),
            "surface": "ceiling",
            "normal": (0, -1, 0),
        }
    )

    wall_heights = [1.25, 1.15, 1.45, 1.1, 0.95, 1.0, 1.35, 1.2]
    faces = ["s", "s", "e", "w", "n", "e", "w", "n"]
    for i, face in enumerate(faces):
        t = 0.22 + randf() * 0.56
        h = wall_heights[i]
        if face == "s":
            pos = (-hw + (hw * 2) * t, h, hd - flush)
            normal = (0, 0, -1)
        elif face == "n":
            pos = (-hw + (hw * 2) * t, h, -hd + flush)
            normal = (0, 0, 1)
        elif face == "e":
            pos = (hw - flush, h, -hd + (hd * 2) * t)
            normal = (-1, 0, 0)
        else:
            pos = (-hw + flush, h, -hd + (hd * 2) * t)
            normal = (1, 0, 0)
        slots.append({"pos": pos, "surface": "wall", "normal": normal})

    for _ in range(6):
        slots.append(
            {
                "pos": (
                    randf() * hw * 1.1 - hw * 0.55,
                    0.0,
                    randf() * hd * 1.1 - hd * 0.55,
                ),
                "surface": "floor",
                "normal": (0, 1, 0),
            }
        )

    return slots


def _wall_segments(span: float, gap_w: float, gap_center: float) -> list[tuple[float, float]]:
    half = span * 0.5
    seg1 = (gap_center - gap_w * 0.5) - (-half)
    seg2 = half - (gap_center + gap_w * 0.5)
    out: list[tuple[float, float]] = []
    if seg1 > 0.05:
        c1 = -half + seg1 * 0.5
        out.append((seg1, c1))
    if seg2 > 0.05:
        c2 = gap_center + gap_w * 0.5 + seg2 * 0.5
        out.append((seg2, c2))
    return out


def _box_nodes(parent: str, name: str, size: tuple, pos: tuple, mat: str, idx: int) -> list[str]:
    sx, sy, sz = size
    px, py, pz = pos
    mesh_id = f"BoxMesh_{idx}"
    shape_id = f"BoxShape_{idx}"
    lines = [
        f'[sub_resource type="BoxMesh" id="{mesh_id}"]',
        f"size = Vector3({sx}, {sy}, {sz})",
        "",
        f'[sub_resource type="BoxShape3D" id="{shape_id}"]',
        f"size = Vector3({sx}, {sy}, {sz})",
        "",
        f'[node name="{name}" type="StaticBody3D" parent="{parent}"]',
        f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {px}, {py}, {pz})",
        "",
        f'[node name="MeshInstance3D" type="MeshInstance3D" parent="{parent}/{name}"]',
        f'mesh = SubResource("{mesh_id}")',
        f"surface_material_override/0 = ExtResource(\"2\")",
        "",
        f'[node name="CollisionShape3D" type="CollisionShape3D" parent="{parent}/{name}"]',
        f'shape = SubResource("{shape_id}")',
        "",
    ]
    return lines


def generate_room(name: str, room_id: int, w: float, d: float, is_pm: bool) -> str:
    hw = w * 0.5
    hd = d * 0.5
    lines: list[str] = []
    sub_idx = 0

    ext_count = 3
    lines.append(f"[gd_scene load_steps={ext_count} format=3]")
    lines.append("")
    lines.append(f'[ext_resource type="Script" path="{ROOM_MAP_SCRIPT}" id="1"]')
    lines.append(f'[ext_resource type="Material" path="{WALL_MAT}" id="2"]')
    lines.append(f'[ext_resource type="Material" path="{FLOOR_MAT}" id="3"]')
    lines.append("")

    # Collect geometry pieces first (subresources inserted before nodes)
    geom_pieces: list[tuple[str, tuple, tuple, str]] = []

    # Floor
    geom_pieces.append(("Floor", (w, WALL, d), (0, -WALL * 0.5, 0), "floor"))
    # Ceiling (no collision)
    geom_pieces.append(("Ceiling", (w, WALL, d), (0, HEIGHT + WALL * 0.5, 0), "ceil"))

    # North wall (full, no door)
    geom_pieces.append(("WallNorth", (w, HEIGHT, WALL), (0, HEIGHT * 0.5, -hd), "wall"))
    # East wall
    geom_pieces.append(("WallEast", (WALL, HEIGHT, d), (hw, HEIGHT * 0.5, 0), "wall"))
    # West wall
    geom_pieces.append(("WallWest", (WALL, HEIGHT, d), (-hw, HEIGHT * 0.5, 0), "wall"))

    # South wall with door gap
    for i, (seg_len, center) in enumerate(_wall_segments(w, DOOR_W, 0.0)):
        geom_pieces.append(
            (f"WallSouth_{i}", (seg_len, HEIGHT, WALL), (center, HEIGHT * 0.5, hd), "wall")
        )
    lintel_h = HEIGHT - DOOR_H
    if lintel_h > 0.05:
        geom_pieces.append(
            ("WallSouth_Lintel", (DOOR_W, lintel_h, WALL), (0, DOOR_H + lintel_h * 0.5, hd), "wall")
        )

    # Write subresources and nodes
    node_lines: list[str] = []
    for piece_name, size, pos, kind in geom_pieces:
        mesh_id = f"BoxMesh_{sub_idx}"
        shape_id = f"BoxShape_{sub_idx}"
        sx, sy, sz = size
        px, py, pz = pos
        lines.extend(
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
        collision = kind != "ceil"
        node_lines.append(f'[node name="{piece_name}" type="StaticBody3D" parent="Geometry"]')
        node_lines.append(
            f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {px}, {py}, {pz})"
        )
        node_lines.append("")
        node_lines.append(f'[node name="MeshInstance3D" type="MeshInstance3D" parent="Geometry/{piece_name}"]')
        node_lines.append(f'mesh = SubResource("{mesh_id}")')
        node_lines.append(f"surface_material_override/0 = ExtResource(\"{mat_ext}\")")
        node_lines.append("")
        if collision:
            node_lines.append(
                f'[node name="CollisionShape3D" type="CollisionShape3D" parent="Geometry/{piece_name}"]'
            )
            node_lines.append(f'shape = SubResource("{shape_id}")')
            node_lines.append("")
        sub_idx += 1

    lines.extend(node_lines)

    # Root
    lines.append(f'[node name="{name}" type="Node3D"]')
    lines.append("script = ExtResource(\"1\")")
    lines.append(f"room_id = {room_id}")
    if is_pm:
        lines.append("is_puppet_master = true")
    lines.append("")

    lines.append('[node name="Geometry" type="Node3D" parent="."]')
    lines.append("")

    lines.append('[node name="PlayerSpawn" type="Marker3D" parent="."]')
    lines.append("transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.1, 0)")
    lines.append("")

    if not is_pm:
        escape_z = hd - WALL
        corridor_z = hd + 0.15
        lines.append('[node name="EscapeDoor" type="Marker3D" parent="."]')
        lines.append(
            f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.025, {escape_z})"
        )
        lines.append("")
        lines.append('[node name="EscapeAttach" type="Marker3D" parent="."]')
        lines.append(
            f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.025, {corridor_z})"
        )
        lines.append("")

    # Item spawn slots
    lines.append('[node name="ItemSpawns" type="Node3D" parent="."]')
    lines.append("")
    slots = _slot_positions(room_id if room_id > 0 else 99, w, d)
    for i, slot in enumerate(slots[:16], start=1):
        px, py, pz = slot["pos"]
        nx, ny, nz = slot["normal"]
        surface = slot["surface"]
        rot_y = math.atan2(nx, nz)
        rot_x = math.pi if surface == "ceiling" else 0.0
        lines.append(f'[node name="Slot_{i:02d}" type="Marker3D" parent="ItemSpawns"]')
        lines.append(f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {px}, {py}, {pz})")
        lines.append(f"script = ExtResource(\"1\")")
        # Fix: slot needs item_spawn_slot script - add as ext resource
        lines[-1] = f"rotation = Vector3({rot_x}, {rot_y}, 0)"
        lines.append(f"slot_index = {i}")
        lines.append(f'surface_kind = "{surface}"')
        lines.append(f"wall_normal = Vector3({nx}, {ny}, {nz})")
        lines.append("")

    return "\n".join(lines)


def generate_room_fixed(name: str, room_id: int, w: float, d: float, is_pm: bool) -> str:
    """Generate with correct ext resources including slot script."""
    hw = w * 0.5
    hd = d * 0.5
    parts: list[str] = []

    # Count subresources
    geom_count = 6 + len(_wall_segments(w, DOOR_W, 0.0))  # floor ceil 3 walls + south segments
    if HEIGHT - DOOR_H > 0.05:
        geom_count += 1
    load_steps = 4 + geom_count * 2  # 2 subresources per geom piece

    parts.append(f"[gd_scene load_steps={load_steps} format=3]")
    parts.append("")
    parts.append(f'[ext_resource type="Script" path="{ROOM_MAP_SCRIPT}" id="1"]')
    parts.append(f'[ext_resource type="Material" path="{WALL_MAT}" id="2"]')
    parts.append(f'[ext_resource type="Material" path="{FLOOR_MAT}" id="3"]')
    parts.append(f'[ext_resource type="Script" path="{SLOT_SCRIPT}" id="4"]')
    parts.append("")

    sub_idx = 0
    geom_pieces: list[tuple[str, tuple, tuple, str]] = []
    geom_pieces.append(("Floor", (w, WALL, d), (0, -WALL * 0.5, 0), "floor"))
    geom_pieces.append(("Ceiling", (w, WALL, d), (0, HEIGHT + WALL * 0.5, 0), "ceil"))
    geom_pieces.append(("WallNorth", (w, HEIGHT, WALL), (0, HEIGHT * 0.5, -hd), "wall"))
    geom_pieces.append(("WallEast", (WALL, HEIGHT, d), (hw, HEIGHT * 0.5, 0), "wall"))
    geom_pieces.append(("WallWest", (WALL, HEIGHT, d), (-hw, HEIGHT * 0.5, 0), "wall"))
    for i, (seg_len, center) in enumerate(_wall_segments(w, DOOR_W, 0.0)):
        geom_pieces.append((f"WallSouth_{i}", (seg_len, HEIGHT, WALL), (center, HEIGHT * 0.5, hd), "wall"))
    lintel_h = HEIGHT - DOOR_H
    if lintel_h > 0.05:
        geom_pieces.append(
            ("WallSouth_Lintel", (DOOR_W, lintel_h, WALL), (0, DOOR_H + lintel_h * 0.5, hd), "wall")
        )

    node_section: list[str] = []
    for piece_name, size, pos, kind in geom_pieces:
        mesh_id = f"BoxMesh_{sub_idx}"
        shape_id = f"BoxShape_{sub_idx}"
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
        node_section.append(f'[node name="{piece_name}" type="StaticBody3D" parent="Geometry"]')
        node_section.append(
            f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {px}, {py}, {pz})"
        )
        node_section.append("")
        node_section.append(
            f'[node name="MeshInstance3D" type="MeshInstance3D" parent="Geometry/{piece_name}"]'
        )
        node_section.append(f'mesh = SubResource("{mesh_id}")')
        node_section.append(f"surface_material_override/0 = ExtResource(\"{mat_ext}\")")
        node_section.append("")
        if kind != "ceil":
            node_section.append(
                f'[node name="CollisionShape3D" type="CollisionShape3D" parent="Geometry/{piece_name}"]'
            )
            node_section.append(f'shape = SubResource("{shape_id}")')
            node_section.append("")
        sub_idx += 1

    parts.append(f'[node name="{name}" type="Node3D"]')
    parts.append('script = ExtResource("1")')
    parts.append(f"room_id = {room_id}")
    if is_pm:
        parts.append("is_puppet_master = true")
    parts.append("")
    parts.append('[node name="Geometry" type="Node3D" parent="."]')
    parts.append("")
    parts.extend(node_section)
    parts.append('[node name="PlayerSpawn" type="Marker3D" parent="."]')
    spawn_z = hd - 1.8
    parts.append(f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.1, {spawn_z})")
    parts.append("")

    if not is_pm:
        escape_z = hd - WALL
        corridor_z = hd + 0.15
        parts.append('[node name="EscapeDoor" type="Marker3D" parent="."]')
        parts.append(
            f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.025, {escape_z})"
        )
        parts.append("")
        parts.append('[node name="EscapeAttach" type="Marker3D" parent="."]')
        parts.append(
            f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.025, {corridor_z})"
        )
        parts.append("")

    parts.append('[node name="ItemSpawns" type="Node3D" parent="."]')
    parts.append("")
    slots = _slot_positions(room_id if room_id > 0 else 99, w, d)
    for i, slot in enumerate(slots[:16], start=1):
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
        path.write_text(generate_room_fixed(name, rid, w, d, is_pm=False), encoding="utf-8")
        print(f"Wrote {path}")

    pm_name, pm_id, pm_w, pm_d = PM
    pm_path = out_dir / f"{pm_name}.tscn"
    pm_path.write_text(generate_room_fixed(pm_name, pm_id, pm_w, pm_d, is_pm=True), encoding="utf-8")
    print(f"Wrote {pm_path}")


if __name__ == "__main__":
    main()
