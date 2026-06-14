#!/usr/bin/env python3
"""generate_osm.py — Tarik jalan & bangunan OSM, petakan ke koordinat Roblox zona.

Sumber kebenaran = output/<zona>/import_manifest.json (geo_bounds + world_size_studs
+ flip_z). TIDAK ada resolusi/koordinat hardcoded — semua dibaca dari manifest, jadi
hasilnya presisi 1:1 dengan terrain yang sudah di-generate.

Output (di folder zona):
  osm_roads.json     -> daftar polyline jalan (path X/Z studs)
  osm_buildings.json -> daftar poligon bangunan (sudut X/Z studs)

Pemakaian:
  python generate_osm.py --zone B_Mina
  python generate_osm.py --manifest output/B_Mina/import_manifest.json
  python generate_osm.py --zone B_Mina --selftest   # uji konversi koordinat, TANPA jaringan

Konversi (origin di tengah, sesuai manifest):
  x = (lon - lon_min)/(lon_max - lon_min) * size_x - size_x/2
  z = (lat_max - lat)/(lat_max - lat_min) * size_z - size_z/2   (balik bila flip_z)
"""

from __future__ import annotations

import argparse
import json
import os
import sys

OVERPASS_URL = "https://overpass-api.de/api/interpreter"


class OsmError(RuntimeError):
    pass


def load_manifest(path: str) -> dict:
    if not os.path.isfile(path):
        raise OsmError(
            f"Manifest tidak ditemukan: '{path}'. Jalankan convert_terrain.py dulu "
            f"(mode zones) supaya output/<zona>/import_manifest.json tersedia."
        )
    with open(path, "r", encoding="utf-8") as f:
        m = json.load(f)
    if "geo_bounds" not in m:
        raise OsmError(
            f"Manifest '{path}' tak punya 'geo_bounds'. Pastikan GeoTIFF ber-geotag "
            f"& tool versi terbaru (geo_bounds ditulis otomatis)."
        )
    return m


def make_projector(manifest: dict):
    """Kembalikan fungsi (lon, lat) -> (x, z) studs berdasar manifest."""
    gb = manifest["geo_bounds"]
    size_x = float(manifest["world_size_studs"]["x"])
    size_z = float(manifest["world_size_studs"]["z"])
    flip_z = bool(manifest.get("flip_z", False))
    lon_min, lon_max = gb["lon_min"], gb["lon_max"]
    lat_min, lat_max = gb["lat_min"], gb["lat_max"]
    dlon = lon_max - lon_min
    dlat = lat_max - lat_min
    if dlon <= 0 or dlat <= 0:
        raise OsmError(f"geo_bounds tidak valid: {gb}")

    def project(lon: float, lat: float) -> tuple[float, float]:
        fx = (lon - lon_min) / dlon
        fz = (lat_max - lat) / dlat          # 0 di utara, 1 di selatan
        if flip_z:
            fz = 1.0 - fz
        x = fx * size_x - size_x / 2.0
        z = fz * size_z - size_z / 2.0
        return round(x, 2), round(z, 2)

    return project, gb, (size_x, size_z), flip_z


def build_query(gb: dict) -> str:
    # Overpass bbox: (lat_min, lon_min, lat_max, lon_max)
    bb = f"{gb['lat_min']},{gb['lon_min']},{gb['lat_max']},{gb['lon_max']}"
    return (
        "[out:json][timeout:120];\n"
        "(\n"
        f'  way["highway"]({bb});\n'
        f'  way["building"]({bb});\n'
        ");\n"
        "out geom;\n"
    )


def fetch_overpass(query: str, timeout: int = 180) -> dict:
    try:
        import requests
    except ImportError as e:
        raise OsmError(
            "Modul 'requests' belum terpasang. Jalankan: pip install requests"
        ) from e
    try:
        resp = requests.post(
            OVERPASS_URL,
            data={"data": query},
            headers={"User-Agent": "RUH-terrain-pipeline/1.0 (academic project)"},
            timeout=timeout,
        )
    except Exception as e:
        raise OsmError(f"Gagal menghubungi Overpass API: {e}") from e
    if resp.status_code != 200:
        raise OsmError(
            f"Overpass API balas HTTP {resp.status_code} "
            f"(server sibuk/rate-limit? coba lagi nanti). Body: {resp.text[:200]}"
        )
    return resp.json()


def parse_elements(data: dict, project) -> tuple[list, list]:
    roads, buildings = [], []
    for el in data.get("elements", []):
        if el.get("type") != "way" or "geometry" not in el:
            continue
        tags = el.get("tags", {})
        pts = [
            {"x": x, "z": z}
            for n in el["geometry"]
            for x, z in [project(n["lon"], n["lat"])]
        ]
        if len(pts) < 2:
            continue
        if "highway" in tags:
            roads.append({
                "name": tags.get("name", ""),
                "type": tags["highway"],
                "path": pts,
            })
        elif "building" in tags:
            if len(pts) < 3:
                continue
            buildings.append({
                "name": tags.get("name", "Bangunan"),
                "building": tags.get("building", "yes"),
                "polygon": pts,
            })
    return roads, buildings


