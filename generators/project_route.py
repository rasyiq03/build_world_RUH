#!/usr/bin/env python3
"""project_route.py — Proyeksikan rute HASIL-LACAK ke koordinat zona (studs lokal).

Baca hajj_route_traced.json (polyline jalan nyata + flag tunnel), proyeksikan ke
satu zona memakai geo_bounds manifest. Output bagian jalur DALAM zona (studs) +
titik MASUK/KELUAR (teleport handoff) + flag tunnel per titik.

Output: output/<zona>/route_local.json
  segments: [ { from, to, ritual, path:[{x,z,tunnel}], entry, exit } ]

Pemakaian:  python project_route.py --zone B_Mina
"""

from __future__ import annotations

import argparse
import json
import os
import sys


def _load(path):
    if not os.path.isfile(path):
        raise SystemExit(f"ERROR: {path} tak ada.")
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="Proyeksi rute hasil-lacak ke zona.")
    p.add_argument("--zone", required=True)
    p.add_argument("--route", default="hajj_route_traced.json")
    args = p.parse_args(argv)

    zone_dir = os.path.join("output", args.zone)
    man = _load(os.path.join(zone_dir, "import_manifest.json"))
    route = _load(args.route)

    gb = man["geo_bounds"]
    sx, sz = man["world_size_studs"]["x"], man["world_size_studs"]["z"]
    flip_z = bool(man.get("flip_z", False))
    lon0, lon1, lat0, lat1 = gb["lon_min"], gb["lon_max"], gb["lat_min"], gb["lat_max"]

    def in_box(lon, lat):
        return lon0 <= lon <= lon1 and lat0 <= lat <= lat1

    def to_xz(lon, lat):
        fx = (lon - lon0) / (lon1 - lon0)
        fz = (lat1 - lat) / (lat1 - lat0)
        if flip_z:
            fz = 1 - fz
        return round(fx * sx - sx / 2, 2), round(fz * sz - sz / 2, 2)

    out_segs = []
    for s in route["segments"]:
        poly = s["polyline_lonlat"]
        mask = s.get("tunnel_mask", [0] * len(poly))
        # kumpulkan run titik di-dalam-box (jalur bisa masuk/keluar zona >1x)
        path, entry, exit_ = [], None, None
        prev_in = False
        for i, (lon, lat) in enumerate(poly):
            inside = in_box(lon, lat)
            if inside:
                x, z = to_xz(lon, lat)
                path.append({"x": x, "z": z, "tunnel": int(mask[i]) if i < len(mask) else 0})
                if not prev_in:
                    entry = entry or {"x": x, "z": z, "from_zone": s["from"]}
            elif prev_in and exit_ is None and path:
                exit_ = {"x": path[-1]["x"], "z": path[-1]["z"], "to_zone": s["to"]}
            prev_in = inside
        if not path:
            continue
        if exit_ is None:  # jalur berakhir di dalam zona (mis. tujuan ritual)
            exit_ = {"x": path[-1]["x"], "z": path[-1]["z"], "to_zone": s["to"]}
        out_segs.append({
            "from": s["from"], "to": s["to"], "ritual": s["ritual"],
            "path": path, "entry": entry, "exit": exit_,
        })

    out = {"zone": args.zone, "world_size_studs": man["world_size_studs"], "segments": out_segs}
    with open(os.path.join(zone_dir, "route_local.json"), "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False)

    print(f"Zona {args.zone}: {len(out_segs)} segmen rute melewati zona.")
    for s in out_segs:
        tun = sum(1 for q in s["path"] if q["tunnel"])
        print(f"  [{s['from']:>11} -> {s['to']:<11}] '{s['ritual']}' | {len(s['path'])} titik in-zone"
              + (f", {tun} titik terowongan" if tun else ""))
        if s["entry"]: print(f"      MASUK dari {s['entry']['from_zone']} @ ({s['entry']['x']},{s['entry']['z']})")
        if s["exit"]:  print(f"      KELUAR ke {s['exit']['to_zone']} @ ({s['exit']['x']},{s['exit']['z']})")
    print(f"  -> output/{args.zone}/route_local.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
