# WORLD_PIPELINE.md — Peta End-to-End Pembangunan Dunia RUH

> **Tujuan dokumen:** menjawab "file ini gunanya apa, datanya dari mana, jadinya apa di Studio, dan
> siapa yang membacanya saat game jalan." Dunia RUH **dibangun dari data nyata** (SRTM + OpenStreetMap),
> bukan asal taruh. Tapi rantainya panjang & sebagian belum sinkron — semua dipetakan di sini.
>
> Anchor desain: [GAME_DESIGN.md](GAME_DESIGN.md). Kontrak terrain: [SPEC.md](SPEC.md) ·
> [PIPELINE.md](PIPELINE.md). Implementasi di Studio: [STUDIO_IMPLEMENTATION.md](STUDIO_IMPLEMENTATION.md).

## 0. Rantai besar (5 lapis)

```
(1) SRTM .tif ──convert_terrain.py (paket terrain/)──► output/<zona>/ : PNG 16-bit + import_manifest.json
                                                          │  (geo_bounds, world_size_studs, flip_z, scale 4)
(2) OSM ──generators/*.py (baca manifest, no hardcode)──► output/<zona>/ : *.json (roads, route, landmarks…)
(3) JSON ──to_roblox_module.py──► output/<zona>/<Nama>.module.lua   (anti limit Command Bar 100k)
(4) STUDIO (Command Bar): Terrain Importer(PNG)→terrain ; build_<zona>.lua / place_*.lua (baca ModuleScript)
                          → Folder di Workspace ; render_route.lua → aspal ; nav_guide.lua → panah (client)
(5) RUNTIME: WorldProviders/PlaceContext baca NODE Workspace hasil (4) → ctx → mechanisms
```

**Sumber kebenaran koordinat = `output/<zona>/import_manifest.json`** (geo_bounds + world_size_studs).
Tidak ada koordinat hardcode di generator (§ aturan AGENTS §3/§8.3).

> ⚠️ **`output/` di-`.gitignore`.** Semua `*.json` & `*.module.lua` di atas TIDAK ada di repo —
> tiap orang **regenerate** (lihat §5). Yang di-commit hanya kode generator + skrip Studio.

---

## 1. Lapis 1 — Terrain (`convert_terrain.py` + paket `terrain/`)

| File | Guna |
|---|---|
| `convert_terrain.py` | CLI: SRTM `.tif` → PNG 16-bit per-tile + manifest. Kontrak: [PIPELINE.md](PIPELINE.md). |
| `terrain/config.py·geo.py·io.py·normalize.py·tiling.py·manifest.py` | paket internal: load config, georeferensi, baca/tulis, normalisasi **GLOBAL**, tata-letak tile, tulis manifest. |
| `config.json` | **4 zona** + box geo + skala 4. Zona: `A_Makkah, B_Mina, C_Arafah, D_Muzdalifah`. |
| `tools/make_demo_dem.py` | DEM sintetis untuk uji tanpa SRTM. |
| `tests/test_pipeline.py` | smoke test terrain (34/34). |

Output per zona: `output/<zona>/RUH_tile_*.png` + `import_manifest.json` + `IMPORT_GUIDE.md`.

## 2. Lapis 2 — Konten dari OSM (`generators/`)

