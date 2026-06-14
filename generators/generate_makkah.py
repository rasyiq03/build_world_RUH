#!/usr/bin/env python3
"""generate_makkah.py — Landmark & area Masjidil Haram (Zona A) dari OSM + spec.

Semua berpusat pada Ka'bah (anchor OSM ~origin). Output placeholder prosedural
(diganti model OBJ user nanti). Skala 4: 1 m = 4 studs.

Output (output/A_Makkah/):
  makkah_landmarks.json : kaaba, mataf, maqam_ibrahim, hijr_ismail, masaa,
                          clock_tower (Abraj), gates — spec relatif Ka'bah.
  makkah_facade.json    : footprint bangunan OSM cincin luar (dinding pembatas).

Pemakaian:  python generate_makkah.py --zone A_Makkah
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys

S = 4  # studs per meter


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
    args = p.parse_args(argv)

    zd = os.path.join("output", args.zone)
    blds = _load(zd, "osm_buildings.json")["buildings"]

    # Ka'bah anchor dari OSM (atau literatur).
    kb = next((b for b in blds if "كعبة" in b.get("name", "")), None)
    if kb:
        kx, kz, _, _ = _ctr(kb["polygon"])
    else:
        kx, kz = 86.0, -9.0
    kx, kz = round(kx, 2), round(kz, 2)

    # Abraj Al-Bait (menara jam) — literatur relatif Ka'bah (selatan).
    clock = {"x": kx - 220, "z": kz + 1728, "height": round(601 * S), "clock_color": [120, 255, 140]}

    landmarks = {
        "kaaba": {
            "center": {"x": kx, "z": kz},
            # Ka'bah ~11,03 x 12,86 x 13,1 m. Rotasi ~30° (Hajar Aswad sudut timur).
            "size": {"w": round(11.03 * S), "l": round(12.86 * S), "h": round(13.1 * S)},
            "rot": 30,
            "hajar_aswad_corner": "timur", "door_side": "timur-laut",
        },
        "mataf": {"center": {"x": kx, "z": kz}, "radius": round(50 * S)},   # pelataran marmer
        "maqam_ibrahim": {"x": kx, "z": kz - 13 * S, "dome_d": round(3 * S)},  # ~13 m depan pintu (NE≈-z)
        "hijr_ismail": {"center": {"x": kx, "z": kz - 9 * S}, "radius": round(8.5 * S), "wall_h": round(1.3 * S)},
        # Mas'a (Safa-Marwah) ~400 m, N-S di timur Haram (perkiraan — refine via model).
        "masaa": {"safa": {"x": kx + 520, "z": kz + 800}, "marwah": {"x": kx + 520, "z": kz - 800},
                  "width": round(20 * S), "green_zone": [-120, 120]},
        "clock_tower": clock,
        "gates": [
            {"name": "King_Abdulaziz_Gate", "x": kx, "z": kz + 760},
            {"name": "King_Fahd_Gate", "x": kx - 760, "z": kz},
            {"name": "Umrah_Gate", "x": kx + 760, "z": kz},
            {"name": "Fath_Gate", "x": kx, "z": kz - 760},
        ],
    }
    json.dump(landmarks, open(os.path.join(zd, "makkah_landmarks.json"), "w", encoding="utf-8"), ensure_ascii=False)
    print(f"Ka'bah @ ({kx},{kz}) | Mataf r={landmarks['mataf']['radius']} | "
          f"Maqam, Hijr Ismail, Mas'a, 4 gerbang, Abraj h={clock['height']} -> makkah_landmarks.json")

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
