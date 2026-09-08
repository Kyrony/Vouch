# VOUCH semantic maps

These are **placement masks**, not terrain textures. The uploads were titled
infographics; `tools/extract_semantic_masks.py` crops the shared neighborhood
frame and writes 512×512 inputs:

| File | Meaning |
|---|---|
| `building.png` | White = allowed building footprints |
| `building_type.png` | Red mansion, orange family, blue uncle, purple garage, cyan utility |
| `road.png` | White = road corridors (roundabout, loop, branches) |
| `no_spawn.png` | White = nothing spawns (roads + buildings + cliff) |
| `cliff.png` | White = east-only drop-off / hard building ban |
| `vegetation.png` | Density 0–3 in the red channel (0 / 85 / 170 / 255) |
| `map_transform.txt` | Configurable UV→world origin + span |
| `buildings.json` | Blob centroids + types |
| `roads.json` | Skeletonized corridor polylines in world XZ |

Press **F8** in a match to cycle a debug plane over the farm showing each
interpreted layer.

Re-extract after dropping new plates into `source/`:

```
python3 tools/extract_semantic_masks.py
```
