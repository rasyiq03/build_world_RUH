#!/usr/bin/env python3
"""trace_hajj_route.py — Lacak jalur manasik di jaringan jalan OSM (pathfinding).

Fetch SEMUA jalan OSM di koridor Makkah-Mina-Muzdalifah-Arafah, bangun graf,
lalu shortest-path tiap segmen (start->end landmark) MENGIKUTI JALAN NYATA.
Menandai bagian TEROWONGAN (tunnel) supaya nanti dibangun sebagai terowongan.

Output: hajj_route_traced.json  (segmen + polyline lon/lat + flag tunnel + panjang m)

Pemakaian:
  python trace_hajj_route.py --route hajj_route.json
"""

from __future__ import annotations

import argparse
import heapq
import json
import math
import os
import sys

# Faktor bobot per kelas jalan (kecil = lebih disukai pejalan kaki).
WCLASS = {
    "pedestrian": 1.0, "footway": 1.0, "path": 1.05, "steps": 1.2, "living_street": 1.1,
    "residential": 1.15, "service": 1.2, "unclassified": 1.15, "track": 1.3,
    "tertiary": 1.1, "secondary": 1.05, "primary": 1.0, "trunk": 1.05,
    "motorway": 5.0,  # pilgrim tak jalan di tol
}


def _hav(a, b):
    """Jarak meter antara (lon,lat) a & b."""
    R = 6371000.0
    lon1, lat1 = map(math.radians, a)
    lon2, lat2 = map(math.radians, b)
    dlon, dlat = lon2 - lon1, lat2 - lat1
    h = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    return 2 * R * math.asin(math.sqrt(h))


def fetch_graph(bbox):
    """Fetch ways+nodes OSM -> (coords{id:(lon,lat)}, adj{id:[(nb,w,length,tunnel)]})."""
    import requests
    lat0, lon0, lat1, lon1 = bbox
    q = (f"[out:json][timeout:240];way[\"highway\"]({lat0},{lon0},{lat1},{lon1});"
         f"out body;>;out skel qt;")
    print("Fetch jaringan jalan koridor dari Overpass (bisa beberapa puluh detik)...")
    r = requests.post("https://overpass-api.de/api/interpreter", data={"data": q},
                      headers={"User-Agent": "RUH-hajj-route/1.0"}, timeout=300)
    r.raise_for_status()
    data = r.json()
    coords = {}
    ways = []
    for el in data["elements"]:
        if el["type"] == "node":
            coords[el["id"]] = (el["lon"], el["lat"])
        elif el["type"] == "way":
            ways.append(el)
    adj = {}
    for w in ways:
        tags = w.get("tags", {})
        cls = tags.get("highway", "")
        wf = WCLASS.get(cls.replace("_link", ""), 1.2)
        tunnel = 1 if tags.get("tunnel") else 0
        nodes = w.get("nodes", [])
        for i in range(len(nodes) - 1):
            a, b = nodes[i], nodes[i + 1]
            if a not in coords or b not in coords:
                continue
            d = _hav(coords[a], coords[b])
            adj.setdefault(a, []).append((b, d * wf, d, tunnel))
            adj.setdefault(b, []).append((a, d * wf, d, tunnel))
    print(f"  graf: {len(coords)} node, {len(ways)} way.")
    return coords, adj


def nearest_node(coords, lon, lat):
    best, bd = None, 1e18
    for nid, (clon, clat) in coords.items():
        d = (clon - lon) ** 2 + (clat - lat) ** 2
        if d < bd:
            bd, best = d, nid
    return best


def dijkstra(adj, src, dst):
    dist = {src: 0.0}
    prev = {}
    pq = [(0.0, src)]
    while pq:
        d, u = heapq.heappop(pq)
        if u == dst:
            break
        if d > dist.get(u, 1e18):
            continue
        for v, w, length, tun in adj.get(u, []):
            nd = d + w
            if nd < dist.get(v, 1e18):
                dist[v] = nd
                prev[v] = (u, length, tun)
                heapq.heappush(pq, (nd, v))
    if dst not in prev and dst != src:
        return None
    # rekonstruksi
    path = [dst]
    edges = []
    cur = dst
    while cur in prev:
        u, length, tun = prev[cur]
        edges.append((length, tun))
        path.append(u)
        cur = u
    path.reverse(); edges.reverse()
    return path, edges


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="Lacak jalur manasik di jaringan jalan OSM.")
    p.add_argument("--route", default="hajj_route.json")
    p.add_argument("--margin", type=float, default=0.01, help="Margin bbox koridor (derajat).")
    args = p.parse_args(argv)

    route = json.load(open(args.route, encoding="utf-8"))
    segs = route["segments"]
    lons = [c for s in segs for c in (s["start"][0], s["end"][0])]
    lats = [c for s in segs for c in (s["start"][1], s["end"][1])]
    m = args.margin
    bbox = (min(lats) - m, min(lons) - m, max(lats) + m, max(lons) + m)
    print(f"Koridor bbox (lat,lon): {bbox}")

    coords, adj = fetch_graph(bbox)

    out_segs = []
    for s in segs:
        a = nearest_node(coords, *s["start"])
        b = nearest_node(coords, *s["end"])
        res = dijkstra(adj, a, b)
        if not res:
            print(f"  [{s['from']}->{s['to']}] TAK ADA jalur tersambung!")
            continue
        path, edges = res
        poly = [list(coords[n]) for n in path]
        length_m = sum(e[0] for e in edges)
        tunnel_m = sum(e[0] for e in edges if e[1])
        # mask tunnel per titik (titik i memakai tunnel-flag edge masuknya)
        tmask = [0] + [e[1] for e in edges]
        out_segs.append({
            "from": s["from"], "to": s["to"], "ritual": s["ritual"],
            "length_m": round(length_m), "tunnel_m": round(tunnel_m),
            "points": len(poly), "polyline_lonlat": [[round(x, 6), round(y, 6)] for x, y in poly],
            "tunnel_mask": tmask,
        })
        print(f"  [{s['from']:>11} -> {s['to']:<11}] {length_m/1000:5.2f} km, {len(poly):4d} titik"
              + (f", TEROWONGAN {tunnel_m:.0f} m" if tunnel_m > 0 else ""))

    out = {"ritual_order": route["ritual_order"], "segments": out_segs}
    with open("hajj_route_traced.json", "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False)
    total = sum(s["length_m"] for s in out_segs)
    print(f"Total jalur manasik: {total/1000:.1f} km -> hajj_route_traced.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
