# PROGRESS — Zona B: Mina

Catatan progres & perubahan Zona Mina. (Doc sejenis untuk Arafah & Mekkah menyusul.)

> Konvensi: skala **4 studs/m** (1 stud = 0,25 m). Karakter Roblox ~5 studs ≈ human →
> bangunan/tenda berukuran nyata BISA dimasuki. Normalisasi elevasi GLOBAL (lintas zona).

---

## Status: TERRAIN + KONTEN DASAR SELESAI, masuk tahap DETAILING

- **.rbxl terukur: ~15,5 MB** (`output/B_Mina/tes mina.rbxl`) — jauh < 100 MB,
  sisa ~84 MB untuk model & detail. Arsitektur multi-place + crop terbukti.

### Parameter zona
- Box (Opsi B, content-driven): `[39.862, 21.401, 39.900, 21.425]` (~3,94 × 2,67 km).
- Dunia: **15.672 × 10.760 studs**, 3 tile, Size_Y 3328, elevasi global 128–960 m.
- Box masih bisa dipersempit/disesuaikan dari Google Maps bila perlu.

---

## Pipeline & artefak (di `output/B_Mina/`)

| Tahap | Tool (Python) | Output | Konsumen Studio (Lua) |
|---|---|---|---|
| Terrain | `convert_terrain.py` (zones) | 3 PNG + `import_manifest.json` + IMPORT_GUIDE | Terrain Importer (manual, 3 tile) |
| OSM | `generate_osm.py` (user fetch) | `osm_roads.json`, `osm_buildings.json` | — |
| Teras+tenda | `generate_terraces.py --valley-fill` | `tent_blocks.json` (403 blok, **7.160 tenda**) | `build_mina.lua` |
| Jamarat/lampu/guard | `generate_mina_extras.py` | `jamarat.json`, `lamps.json` (230, area konten), `guardline.json` | `build_mina.lua` |
| Rute | `hajj_route.json`→`trace_hajj_route.py`→`project_route.py` | `route_local.json` (+ master `hajj_route_traced.json`) | `render_route.lua`, `nav_guide.lua` |
| Modul | `to_roblox_module.py` | `*.module.lua` (MinaTerraces/Barriers/Jamarat/Lamps/Route) | ModuleScript di ReplicatedStorage |

Tutorial impor lengkap: `../TUTORIAL_MINA.md`.

### Mesh
- `models/tenda_mina.obj` (2 objek: kain+baja, Y-up, low-poly) → `TentMaster` di
  ReplicatedStorage, ukuran ~32 studs. Pola **master-clone** (1 mesh, ribuan instance).
- Model besar (Masjidil Haram, Jamarat, dll.) akan ditaruh user di `models/` (OBJ).

---

## Konten yang sudah terbangun (via build_mina.lua + render_route.lua)
- Terrain Mina (lembah, elevasi nyata).
- **Teras**: 403 blok diratakan (Terrain:FillBlock carve+fill) → tenda berdiri di
  platform datar berundak (rapi, bukan miring di lereng).
- **7.160 tenda** (clone TentMaster) di area camp NW.
- **Jamarat**: penanda di `جسر الجمرات` (center ~ −3440, −3518).
- **Lampu**: 230 titik di jalan utama dalam area konten.
- **Guardline**: persegi pembatas keliling konten.
- **Jalur manasik** + **navigasi melayang** (panah + meter + ETA, WalkSpeed
  realistis 6 studs/s, SHIFT=percepat → ETA memendek).

---

## Perubahan DETAILING (sudah di skrip, BELUM di-run user — per 2026-06-09)

1. **Jalan final + menjuntai terrain** (`render_route.lua`): subdivide + raycast
   tiap ~30 studs → jalan ikut tanah (tak terendam/melayang), aspal realistis.
2. **Tenda bisa dimasuki**: `build_mina.lua` set tent CanCollide=false (walk-through).
   *(Pintu/rongga asli = edit mesh Blender nanti.)*
3. **Jamarat multi-lantai**: `build_mina.lua` → 5 deck jalan-layang + pagar + 3 tugu
   batu (Jamratul Ula/Wusta/Aqabah) menembus lantai. Lebih dikenali.

> Untuk menerapkan: re-paste `build_mina.lua` lalu `render_route.lua`, re-run.

---

## PENDING / kandidat detailing berikutnya
- [ ] **Kecualikan tenda** di radius footprint Jamarat (sekarang menumpuk).
- [ ] **Tenda hero** berfurnitur (kursi + sejadah) di beberapa tenda dekat jalur.
- [ ] **Bangun terowongan** sungguhan di ruas tunnel (excavate + tabung).
- [ ] **Sistem teleport** antar-place (aktif setelah Arafah/Mekkah ada): trigger di
      gate KELUAR → spawn di MASUK zona berikut.
- [ ] **Model detail** Jamarat & bangunan utama (dari `models/`, OBJ) menggantikan
      penanda prosedural — via proses detailing (Claude baca OBJ).
- [ ] Mesh tenda dengan **pintu/rongga** (Blender) menggantikan walk-through.

---

## Urutan ritual (acuan rute & teleport)
**Makkah → Mina → Arafah → Muzdalifah → Mina (Jamarat) → Makkah** (Mina 2×).
Rute terlacak di jalan OSM nyata, total **42,1 km**, terowongan terdeteksi
(Makkah↔Mina ~2 km). Peta: `../route_map.html`.
