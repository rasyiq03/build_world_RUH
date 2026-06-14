#!/usr/bin/env python3
"""visualize_route.py — Peta interaktif jalur manasik (hajj_route_traced.json -> HTML).

Membuat route_map.html: peta Leaflet (OpenStreetMap) dengan polyline tiap segmen
(warna beda), bagian TEROWONGAN ditandai merah putus-putus, + penanda landmark.
Buka file-nya di browser (butuh internet untuk tile peta).

Pemakaian:
  python visualize_route.py
"""

from __future__ import annotations

import json
import os
import sys

SEG_COLORS = ["#1f77b4", "#2ca02c", "#ff7f0e", "#9467bd", "#17becf", "#8c564b"]


def _runs(poly, mask):
    """Pecah polyline jadi sub-segmen [(is_tunnel, [[lat,lon],...]), ...]."""
    out = []
    cur = [[poly[0][1], poly[0][0]]]
    cur_t = mask[1] if len(mask) > 1 else 0
    for i in range(1, len(poly)):
        t = mask[i] if i < len(mask) else 0
        if t != cur_t:
            cur.append([poly[i][1], poly[i][0]])
            out.append((cur_t, cur))
            cur = [[poly[i][1], poly[i][0]]]
            cur_t = t
        else:
            cur.append([poly[i][1], poly[i][0]])
    out.append((cur_t, cur))
    return out


def main(argv=None) -> int:
    if not os.path.isfile("hajj_route_traced.json"):
        raise SystemExit("hajj_route_traced.json tak ada. Jalankan trace_hajj_route.py dulu.")
    traced = json.load(open("hajj_route_traced.json", encoding="utf-8"))
    landmarks = {}
    if os.path.isfile("hajj_route.json"):
        landmarks = json.load(open("hajj_route.json", encoding="utf-8")).get("landmarks", {})

    # Susun data segmen untuk JS.
    segs_js = []
    for i, s in enumerate(traced["segments"]):
        poly = s["polyline_lonlat"]; mask = s.get("tunnel_mask", [])
        runs = _runs(poly, mask)
        segs_js.append({
            "label": f"{s['from']} -> {s['to']}",
            "ritual": s["ritual"],
            "km": round(s["length_m"] / 1000, 2),
            "tunnel_m": s.get("tunnel_m", 0),
            "color": SEG_COLORS[i % len(SEG_COLORS)],
            "runs": [{"t": t, "pts": pts} for t, pts in runs],
        })
    marks_js = [{"name": k, "ll": [v[1], v[0]]} for k, v in landmarks.items()]

    html = """<!DOCTYPE html>
<html lang="id"><head><meta charset="utf-8"/>
<title>Jalur Manasik Haji — RUH</title>
<meta name="viewport" content="width=device-width, initial-scale=1.0"/>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<style>
  html,body,#map{height:100%;margin:0}
  .legend{background:#fff;padding:8px 10px;border-radius:6px;font:13px/1.4 sans-serif;box-shadow:0 1px 4px #0003}
  .legend b{display:inline-block;margin-top:4px}
  .sw{display:inline-block;width:14px;height:4px;vertical-align:middle;margin-right:6px}
</style></head><body><div id="map"></div>
<script>
const SEGS = __SEGS__;
const MARKS = __MARKS__;
const map = L.map('map');
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
  {maxZoom:19, attribution:'© OpenStreetMap'}).addTo(map);
let all = [];
SEGS.forEach(s => {
  s.runs.forEach(r => {
    const style = r.t
      ? {color:'#d62728', weight:5, dashArray:'6 8', opacity:0.95}   // terowongan
      : {color:s.color, weight:5, opacity:0.9};
    const pl = L.polyline(r.pts, style).addTo(map);
    pl.bindPopup(`<b>${s.label}</b><br>${s.ritual}<br>${s.km} km`
      + (s.tunnel_m? `<br>terowongan total ${s.tunnel_m} m`:'')
      + (r.t? '<br><i>(ruas terowongan)</i>':''));
    all = all.concat(r.pts);
  });
});
MARKS.forEach(m => L.marker(m.ll).addTo(map).bindPopup('<b>'+m.name+'</b>'));
if(all.length) map.fitBounds(all);
// Legend
const lg = L.control({position:'topright'});
lg.onAdd = () => { const d=L.DomUtil.create('div','legend');
  let h='<b>Jalur Manasik Haji</b><br>';
  SEGS.forEach(s=>{h+=`<span class="sw" style="background:${s.color}"></span>${s.label} (${s.km} km)<br>`;});
  h+='<span class="sw" style="background:#d62728"></span>terowongan 🚇';
  d.innerHTML=h; return d; };
lg.addTo(map);
</script></body></html>"""
    html = html.replace("__SEGS__", json.dumps(segs_js, ensure_ascii=False))
    html = html.replace("__MARKS__", json.dumps(marks_js, ensure_ascii=False))
    with open("route_map.html", "w", encoding="utf-8") as f:
        f.write(html)
    total = sum(s["km"] for s in segs_js)
    print(f"route_map.html dibuat: {len(segs_js)} segmen, {total:.1f} km, {len(marks_js)} landmark.")
    print("Buka route_map.html di browser (butuh internet untuk tile peta).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
