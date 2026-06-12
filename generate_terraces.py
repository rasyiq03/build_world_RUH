#!/usr/bin/env python3
"""generate_terraces.py — Tenda Mina sebagai BLOK TERAS di footprint perkemahan asli.

Mina nyata: tenda menempati blok perkemahan (Maktab) yang tanahnya DIRATAKAN jadi
teras berundak — bukan mengikuti lereng mentah. Skrip ini memetakan tiap perkemahan
OSM (building=residential / nama 'مخيم') jadi satu BLOK: diisi grid tenda, dan
mencatat kotak platform untuk diratakan di Studio (Terrain:FillBlock).

Output: output/<zona>/tent_blocks.json
  { tent_size_studs, count_blocks, count_tents,
    blocks: [ { name, bbox:{x0,z0,x1,z1}, center:{x,z}, rot, tents:[{x,z,rot}] } ] }

Pemakaian:
  python generate_terraces.py --zone B_Mina --tent-size 32 --spacing 40
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys


def _load(zone_dir, name):
    p = os.path.join(zone_dir, name)
    if not os.path.isfile(p):
        raise SystemExit(f"ERROR: {p} tak ada (jalankan convert_terrain.py & generate_osm.py).")
    with open(p, encoding="utf-8") as f:
        return json.load(f)


def _is_camp(b):
    return b.get("building") == "residential" or "مخيم" in b.get("name", "")


def _bbox(poly):
    xs = [p["x"] for p in poly]; zs = [p["z"] for p in poly]
    return min(xs), min(zs), max(xs), max(zs)


def _dominant_angle(poly):
    """Sudut sisi terpanjang poligon (derajat) -> orientasi grid tenda."""
    best_len, best_ang = 0.0, 0.0
    for i in range(len(poly) - 1):
        dx = poly[i + 1]["x"] - poly[i]["x"]
        dz = poly[i + 1]["z"] - poly[i]["z"]
        d = math.hypot(dx, dz)
        if d > best_len:
            best_len, best_ang = d, math.degrees(math.atan2(dz, dx))
    return round(best_ang, 1)


def _point_in_poly(x, z, poly):
    """Ray casting point-in-polygon."""
    inside = False
    n = len(poly)
    j = n - 1
    for i in range(n):
        xi, zi = poly[i]["x"], poly[i]["z"]
        xj, zj = poly[j]["x"], poly[j]["z"]
        if ((zi > z) != (zj > z)) and (x < (xj - xi) * (z - zi) / (zj - zi + 1e-12) + xi):
            inside = not inside
        j = i
    return inside


def _fill_block(poly, spacing, rot, margin):
    """Grid tenda di dalam poligon (dengan margin tepi), sejajar orientasi blok."""
    x0, z0, x1, z1 = _bbox(poly)
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    ang = math.radians(rot)
    ca, sa = math.cos(ang), math.sin(ang)
    # langkah grid di ruang lokal (terotasi) supaya baris tenda rapi sejajar blok
    half_w = (x1 - x0) / 2 + spacing
    half_d = (z1 - z0) / 2 + spacing
    tents = []
    u = -half_w
    while u <= half_w:
        v = -half_d
        while v <= half_d:
            # rotasi ke world
            wx = cx + u * ca - v * sa
            wz = cz + u * sa + v * ca
            if _point_in_poly(wx, wz, poly):
                tents.append({"x": round(wx, 2), "z": round(wz, 2), "rot": rot})
            v += spacing
        u += spacing
    return tents


def _valley_fill(zone_dir, camps, args):
    """Isi padat lembah tenda: grid teras menutup hull camps, hindari jalan."""
    import numpy as np
    # Region = bbox semua poligon camp + margin.
    xs, zs = [], []
    for b in camps:
        for p in b["polygon"]:
            xs.append(p["x"]); zs.append(p["z"])
    mx = args.block
    x0, x1 = min(xs) - mx, max(xs) + mx
    z0, z1 = min(zs) - mx, max(zs) + mx

    # Segmen jalan (hindari menaruh tenda di jalan).
    rA, rB = [], []
    rp = os.path.join(zone_dir, "osm_roads.json")
    if os.path.isfile(rp):
        roads = _load(zone_dir, "osm_roads.json").get("roads", [])
        for r in roads:
            pth = r.get("path", [])
            for i in range(len(pth) - 1):
                rA.append((pth[i]["x"], pth[i]["z"]))
                rB.append((pth[i + 1]["x"], pth[i + 1]["z"]))
    rA = np.array(rA) if rA else np.empty((0, 2))
    rB = np.array(rB) if rB else np.empty((0, 2))

    def near_road(x, z):
        if len(rA) == 0:
            return False
        AB = rB - rA; AC = np.array([x, z]) - rA
        den = np.where((AB * AB).sum(1) < 1e-9, 1e-9, (AB * AB).sum(1))
        t = np.clip((AC * AB).sum(1) / den, 0, 1)
        proj = rA + t[:, None] * AB
        return float(np.hypot(x - proj[:, 0], z - proj[:, 1]).min()) < args.road_clear

    sp = args.spacing
    blocks = []
    total = 0
    bz = z0
    while bz < z1:
        bx = x0
        while bx < x1:
            # super-blok teras [bx,bx+block) x [bz,bz+block)
            tents = []
            u = bx + sp / 2
            while u < bx + args.block:
                v = bz + sp / 2
                while v < bz + args.block:
                    if not near_road(u, v):
                        tents.append({"x": round(u, 2), "z": round(v, 2), "rot": 0.0})
                    v += sp
                u += sp
            if tents:
                blocks.append({
                    "name": "Maktab",
                    "bbox": {"x0": round(bx, 2), "z0": round(bz, 2),
                             "x1": round(bx + args.block, 2), "z1": round(bz + args.block, 2)},
                    "center": {"x": round(bx + args.block / 2, 2), "z": round(bz + args.block / 2, 2)},
                    "rot": 0.0, "tents": tents,
                })
                total += len(tents)
            bx += args.block
        bz += args.block

    out = {"zone": args.zone, "tent_size_studs": args.tent_size,
           "count_blocks": len(blocks), "count_tents": total, "blocks": blocks}
    with open(os.path.join(zone_dir, "tent_blocks.json"), "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
    print(f"Zona {args.zone} [VALLEY-FILL]: {len(blocks)} blok teras, {total} tenda "
          f"(region {x1-x0:.0f}x{z1-z0:.0f} studs, spacing {sp}).")
    print(f"  -> output/{args.zone}/tent_blocks.json")
    return 0


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="Tenda Mina sebagai blok teras (footprint camp OSM).")
    p.add_argument("--zone", required=True)
    p.add_argument("--tent-size", type=float, default=32.0, help="Footprint tenda (studs, skala 4 = 8m).")
    p.add_argument("--spacing", type=float, default=40.0, help="Jarak antar tenda (studs).")
    p.add_argument("--edge-margin", type=float, default=10.0, help="Margin dari tepi camp (studs).")
    p.add_argument("--all-buildings", action="store_true",
                   help="Pakai SEMUA bangunan, bukan hanya camp (residential/مخيم).")
    p.add_argument("--valley-fill", action="store_true",
                   help="Isi PADAT seluruh lembah tenda (grid teras), bukan hanya footprint camp.")
    p.add_argument("--block", type=float, default=240.0, help="Ukuran super-blok teras (studs).")
    p.add_argument("--road-clear", type=float, default=24.0, help="Jarak min tenda dari jalan (studs).")
    args = p.parse_args(argv)

    zone_dir = os.path.join("output", args.zone)
    blds = _load(zone_dir, "osm_buildings.json")["buildings"]
    camps = blds if args.all_buildings else [b for b in blds if _is_camp(b)]
    if not camps:
        raise SystemExit("Tak ada blok perkemahan (residential/مخيم). Coba --all-buildings.")

    if args.valley_fill:
        return _valley_fill(zone_dir, camps, args)

    blocks = []
    total_tents = 0
    for b in camps:
        poly = b.get("polygon", [])
        if len(poly) < 4:
            continue
        rot = _dominant_angle(poly)
        tents = _fill_block(poly, args.spacing, rot, args.edge_margin)
        if not tents:
            continue
        x0, z0, x1, z1 = _bbox(poly)
        blocks.append({
            "name": b.get("name", "Maktab"),
            "bbox": {"x0": round(x0, 2), "z0": round(z0, 2), "x1": round(x1, 2), "z1": round(z1, 2)},
            "center": {"x": round((x0 + x1) / 2, 2), "z": round((z0 + z1) / 2, 2)},
            "rot": rot,
            "tents": tents,
        })
        total_tents += len(tents)

    out = {
        "zone": args.zone,
        "tent_size_studs": args.tent_size,
        "count_blocks": len(blocks),
        "count_tents": total_tents,
        "blocks": blocks,
    }
    op = os.path.join(zone_dir, "tent_blocks.json")
    with open(op, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
    print(f"Zona {args.zone}: {len(blocks)} blok teras, {total_tents} tenda "
          f"(size {args.tent_size}, spacing {args.spacing}).")
    print(f"  -> {op}")
    print("Studio: build_mina.lua akan meratakan tiap blok (FillBlock) lalu sebar tenda di atasnya.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
