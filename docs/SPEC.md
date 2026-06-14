# SPEC.md — Spesifikasi Teknis (Otoritatif)

Dokumen ini adalah sumber kebenaran untuk semua angka & rumus. Kalau ada konflik dengan ingatanmu, ikuti dokumen ini.

## 1. Sistem Koordinat & Skala

- **Skala dunia (default):** `1 stud = 0.5 m` → `2 studs/meter`. Bisa diubah lewat config (`scale_studs_per_m`).
- **Origin (0,0,0):** titik tengah rute Masjidil Haram–Arafah. Tile disusun **simetris** terhadap origin.
- **Sumbu:**
  - `X` = arah rute Barat→Timur (Masjidil Haram di X negatif, Arafah di X positif).
  - `Z` = Utara–Selatan (pegunungan latar).
  - `Y` = ketinggian (elevasi).

### Kenapa skala dikompresi (bukan 1:1)
Pada 1:1 (~0.28 m/stud) rute 20 km = ~71.000 studs → koordinat ekstrem memicu jitter floating-point (float 32-bit). Dengan `2 studs/m`, rute ~40.000 studs, origin di tengah → semua koordinat di **±20.000 studs**, presisi ~2–3 mm (aman). Penskalaan seragam **tidak mengubah proporsi** topografi SRTM. Walkability tetap utuh (rute penuh ~40 menit jalan kaki).

## 2. Data Sumber

- **Format input:** GeoTIFF (SRTM GL1, ~30 m/piksel) dari OpenTopography.
- **Catatan resolusi:** detail riil dibatasi ~30 m/piksel oleh SRTM. Memotong tile **tidak** menurunkan ini (memotong = cropping, bukan resize). Bit-depth 16 dipertahankan utuh per tile.
- **NoData:** SRTM sering memakai nilai sangat negatif (mis. `-32768`, `-9999`). Ambang aman: nilai `<= nodata_threshold` (default `-500`) dianggap NoData dan di-clamp ke elevasi valid minimum.

## 3. Pipeline Nilai Elevasi

```
1. dem = baca GeoTIFF sebagai float32
2. valid_mask = dem > nodata_threshold
3. valid_min = min(dem[valid_mask]);  dem[~valid_mask] = valid_min
4. gmin = min(dem); gmax = max(dem)          # GLOBAL, sebelum tiling
5. norm = (dem - gmin) / (gmax - gmin)       # rentang 0.0..1.0
6. img16 = round(norm * 65535) as uint16
7. (baru) potong img16 jadi tile dengan overlap
```
Langkah 4–5 (normalisasi global) **harus** sebelum langkah 7. Inilah yang membuat ketinggian antar-tile satu sistem.

## 4. Tata Letak Tile

Konstanta: `MAX_TILE_STUDS = 16384` (batas aman Size satu impor), `MAX_TILE_PX = 4096`.

### Rumus
```
size_x_total = box_width_km  * 1000 * scale          # studs
size_z_total = box_height_km * 1000 * scale          # studs

tiles_x = ceil(size_x_total / MAX_TILE_STUDS)
tiles_z = ceil(size_z_total / MAX_TILE_STUDS)

size_x_tile = size_x_total / tiles_x                 # studs per tile (X)
size_z_tile = size_z_total / tiles_z                 # studs per tile (Z)

size_y = (gmax - gmin) * scale                       # tinggi relief, studs
```
Validasi: lebar/tinggi piksel per tile **harus ≤ MAX_TILE_PX**. Jika tidak, naikkan tiles_x/tiles_z.

### Posisi (origin di tengah, simetris)
Untuk indeks tile `ix` (0..tiles_x-1) dan `iz` (0..tiles_z-1):
```
position_x(ix) = (ix - (tiles_x - 1)/2) * size_x_tile
position_z(iz) = (iz - (tiles_z - 1)/2) * size_z_tile
position_y     = -(size_y / 2)        # sama untuk semua tile
```

### Contoh kerja (default)
`box_width_km=26`, `box_height_km=16`, `scale=2`:
- size_x_total = 52.000 → tiles_x = 4 → size_x_tile = 13.000
- size_z_total = 32.000 → tiles_z = 2 → size_z_tile = 16.000
- Position X tile: `-19.500, -6.500, +6.500, +19.500`
- Position Z tile: `-8.000, +8.000`
- size_y = (gmax-gmin) * 2 (mis. delta 800 m → 1.600 studs), position_y = -800

> Angka di atas ilustrasi. Nilai final dihitung tool dari config + elevasi aktual.

## 5. Overlap Antar-Tile

- Saat memotong piksel, tile bersebelahan **berbagi 1 piksel tepi** (`overlap_px`, default 1).
- Tujuannya: elevasi di garis sambung identik di kedua tile → tanpa celah.
- Konsekuensi posisi: karena tile berbagi 1 piksel, lebar dunia efektif sedikit berkurang; tool harus menghitung Position berdasarkan **lebar efektif** agar tile tetap pas bersebelahan. Dokumentasikan asumsi ini di manifest.
- Jika pembagian piksel tidak pas (sisa), **jangan buang diam-diam** — pad tepi atau bagi rata; catat di log.

## 6. Output Manifest

`import_manifest.json` (machine-readable) — array objek per tile:
```json
{
  "scale_studs_per_m": 2,
  "origin": "center-of-route",
  "elevation_min_m": 210.0,
  "elevation_max_m": 1014.0,
  "size_y_studs": 1608,
  "world_size_studs": { "x": 52000, "z": 32000 },
  "tiles": [
    {
      "file": "RUH_tile_x0_z0.png",
      "pixels": { "w": 217, "h": 267 },
      "size":     { "x": 13000, "y": 1608, "z": 16000 },
      "position": { "x": -19500, "y": -804, "z": -8000 }
    }
  ]
}
```
`IMPORT_GUIDE.md` (human-readable) — langkah impor berurutan, satu blok per tile, berisi nilai Size X/Y/Z, Position X/Y/Z, material (`Sand`/`Rock`/`Sandstone`, **bukan Water**), dan pengingat smooth di sambungan.

## 7. Validasi Akhir (tool harus mengecek)

- Tidak ada NaN/inf di output.
- `0 <= img16 <= 65535`, dtype `uint16`.
- Tiap tile ≤ 4096 px.
- Jumlah tile = tiles_x * tiles_z.
- Position simetris terhadap 0 (jumlah position_x semua tile ≈ 0).
