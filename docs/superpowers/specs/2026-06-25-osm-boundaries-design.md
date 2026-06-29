# Desain: Batas masyair dari OSM nyata (Temuan B)

**Tanggal:** 2026-06-25
**Status:** disetujui, siap rencana implementasi
**Konteks audit:** `docs/WORLD_PIPELINE.md` §7 Temuan B.

## 1. Masalah

Di SEMUA zona, batas/gapura ("Batas Arafah/Muzdalifah"), guardline Mina, dan (kelak) batas
Haram Makkah dihasilkan sebagai **persegi/grid prosedural** di sekeliling bbox konten — bukan
poligon batas nyata dari OSM. Untuk Arafah & Muzdalifah ini bermakna syar'i/gameplay (wukuf
wajib DI DALAM batas Arafat; mabit di Muzdalifah; `WorldProviders.arafahZone` mengecek
keanggotaan). Tujuan: jadikan batas mengikuti **outline OSM nyata** bila tersedia, gagal-aman
ke perilaku lama bila tidak — dengan provenance eksplisit.

## 2. Lingkup

Konversi batas → poligon OSM nyata untuk **4 zona**: Arafah, Muzdalifah, guardline Mina, dan
batas Haram Makkah. MCK/lampu/fasilitas TIDAK diubah (kosmetik; lampu sudah ikut jalan nyata).

**Ekspektasi jujur:** Arafah & Muzdalifah paling berpeluang dapat poligon nyata. Mina & Haram
Makkah kemungkinan besar jatuh ke fallback prosedural (penandaan poligon OSM-nya sering
tak ada/tak bersih). Itu wajar dan terlihat dari field `source`.

## 3. Keputusan terkunci

- **Arsitektur:** util batas bersama + perluas `generate_osm` + modifikasi 4 generator zona
  (bukan generator mandiri, bukan fetch inline per-generator). Alasan: reuse satu fetch
  Overpass, tanpa konflik overwrite `boundary.json`/`guardline.json`, helper murni-Python
  bisa diuji headless.
- **Fallback:** poligon OSM bila ada → `source:"osm"`; bila tidak → persegi prosedural lama
  → `source:"procedural"` + log WARN. Tak pernah crash, tak pernah mengarang batas sebagai nyata.
- **Kompatibilitas:** output batas tetap SHAPE JSON yang sama (Arafah/Muzdalifah = `{gates:[{x,z}]}`,
  Mina = `{barriers:[{path:[..]}]}`) → skrip build Arafah/Muzdalifah/Mina **tidak diubah**.
  Hanya `build_makkah.lua` mendapat seksi render batas Haram (Makkah belum punya renderer batas).

## 4. Aliran data

```
generate_osm.py ─► osm_roads.json, osm_buildings.json, osm_boundaries.json (BARU)
_boundary_util.select_boundary(boundaries, center_xz, keywords) ─► polygon | None
generator zona:
   polygon ada ─► gates_along/barriers_along(polygon)   [source="osm"]
   else        ─► rect_gates/rect_barriers(bbox)         [source="procedural"]
```

## 5. Komponen

### 5.1 `generate_osm.py` (modifikasi)
- `build_query`: tambah `relation["boundary"](bb); way["boundary"](bb); relation["place"](bb);
  way["place"](bb);` dan area ber-nama masyair via `["name"~"عرفات|مزدلفة|منى|المسجد الحرام"]`.
  TIDAK menarik `landuse` (terlalu luas).
- `parse_elements` (atau fungsi baru `parse_boundaries`): kumpulkan closed way + relasi
  (rakit outer ring best-effort dari member `out geom`; gagal-rakit → skip kandidat itu).
  Hasil: list `{name, tags, polygon:[{x,z}]}` (≥3 titik).
- Tulis `osm_boundaries.json` (`{zone, count, boundaries:[...]}`) di folder zona.
- `--selftest` tetap jalan tanpa jaringan (parsing diuji terpisah dgn JSON kalengan).

