# AGENTS.md — RUH Main Place Terrain Pipeline

> Baca file ini sampai habis sebelum menulis kode apa pun.
> Spec teknis lengkap ada di `SPEC.md`, kontrak tool ada di `PIPELINE.md`, urutan kerja ada di `TASKS.md`.

## 1. Konteks Proyek

RUH (Route to Umrah & Hajj) adalah simulator manasik haji & umrah di Roblox untuk mata kuliah Komputer Grafik. **Main Place** adalah dunia menerus berskala besar di mana pemain bisa **berjalan kaki penuh** dari Masjidil Haram → Mina → Muzdalifah → Arafah, dengan topografi nyata.

Terrain dibangun dari data elevasi SRTM (GeoTIFF dari OpenTopography). Roblox **tidak bisa membaca `.tif`** — hanya `.png`/`.jpg`. Importer terrain Roblox juga membaca **maksimal 4096×4096 px** dan satu kali impor punya batas rentang studs, sehingga dunia besar harus **dipotong jadi beberapa tile**.

## 2. Yang Akan Kamu Bangun

Sebuah CLI tool Python (`convert_terrain.py` + modul pendukung) yang:
1. Membaca GeoTIFF SRTM.
2. Membersihkan NoData, menormalisasi elevasi ke **16-bit**.
3. Memotongnya jadi **grid tile PNG 16-bit** dengan **overlap 1 piksel** antar-tile.
4. Menghasilkan **manifest** berisi parameter Size & Position **persis** untuk setiap tile, siap diketik di Roblox Studio Terrain Importer.

Tool ini dijalankan **di komputer (offline)**, bukan di dalam Roblox. Output utamanya: file PNG tile + `import_manifest.json` + `IMPORT_GUIDE.md`.

## 3. ATURAN EMAS (invarian — jangan dilanggar)

1. **Output WAJIB PNG 16-bit (`uint16`).** 8-bit membuat lereng berundak (terracing). Jangan pakai 8-bit.
2. **Normalisasi elevasi WAJIB global** — pakai min/max SELURUH DEM **sebelum** memotong. Normalisasi per-tile = sambungan jadi tebing patah. Ini bug paling fatal; cegah di awal.
3. **Tile bersebelahan WAJIB overlap 1 piksel** (berbagi baris/kolom tepi) agar tidak ada celah/jahitan di sambungan.
4. **Tiap tile ≤ 4096 px** di kedua sisi. Kalau melebihi, tambah jumlah tile.
5. **Skala seragam** untuk seluruh dunia (default `2 studs/m`, lihat SPEC). Jangan pernah skala berbeda antar-tile.
6. **Origin di tengah rute.** Tile disusun simetris terhadap (0,0,0).
7. **`Position Y = -(Size_Y / 2)`** di tiap tile (mencegah "pulau bolong").
8. **Jangan membentuk terrain via script Roblox.** Tool ini hanya menyiapkan data; pembentukan tanah dilakukan lewat Terrain Importer Studio memakai manifest.
9. **Determinisme.** Output harus sama untuk input + config yang sama. Tidak ada randomness.

## 4. Lingkungan & Setup

- Python 3.10+.
- Library: `tifffile`, `numpy`, `imageio` (hindari `rasterio`/GDAL agar tidak ribet di Windows).
- Buat `requirements.txt`. Setup:
  ```bash
  python -m venv .venv
  # Windows: .venv\Scripts\activate  | Linux/Mac: source .venv/bin/activate
  pip install -r requirements.txt
  ```

## 5. Cara Menjalankan & Verifikasi

```bash
python convert_terrain.py --config config.json
```
Verifikasi (tulis juga sebagai langkah QA di tool/README):
- Jumlah PNG tile = `tiles_x * tiles_z` dari config.
- Tiap PNG terbaca 16-bit (mode `I;16` / dtype uint16), dimensi ≤ 4096.
- `import_manifest.json` ada, dan jumlah entri = jumlah tile.
- Position antar-tile bersebelahan, simetris terhadap 0, dengan overlap sesuai config.
- Cetak ringkasan: rentang elevasi (m), Size Y saran, ukuran dunia total (studs).

## 6. Struktur Repo (target)

```
make_main_place/
├── AGENTS.md            # file ini
├── SPEC.md              # spec teknis & matematika (otoritatif)
├── PIPELINE.md          # kontrak I/O tool
├── TASKS.md             # checklist berurutan
├── START_PROMPT.md      # prompt pemicu
├── requirements.txt     # (kamu buat)
├── config.json          # (kamu buat) — konfigurasi yang bisa diedit user
├── convert_terrain.py   # (kamu buat) — entry point CLI
├── terrain/             # (kamu buat) — modul: io, normalize, tiling, manifest
└── output/              # (dihasilkan) — PNG tile + manifest + IMPORT_GUIDE.md
```

## 7. Gaya & Kualitas Kode

- Pisahkan logika ke modul kecil yang teruji (baca, normalisasi, tiling, manifest), jangan satu fungsi raksasa.
- Validasi input + pesan error jelas (file tidak ada, config tidak lengkap, tile > 4096 px).
- Komentar berbahasa Indonesia singkat di titik kritis (terutama normalisasi global & overlap).
- Logging progres yang informatif.
- Buat `README.md` ringkas untuk user (cara pakai, cara impor ke Studio).

## 8. Definition of Done

- [ ] Tool berjalan end-to-end dari satu GeoTIFF + config → PNG tile 16-bit + manifest.
- [ ] Semua Aturan Emas terpenuhi & terverifikasi.
- [ ] `IMPORT_GUIDE.md` berisi langkah impor per-tile dengan angka Size & Position persis.
- [ ] README + requirements.txt lengkap.
- [ ] Ada minimal smoke test (boleh pakai DEM dummy / array sintetis) yang membuktikan normalisasi global & overlap benar.

## 9. Saat Ragu

Jangan menebak nilai bounding box atau nama file GeoTIFF. Kalau belum ada di `config.json`, **tanyakan ke user** atau sediakan placeholder yang jelas + validasi yang gagal-aman. Selalu utamakan invarian di Bagian 3 di atas konvensi gaya apa pun.
