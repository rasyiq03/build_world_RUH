#!/usr/bin/env python3
"""roads_to_colormap.py — osm_roads.json -> Colormap PNG per-tile (auto-paint Aspal).

Kenapa colormap, bukan Part: satu zona kota bisa punya belasan ribu segmen jalan.
Sebagai Part itu meledakkan instance (file place + lag). Colormap = 0 Part: Roblox
Terrain Importer mengecat material otomatis dari warna gambar saat (re-)import.

Selaras 1:1 dengan heightmap: tiap tile heightmap punya colormap berdimensi SAMA,
menutup piksel yang SAMA (dibaca dari import_manifest.json). Background = warna Pasir
(-> material Sand), garis jalan = warna Aspal (-> material Ground/Asphalt).

Pemakaian:
  python roads_to_colormap.py --zone B_Mina
  python roads_to_colormap.py --zone B_Mina --min-class tertiary   # buang jalan kecil

Impor di Studio: re-import tiap tile heightmap SEKALIGUS colormap-nya (Heightmap +
Colormap di dialog Import), map warna Pasir->Sand, Aspal->Ground/Asphalt.
"""

from __future__ import annotations

import argparse
import json
import os
import sys

# Warna (RGB) -> nanti dipetakan ke material di dialog Import Studio.
COLOR_SAND = (196, 184, 160)     # latar -> Sand
COLOR_ASPHALT = (70, 70, 70)     # jalan -> Ground/Asphalt

# Lebar garis (studs) per kelas jalan. Dikonversi ke piksel via studs/piksel tile.
CLASS_WIDTH_STUDS = {
    "motorway": 32, "trunk": 28, "primary": 24, "secondary": 20, "tertiary": 16,
    "residential": 12, "unclassified": 12, "service": 8, "living_street": 10,
    "pedestrian": 8, "footway": 5, "steps": 4, "path": 4, "track": 6,
    "motorway_link": 16, "trunk_link": 16, "primary_link": 14, "secondary_link": 12,
    "tertiary_link": 10, "road": 12, "construction": 8, "rest_area": 10,
}
DEFAULT_WIDTH_STUDS = 10

# Urutan kelas (untuk --min-class: buang yang lebih kecil dari ambang).
CLASS_ORDER = [
    "motorway", "trunk", "primary", "secondary", "tertiary",
    "residential", "unclassified", "living_street", "service",
    "pedestrian", "footway", "track", "path", "steps",
]


def _rank(cls: str) -> int:
    base = cls.replace("_link", "")
    return CLASS_ORDER.index(base) if base in CLASS_ORDER else len(CLASS_ORDER)


def load(zone_dir: str):
    mpath = os.path.join(zone_dir, "import_manifest.json")
    rpath = os.path.join(zone_dir, "osm_roads.json")
    for p in (mpath, rpath):
        if not os.path.isfile(p):
            raise SystemExit(f"ERROR: tak ada '{p}'. Jalankan convert_terrain.py & generate_osm.py dulu.")
    with open(mpath, encoding="utf-8") as f:
        manifest = json.load(f)
    with open(rpath, encoding="utf-8") as f:
        roads = json.load(f)
    return manifest, roads


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="osm_roads.json -> colormap PNG per tile.")
    g = p.add_mutually_exclusive_group(required=True)
    g.add_argument("--zone", help="Nama zona (folder output/<zona>/).")
    g.add_argument("--zone-dir", help="Path folder zona langsung.")
    p.add_argument("--min-class", default=None,
                   help="Buang jalan lebih kecil dari kelas ini (mis. tertiary).")
    p.add_argument("--width-scale", type=float, default=1.0, help="Skala lebar jalan.")
    args = p.parse_args(argv)

    try:
        from PIL import Image, ImageDraw
    except ImportError:
        raise SystemExit("ERROR: butuh Pillow. Jalankan: pip install pillow")

    zone_dir = args.zone_dir or os.path.join("output", args.zone)
    manifest, roads_doc = load(zone_dir)

    size_x = float(manifest["world_size_studs"]["x"])
    size_z = float(manifest["world_size_studs"]["z"])
    flip_z = bool(manifest.get("flip_z", False))
    tiles = manifest["tiles"]
    # Dimensi piksel zona penuh = batas piksel maksimum antar-tile.
    W = max(t["pixel_bounds"]["x1"] for t in tiles)
    H = max(t["pixel_bounds"]["z1"] for t in tiles)
    px_per_stud_x = W / size_x
    px_per_stud_z = H / size_z

    roads = roads_doc.get("roads", [])
    if args.min_class:
        thr = _rank(args.min_class)
        roads = [r for r in roads if _rank(r["type"]) <= thr]

    # Kanvas zona penuh (latar pasir), gambar semua jalan, lalu potong per tile.
    canvas = Image.new("RGB", (W, H), COLOR_SAND)
    draw = ImageDraw.Draw(canvas)

    def to_px(pt):
        # studs (origin tengah) -> piksel kanvas. col0=barat(-X), row0=utara(-Z).
        col = (pt["x"] + size_x / 2.0) / size_x * W
        frac_z = (pt["z"] + size_z / 2.0) / size_z      # 0 utara .. 1 selatan
        if flip_z:
            frac_z = 1.0 - frac_z
        return (col, frac_z * H)

    drawn = 0
    for r in roads:
        path = r.get("path", [])
        if len(path) < 2:
            continue
        w_studs = CLASS_WIDTH_STUDS.get(r["type"], DEFAULT_WIDTH_STUDS) * args.width_scale
        w_px = max(1, round(w_studs * px_per_stud_x))
        pts = [to_px(pt) for pt in path]
        draw.line(pts, fill=COLOR_ASPHALT, width=w_px, joint="curve")
        # Bulatkan ujung/sendi supaya tidak putus-putus.
        rad = w_px / 2.0
        for (cx, cy) in pts:
            draw.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=COLOR_ASPHALT)
        drawn += 1

    # Potong per tile (dimensi & piksel SAMA dgn heightmap tile).
    out = []
    for t in tiles:
        b = t["pixel_bounds"]
        crop = canvas.crop((b["x0"], b["z0"], b["x1"], b["z1"]))
        cm_name = t["file"].replace(".png", "_colormap.png")
        cm_path = os.path.join(zone_dir, cm_name)
        # Validasi dimensi cocok dgn heightmap tile.
        if crop.size != (t["pixels"]["w"], t["pixels"]["h"]):
            raise SystemExit(
                f"ERROR: colormap {crop.size} != heightmap {(t['pixels']['w'], t['pixels']['h'])} "
                f"untuk {t['file']}."
            )
        crop.save(cm_path)
        out.append((cm_name, crop.size))

    print(f"Zona: {manifest.get('zone', zone_dir)} | kanvas {W}x{H}px | {drawn} jalan digambar"
          + (f" (filter >= {args.min_class})" if args.min_class else ""))
    for name, sz in out:
        print(f"  + {name}  {sz[0]}x{sz[1]}px")
    print("Impor: re-import tiap tile (Heightmap + Colormap), warna Pasir->Sand, Aspal->Ground.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