### 5.2 `generators/_boundary_util.py` (BARU, murni-Python)
- `load_boundaries(zone_dir) -> list` (file opsional; tak ada → `[]`).
- `polygon_area(poly) -> float`, `point_in_poly(x, z, poly) -> bool`.
- `select_boundary(boundaries, center_xz, keywords) -> poly|None`: pilih kandidat ber-nama
  cocok `keywords` yang **melingkupi center**; bila >1 ambil **area terbesar**; bila tak ada
  yang name-match tapi ada poligon melingkupi center → kandidat sekunder (area terbesar);
  bila tetap kosong → `None`.
- `gates_along(poly, spacing) -> list[{x,z}]`: titik tiap `spacing` studs sepanjang keliling.
- `barriers_along(poly) -> list[{path:[{x,z},{x,z}]}]`: segmen tepi poligon.
- `rect_gates(x0,z0,x1,z1,spacing)` & `rect_barriers(x0,z0,x1,z1)`: fallback (logika persegi lama).

### 5.3 Generator zona (modifikasi)
- `generate_arafah.py`: batas via `select_boundary(..., keywords=["عرفات","arafat","arafa"],
  center=(jx,jz))`. OSM → `gates_along`, else `rect_gates(bbox konten)`. `boundary.json` +
  `"source"` + (bila OSM) `"polygon"`.
- `generate_muzdalifah.py`: idem, `keywords=["مزدلفة","muzdalifa","mash","حرام"]`, center=Masy'aril.
- `generate_mina_extras.py`: guardline via `keywords=["منى","mina"]`, center=Jamarat/konten.
  OSM → `barriers_along`, else `rect_barriers`. `guardline.json` + `"source"`.
- `generate_makkah.py`: `keywords=["المسجد الحرام","great mosque","grand mosque","حرم"]`,
  center=Ka'bah → tambah `haram_boundary:{polygon, gates, source}` ke `makkah_landmarks.json`.

### 5.4 `build_makkah.lua` (modifikasi — satu-satunya edit Studio)
- Seksi aditif `BatasHaram`: bila `L.haram_boundary` ada, render tiang sepanjang
  `L.haram_boundary.gates` (pola sama loop `Gerbang`). Tanpa data → lewati.

## 6. Penanganan error

- `osm_boundaries.json` absen → `load_boundaries`=`[]` → fallback prosedural (file opsional).
- Gagal jaringan `generate_osm` → jalur `OsmError` yang sudah ada (tak berubah).
- Relasi OSM gagal dirakit jadi ring → kandidat di-skip, bukan crash.
- Poligon < 3 titik → diabaikan.

## 7. Pengujian (headless, tanpa jaringan)

- **Unit `_boundary_util`:** `select_boundary` memilih poligon name-match terbesar yang
  melingkupi center; mengabaikan poligon di luar; `gates_along` spacing benar & tertutup;
  `barriers_along` menghasilkan N segmen utk poligon N-titik; `point_in_poly` & `polygon_area`
  benar; fallback `rect_*` setara perilaku lama.
- **Integrasi generator** (fixture sintetik manifest + osm_buildings + osm_boundaries):
  jalur OSM → `source="osm"` & gates/barriers ikut poligon; tanpa match → `source="procedural"`.
- **Parse `generate_osm`:** `parse_boundaries` atas Overpass JSON kalengan (closed way + relasi).
- Bersihkan zona uji sintetik setelah tiap run.

## 8. Provenance & kejujuran §5

Setiap JSON batas/guardline membawa `"source":"osm"|"procedural"`. Generator mencetak WARN saat
fallback. Tidak ada koordinat batas yang diklaim "nyata" tanpa sumber OSM aktual.

## 9. Di luar lingkup (YAGNI)

Posisi MCK/fasilitas, lampu (sudah ikut jalan), penyatuan multipolygon OSM rumit (best-effort
saja), batas administratif kota Makkah, validasi geometrik lanjutan.