| Generator | Input | Output JSON (di `output/<zona>/`) |
|---|---|---|
| `generate_osm.py` | OSM (Overpass) + manifest | `osm_roads.json`, `osm_buildings.json`, `osm_barriers.json` |
| `corridor_filter.py` | `osm_buildings.json` + rute | `osm_buildings_corridor.json` (hemat instance: hanya gedung tepi jalan) |
| `roads_to_colormap.py` | `osm_roads.json` | **Colormap PNG** (jalan kota dicat ke terrain, **0 Part**) |
| `trace_hajj_route.py` | OSM koridor Makkah–Mina–Muzdalifah–Arafah | `hajj_route_traced.json` (root) — polyline jalan **NYATA** + flag terowongan |
| `project_route.py` | `hajj_route_traced.json` + manifest | `route_local.json` (studs lokal) + `route.json` (waypoint) |
| `generate_terraces.py` | `osm_roads.json` | `tent_blocks.json` (blok teras + titik tenda) |
| `generate_tents.py` | `route.json` + `osm_roads.json` | `mina_tents.json` (ribuan titik tenda) |
| `generate_mina_extras.py` | koordinat + manifest | `jamarat.json`, `lamps.json`, `guardline.json` |
| `generate_makkah.py` | OSM + spec | `makkah_landmarks.json`, `makkah_facade.json` |
| `generate_arafah.py` | OSM + koordinat | `jabal_rahmah.json`, `namirah.json`, `boundary.json`, `facilities.json`, `mist.json` |
| `generate_muzdalifah.py` | OSM (opsional) + koordinat | `masyaril_haram.json`, `boundary.json`, `pebble_area.json`, `facilities.json` |
| `tools/visualize_route.py` | route JSON | `route_map.html` (pratinjau) |

## 3. Lapis 3 — Bungkus jadi ModuleScript (`to_roblox_module.py`)

**Kontrak nama ModuleScript = `to_roblox_module.MAPS`** (sumber kebenaran):

| Zona | ModuleScript ← JSON sumber |
|---|---|
| **A_Makkah** | `MakkahLandmarks`←makkah_landmarks · `MakkahFacade`←makkah_facade · `MakkahRoute`←route_local |
| **B_Mina** | `MinaTerraces`←tent_blocks · `MinaBarriers`←guardline · `MinaJamarat`←jamarat · `MinaLamps`←lamps · `MinaTents`←mina_tents · `MinaBuildings`←osm_buildings_corridor · `MinaRoute`←route_local |
| **C_Arafah** | `ArafahJabalRahmah` · `ArafahNamirah` · `ArafahBoundary` · `ArafahFacilities` · `ArafahMist` · `ArafahRoute` |
| **D_Muzdalifah** | `MuzdalifahMasyaril`←masyaril_haram · `MuzdalifahBoundary`←boundary · `MuzdalifahPebbleArea`←pebble_area · `MuzdalifahFacilities`←facilities · `MuzdalifahRoute`←route_local |

`python generators/to_roblox_module.py --zone <zona>` → `output/<zona>/<Nama>.module.lua`. Di Studio:
buat ModuleScript bernama persis di ReplicatedStorage, tempel isi `.module.lua` (lewat editor skrip).

## 4. Lapis 4 — Skrip Studio (Command Bar) → Workspace

| Skrip | Membaca | Menghasilkan (Workspace) |
|---|---|---|
| `A_Makkah/build_makkah.lua` | `MakkahLandmarks`, `MakkahFacade` | `A_Makkah.{Kaaba, Mataf, MaqamIbrahim, HijrIsmail, Masaa, AbrajAlBait, Gerbang, Facade}` |
| `B_Mina/build_mina.lua` | `MinaTerraces`, `MinaBarriers`, `MinaJamarat`, `MinaLamps` | `Mina_Tents`*, `Mina_Barriers`, `Jamarat.Jamratul_*`, `Mina_Lamps`, **`TempatQurban`** |
| `C_Arafah/build_arafah.lua` | `ArafahJabalRahmah/Namirah/Boundary/Facilities/Mist` | `C_Arafah.{JabalRahmah, Namirah, BatasArafah, Fasilitas, Mist}` |
| `D_Muzdalifah/build_muzdalifah.lua` | `MuzdalifahMasyaril/Boundary/PebbleArea/Facilities` | `D_Muzdalifah.{MasyarilHaram, AreaKerikil, BatasMuzdalifah, Fasilitas}` |
| `common/build_miqat.lua` | — (atribut `PlaceName`) | `Miqat.{Peron,Papan}`, **`Bus`** |
| `common/place_from_modules.lua` ★ | `MinaBuildings`(/`MinaBarriers`/`MinaTents`) + `TentMaster` | `OSM_Buildings` (fasad OSM). KANONIK — gantikan `place_osm_buildings`/`place_tents` (dihapus). Pembatas/tenda tumpang-tindih build_mina. |
| `common/build_tent_master.lua` | — | `TentMaster` (master mesh untuk di-clone) |
| `<zona>/render_route.lua` | `<Zona>Route` | `<Zona>_Route` (slab aspal; **CARVE koridor** FillBlock → jalan rata, tak terbenam di lereng. `CARVE_ROAD=false` = drape lama) |
| `<zona>/nav_guide.lua` | `<Zona>Route` | **client** LocalScript: panah arah + jarak + ETA |

