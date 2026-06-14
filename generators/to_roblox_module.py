#!/usr/bin/env python3
"""to_roblox_module.py — Bungkus JSON zona jadi ModuleScript Lua (anti limit Command Bar).

Command Bar Studio dibatasi 100.000 karakter, jadi data besar (ratusan bangunan,
ribuan tenda) tak bisa di-paste inline. Solusinya: simpan data di ModuleScript
(editor skrip TIDAK kena batas itu), lalu skrip loader mem-require-nya.

Skrip ini mengubah JSON (compact) jadi file .lua berisi:  return [==[ <json> ]==]

Pemakaian:
  python to_roblox_module.py --zone B_Mina
    -> output/B_Mina/MinaBuildings.module.lua  (dari osm_buildings_corridor.json)
       output/B_Mina/MinaBarriers.module.lua   (dari osm_barriers.json)
       output/B_Mina/MinaTents.module.lua       (dari mina_tents.json)

Di Studio:
  1. Buat ModuleScript di ReplicatedStorage bernama: MinaBuildings, MinaBarriers, MinaTents.
  2. Buka tiap ModuleScript (double-click) -> tempel SELURUH isi file .lua yang sesuai.
  3. Jalankan roblox_scripts/place_from_modules.lua di Command Bar (kecil, baca module).
"""

from __future__ import annotations

import argparse
import json
import os
import sys

# Nama ModuleScript -> file JSON sumber, per ZONA. File yang tak ada dilewati.
MAPS = {
    "B_Mina": {
        "MinaTerraces": "tent_blocks.json",
        "MinaBarriers": "guardline.json",
        "MinaJamarat": "jamarat.json",
        "MinaLamps": "lamps.json",
        "MinaRoute": "route_local.json",
    },
    "C_Arafah": {
        "ArafahJabalRahmah": "jabal_rahmah.json",
        "ArafahNamirah": "namirah.json",
        "ArafahBoundary": "boundary.json",
        "ArafahFacilities": "facilities.json",
        "ArafahMist": "mist.json",
        "ArafahRoute": "route_local.json",
    },
    "A_Makkah": {
        "MakkahLandmarks": "makkah_landmarks.json",
        "MakkahFacade": "makkah_facade.json",
        "MakkahRoute": "route_local.json",
    },
}


def wrap_module(name: str, json_path: str, out_path: str) -> int:
    with open(json_path, encoding="utf-8") as f:
        data = json.load(f)
    compact = json.dumps(data, separators=(",", ":"), ensure_ascii=False)
    if "]==]" in compact:  # sangat tak mungkin di JSON, tapi jaga-jaga
        raise SystemExit(f"JSON {json_path} mengandung ']==]' — butuh delimiter lain.")
    header = (
        f"-- ModuleScript: {name} (auto-generated dari {os.path.basename(json_path)})\n"
        f"-- Buat ModuleScript bernama '{name}' di ReplicatedStorage, tempel SELURUH\n"
        f"-- isi file ini ke dalamnya (lewat EDITOR SKRIP, bukan Command Bar).\n"
        f"return [==[{compact}]==]\n"
    )
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(header)
    return len(compact)


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="JSON zona -> ModuleScript Lua.")
    p.add_argument("--zone", required=True, help="Nama zona (output/<zona>/).")
    args = p.parse_args(argv)

    zone_dir = os.path.join("output", args.zone)
    mapping = MAPS.get(args.zone)
    if mapping is None:
        raise SystemExit(f"Tak ada peta module untuk zona '{args.zone}'. Zona dikenal: {list(MAPS)}.")
    made = 0
    for name, src in mapping.items():
        json_path = os.path.join(zone_dir, src)
        if not os.path.isfile(json_path):
            print(f"  (lewati {name}: {src} belum ada)")
            continue
        out_path = os.path.join(zone_dir, f"{name}.module.lua")
        n = wrap_module(name, json_path, out_path)
        warn = "  <-- masih > 100k, tapi MODULE tak kena batas Command Bar (aman)" if n > 100000 else ""
        print(f"  + {out_path}  ({n:,} char JSON compact){warn}")
        made += 1
    if not made:
        print("Tak ada file sumber. Jalankan generate_osm.py / corridor_filter.py / generate_tents.py dulu.")
        return 1
    print("\nLangkah Studio: buat ModuleScript di ReplicatedStorage (nama persis seperti di atas),")
    print("tempel isi tiap .lua, lalu jalankan roblox_scripts/place_from_modules.lua.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
