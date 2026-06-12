"""Tulis import_manifest.json (machine-readable) + IMPORT_GUIDE.md (human).

SPEC §6. Manifest dipakai user untuk mengetik Size & Position di Roblox Studio
Terrain Importer, satu impor per tile.
"""

from __future__ import annotations

import json
import os
from typing import List

from .tiling import Layout, TilePlan

# Material non-Water (aturan SPEC §6). Default seragam; user bisa repaint.
DEFAULT_MATERIAL = "Sandstone"


def _num(value: float) -> float | int:
    """Bulatkan rapi: kembalikan int bila praktis bulat, selain itu float 3 desimal."""
    r = round(float(value), 3)
    if abs(r - round(r)) < 1e-6:
        return int(round(r))
    return r


def build_manifest_dict(cfg, layout: Layout, elev_min_m: float, elev_max_m: float,
                        geo_bounds: dict | None = None) -> dict:
    tiles_out: List[dict] = []
    for t in layout.tiles:
        tiles_out.append(
            {
                "file": t.file,
                "tile_index": {"ix": t.ix, "iz": t.iz},
                "pixels": {"w": t.px_w, "h": t.px_h},
                "pixel_bounds": {"x0": t.x0, "x1": t.x1, "z0": t.z0, "z1": t.z1},
                "size": {"x": _num(t.size_x), "y": _num(t.size_y), "z": _num(t.size_z)},
                "position": {
                    "x": _num(t.position_x),
                    "y": _num(t.position_y),
                    "z": _num(t.position_z),
                },
                "voxels": int(round(t.voxels)),
                "material": DEFAULT_MATERIAL,
            }
        )

    manifest = {
        "generator": "convert_terrain.py (RUH Main Place terrain pipeline)",
        "scale_studs_per_m": _num(cfg.scale_studs_per_m),
        "origin": "center-of-route",
        "flip_z": cfg.flip_z,
        "elevation_min_m": _num(elev_min_m),
        "elevation_max_m": _num(elev_max_m),
        "elevation_delta_m": _num(elev_max_m - elev_min_m),
        "size_y_studs": _num(layout.size_y),
        "position_y_studs": _num(layout.position_y),
        "world_size_studs": {
            "x": _num(layout.size_x_total),
            "z": _num(layout.size_z_total),
        },
        "tiles_x": layout.tiles_x,
        "tiles_z": layout.tiles_z,
        "overlap_px": layout.overlap_px,
        "voxels_per_tile": int(round(layout.voxels_per_tile)),
        "max_tile_voxels": int(round(layout.max_tile_voxels)),
        "voxel_note": (
            "Roblox Terrain Importer membatasi volume satu impor (~jumlah voxel "
            "4x4x4). voxels = (Size.X/4)*(Size.Y/4)*(Size.Z/4) <= max_tile_voxels. "
            "Grid dipilih agar tile sesedikit mungkin namun tetap di bawah budget."
        ),
        "overlap_note": (
            "Tile bersebelahan berbagi overlap_px piksel tepi pada heightmap "
            "(elevasi di garis sambung identik). Size/Position studs dihitung "
            "edge-to-edge dari box & scale (SPEC §4); importer me-resample PNG."
        ),
        "notes": list(layout.warnings),
        "tiles": tiles_out,
    }

    # geo_bounds = extent lon/lat AKTUAL crop (sumber kebenaran untuk OSM->studs).
    if geo_bounds is not None:
        manifest["geo_bounds"] = {
            "lon_min": geo_bounds["lon_min"],
            "lat_min": geo_bounds["lat_min"],
            "lon_max": geo_bounds["lon_max"],
            "lat_max": geo_bounds["lat_max"],
        }
        manifest["geo_note"] = (
            "Petakan OSM lon/lat -> studs: "
            "x = (lon-lon_min)/(lon_max-lon_min)*world_size.x - world_size.x/2; "
            "z = (lat_max-lat)/(lat_max-lat_min)*world_size.z - world_size.z/2 "
            "(balik tanda z bila flip_z=true). Origin di tengah (0,0)."
        )

    return manifest


def write_manifest_json(path: str, manifest: dict) -> None:
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
        f.write("\n")


def write_import_guide(path: str, cfg, layout: Layout, manifest: dict) -> None:
    """Tulis IMPORT_GUIDE.md: satu blok per tile dengan angka persis."""
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)

    lines: List[str] = []
    lines.append("# IMPORT_GUIDE.md — Impor Terrain RUH Main Place ke Roblox Studio\n")
    lines.append(
        "Tool ini menyiapkan heightmap PNG 16-bit + parameter Size/Position. "
        "Pembentukan tanah dilakukan di **Studio Terrain Importer** (bukan via "
        "script). Impor tiap tile satu per satu dengan angka di bawah.\n"
    )

    lines.append("## Ringkasan\n")
    lines.append(f"- Skala: **{manifest['scale_studs_per_m']} studs/m** (seragam semua tile).")
    lines.append(f"- Origin: tengah rute (0,0,0); tile simetris terhadap origin.")
    lines.append(
        f"- Elevasi: **{manifest['elevation_min_m']}–{manifest['elevation_max_m']} m** "
        f"(delta {manifest['elevation_delta_m']} m)."
    )
    lines.append(
        f"- Ukuran dunia: **{manifest['world_size_studs']['x']} x "
        f"{manifest['world_size_studs']['z']} studs**, "
        f"grid **{layout.tiles_x} x {layout.tiles_z}** = "
        f"{layout.tiles_x * layout.tiles_z} tile."
    )
    lines.append(f"- Size Y (relief): **{manifest['size_y_studs']} studs**.")
    lines.append(f"- flip_z: **{cfg.flip_z}**.\n")

    if layout.warnings:
        lines.append("> **Catatan tiling:**")
        for w in layout.warnings:
            lines.append(f"> - {w}")
        lines.append("")

    lines.append("## Langkah Umum (tiap tile)\n")
    lines.append("1. Buka **Terrain Editor → Import** (atau Terrain:ImportHeightmap).")
    lines.append("2. Pilih file PNG tile yang sesuai.")
    lines.append("3. Masukkan **Size X/Y/Z** dan **Position X/Y/Z** persis seperti blok tile.")
    lines.append(
        f"4. Material: gunakan non-air, mis. **{DEFAULT_MATERIAL}** "
        "(boleh Rock di puncak, Sand di dataran). **Jangan Water.**"
    )
    lines.append(
        "5. **Position Y negatif** (= -Size_Y/2) sudah diperhitungkan — jangan diubah, "
        "ini mencegah \"pulau bolong\".")
    lines.append(
        "6. Setelah semua tile masuk, **smooth** sedikit di garis sambung bila perlu "
        "(overlap 1 px sudah meminimalkan jahitan).\n"
    )

    lines.append("## Tile\n")
    for t, m in zip(layout.tiles, manifest["tiles"]):
        lines.append(f"### {m['file']}  (ix={t.ix}, iz={t.iz})\n")
        lines.append(f"- Piksel sumber: {m['pixels']['w']} x {m['pixels']['h']} px")
        lines.append(
            f"- **Size**:  X = `{m['size']['x']}`,  Y = `{m['size']['y']}`,  "
            f"Z = `{m['size']['z']}`  (studs)"
        )
        lines.append(
            f"- **Position**:  X = `{m['position']['x']}`,  Y = `{m['position']['y']}`,  "
            f"Z = `{m['position']['z']}`  (studs)"
        )
        lines.append(f"- Material: `{m['material']}`\n")

    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
