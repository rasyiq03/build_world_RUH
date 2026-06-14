#!/usr/bin/env python3
"""generate_tents.py — Titik penempatan tenda Mina (grid prosedural) -> JSON.

Prinsip hemat memori: TIDAK ada geometri di sini. Hanya daftar titik (x,z,rot).
Di Studio, satu MeshPart tenda master di-Clone() ke tiap titik (instancing).

Tenda diisi di PITA sepanjang rute jalan kaki (di antara jalur & pembatas), supaya
pemain melihat lembah tenda penuh dari jalan, TANPA menutupi jalur atau jalan raya.
Deterministik (grid, tanpa random).

Pemakaian:
  python generate_tents.py --zone B_Mina --route output/B_Mina/route.json
  python generate_tents.py --zone B_Mina --route output/B_Mina/route.json \
      --spacing 20 --band-min 16 --band-max 85 --max-tents 3000
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys
import numpy as np


def _load_json(path):
    if not os.path.isfile(path):
        raise SystemExit(f"ERROR: tak ada '{path}'.")
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def _route_segments(route_doc, manifest):
    """Waypoint rute -> segmen studs (A,B) + heading tiap segmen (derajat)."""
    if "waypoints_xz" in route_doc:
        wp = [(float(x), float(z)) for x, z in route_doc["waypoints_xz"]]
    elif "waypoints_lonlat" in route_doc:
        from generate_osm import make_projector
        project, _, _, _ = make_projector(manifest)
        wp = [project(float(lo), float(la)) for lo, la in route_doc["waypoints_lonlat"]]
    else:
        raise SystemExit("route butuh 'waypoints_xz' atau 'waypoints_lonlat'.")
    if len(wp) < 2:
        raise SystemExit("route butuh >= 2 waypoint.")
    A = np.array(wp[:-1], float)
    B = np.array(wp[1:], float)
    return A, B


def _seg_dist_and_heading(P, A, B):
    """Untuk titik P (2,), kembalikan (jarak min ke segmen, heading segmen terdekat)."""
    AB = B - A
    AC = P - A
    denom = np.where((AB * AB).sum(1) < 1e-9, 1e-9, (AB * AB).sum(1))
    t = np.clip((AC * AB).sum(1) / denom, 0.0, 1.0)
    proj = A + t[:, None] * AB
    d = np.hypot(P[0] - proj[:, 0], P[1] - proj[:, 1])
    i = int(d.argmin())
    heading = math.degrees(math.atan2(AB[i, 1], AB[i, 0]))
    return float(d[i]), heading


def _road_segments(roads_doc):
    A, B = [], []
    for r in roads_doc.get("roads", []):
        p = r.get("path", [])
        for i in range(len(p) - 1):
            A.append((p[i]["x"], p[i]["z"]))
            B.append((p[i + 1]["x"], p[i + 1]["z"]))
    if not A:
        return np.empty((0, 2)), np.empty((0, 2))
    return np.asarray(A, float), np.asarray(B, float)


def _min_dist(P, A, B):
    if len(A) == 0:
        return 1e9
    AB = B - A
    AC = P - A
    denom = np.where((AB * AB).sum(1) < 1e-9, 1e-9, (AB * AB).sum(1))
    t = np.clip((AC * AB).sum(1) / denom, 0.0, 1.0)
    proj = A + t[:, None] * AB
    return float(np.hypot(P[0] - proj[:, 0], P[1] - proj[:, 1]).min())


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="Grid titik tenda Mina -> mina_tents.json.")
    p.add_argument("--zone", required=True, help="Nama zona (output/<zona>/).")
    p.add_argument("--route", required=True, help="route.json (waypoints rute jalan kaki).")
    p.add_argument("--spacing", type=float, default=20.0, help="Jarak antar tenda (studs).")
    p.add_argument("--band-min", type=float, default=16.0, help="Jarak min tenda dari rute (sisakan jalur).")
    p.add_argument("--band-max", type=float, default=85.0, help="Jarak max tenda dari rute (~pembatas).")
    p.add_argument("--road-clear", type=float, default=10.0, help="Jarak min tenda dari jalan raya OSM.")
    p.add_argument("--tent-size", type=float, default=16.0, help="Footprint tenda (studs, untuk meta).")
    p.add_argument("--max-tents", type=int, default=3000, help="Batas jumlah tenda (kendali instance).")
    p.add_argument("--align-route", action="store_true", help="Putar tenda mengikuti arah rute.")
    args = p.parse_args(argv)

    zone_dir = os.path.join("output", args.zone)
    manifest = _load_json(os.path.join(zone_dir, "import_manifest.json"))
    route_doc = _load_json(args.route)
    A, B = _route_segments(route_doc, manifest)

    rA = rB = np.empty((0, 2))
    rpath = os.path.join(zone_dir, "osm_roads.json")
    if os.path.isfile(rpath):
        rA, rB = _road_segments(_load_json(rpath))

    size_x = float(manifest["world_size_studs"]["x"])
    size_z = float(manifest["world_size_studs"]["z"])
    half_x, half_z = size_x / 2.0, size_z / 2.0

    # Grid kandidat di kotak-batas rute diperluas band-max (hemat: tak seluruh dunia).
    xs = np.concatenate([A[:, 0], B[:, 0]])
    zs = np.concatenate([A[:, 1], B[:, 1]])
    x0 = max(-half_x, xs.min() - args.band_max)
    x1 = min(half_x, xs.max() + args.band_max)
    z0 = max(-half_z, zs.min() - args.band_max)
    z1 = min(half_z, zs.max() + args.band_max)

    sp = args.spacing
    gx = np.arange(x0, x1 + sp, sp)
    gz = np.arange(z0, z1 + sp, sp)

    tents = []
    for zz in gz:
        for xx in gx:
            P = np.array([xx, zz])
            d_route, heading = _seg_dist_and_heading(P, A, B)
            if d_route < args.band_min or d_route > args.band_max:
                continue
            if _min_dist(P, rA, rB) < args.road_clear:
                continue
            rot = round(heading, 1) if args.align_route else 0.0
            tents.append({"x": round(float(xx), 2), "z": round(float(zz), 2), "rot": rot})
            if len(tents) >= args.max_tents:
                break
        if len(tents) >= args.max_tents:
            break

    out = {
        "zone": manifest.get("zone", args.zone),
        "world_size_studs": manifest["world_size_studs"],
        "tent_size_studs": args.tent_size,
        "count": len(tents),
        "tents": tents,
    }
    op = os.path.join(zone_dir, "mina_tents.json")
    with open(op, "w", encoding="utf-8") as f:
        json.dump(out, f, indent=2, ensure_ascii=False)
    print(f"Zona {args.zone}: {len(tents)} titik tenda (spacing {sp}, band {args.band_min}-{args.band_max} studs)"
          + (" [capped]" if len(tents) >= args.max_tents else ""))
    print(f"  -> {op}")
    print("Studio: pakai place_tents.lua + 1 MeshPart tenda master (Clone per titik).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
