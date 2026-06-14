# PLAYBOOK.md — GeoTIFF → World Roblox Matang (siap di-detail)

> Pedoman eksekusi end-to-end RUH Main Place. Versi ini **terkoreksi** dari draf
> pipeline awal: semua langkah hilir (jalan, bangunan) **membaca angka nyata dari
> `import_manifest.json`** — bukan resolusi/koordinat hardcoded — supaya presisi.
> Konsep & trade-off ada di [PLAN_ARSITEKTUR.md](PLAN_ARSITEKTUR.md).

Status: ✅ = selesai & teruji · 🔜 = langkah berikut · 📋 = manual di Studio

---

## Kontrak koordinat (kunci semua langkah)

Setiap zona = satu **place** dengan dunia berukuran `Size_X × Size_Z` studs,
**origin di tengah (0,0,0)**, `Position Y = -(Size_Y/2)`. Angka pastinya ada di
`output/<zona>/import_manifest.json`. **Semua skrip jalan/bangunan WAJIB memakai
`world_size_studs` & box geo zona dari manifest itu** untuk memetakan lon/lat →
X/Z. Jangan pakai angka 4000 hardcoded; itu sumber salah-align.

---

## ✅ Langkah 1 — Terrain per-zona (SELESAI)

Tool: `convert_terrain.py` dengan `zones` di `config.json`. Normalisasi **GLOBAL**
(satu skala tinggi untuk semua zona), tiap zona dipotong dari SRTM penuh.

```bash
python convert_terrain.py --config config.json --dry-run   # cek rencana
python convert_terrain.py --config config.json             # tulis PNG+manifest
```

Hasil (SRTM Mekkah asli, scale 2, semua voxel-aligned & < budget impor):

| Zona | Dunia (studs) | Tile | Voxel/tile | Output |
|---|---|---|---|---|
| A_Makkah | 17616 × 17808 | 2×2 = 4 | 2,04 mljr | `output/A_Makkah/` |
| B_Mina | 14512 × 11136 | 2×1 = 2 | 2,10 mljr | `output/B_Mina/` |
| C_Arafah | 20384 × 19664 | 2×2 = 4 | 2,60 mljr | `output/C_Arafah/` |

`Size_Y = 1664` & elevasi 128–960 m **identik di semua zona** → tinggi nyambung
saat teleport. Tiap zona punya `import_manifest.json` + `IMPORT_GUIDE.md` sendiri.

> Batas kotak zona di `config.json` masih perkiraan — sesuaikan dari Google Maps
> bila perlu, lalu rerun (auto-clean tile lama).

---

## 📋 Langkah 2 — Impor 1 zona + UKUR `.rbxl` (GATE WAJIB)

**Jangan tulis skrip jalan/bangunan sebelum langkah ini.** Mulai dari **Mina**
(paling ringan, paling khas manasik):

1. Place kosong baru → Terrain Editor → Import.
2. Impor tiap PNG di `output/B_Mina/` dengan Size/Position **persis** dari
   `IMPORT_GUIDE.md` (Snap to Voxels boleh ON — semua angka ÷4). Material non-Water.
   **Jangan ubah Position Y** (sudah = −Size_Y/2).
3. **File → Save to File (.rbxl)**, catat ukurannya (MB).

Angka ini mengkalibrasi semua estimasi & menentukan berapa banyak tenda yang aman.

---

## ✅🔜 Langkah 3-4 — Jalan & bangunan OSM (generator SIAP & teruji)

`generate_osm.py` **sudah dibuat & terbukti** (konversi koordinat lolos selftest:
pojok NW/SE & tengah tepat, origin di tengah). Ia membaca `geo_bounds` +
`world_size_studs` + `flip_z` dari `import_manifest.json` zona — **tanpa hardcode**.

```bash
python generate_osm.py --zone B_Mina --selftest   # cek koordinat, TANPA jaringan
python generate_osm.py --zone B_Mina              # tarik OSM -> osm_roads.json + osm_buildings.json
```

Output (di `output/B_Mina/`): `osm_roads.json` (polyline jalan, X/Z studs) &
`osm_buildings.json` (poligon bangunan, footprint asli OSM).

Lalu di Studio (SETELAH terrain zona ter-generate): tempel isi `osm_buildings.json`
ke `roblox_scripts/place_osm_buildings.lua`, jalankan di Command Bar → dinding
keliling tiap bangunan dibangun via **raycast ke terrain** (bentuk asli, siap
di-texture). Geometri polos dulu; detail/atap/material menyusul.

> **Tenda Mina** umumnya TIDAK dipetakan satuan di OSM. Tenda = penempatan
> **prosedural** (grid/baris di lembah) sebagai **instance 1-mesh** (Fase 2),
> bukan dari OSM, bukan model multi-part. Jalan juga bisa dijadikan **colormap**
> (auto-paint Asphalt) sebagai alternatif part — opsi belakangan.

---

## 🔜 Langkah 5 — Teleport antar-place

Tiap zona = place terpisah dalam 1 Experience. Spawn pemain di perbatasan zona,
`TeleportService` saat melewati trigger. Loading = "perjalanan antar-ritus".

---

## 📋 Langkah 6 — Detailing (tim 3D)

Ganti balok penanda dengan model 3D (mesh tunggal + instancing), pasang lampu,
trigger ibadah (wukuf, lempar jumrah), StreamingEnabled + LOD untuk perf runtime.

---

## Urutan aman (ringkas)

1. ✅ Terrain 3 zona (sudah jadi).
2. 📋 Impor Mina → **ukur .rbxl** ← kamu di sini.
3. 🔜 Colormap jalan Mina (skrip baca manifest).
4. 🔜 Penanda bangunan Mina (skrip baca manifest) + tenda prosedural.
5. 🔜 Replikasi ke Makkah & Arafah + teleport.
6. 📋 Detailing 3D.

> Prinsip tetap: **ukur dulu, baru optimasi**; semua hilir baca manifest; jangan
> ulangi regresi (Position Y arbitrer, resolusi hardcoded, model tenda multi-part).
