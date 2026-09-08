#!/usr/bin/env python3
"""Crop Kyle's infographic semantic maps into production 512x512 masks.

The uploads are titled design plates (navy background, legends, outlines).
This writes clean, terrain-aligned masks under assets/horror/farm/masks/.
"""

from __future__ import annotations

import json
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
UPLOADED = {
    "building": Path("/home/ubuntu/.cursor/projects/workspace/assets/32d460f0-06dc-41c5-9376-916479ceef32.png"),
    "building_type": Path("/home/ubuntu/.cursor/projects/workspace/assets/a096d3b0-cad0-45b1-bf86-357e11e19bff.png"),
    "road": Path("/home/ubuntu/.cursor/projects/workspace/assets/a369ea9e-d856-4078-97f0-2cb1c72ed947.png"),
    "no_spawn": Path("/home/ubuntu/.cursor/projects/workspace/assets/5c6c9988-8bdb-46e0-9e0c-8aae6a5274dc.png"),
    "cliff": Path("/home/ubuntu/.cursor/projects/workspace/assets/8ea8ab75-9aee-44c7-8850-eb9d5157a0f9.png"),
    "vegetation": Path("/home/ubuntu/.cursor/projects/workspace/assets/5c3d291c-03ac-4232-9c03-b61a9f735fd0.png"),
}


def _src_path(key: str) -> Path:
    local = (ROOT / "assets/horror/farm/masks/source" / f"{key}_infographic.png")
    if local.exists():
        return local
    return UPLOADED[key]


SRC = {key: _src_path(key) for key in UPLOADED}
OUT = ROOT / "assets/horror/farm/masks"
SRC_OUT = OUT / "source"
DEBUG = OUT / "_debug"
SIZE = 512


def _navy(r: np.ndarray, g: np.ndarray, b: np.ndarray) -> np.ndarray:
    return (r < 50) & (g < 95) & (b < 140) & (b > g - 5)


def _load_rgb(path: Path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.uint8)


def _content_bbox(rgb: np.ndarray, title_frac: float, footer_frac: float) -> tuple[int, int, int, int]:
    """Inner neighborhood frame — skip title, legend, and full-height side bars."""
    h, w = rgb.shape[:2]
    y0 = int(h * title_frac)
    y1 = int(h * (1.0 - footer_frac))
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    interesting = ~_navy(r, g, b)
    interesting[:y0, :] = False
    interesting[y1:, :] = False
    col = interesting.sum(axis=0)
    row = interesting.sum(axis=1)
    # Side bars in these plates are 1–2px white rules spanning the crop.
    col_ok = (col > 8) & (col < h * 0.72)
    row_ok = (row > 8) & (row < w * 0.72)
    xs = np.where(col_ok)[0]
    ys = np.where(row_ok)[0]
    if xs.size == 0 or ys.size == 0:
        ys, xs = np.where(interesting)
    pad = 6
    return (
        max(0, int(xs.min()) - pad),
        max(y0, int(ys.min()) - pad),
        min(w - 1, int(xs.max()) + pad),
        min(y1 - 1, int(ys.max()) + pad),
    )


def _crop(rgb: np.ndarray, box: tuple[int, int, int, int]) -> np.ndarray:
    x0, y0, x1, y1 = box
    return rgb[y0 : y1 + 1, x0 : x1 + 1]


def _resize(arr: np.ndarray) -> np.ndarray:
    im = Image.fromarray(arr)
    return np.asarray(im.resize((SIZE, SIZE), Image.Resampling.NEAREST), dtype=np.uint8)


def _binary_from(rgb: np.ndarray, pred) -> np.ndarray:
    mask = pred(rgb[..., 0], rgb[..., 1], rgb[..., 2])
    out = np.zeros((SIZE, SIZE, 3), dtype=np.uint8)
    out[mask] = (255, 255, 255)
    return out


def _is_building(r, g, b):
    return (r > 170) & (g < 140) & (b < 160) & (r > g + 40)


def _is_road(r, g, b):
    # Thick white corridors only — not faint cyan outlines.
    return (r > 210) & (g > 210) & (b > 210) & (np.abs(r.astype(int) - b.astype(int)) < 25)


def _is_nospawn(r, g, b):
    # Light grey exclusion + leftover white roads/buildings.
    grey = (r > 110) & (g > 110) & (b > 110) & (np.abs(r.astype(int) - g.astype(int)) < 30)
    return grey | _is_road(r, g, b) | _is_building(r, g, b)


def _is_cliff(r, g, b):
    return (r > 160) & (g > 150) & (b < 90) & (r + g > 2 * b + 80)


