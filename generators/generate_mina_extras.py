#!/usr/bin/env python3
"""generate_mina_extras.py — Jamarat + lampu + guardline untuk Zona B Mina.

Output (output/B_Mina/):
  jamarat.json   : center + footprint + jumlah lantai (penanda multi-lantai)
  lamps.json     : titik lampu sepanjang jalan utama
  guardline.json : pembatas keliling area konten (player tak bisa keluar)

Pemakaian:
  python generate_mina_extras.py --zone B_Mina --jamarat-levels 5 --lamp-spacing 160
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys


def _load(zone_dir, name, optional=False):
    p = os.path.join(zone_dir, name)
    if not os.path.isfile(p):
        if optional:
            return None
        raise SystemExit(f"ERROR: {p} tak ada.")
    with open(p, encoding="utf-8") as f:
        return json.load(f)


CLASS_MAIN = {"motorway", "trunk", "primary", "secondary", "tertiary"}


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="Jamarat + lampu + guardline Mina.")
    p.add_argument("--zone", required=True)
    p.add_argument("--jamarat-levels", type=int, default=5, help="Jumlah lantai penanda Jamarat.")
    p.add_argument("--floor-height", type=float, default=24.0, help="Tinggi antar-lantai (studs).")
    p.add_argument("--lamp-spacing", type=float, default=160.0, help="Jarak antar lampu di jalan (studs).")
    p.add_argument("--guard-margin", type=float, default=120.0, help="Margin guardline dari konten (studs).")
    args = p.parse_args(argv)

    zone_dir = os.path.join("output", args.zone)
    blds = _load(zone_dir, "osm_buildings.json")["buildings"]
    roads = _load(zone_dir, "osm_roads.json")["roads"]

    # --- JAMARAT: cari جسر الجمرات ---
    jam = next((b for b in blds if "جمرات" in b.get("name", "") or "jamarat" in b.get("name", "").lower()), None)
    jamarat = None
    if jam:
        poly = jam["polygon"]
        xs = [q["x"] for q in poly]; zs = [q["z"] for q in poly]
        jamarat = {
            "name": jam["name"],
            "center": {"x": round(sum(xs) / len(xs), 2), "z": round(sum(zs) / len(zs), 2)},
            "size": {"w": round(max(xs) - min(xs), 2), "l": round(max(zs) - min(zs), 2)},
            "levels": args.jamarat_levels,
            "floor_height": args.floor_height,
            "footprint": poly,
        }
        with open(os.path.join(zone_dir, "jamarat.json"), "w", encoding="utf-8") as f:
            json.dump(jamarat, f, ensure_ascii=False)
        print(f"Jamarat: '{jam['name']}' center {jamarat['center']} size {jamarat['size']} "
              f"{args.jamarat_levels} lantai -> jamarat.json")
    else:
        print("Jamarat: tak ditemukan di OSM (lewati).")

    # --- AREA KONTEN: bbox keliling tenda + Jamarat (dipakai utk lampu & guardline) ---
    man = _load(zone_dir, "import_manifest.json")
    half_x = man["world_size_studs"]["x"] / 2
    half_z = man["world_size_studs"]["z"] / 2
    xs, zs = [], []
    tb = _load(zone_dir, "tent_blocks.json", optional=True)
    if tb:
        for b in tb["blocks"]:
            xs += [b["bbox"]["x0"], b["bbox"]["x1"]]; zs += [b["bbox"]["z0"], b["bbox"]["z1"]]
    if jamarat:
        jc, js = jamarat["center"], jamarat["size"]
        xs += [jc["x"] - js["w"] / 2, jc["x"] + js["w"] / 2]
        zs += [jc["z"] - js["l"] / 2, jc["z"] + js["l"] / 2]
    if not xs:
        xs, zs = [-half_x / 2, half_x / 2], [-half_z / 2, half_z / 2]
    m = args.guard_margin
    x0 = max(-half_x, min(xs) - m); x1 = min(half_x, max(xs) + m)
    z0 = max(-half_z, min(zs) - m); z1 = min(half_z, max(zs) + m)

    def in_area(x, z):
        return x0 <= x <= x1 and z0 <= z <= z1

    # --- LAMPU: di jalan utama, HANYA dalam area konten (bukan seluruh box) ---
    lamps = []
    for r in roads:
        if r.get("type", "").replace("_link", "") not in CLASS_MAIN:
            continue
        path = r.get("path", [])
        acc = 0.0
        for i in range(len(path) - 1):
            ax, az = path[i]["x"], path[i]["z"]
            bx, bz = path[i + 1]["x"], path[i + 1]["z"]
            seg = math.hypot(bx - ax, bz - az)
            d = acc
            while d < seg:
                t = d / seg if seg > 0 else 0
                lx, lz = round(ax + (bx - ax) * t, 2), round(az + (bz - az) * t, 2)
                if in_area(lx, lz):
                    lamps.append({"x": lx, "z": lz})
                d += args.lamp_spacing
            acc = d - seg
    with open(os.path.join(zone_dir, "lamps.json"), "w", encoding="utf-8") as f:
        json.dump({"count": len(lamps), "lamps": lamps}, f, ensure_ascii=False)
    print(f"Lampu: {len(lamps)} titik (di jalan utama DALAM area konten) -> lamps.json")

    # --- GUARDLINE: persegi keliling area konten ---
    corners = [(x0, z0), (x1, z0), (x1, z1), (x0, z1), (x0, z0)]
    barriers = [{"path": [{"x": round(corners[i][0], 2), "z": round(corners[i][1], 2)},
                          {"x": round(corners[i + 1][0], 2), "z": round(corners[i + 1][1], 2)}]}
                for i in range(len(corners) - 1)]
    with open(os.path.join(zone_dir, "guardline.json"), "w", encoding="utf-8") as f:
        json.dump({"count": len(barriers), "barriers": barriers}, f, ensure_ascii=False)
    print(f"Guardline: persegi {x1-x0:.0f}x{z1-z0:.0f} studs ({len(barriers)} sisi) -> guardline.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
