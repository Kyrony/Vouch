#!/usr/bin/env python3
"""Write Godot 4.3 .import sidecars for K7 overlay PNGs.

Filter is Linear at the CanvasItem (Godot 4 removed filter from import).
Mipmaps off. Lossless compress keeps RGBA.
"""

from __future__ import annotations

import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OVERLAYS = ROOT / "hud" / "k7_overlays"

IMPORT_BODY = """[remap]

importer="texture"
type="CompressedTexture2D"
uid="{uid}"
path="{ctex}"
metadata={{
"vram_texture": false
}}

[deps]

source_file="res://{rel}"
dest_files=["{ctex}"]

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
detect_3d/compress_to=0
"""


def write_import(png: Path) -> None:
    rel = png.relative_to(ROOT).as_posix()
    digest = hashlib.md5(rel.encode()).hexdigest()
    uid = "uid://k7" + digest[:10]
    ctex = f"res://.godot/imported/{png.name}-{digest}.ctex"
    text = IMPORT_BODY.format(uid=uid, ctex=ctex, rel=rel)
    sidecar = png.with_name(png.name + ".import")
    sidecar.write_text(text)
    print("import", sidecar.relative_to(ROOT))


def main() -> None:
    if not OVERLAYS.exists():
        raise SystemExit("hud/k7_overlays missing")
    count = 0
    for png in sorted(OVERLAYS.rglob("*.png")):
        write_import(png)
        count += 1
    print(f"wrote {count} .import sidecars (Linear on TextureRect, mipmaps off, lossless RGBA)")


if __name__ == "__main__":
    main()