def selftest(manifest: dict) -> bool:
    """Verifikasi konversi koordinat di sudut & tengah — TANPA jaringan."""
    project, gb, (sx, sz), flip_z = make_projector(manifest)
    ok = True

    def check(label, cond):
        nonlocal ok
        print(f"  [{'PASS' if cond else 'FAIL'}] {label}")
        ok = ok and cond

    # NW (lon_min, lat_max): pojok barat-laut. flip_z=False -> (-sx/2, -sz/2).
    x, z = project(gb["lon_min"], gb["lat_max"])
    exp_z = (sz / 2) if flip_z else (-sz / 2)
    check(f"pojok NW -> ({-sx/2:.0f},{exp_z:.0f})", abs(x + sx / 2) < 0.01 and abs(z - exp_z) < 0.01)

    # SE (lon_max, lat_min): pojok tenggara.
    x, z = project(gb["lon_max"], gb["lat_min"])
    exp_z = (-sz / 2) if flip_z else (sz / 2)
    check(f"pojok SE -> ({sx/2:.0f},{exp_z:.0f})", abs(x - sx / 2) < 0.01 and abs(z - exp_z) < 0.01)

    # Tengah geo -> (0,0).
    cx, cz = project((gb["lon_min"] + gb["lon_max"]) / 2, (gb["lat_min"] + gb["lat_max"]) / 2)
    check(f"tengah -> (0,0)  dapat ({cx:.1f},{cz:.1f})", abs(cx) < 0.01 and abs(cz) < 0.01)

    # Semua titik dalam batas [-size/2, +size/2].
    in_bounds = abs(cx) <= sx / 2 + 1 and abs(cz) <= sz / 2 + 1
    check("titik di dalam batas dunia", in_bounds)
    return ok


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="OSM -> koordinat Roblox (baca manifest zona).")
    g = p.add_mutually_exclusive_group(required=True)
    g.add_argument("--zone", help="Nama zona (mis. B_Mina) -> output/<zona>/import_manifest.json.")
    g.add_argument("--manifest", help="Path manifest langsung.")
    p.add_argument("--output-dir", help="Folder output JSON (default: folder manifest).")
    p.add_argument("--selftest", action="store_true", help="Uji konversi koordinat, tanpa jaringan.")
    args = p.parse_args(argv)

    manifest_path = args.manifest or os.path.join("output", args.zone, "import_manifest.json")
    try:
        manifest = load_manifest(manifest_path)
    except OsmError as e:
        print(f"ERROR: {e}")
        return 2

    out_dir = args.output_dir or os.path.dirname(os.path.abspath(manifest_path))
    zone = manifest.get("zone", os.path.basename(out_dir))
    print(f"Zona: {zone} | manifest: {manifest_path}")
    print(f"world_size_studs: {manifest['world_size_studs']} | flip_z: {manifest.get('flip_z')}")
    print(f"geo_bounds: {manifest['geo_bounds']}")

    if args.selftest:
        print("\n[SELFTEST] konversi koordinat (tanpa jaringan):")
        return 0 if selftest(manifest) else 1

    try:
        project, gb, _, _ = make_projector(manifest)
        print("\nMenarik data dari Overpass API (jalan + bangunan)...")
        data = fetch_overpass(build_query(gb))
        roads, buildings = parse_elements(data, project)
    except OsmError as e:
        print(f"ERROR: {e}")
        return 3

    meta = {
        "zone": zone,
        "world_size_studs": manifest["world_size_studs"],
        "origin": "center",
        "source": "OpenStreetMap via Overpass API",
    }
    roads_out = {**meta, "count": len(roads), "roads": roads}
    bld_out = {**meta, "count": len(buildings), "buildings": buildings}

    os.makedirs(out_dir, exist_ok=True)
    rp = os.path.join(out_dir, "osm_roads.json")
    bp = os.path.join(out_dir, "osm_buildings.json")
    with open(rp, "w", encoding="utf-8") as f:
        json.dump(roads_out, f, indent=2, ensure_ascii=False)
    with open(bp, "w", encoding="utf-8") as f:
        json.dump(bld_out, f, indent=2, ensure_ascii=False)

    print(f"\nSelesai: {len(roads)} jalan -> {rp}")
    print(f"         {len(buildings)} bangunan -> {bp}")
    print("Berikutnya: jalankan generator dinding Lua di Studio (baca osm_buildings.json).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
