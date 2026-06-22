#!/usr/bin/env python3
"""generate_muzdalifah.py — Tandai area & landmark Muzdalifah (Zona D) dari OSM + koordinat.

Muzdalifah = tempat MABIT (bermalam) malam 10 Dzulhijjah + AMBIL 7 KERIKIL untuk Jumrah, dekat
Masy'aril Haram (Mash'ar al-Haram). Output (output/D_Muzdalifah/):
  masyaril_haram.json : Masy'aril Haram — masjid/monumen (footprint OSM bila ada, else spec) + center
  boundary.json       : gapura "Batas Muzdalifah" keliling area mabit
  pebble_area.json    : region pengambilan kerikil (center + radius studs) — DIBACA WorldProviders
  facilities.json     : blok MCK tersebar di area mabit

Sumber kebenaran koordinat = output/D_Muzdalifah/import_manifest.json (no hardcode). OSM opsional.

Pemakaian:
  python generate_muzdalifah.py --zone D_Muzdalifah
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys

# Masy'aril Haram (Mash'ar al-Haram), Muzdalifah — (lon, lat), literatur.
MASYARIL_HARAM = (39.93700, 21.38330)


def _load(zone_dir, name, opt=False):
    p = os.path.join(zone_dir, name)
    if not os.path.isfile(p):
        if opt:
            return None
        raise SystemExit(f"ERROR: {p} tak ada.")
    with open(p, encoding="utf-8") as f:
        return json.load(f)


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="Tandai area & landmark Muzdalifah.")
    p.add_argument("--zone", default="D_Muzdalifah")
    p.add_argument("--gate-spacing", type=float, default=600.0, help="Jarak antar gapura batas (studs).")
    p.add_argument("--facility-spacing", type=float, default=900.0, help="Grid blok MCK (studs).")
    p.add_argument("--pebble-radius", type=float, default=160.0, help="Radius area ambil kerikil (studs).")
    p.add_argument("--default-half", type=float, default=1500.0, help="Setengah-sisi area konten bila OSM kosong (studs).")
    args = p.parse_args(argv)

    zd = os.path.join("output", args.zone)
    man = _load(zd, "import_manifest.json")
    blds = (_load(zd, "osm_buildings.json", opt=True) or {}).get("buildings", [])
    gb = man["geo_bounds"]
    sx = man["world_size_studs"]["x"]
    sz = man["world_size_studs"]["z"]
    scale = man["scale_studs_per_m"]
    half_x, half_z = sx / 2, sz / 2

    def to_xz(lon, lat):
        fx = (lon - gb["lon_min"]) / (gb["lon_max"] - gb["lon_min"])
        fz = (gb["lat_max"] - lat) / (gb["lat_max"] - gb["lat_min"])
        return round(fx * sx - sx / 2, 2), round(fz * sz - sz / 2, 2)

    # --- MASY'ARIL HARAM (masjid/monumen) ---
    mhx, mhz = to_xz(*MASYARIL_HARAM)
    mh = next((b for b in blds if "حرام" in b.get("name", "") or "mash" in b.get("name", "").lower()), None)
    if mh:
        poly = mh["polygon"]
        xs = [q["x"] for q in poly]
        zs = [q["z"] for q in poly]
        mhx, mhz = round(sum(xs) / len(xs), 2), round(sum(zs) / len(zs), 2)
        masyaril = {"name": mh.get("name", "Masy'aril Haram"), "footprint": poly,
                    "center": {"x": mhx, "z": mhz},
                    "size": {"w": round(max(xs) - min(xs), 2), "l": round(max(zs) - min(zs), 2)},
                    "minarets": 2}
    else:
        masyaril = {"name": "Masy'aril Haram", "center": {"x": mhx, "z": mhz},
                    "size": {"w": round(60 * scale, 1), "l": round(40 * scale, 1)}, "minarets": 2}
    json.dump(masyaril, open(os.path.join(zd, "masyaril_haram.json"), "w", encoding="utf-8"), ensure_ascii=False)
    print(f"Masy'aril Haram: center ({mhx},{mhz}) -> masyaril_haram.json")

    # --- AREA KONTEN: bbox bangunan OSM (kemah mabit) + landmark; default kotak bila OSM kosong ---
    xs, zs = [mhx], [mhz]
    for b in blds:
        for q in b["polygon"]:
            xs.append(q["x"]); zs.append(q["z"])
    margin = 250
    if len(xs) > 1:
        x0 = max(-half_x, min(xs) - margin); x1 = min(half_x, max(xs) + margin)
        z0 = max(-half_z, min(zs) - margin); z1 = min(half_z, max(zs) + margin)
    else:
        x0 = max(-half_x, mhx - args.default_half); x1 = min(half_x, mhx + args.default_half)
        z0 = max(-half_z, mhz - args.default_half); z1 = min(half_z, mhz + args.default_half)

    # --- PEBBLE AREA: lingkaran di sekitar Masy'aril Haram (tempat ambil 7 kerikil) ---
    pebble = {"center": {"x": mhx, "z": mhz}, "radius": round(args.pebble_radius, 1)}
    json.dump(pebble, open(os.path.join(zd, "pebble_area.json"), "w", encoding="utf-8"), ensure_ascii=False)
    print(f"Area kerikil: center ({mhx},{mhz}) r={pebble['radius']} -> pebble_area.json")

    # --- BATAS MUZDALIFAH: gapura keliling persegi area konten ---
    gates = []
    corners = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]
    for i in range(4):
        ax, az = corners[i]; bx, bz = corners[(i + 1) % 4]
        seg = math.hypot(bx - ax, bz - az); d = 0.0
        while d < seg:
            t = d / seg if seg > 0 else 0
            gates.append({"x": round(ax + (bx - ax) * t, 2), "z": round(az + (bz - az) * t, 2)})
            d += args.gate_spacing
    json.dump({"count": len(gates), "gates": gates},
              open(os.path.join(zd, "boundary.json"), "w", encoding="utf-8"), ensure_ascii=False)
    print(f"Batas Muzdalifah: {len(gates)} gapura ({x1-x0:.0f}x{z1-z0:.0f} studs) -> boundary.json")

    # --- FASILITAS (MCK): grid blok beton di area mabit, jauh dari Masy'aril Haram & area kerikil ---
    facilities = []
    x = x0 + args.facility_spacing / 2
    while x < x1:
        z = z0 + args.facility_spacing / 2
        while z < z1:
            if math.hypot(x - mhx, z - mhz) > args.pebble_radius + 200:
                facilities.append({"x": round(x, 2), "z": round(z, 2), "w": 60, "l": 24})
            z += args.facility_spacing
        x += args.facility_spacing
    json.dump({"count": len(facilities), "blocks": facilities},
              open(os.path.join(zd, "facilities.json"), "w", encoding="utf-8"), ensure_ascii=False)
    print(f"Fasilitas MCK: {len(facilities)} blok -> facilities.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