def _veg_level(r, g, b) -> np.ndarray:
    """0 none, 1 sparse, 2 medium, 3 dense from the green/yellow key."""
    out = np.zeros(r.shape, dtype=np.uint8)
    # White roads / building cutouts / navy → 0
    none = _navy(r, g, b) | ((r > 200) & (g > 200) & (b > 200))
    green = (g > r + 15) & (g > b - 10) & (g > 50)
    # Brightness of green channel + yellow shift
    score = g.astype(np.float32) + 0.35 * r.astype(np.float32)
    out[green & (score < 140)] = 1
    out[green & (score >= 140) & (score < 210)] = 2
    out[green & (score >= 210)] = 3
    # Yellow-green dense (legend 3)
    yellow = (r > 140) & (g > 160) & (b < 90)
    out[yellow] = 3
    out[none] = 0
    return out


def _type_rgb(r, g, b) -> np.ndarray:
    """Encode building types as stable RGB so Godot can classify without guessing."""
    h, w = r.shape
    out = np.zeros((h, w, 3), dtype=np.uint8)
    # mansion red
    mansion = (r > 180) & (g < 110) & (b < 130)
    # family orange
    family = (r > 180) & (g > 90) & (g < 200) & (b < 100) & (r > g)
    # uncle blue
    uncle = (b > 160) & (r < 90) & (g < 170) & (b > g)
    # garage purple
    garage = (r > 90) & (b > 160) & (g < 90)
    # utility cyan
    utility = (b > 160) & (g > 130) & (r < 80) & (g > r)
    out[mansion] = (220, 40, 50)
    out[family] = (240, 150, 50)
    out[uncle] = (30, 110, 240)
    out[garage] = (150, 40, 230)
    out[utility] = (10, 190, 220)
    return out


def _connected(mask: np.ndarray) -> list[dict]:
    h, w = mask.shape
    seen = np.zeros_like(mask, dtype=np.uint8)
    blobs = []
    for y in range(h):
        for x in range(w):
            if not mask[y, x] or seen[y, x]:
                continue
            q = deque([(x, y)])
            seen[y, x] = 1
            cells = []
            sx = sy = 0
            while q:
                cx, cy = q.popleft()
                cells.append((cx, cy))
                sx += cx
                sy += cy
                for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                    if 0 <= nx < w and 0 <= ny < h and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = 1
                        q.append((nx, ny))
            if len(cells) < 20:
                continue
            blobs.append({
                "n": len(cells),
                "cx": sx / len(cells),
                "cy": sy / len(cells),
            })
    blobs.sort(key=lambda b: -b["n"])
    return blobs


def _thin(binary: np.ndarray) -> np.ndarray:
    """Zhang-Suen thinning on a bool array."""
    img = binary.astype(np.uint8)
    changed = True
    while changed:
        changed = False
        for step in (0, 1):
            to_clear = []
            h, w = img.shape
            for y in range(1, h - 1):
                for x in range(1, w - 1):
                    if img[y, x] == 0:
                        continue
                    p2, p3, p4 = img[y - 1, x], img[y - 1, x + 1], img[y, x + 1]
                    p5, p6, p7 = img[y + 1, x + 1], img[y + 1, x], img[y + 1, x - 1]
                    p8, p9 = img[y, x - 1], img[y - 1, x - 1]
                    nbr = [p2, p3, p4, p5, p6, p7, p8, p9]
                    b = int(sum(nbr))
                    if b < 2 or b > 6:
                        continue
                    a = 0
                    for i in range(8):
                        if nbr[i] == 0 and nbr[(i + 1) % 8] == 1:
                            a += 1
                    if a != 1:
                        continue
                    if step == 0 and p2 * p4 * p6 != 0:
                        continue
                    if step == 0 and p4 * p6 * p8 != 0:
                        continue
                    if step == 1 and p2 * p4 * p8 != 0:
                        continue
                    if step == 1 and p2 * p6 * p8 != 0:
                        continue
                    to_clear.append((y, x))
            if to_clear:
                changed = True
                for y, x in to_clear:
                    img[y, x] = 0
    return img.astype(bool)