\* `Mina_Tents` diisi oleh `build_mina` (via `MinaTerraces`). `place_from_modules` opsional utk lapisan bangunan OSM.

## 5. Lapis 5 — Kontrak logic ↔ world (NODE yang dibaca runtime)

`server/WorldProviders.lua` (& `PlaceContext.lua`) mencari node hasil §4. **Bila tak ada → placeholder.**

| Node Workspace | Dibaca oleh | Dibuat oleh |
|---|---|---|
| `A_Makkah.Kaaba.Kaaba` (pusat Tawaf) | `WorldProviders.makkahMarks` | build_makkah |
| `A_Makkah.Masaa.Bukit_Safa`/`Bukit_Marwah` (ujung Sa'i) | `WorldProviders.makkahMarks` | build_makkah |
| `Jamarat.Jamratul_Ula/Wusta/Aqabah` | `WorldProviders.minaPillars` | build_mina |
| `TempatQurban` | `WorldProviders.qurbanStation` | build_mina |
| `C_Arafah.BatasArafah` (zona Wukuf) | `WorldProviders.arafahZone` | build_arafah |
| `Bus` | `WorldProviders.miqatBus` | build_miqat |
| `D_Muzdalifah.AreaKerikil` (region kerikil) | `WorldProviders.muzdalifahPebbles` (sebar 60 kerikil DI region ini) | build_muzdalifah |

### Urutan regenerate (dari nol)
```bash
python convert_terrain.py --config config.json                 # 1. terrain PNG + manifest (semua zona)
python generators/generate_osm.py --zone A_Makkah              # 2. roads/buildings/barriers (ulang per zona)
python generators/trace_hajj_route.py                          # 3. rute jalan-nyata (sekali, seluruh koridor)
python generators/project_route.py --zone A_Makkah            # 4. route_local/route (per zona)
python generators/corridor_filter.py --zone A_Makkah          # 5. fasad koridor
python generators/generate_makkah.py        # / generate_mina_extras / generate_arafah / generate_muzdalifah / generate_terraces / generate_tents
python generators/roads_to_colormap.py --zone A_Makkah        # 6. colormap jalan kota
python generators/to_roblox_module.py --zone A_Makkah          # 7. .module.lua → tempel ke Studio
# Studio: import PNG → import colormap → buat ModuleScript → run build/place/render scripts (§4)
```

---

## 6. ⚠️ Celah & desync TERVERIFIKASI (audit 2026-06-23)

Bukan dugaan — ditemukan dari kode. **Perbaiki sebelum dianggap "world serius & sinkron".**

1. ✅ **DIPERBAIKI 2026-06-23 (paritas 4=4).** Ditambah `generate_muzdalifah.py` (masyaril_haram/
   boundary/pebble_area/facilities), `to_roblox_module.MAPS["D_Muzdalifah"]`, `D_Muzdalifah/
   build_muzdalifah.lua`, dan `WorldProviders.muzdalifahPebbles` kini menyebar kerikil DI region nyata
   `D_Muzdalifah.AreaKerikil` (placeholder origin hanya bila build belum jalan). ✅ **DITUNTASKAN
   2026-06-25:** ditambah `D_Muzdalifah/render_route.lua` (aspal `MuzdalifahRoute`, CARVE koridor)
   & `D_Muzdalifah/nav_guide.lua` (panah+ETA, default ke segmen KELUAR Muzdalifah→Mina). Paritas
   route+nav kini **4=4 penuh**.
2. ✅ **DIPERBAIKI 2026-06-23.** `to_roblox_module.MAPS["B_Mina"]` kini memuat `MinaTents`←mina_tents
   & `MinaBuildings`←osm_buildings_corridor (yang dibaca `place_from_modules.lua`); docstring contoh
   diselaraskan dgn MAPS. (Dulu: kedua module tak pernah dibungkus → link putus.)
3. ✅ **DIPERBAIKI 2026-06-23.** `place_osm_buildings.lua` (12,5k baris inline) & `place_tents.lua`
   (tempel-inline) DIHAPUS; data 440 bangunan diselamatkan ke `output/B_Mina/osm_buildings_corridor.json`.
   Kanonik = `place_from_modules.lua` (module-based). Tenda kanonik via `build_mina`/`MinaTerraces`.
4. ✅ **DIPERBAIKI 2026-06-23.** `render_route.lua` (keempat zona, termasuk Muzdalifah sejak 2026-06-25)
   kini CARVE koridor: `FillBlock` Air di atas (`CARVE_UP`) + Sand roadbed di bawah (`FILL_DOWN`)
   sepanjang slab → jalan rata, tak terbenam di lereng menyamping. Toggle `CARVE_ROAD` (default true; false = drape lama).
5. ✅ **DIPERBAIKI 2026-06-23.** Header `render_route.lua` tiap zona kini merujuk zona & build benar
   (Makkah→build_makkah, Arafah→build_arafah, Mina→build_mina, Muzdalifah→build_muzdalifah).
6. ✅ **DIPERBAIKI 2026-06-23.** Contoh `PIPELINE.md` diselaraskan ke skala 4 + box 26.286×19.636 (sesuai `config.json`).

> Status sinkron logic↔world: **Makkah/Mina/Arafah/Muzdalifah/Bus SUDAH cocok** (§5). Paritas
> build + route + nav kini **4=4 penuh** (Muzdalifah dituntaskan 2026-06-25, lihat #1).

---

## 7. 🌍 Audit FIDELITY dunia-nyata (2026-06-25)

Audit ini ≠ §6 (yang soal pipeline desync). Ini soal "seberapa setia geometri ke dunia nyata".
**Verdikt: rantai data faithful** — rute = jalan OSM nyata (Dijkstra, `trace_hajj_route.py`),
proyeksi baca `geo_bounds` manifest (nol hardcode), 5 landmark jatuh di kotak zona masing-masing,
urutan geografis benar (Makkah→Mina→Muzdalifah→Arafah, barat→timur / utara→selatan).

**✅ Temuan A — DIPERBAIKI.** `generate_makkah.py` dulu skematik (offset Ka'bah hardcode ±760,
fallback studs `86,-9`, label "perkiraan—refine"). Kini **hybrid real-coord**: baca manifest + proyektor
`to_xz`; Ka'bah (OSM `كعبة` / lon-lat literatur), Abraj/Safa/Marwah dari lon/lat literatur via manifest;
Maqam (13 m TL) & Hijr Ismail (9 m BL, r 8,5 m) dari offset **meter nyata** relatif Ka'bah; gerbang
bearing nyata 4 sisi (`approx:true`). Field `_provenance` mencatat sumber. Terverifikasi headless (zona
sintetik): Abraj 425 m S, Mas'a 380 m, arah semua benar. Kontrak JSON `build_makkah.lua` utuh.

**⚠️ Temuan B — DIKETAHUI, by-design (belum diubah).** Di SEMUA zona, **batas/gapura** ("Batas Arafah/
Muzdalifah"), **fasilitas MCK**, **lampu-grid**, dan **guardline** = persegi/grid **prosedural** di sekeliling
bbox konten — **BUKAN** rambu/batas masyair tersurvei dari OSM. Ini sengaja (pengurung gameplay), tapi
JANGAN dikira batas nyata. (Mist & lampu utama tetap ikut polyline rute/jalan nyata.) Bila kelak ingin
batas nyata: tarik relation `boundary`/`landuse` dari OSM, ganti generator persegi → poligon OSM.

**Catatan provenance landmark:** Safa/Marwah/Abraj/gerbang Makkah masih lon/lat **literatur** (terlabel di
`_provenance` makkah_landmarks.json), bukan node OSM. Refine via OSM node bila perlu presisi lebih.
