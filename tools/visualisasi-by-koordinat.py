#!/usr/bin/env python3
"""visualisasi-by-koordinat.py — Peta spasial zona ritual RUH (Leaflet HTML).

Membaca zona dari `config.json` (box geo) -> `Visualisasi_Spasial_Roblox.html`:
peta OpenStreetMap dengan kotak tiap zona ritual (Makkah, Mina, Muzdalifah, Arafah),
penanda pusat + label, dan alur manasik skematik (siklus). DATA-DRIVEN: tambah/ubah
zona di config.json -> peta otomatis ikut. Tanpa dependensi (Leaflet via CDN).

Pemakaian:  python tools/visualisasi-by-koordinat.py   (dari root repo)
"""
from __future__ import annotations

import json
import os
import sys

# Label (Indonesia) + warna per zona. Zona tak terdaftar -> fallback abu-abu.
ZONA = {
    "A_Makkah":     {"label": "Makkah — Masjidil Haram (Tawaf, Sa'i)",                 "color": "#3186cc"},
    "B_Mina":       {"label": "Mina — Tenda & 3 Jamarat (lempar jumrah)",              "color": "#28a745"},
    "C_Arafah":     {"label": "Arafah — Wukuf (Jabal Rahmah, Namirah)",                "color": "#dc3545"},
    "D_Muzdalifah": {"label": "Muzdalifah — Mabit & ambil kerikil (Masy'aril Haram)",  "color": "#fd7e14"},
}
# Alur manasik haji (skematik, lewat pusat zona): siklus balik-balik.
FLOW_ORDER = ["A_Makkah", "B_Mina", "C_Arafah", "D_Muzdalifah", "B_Mina", "A_Makkah"]

TEMPLATE = """<!DOCTYPE html>
<html lang="id"><head><meta charset="utf-8"/>
<title>Peta Spasial Zona Ritual — RUH</title>
<meta name="viewport" content="width=device-width, initial-scale=1.0"/>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<style>
  html,body,#map{height:100%;margin:0}
  .legend{background:#fff;padding:9px 11px;border-radius:6px;font:13px/1.5 sans-serif;box-shadow:0 1px 4px #0003;max-width:270px}
  .legend b{display:block;margin-bottom:5px}
  .sw{display:inline-block;width:12px;height:12px;border-radius:2px;vertical-align:middle;margin-right:6px;opacity:.65}
  .zlbl{background:rgba(255,255,255,.85);border:none;box-shadow:0 1px 3px #0004;font-weight:600;padding:1px 5px}
</style></head><body><div id="map"></div>
<script>
const RECTS=__RECTS__, FLOW=__FLOW__;
const map=L.map('map');
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
  {maxZoom:19, attribution:'© OpenStreetMap'}).addTo(map);
let all=[];
RECTS.forEach(z=>{
  L.rectangle(z.bounds,{color:z.color,weight:2,fillColor:z.color,fillOpacity:.25}).addTo(map)
    .bindPopup('<b>'+z.label+'</b><br>zona: '+z.name);
  L.marker(z.center).addTo(map).bindTooltip(z.label,{permanent:true,direction:'top',className:'zlbl'});
  all=all.concat(z.bounds);
});
if(FLOW.length>1){
  L.polyline(FLOW,{color:'#444',weight:2,dashArray:'8 8',opacity:.85}).addTo(map)
   .bindPopup('Alur manasik (skematik): Makkah → Mina → Arafah → Muzdalifah → Mina → Makkah');
}
if(all.length) map.fitBounds(all,{padding:[35,35]});
const lg=L.control({position:'topright'});
lg.onAdd=()=>{const d=L.DomUtil.create('div','legend');
  let h='<b>Zona Ritual RUH (Main Place)</b>';
  RECTS.forEach(z=>{h+='<div><span class="sw" style="background:'+z.color+'"></span>'+z.label+'</div>';});
  h+='<div style="margin-top:6px;border-top:1px solid #ddd;padding-top:5px">'
    +'- - - alur manasik (skematik)<br><small>5 miqat di luar bingkai (jauh dari Makkah)</small></div>';
  d.innerHTML=h;return d;};
lg.addTo(map);
</script></body></html>"""


def main(argv=None) -> int:
    if not os.path.isfile("config.json"):
        raise SystemExit("config.json tak ada. Jalankan dari root repo: python tools/visualisasi-by-koordinat.py")
    cfg = json.load(open("config.json", encoding="utf-8"))
    zones = cfg.get("zones", [])
    if not zones:
        raise SystemExit("Tak ada 'zones' di config.json.")

    rects, centers = [], {}
    for z in zones:
        name = z["name"]
        lon0, lat0, lon1, lat1 = z["box"]  # [lon_min, lat_min, lon_max, lat_max]
        meta = ZONA.get(name, {"label": name, "color": "#666666"})
        center = [(lat0 + lat1) / 2.0, (lon0 + lon1) / 2.0]
        centers[name] = center
        rects.append({
            "name": name, "label": meta["label"], "color": meta["color"],
            "bounds": [[lat0, lon0], [lat1, lon1]], "center": center,
        })

    flow = [centers[n] for n in FLOW_ORDER if n in centers]

    html = (TEMPLATE
            .replace("__RECTS__", json.dumps(rects, ensure_ascii=False))
            .replace("__FLOW__", json.dumps(flow, ensure_ascii=False)))
    out = "Visualisasi_Spasial_Roblox.html"
    with open(out, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"OK {out}: {len(rects)} zona -> {', '.join(r['name'] for r in rects)}")
    print("Buka di browser (butuh internet untuk tile peta).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