def _trace_roads(road: np.ndarray, origin: tuple[float, float], span: tuple[float, float]) -> list[list[list[float]]]:
    """Skeletonize the white corridors and emit world-XZ polylines."""
    small = np.array(Image.fromarray((road.astype(np.uint8) * 255)).resize((160, 160), Image.Resampling.NEAREST)) > 127
    skel = _thin(small)
    h, w = skel.shape
    used = np.zeros_like(skel, dtype=np.uint8)

    def neighbors(x: int, y: int) -> list[tuple[int, int]]:
        out = []
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dx == 0 and dy == 0:
                    continue
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and skel[ny, nx]:
                    out.append((nx, ny))
        return out

    def to_world(x: int, y: int) -> list[float]:
        u = x / (w - 1)
        v = y / (h - 1)
        return [round(origin[0] + u * span[0], 2), round(origin[1] + v * span[1], 2)]

    def walk(start: tuple[int, int]) -> list[list[float]]:
        path = [start]
        used[start[1], start[0]] = 1
        cur = start
        while True:
            opts = [n for n in neighbors(*cur) if not used[n[1], n[0]]]
            if not opts:
                break
            nxt = min(opts, key=lambda n: (n[0] - cur[0]) ** 2 + (n[1] - cur[1]) ** 2)
            used[nxt[1], nxt[0]] = 1
            path.append(nxt)
            cur = nxt
        return [to_world(x, y) for x, y in path]

    lines: list[list[list[float]]] = []
    endpoints = []
    junctions = []
    for y in range(h):
        for x in range(w):
            if not skel[y, x]:
                continue
            deg = len(neighbors(x, y))
            if deg == 1:
                endpoints.append((x, y))
            elif deg != 2:
                junctions.append((x, y))
    for pt in endpoints + junctions:
        if used[pt[1], pt[0]]:
            continue
        line = walk(pt)
        if len(line) >= 3:
            lines.append(line)
    for y in range(h):
        for x in range(w):
            if skel[y, x] and not used[y, x]:
                line = walk((x, y))
                if len(line) >= 3:
                    lines.append(line)
    return lines


def _kind_from_rgb(rgb: tuple[int, int, int]) -> str:
    r, g, b = rgb
    if r > 180 and g < 80:
        return "mansion"
    if r > 180 and 80 <= g < 200:
        return "family"
    if b > 160 and g > 140 and r < 80:
        return "utility"
    if r > 80 and b > 180 and g < 100:
        return "garage"
    if b > 180 and r < 80:
        return "uncle"
    return "unknown"


def _family_targets(fam: list[dict]) -> list[tuple[dict, tuple[float, float]]]:
    """West column north→south = A,B,C; remaining orange = D."""
    if not fam:
        return []
    fam = list(fam)
    fam.sort(key=lambda b: b["u"])
    west = fam[:3]
    rest = fam[3:]
    west.sort(key=lambda b: b["v"])
    targets = [(-38.0, -18.0), (-38.0, 2.0), (-38.0, 24.0)]
    out = list(zip(west, targets))
    rest.sort(key=lambda b: (b["v"], b["u"]))
    if rest:
        out.append((rest[0], (-14.0, 24.0)))
    return out


