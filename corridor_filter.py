#!/usr/bin/env python3
"""corridor_filter.py — Pendekatan FASAD KORIDOR untuk hemat instance (anti 100 MB).

Masalah: satu zona kota = ribuan bangunan. Membangun semua = ledakan instance.
Strategi: pemain hanya menyusuri JALAN UTAMA (rute haji/umrah: ke Mina, Arafah, dst.).
Jadi cukup bangun bangunan ~2-3 lapis di sepanjang jalan utama (kota tetap terlihat
penuh dari jalan), lalu pasang PEMBATAS agar pemain tak bisa masuk lebih dalam.

Baca file yang SUDAH di-fetch (output/<zona>/osm_roads.json + osm_buildings.json),
saring offline, tulis:
  osm_buildings_corridor.json  -> bangunan dalam koridor jalan utama saja
  osm_barriers.json            -> garis pembatas (offset dari jalan utama)

Pemakaian:
  python corridor_filter.py --zone B_Mina                 # default koridor 70 studs
  python corridor_filter.py --zone B_Mina --corridor 60 --main-class primary
  python corridor_filter.py --zone A_Makkah --keep-all     # Masjidil Haram: jelajah penuh
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import numpy as np

# Kelas jalan dari besar -> kecil (untuk ambang "jalan utama").
CLASS_ORDER = [
    "motorway", "trunk", "primary", "secondary", "tertiary",
    "residential", "unclassified", "living_street", "service",
    "pedestrian", "footway", "track", "path", "steps",
]


def _rank(cls: str) -> int:
    base = cls.replace("_link", "")
    return CLASS_ORDER.index(base) if base in CLASS_ORDER else len(CLASS_ORDER)


def _load(zone_dir: str):
    rp = os.path.join(zone_dir, "osm_roads.json")
    bp = os.path.join(zone_dir, "osm_buildings.json")
    for p in (rp, bp):
        if not os.path.isfile(p):
            raise SystemExit(f"ERROR: tak ada '{p}'. Jalankan generate_osm.py dulu.")
    with open(rp, encoding="utf-8") as f:
        roads = json.load(f)
    with open(bp, encoding="utf-8") as f:
        blds = json.load(f)
    return roads, blds


def _road_length(r: dict) -> float:
    p = r.get("path", [])
    return sum(((p[i + 1]["x"] - p[i]["x"]) ** 2 + (p[i + 1]["z"] - p[i]["z"]) ** 2) ** 0.5
               for i in range(len(p) - 1))


def _route_roads(roads: list, main_rank: int, top_n: int) -> list:
    """Pilih jalan rute: kelas >= ambang. top_n>0 -> ambil N TERPANJANG (proksi
    jalan-tembus utama, hindari seluruh grid arteri kota)."""
    cand = [r for r in roads if _rank(r["type"]) <= main_rank and len(r.get("path", [])) >= 2]
    cand.sort(key=_road_length, reverse=True)
    return cand[:top_n] if top_n > 0 else cand


def _segments_of(route: list):
    """Array (N,2) A & B dari daftar jalan terpilih."""
    A, B = [], []
    for r in route:
        path = r["path"]
        for i in range(len(path) - 1):
            A.append((path[i]["x"], path[i]["z"]))
            B.append((path[i + 1]["x"], path[i + 1]["z"]))
    if not A:
        return np.empty((0, 2)), np.empty((0, 2))
    return np.asarray(A, float), np.asarray(B, float)


def _point_seg_dist(c: np.ndarray, A: np.ndarray, B: np.ndarray) -> float:
    """Jarak titik c ke himpunan segmen (A,B), ambil minimum (vektorisasi numpy)."""
    AB = B - A
    AC = c - A
    denom = (AB * AB).sum(1)
    denom = np.where(denom < 1e-9, 1e-9, denom)
    t = np.clip((AC * AB).sum(1) / denom, 0.0, 1.0)
    proj = A + t[:, None] * AB
    d = np.hypot(c[0] - proj[:, 0], c[1] - proj[:, 1])
    return float(d.min())


def _centroid(poly: list) -> np.ndarray:
    pts = np.array([(p["x"], p["z"]) for p in poly], float)
    return pts.mean(axis=0)


def _route_from_file(route_file: str, zone_dir: str):
    """Baca waypoint rute manual -> segmen (A,B) dalam studs.

    Format JSON: {"waypoints_xz":[[x,z],...]} (langsung studs) ATAU
                 {"waypoints_lonlat":[[lon,lat],...]} (diproyeksikan via manifest zona).
    """
    if not os.path.isfile(route_file):
        raise SystemExit(f"ERROR: route-file '{route_file}' tak ditemukan.")
    with open(route_file, encoding="utf-8") as f:
        doc = json.load(f)

    if "waypoints_xz" in doc:
        wp = [(float(x), float(z)) for x, z in doc["waypoints_xz"]]
    elif "waypoints_lonlat" in doc:
        # Proyeksi lon/lat -> studs pakai manifest zona (sama dgn generate_osm).
        from generate_osm import load_manifest, make_projector
        manifest = load_manifest(os.path.join(zone_dir, "import_manifest.json"))
        project, _, _, _ = make_projector(manifest)
        wp = [project(float(lon), float(lat)) for lon, lat in doc["waypoints_lonlat"]]
    else:
        raise SystemExit("route-file butuh 'waypoints_xz' atau 'waypoints_lonlat'.")

    if len(wp) < 2:
        raise SystemExit("route-file butuh >= 2 waypoint.")
    A = np.array(wp[:-1], float)
    B = np.array(wp[1:], float)
    return A, B


def _barriers(A: np.ndarray, B: np.ndarray, offset: float) -> list:
    """Offset tiap segmen jalan utama ±offset (tegak lurus) -> garis pembatas."""
    out = []
    AB = B - A
    length = np.hypot(AB[:, 0], AB[:, 1])
    length = np.where(length < 1e-9, 1e-9, length)
    # Normal satuan (tegak lurus arah segmen).
    nx = -AB[:, 1] / length
    ny = AB[:, 0] / length
    for sign in (+1.0, -1.0):
        for i in range(len(A)):
            ox, oy = sign * offset * nx[i], sign * offset * ny[i]
            out.append({"path": [
                {"x": round(A[i, 0] + ox, 2), "z": round(A[i, 1] + oy, 2)},
                {"x": round(B[i, 0] + ox, 2), "z": round(B[i, 1] + oy, 2)},
            ]})
    return out


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="Filter bangunan ke koridor jalan utama + pembatas.")
    g = p.add_mutually_exclusive_group(required=True)
    g.add_argument("--zone", help="Nama zona (output/<zona>/).")
    g.add_argument("--zone-dir", help="Path folder zona langsung.")
    p.add_argument("--main-class", default="primary",
                   help="Ambang kelas kandidat rute (motorway..steps). Default primary.")
    p.add_argument("--route-top", type=int, default=3,
                   help="Pakai N jalan TERPANJANG sebagai rute (proksi jalan-tembus). "
                        "0 = semua jalan kelas itu. Default 3.")
    p.add_argument("--corridor", type=float, default=70.0,
                   help="Jarak maks bangunan dari rute (studs ~ 2-3 bangunan). Default 70.")
    p.add_argument("--barrier-offset", type=float, default=None,
                   help="Jarak garis pembatas dari jalan utama (default corridor+10).")
    p.add_argument("--route-file", default=None,
                   help="JSON rute jalan kaki manual: {\"waypoints_lonlat\":[[lon,lat],...]} "
                        "atau {\"waypoints_xz\":[[x,z],...]}. Lebih akurat dari auto.")
    p.add_argument("--keep-all", action="store_true",
                   help="JANGAN filter (mis. zona Masjidil Haram: jelajah penuh).")
    p.add_argument("--no-barriers", action="store_true", help="Jangan tulis pembatas.")
    args = p.parse_args(argv)

    zone_dir = args.zone_dir or os.path.join("output", args.zone)
    roads_doc, blds = _load(zone_dir)
    roads = roads_doc.get("roads", [])
    buildings = blds.get("buildings", [])
    total = len(buildings)

    if args.keep_all:
        kept = buildings
        barriers = []
        print(f"--keep-all: {total} bangunan dipertahankan (zona jelajah penuh).")
    else:
        if args.route_file:
            A, B = _route_from_file(args.route_file, zone_dir)
            print(f"Rute MANUAL dari {args.route_file}: {len(A)} segmen.")
        else:
            main_rank = _rank(args.main_class)
            route = _route_roads(roads, main_rank, args.route_top)
            A, B = _segments_of(route)
            rt = f"{args.route_top} jalan terpanjang" if args.route_top > 0 else f"semua kelas >= {args.main_class}"
            names = [r.get("name") or "(tanpa nama)" for r in route]
            print(f"Rute AUTO = {rt} (kelas >= {args.main_class}): {len(A)} segmen.")
            print(f"  jalan rute: {names}")
        if len(A) == 0:
            raise SystemExit("Rute kosong. Beri --route-file atau --main-class lebih longgar.")
        kept = []
        for b in buildings:
            poly = b.get("polygon", [])
            if len(poly) < 3:
                continue
            if _point_seg_dist(_centroid(poly), A, B) <= args.corridor:
                kept.append(b)
        off = args.barrier_offset if args.barrier_offset is not None else args.corridor + 10.0
        barriers = [] if args.no_barriers else _barriers(A, B, off)
        print(f"Bangunan: {total} -> {len(kept)} di koridor <= {args.corridor} studs "
              f"({100 * len(kept) / max(1, total):.0f}%).")
        if barriers:
            print(f"Pembatas: {len(barriers)} segmen (offset {off:g} studs).")

    meta = {k: blds.get(k) for k in ("zone", "world_size_studs", "origin")}
    bp = os.path.join(zone_dir, "osm_buildings_corridor.json")
    with open(bp, "w", encoding="utf-8") as f:
        json.dump({**meta, "count": len(kept), "buildings": kept}, f, indent=2, ensure_ascii=False)
    print(f"  -> {bp}")
    if barriers:
        xp = os.path.join(zone_dir, "osm_barriers.json")
        with open(xp, "w", encoding="utf-8") as f:
            json.dump({**meta, "count": len(barriers), "barriers": barriers}, f, indent=2, ensure_ascii=False)
        print(f"  -> {xp}")
    print("Studio: pakai osm_buildings_corridor.json di place_osm_buildings.lua "
          "(+ osm_barriers.json untuk dinding pembatas).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
