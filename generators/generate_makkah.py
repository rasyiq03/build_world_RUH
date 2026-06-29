#!/usr/bin/env python3
"""generate_makkah.py — Landmark & area Masjidil Haram (Zona A) dari OSM + koordinat nyata.

Sumber kebenaran koordinat = output/A_Makkah/import_manifest.json (geo_bounds). Landmark
besar (Ka'bah, Abraj Al-Bait, Safa, Marwah) diproyeksi dari lon/lat DUNIA-NYATA via manifest
(pola identik generate_arafah/muzdalifah). Maqam Ibrahim & Hijr Ismail ditempatkan dari JARAK
METER NYATA relatif Ka'bah (≈13 m / radius 8,5 m) — relasi metrik yang memang terdefinisi
terhadap Ka'bah. Gerbang dari bearing nyata 4 sisi (ditandai approx). Output placeholder
prosedural (diganti model OBJ user nanti). Skala dibaca dari manifest (default 4: 1 m = 4 studs).

Output (output/A_Makkah/):
  makkah_landmarks.json : kaaba, mataf, maqam_ibrahim, hijr_ismail, masaa,
                          clock_tower (Abraj), gates — koordinat studs hasil proyeksi.
  makkah_facade.json    : footprint bangunan OSM cincin luar (dinding pembatas).

Pemakaian:  python generate_makkah.py --zone A_Makkah
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys

S_FALLBACK = 4  # studs per meter bila manifest tak punya scale_studs_per_m

# Landmark DUNIA-NYATA (lon, lat) — literatur; diproyeksi via manifest (refine via model/OSM).
LANDMARKS_LONLAT = {
    "kaaba":  (39.826167, 21.422510),  # Ka'bah (anchor; OSM كعبة diutamakan bila ada)
    "abraj":  (39.825710, 21.418670),  # Makkah Royal Clock Tower (Abraj Al-Bait), ~430 m S
    "safa":   (39.827650, 21.421990),  # ujung SELATAN Mas'a (Bukit Safa), ~57 m S Ka'bah
    "marwah": (39.826900, 21.425350),  # ujung UTARA Mas'a (Bukit Marwah), ~380 m dari Safa
}


def _load(zd, name):
    p = os.path.join(zd, name)
    if not os.path.isfile(p):
        raise SystemExit(f"ERROR: {p} tak ada.")
    with open(p, encoding="utf-8") as f:
        return json.load(f)


def _ctr(poly):
    xs = [p["x"] for p in poly]; zs = [p["z"] for p in poly]
    return sum(xs) / len(xs), sum(zs) / len(zs), max(xs) - min(xs), max(zs) - min(zs)


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="Landmark Masjidil Haram.")
    p.add_argument("--zone", default="A_Makkah")
    p.add_argument("--facade-inner", type=float, default=1400.0, help="Radius dalam cincin façade (studs).")
    p.add_argument("--facade-outer", type=float, default=4500.0, help="Radius luar cincin façade (studs).")
    p.add_argument("--facade-min-area", type=float, default=12000.0, help="Luas min bangunan façade (studs^2).")
    p.add_argument("--gate-dist-m", type=float, default=200.0, help="Jarak gerbang dari Ka'bah (meter, approx).")
    args = p.parse_args(argv)

    zd = os.path.join("output", args.zone)
    man = _load(zd, "import_manifest.json")
    blds = _load(zd, "osm_buildings.json")["buildings"]

    gb = man["geo_bounds"]
    sx = float(man["world_size_studs"]["x"]); sz = float(man["world_size_studs"]["z"])
    scale = float(man.get("scale_studs_per_m", S_FALLBACK))
    flip_z = bool(man.get("flip_z", False))
    dlon = gb["lon_max"] - gb["lon_min"]; dlat = gb["lat_max"] - gb["lat_min"]

    def to_xz(lon, lat):
        """(lon,lat) -> (x,z) studs via manifest. +x = timur, +z = selatan."""
        fx = (lon - gb["lon_min"]) / dlon
        fz = (gb["lat_max"] - lat) / dlat
        if flip_z:
            fz = 1.0 - fz
        return round(fx * sx - sx / 2, 2), round(fz * sz - sz / 2, 2)

    def offset(cx, cz, east_m, north_m):
        """Geser dari (cx,cz) sejauh meter nyata. +x = timur, utara = -z."""
        return round(cx + east_m * scale, 2), round(cz - north_m * scale, 2)

    # --- KA'BAH: anchor dari OSM (كعبة) bila ada, else proyeksi lon/lat nyata ---
    kb = next((b for b in blds if "كعبة" in b.get("name", "")), None)
    if kb:
        kx, kz, _, _ = _ctr(kb["polygon"])
        kx, kz = round(kx, 2), round(kz, 2); ksrc = "OSM"
    else:
        kx, kz = to_xz(*LANDMARKS_LONLAT["kaaba"]); ksrc = "literatur (lon/lat)"

    # --- ABRAJ AL-BAIT: proyeksi lon/lat nyata (≈430 m S Ka'bah) ---
    ax, az = to_xz(*LANDMARKS_LONLAT["abraj"])
    clock = {"x": ax, "z": az, "height": round(601 * scale), "clock_color": [120, 255, 140]}

    # --- MAQAM IBRAHIM: ≈13 m timur-laut Ka'bah (depan pintu) ---
    mqx, mqz = offset(kx, kz, east_m=9.2, north_m=9.2)  # 13 m NE = 13/√2 per komponen

    # --- HIJR ISMAIL: ≈9 m barat-laut Ka'bah, radius 8,5 m ---
    hix, hiz = offset(kx, kz, east_m=-6.4, north_m=6.4)  # 9 m NW

    # --- MAS'A (Safa-Marwah): proyeksi lon/lat nyata, di timur Haram ---
    sax, saz = to_xz(*LANDMARKS_LONLAT["safa"])
    mwx, mwz = to_xz(*LANDMARKS_LONLAT["marwah"])

    # --- GERBANG: bearing nyata 4 sisi (jarak approx; tandai approx=true) ---
    gd = args.gate_dist_m
    diag = gd * 0.7071
    gate_spec = [
        ("King_Abdulaziz_Gate", 0.0, -gd),     # SELATAN (gerbang utama selatan)
        ("King_Fahd_Gate", -gd, 0.0),          # BARAT
        ("Umrah_Gate", -diag, diag),           # BARAT-LAUT
        ("Fath_Gate", 0.0, gd),                # UTARA
    ]
    gates = []
    for name, e, n in gate_spec:
        gx, gz = offset(kx, kz, e, n)
        gates.append({"name": name, "x": gx, "z": gz, "approx": True})

    landmarks = {
        "_provenance": "Ka'bah=" + ksrc + "; Abraj/Safa/Marwah=lon/lat literatur via manifest; "
                       "Maqam/Hijr=offset meter nyata dari Ka'bah; gerbang=bearing nyata (approx).",
        "kaaba": {
            "center": {"x": kx, "z": kz},
            # Ka'bah ~11,03 x 12,86 x 13,1 m. Rotasi ~30° (Hajar Aswad sudut timur).
            "size": {"w": round(11.03 * scale), "l": round(12.86 * scale), "h": round(13.1 * scale)},
            "rot": 30,
            "hajar_aswad_corner": "timur", "door_side": "timur-laut",
        },
        "mataf": {"center": {"x": kx, "z": kz}, "radius": round(50 * scale)},   # pelataran marmer ~50 m
        "maqam_ibrahim": {"x": mqx, "z": mqz, "dome_d": round(3 * scale)},
        "hijr_ismail": {"center": {"x": hix, "z": hiz}, "radius": round(8.5 * scale), "wall_h": round(1.3 * scale)},
        "masaa": {"safa": {"x": sax, "z": saz}, "marwah": {"x": mwx, "z": mwz},
                  "width": round(20 * scale), "green_zone": [-120, 120]},
        "clock_tower": clock,
        "gates": gates,
    }
    json.dump(landmarks, open(os.path.join(zd, "makkah_landmarks.json"), "w", encoding="utf-8"), ensure_ascii=False)
    print(f"Ka'bah @ ({kx},{kz}) [{ksrc}] | Abraj @ ({ax},{az}) | Mataf r={landmarks['mataf']['radius']}")
    print(f"  Maqam ({mqx},{mqz}) | Hijr ({hix},{hiz}) | Safa ({sax},{saz}) Marwah ({mwx},{mwz})")
    print(f"  {len(gates)} gerbang (approx) -> makkah_landmarks.json")

    # --- FAÇADE: bangunan OSM di cincin [inner,outer] dari Ka'bah, cukup besar ---
    facade = []
    for b in blds:
        cx, cz, w, l = _ctr(b["polygon"])
        r = math.hypot(cx - kx, cz - kz)
        if args.facade_inner <= r <= args.facade_outer and (w * l) >= args.facade_min_area:
            facade.append({"name": b.get("name", ""), "polygon": b["polygon"]})
    json.dump({"count": len(facade), "buildings": facade},
              open(os.path.join(zd, "makkah_facade.json"), "w", encoding="utf-8"), ensure_ascii=False)
    print(f"Façade: {len(facade)} bangunan cincin luar [{args.facade_inner:.0f}-{args.facade_outer:.0f} studs] -> makkah_facade.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