def _fit_transform(blobs: list[dict]) -> tuple[tuple[float, float], tuple[float, float]]:
    """Axis-aligned UV→world fit onto Kyle pad centroids. Utility is not a pad."""
    pairs: list[tuple[tuple[float, float], tuple[float, float]]] = []
    for blob in blobs:
        uv = (blob["u"], blob["v"])
        if blob["kind"] == "mansion":
            pairs.append((uv, (22.0, -6.0)))
        elif blob["kind"] == "uncle":
            pairs.append((uv, (16.0, -28.0)))
        elif blob["kind"] == "garage":
            pairs.append((uv, (28.0, -28.0)))
    for blob, tgt in _family_targets([b for b in blobs if b["kind"] == "family"]):
        pairs.append(((blob["u"], blob["v"]), tgt))
    if len(pairs) < 3:
        return (-72.0, -60.0), (144.0, 120.0)
    us = np.array([p[0][0] for p in pairs], dtype=np.float64)
    vs = np.array([p[0][1] for p in pairs], dtype=np.float64)
    xs = np.array([p[1][0] for p in pairs], dtype=np.float64)
    zs = np.array([p[1][1] for p in pairs], dtype=np.float64)
    span_x, origin_x = [float(v) for v in np.polyfit(us, xs, 1)]
    span_z, origin_z = [float(v) for v in np.polyfit(vs, zs, 1)]
    print("correspondences:")
    for (u, v), (x, z) in pairs:
        px, pz = origin_x + u * span_x, origin_z + v * span_z
        print(f"  uv=({u:.3f},{v:.3f}) -> want ({x:6.1f},{z:6.1f}) got ({px:6.1f},{pz:6.1f})")
    return (origin_x, origin_z), (span_x, span_z)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    SRC_OUT.mkdir(parents=True, exist_ok=True)
    DEBUG.mkdir(parents=True, exist_ok=True)

    raw = {k: _load_rgb(p) for k, p in SRC.items()}
    for k, p in SRC.items():
        dest = SRC_OUT / f"{k}_infographic.png"
        dest.write_bytes(p.read_bytes())

    # One shared normalized frame so every mask lines up on the same neighborhood.
    ref = raw["building"]
    ref_box = _content_bbox(ref, 0.145, 0.035)
    rh, rw = ref.shape[:2]
    u0, v0 = ref_box[0] / rw, ref_box[1] / rh
    u1, v1 = ref_box[2] / rw, ref_box[3] / rh
    print(f"shared UV frame u={u0:.3f}..{u1:.3f} v={v0:.3f}..{v1:.3f}")

    crops = {}
    for key, rgb in raw.items():
        h, w = rgb.shape[:2]
        box = (
            int(round(u0 * w)),
            int(round(v0 * h)),
            int(round(u1 * w)),
            int(round(v1 * h)),
        )
        crops[key] = _resize(_crop(rgb, box))
        print(f"{key:14} raw={w}x{h} crop={box}")

    building = _binary_from(crops["building"], _is_building)
    road = _binary_from(crops["road"], _is_road)
    nospawn = _binary_from(crops["no_spawn"], _is_nospawn)
    cliff = _binary_from(crops["cliff"], _is_cliff)
    # Cliff is east-only: zero anything on the left 62% so a wrap-around never appears.
    cliff[:, : int(SIZE * 0.62)] = 0
    types = _type_rgb(crops["building_type"][..., 0], crops["building_type"][..., 1], crops["building_type"][..., 2])
    veg_lv = _veg_level(crops["vegetation"][..., 0], crops["vegetation"][..., 1], crops["vegetation"][..., 2])
    veg = np.zeros((SIZE, SIZE, 3), dtype=np.uint8)
    veg[veg_lv == 1] = (20, 90, 20)
    veg[veg_lv == 2] = (80, 190, 20)
    veg[veg_lv == 3] = (210, 230, 20)
    # Encode density in red as 0/85/170/255 for cheap Godot sampling.
    veg[..., 0] = veg_lv * 85

    # Roads and buildings are also no-spawn.
    nospawn[(road[..., 0] > 200) | (building[..., 0] > 200) | (cliff[..., 0] > 200)] = 255

    outputs = {
        "building.png": building,
        "road.png": road,
        "no_spawn.png": nospawn,
        "cliff.png": cliff,
        "building_type.png": types,
        "vegetation.png": veg,
    }
    for name, arr in outputs.items():
        Image.fromarray(arr, "RGB").save(OUT / name)
        print("wrote", name, arr.shape, "lit", int((arr.max(axis=2) > 20).sum()))

    bmask = building[..., 0] > 200
    blobs = _connected(bmask)
    print(f"building blobs: {len(blobs)}")
    classified = []
    for i, blob in enumerate(blobs):
        u, v = blob["cx"] / (SIZE - 1), blob["cy"] / (SIZE - 1)
        ty = tuple(int(c) for c in types[int(blob["cy"]), int(blob["cx"])])
        kind = _kind_from_rgb(ty)
        classified.append({**blob, "u": u, "v": v, "kind": kind, "type_rgb": ty})
        print(f"  blob{i} n={blob['n']:5} uv=({u:.3f},{v:.3f}) kind={kind:8} type_rgb={ty}")
    origin, span = _fit_transform(classified)
    print(f"fitted origin=({origin[0]:.2f},{origin[1]:.2f}) span=({span[0]:.2f},{span[1]:.2f})")
    (OUT / "map_transform.txt").write_text(
        "origin_x=%.4f\norigin_z=%.4f\nspan_x=%.4f\nspan_z=%.4f\n"
        % (origin[0], origin[1], span[0], span[1])
    )
    buildings = []
    for blob in classified:
        x = origin[0] + blob["u"] * span[0]
        z = origin[1] + blob["v"] * span[1]
        buildings.append({
            "kind": blob["kind"],
            "u": round(blob["u"], 4),
            "v": round(blob["v"], 4),
            "x": round(x, 3),
            "z": round(z, 3),
            "pixels": int(blob["n"]),
        })
    (OUT / "buildings.json").write_text(json.dumps(buildings, indent=2) + "\n")
    polylines = _trace_roads(road[..., 0] > 200, origin, span)
    (OUT / "roads.json").write_text(json.dumps(polylines, indent=2) + "\n")
    print(f"buildings.json={len(buildings)} roads.json={len(polylines)} spans")

    # Debug atlas so Kyle can see interpretation.
    atlas = Image.new("RGB", (SIZE * 3, SIZE * 2), (8, 12, 20))
    labels = [
        (0, 0, "building", building),
        (1, 0, "road", road),
        (2, 0, "no_spawn", nospawn),
        (0, 1, "cliff", cliff),
        (1, 1, "building_type", types),
        (2, 1, "vegetation", veg),
    ]
    draw = ImageDraw.Draw(atlas)
    for cx, cy, label, arr in labels:
        atlas.paste(Image.fromarray(arr, "RGB"), (cx * SIZE, cy * SIZE))
        draw.text((cx * SIZE + 10, cy * SIZE + 8), label, fill=(255, 255, 255))
    atlas.save(DEBUG / "interpreted_atlas.png")
    print("debug atlas", DEBUG / "interpreted_atlas.png")


if __name__ == "__main__":
    main()
