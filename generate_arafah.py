#!/usr/bin/env python3
"""generate_arafah.py — Tandai area & landmark Arafah (Zona C) dari OSM + koordinat.

Output (output/C_Arafah/):
  jabal_rahmah.json : bukit + tugu putih ~8 m (32 studs)
  namirah.json      : footprint Masjid Namirah (OSM) + spec (6 menara, 3 kubah)
  boundary.json     : gapura kuning "Batas Arafah" keliling area konten
  facilities.json   : blok toilet/MCK tersebar di area perkemahan
  mist.json         : tiang mist (penyemprot kabut) di jalan utama

Pemakaian:
  python generate_arafah.py --zone C_Arafah
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys

# Landmark (lon, lat) — literatur.
JABAL_RAHMAH = (39.98430, 21.35480)
CLASS_MAIN = {"motorway", "trunk", "primary", "secondary", "tertiary"}


def _load(zone_dir, name, opt=False):
    p = os.path.join(zone_dir, name)
    if not os.path.isfile(p):
        if opt:
            return None
        raise SystemExit(f"ERROR: {p} tak ada.")
    with open(p, encoding="utf-8") as f:
        return json.load(f)


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="Tandai area & landmark Arafah.")
    p.add_argument("--zone", default="C_Arafah")
    p.add_argument("--gate-spacing", type=float, default=600.0, help="Jarak antar gapura batas (studs).")
    p.add_argument("--mist-spacing", type=float, default=140.0, help="Jarak antar tiang mist (studs).")
    p.add_argument("--facility-spacing", type=float, default=900.0, help="Grid blok MCK (studs).")
    args = p.parse_args(argv)

    zd = os.path.join("output", args.zone)
    man = _load(zd, "import_manifest.json")
    blds = _load(zd, "osm_buildings.json")["buildings"]
    roads = _load(zd, "osm_roads.json")["roads"]
    gb = man["geo_bounds"]; sx = man["world_size_studs"]["x"]; sz = man["world_size_studs"]["z"]
    half_x, half_z = sx / 2, sz / 2

    def to_xz(lon, lat):
        fx = (lon - gb["lon_min"]) / (gb["lon_max"] - gb["lon_min"])
        fz = (gb["lat_max"] - lat) / (gb["lat_max"] - gb["lat_min"])
        return round(fx * sx - sx / 2, 2), round(fz * sz - sz / 2, 2)

    # --- JABAL AR-RAHMAH (bukit + tugu putih ~8 m) ---
    jx, jz = to_xz(*JABAL_RAHMAH)
    scale = man["scale_studs_per_m"]
    jr = {"center": {"x": jx, "z": jz}, "pillar_height": round(8 * scale, 1), "pillar_color": [240, 240, 240]}
    json.dump(jr, open(os.path.join(zd, "jabal_rahmah.json"), "w", encoding="utf-8"), ensure_ascii=False)
    print(f"Jabal ar-Rahmah: ({jx},{jz}), tugu {jr['pillar_height']} studs -> jabal_rahmah.json")

    # --- MASJID NAMIRAH (footprint OSM) ---
    nm = next((b for b in blds if "نمرة" in b.get("name", "") or "namir" in b.get("name", "").lower()), None)
    namirah = None
    if nm:
        poly = nm["polygon"]
        xs = [q["x"] for q in poly]; zs = [q["z"] for q in poly]
        namirah = {"name": nm["name"], "footprint": poly,
                   "center": {"x": round(sum(xs) / len(xs), 2), "z": round(sum(zs) / len(zs), 2)},
                   "size": {"w": round(max(xs) - min(xs), 2), "l": round(max(zs) - min(zs), 2)},
                   "minarets": 6, "domes": 3}
        json.dump(namirah, open(os.path.join(zd, "namirah.json"), "w", encoding="utf-8"), ensure_ascii=False)
        print(f"Masjid Namirah: center {namirah['center']} size {namirah['size']} -> namirah.json")
    else:
        print("Masjid Namirah: tak ditemukan di OSM (lewati).")

    # --- AREA KONTEN: bbox semua bangunan OSM (perkemahan) + landmark ---
    xs, zs = [], []
    for b in blds:
        for q in b["polygon"]:
            xs.append(q["x"]); zs.append(q["z"])
    xs += [jx]; zs += [jz]
    if namirah:
        xs.append(namirah["center"]["x"]); zs.append(namirah["center"]["z"])
    margin = 250
    x0 = max(-half_x, min(xs) - margin); x1 = min(half_x, max(xs) + margin)
    z0 = max(-half_z, min(zs) - margin); z1 = min(half_z, max(zs) + margin)

    def in_area(x, z):
        return x0 <= x <= x1 and z0 <= z <= z1

    # --- BATAS ARAFAH: gapura kuning keliling persegi area konten ---
    gates = []
    corners = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]
    for i in range(4):
        ax, az = corners[i]; bx, bz = corners[(i + 1) % 4]
        seg = math.hypot(bx - ax, bz - az); d = 0.0
        while d < seg:
            t = d / seg
            gates.append({"x": round(ax + (bx - ax) * t, 2), "z": round(az + (bz - az) * t, 2)})
            d += args.gate_spacing
    json.dump({"count": len(gates), "gates": gates},
              open(os.path.join(zd, "boundary.json"), "w", encoding="utf-8"), ensure_ascii=False)
    print(f"Batas Arafah: {len(gates)} gapura kuning ({x1-x0:.0f}x{z1-z0:.0f} studs) -> boundary.json")

    # --- MIST: tiang di sepanjang RUTE pejalan kaki (bukan semua jalan) ---
    mist = []
    rl = _load(zd, "route_local.json", opt=True)
    if rl:
        for seg in rl.get("segments", []):
            path = seg.get("path", []); acc = 0.0
            for i in range(len(path) - 1):
                ax, az = path[i]["x"], path[i]["z"]; bx, bz = path[i + 1]["x"], path[i + 1]["z"]
                slen = math.hypot(bx - ax, bz - az); d = acc
                while d < slen:
                    t = d / slen if slen > 0 else 0
                    mist.append({"x": round(ax + (bx - ax) * t, 2), "z": round(az + (bz - az) * t, 2)})
                    d += args.mist_spacing
                acc = d - slen
    json.dump({"count": len(mist), "poles": mist},
              open(os.path.join(zd, "mist.json"), "w", encoding="utf-8"), ensure_ascii=False)
    print(f"Mist: {len(mist)} tiang di sepanjang rute -> mist.json")

    # --- FASILITAS (MCK): grid blok beton di area konten, jauh dari landmark ---
    facilities = []
    x = x0 + args.facility_spacing / 2
    while x < x1:
        z = z0 + args.facility_spacing / 2
        while z < z1:
            # jauhkan dari Jabal Rahmah & Namirah
            far = (math.hypot(x - jx, z - jz) > 400) and \
                  (not namirah or math.hypot(x - namirah["center"]["x"], z - namirah["center"]["z"]) > 400)
            if far:
                facilities.append({"x": round(x, 2), "z": round(z, 2), "w": 60, "l": 24})
            z += args.facility_spacing
        x += args.facility_spacing
    json.dump({"count": len(facilities), "blocks": facilities},
              open(os.path.join(zd, "facilities.json"), "w", encoding="utf-8"), ensure_ascii=False)
    print(f"Fasilitas MCK: {len(facilities)} blok -> facilities.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
