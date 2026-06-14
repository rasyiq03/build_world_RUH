# PIPELINE.md — Kontrak Tool

Definisi input/output & perilaku `convert_terrain.py`. Implementasi harus mematuhi ini.

## 1. Konfigurasi (`config.json`)

```json
{
  "input_tif": "data/output_srtm.tif",
  "output_dir": "output",
  "scale_studs_per_m": 2.0,
  "box_width_km": 26.0,
  "box_height_km": 16.0,
  "nodata_threshold": -500.0,
  "overlap_px": 1,
  "max_tile_studs": 16384,
  "max_tile_px": 4096,
  "output_prefix": "RUH_tile",
  "flip_z": false
}
```

Aturan:
- `input_tif`, `box_width_km`, `box_height_km` **wajib**; jika kosong/placeholder → gagal dengan pesan jelas, jangan menebak.
- Semua angka lain punya default seperti di atas.
- `flip_z`: kalau orientasi Utara–Selatan terbalik saat di Studio, user set `true` (jangan diatur otomatis tanpa konfirmasi).
- Dukung override via CLI flag (mis. `--scale`, `--input`) yang menimpa config.

## 2. Antarmuka CLI

```bash
python convert_terrain.py --config config.json
python convert_terrain.py --input data/x.tif --box 26 16 --scale 2   # mode cepat tanpa file config
python convert_terrain.py --config config.json --dry-run             # hitung & cetak rencana tile TANPA menulis PNG
```
`--dry-run` penting: user bisa melihat jumlah & posisi tile sebelum proses berat.

## 3. Tahapan Eksekusi

1. **Load & validasi config** (gagal-aman bila wajib kosong).
2. **Baca GeoTIFF** → array float32. Tangani multi-band (ambil band 1).
3. **Bersihkan NoData** (SPEC §3 langkah 2–3).
4. **Normalisasi global 16-bit** (SPEC §3 langkah 4–6).
5. **Hitung tata letak tile** (SPEC §4) + validasi ≤ max_tile_px.
6. **Potong tile dengan overlap** (SPEC §5).
7. **Tulis PNG 16-bit** per tile ke `output_dir`.
8. **Tulis `import_manifest.json` + `IMPORT_GUIDE.md`** (SPEC §6).
9. **Cetak ringkasan** ke stdout: rentang elevasi, size_y, ukuran dunia, jumlah tile, lokasi output.

## 4. Penanganan Error (wajib eksplisit)

| Kondisi | Aksi |
|---|---|
| File TIF tidak ada | Error jelas + saran path |
| Config wajib kosong | Error + tunjuk field |
| Tile > max_tile_px | Error + sarankan naikkan jumlah tile / turunkan skala |
| Seluruh DEM ter-flag NoData | Error (ambang salah?) |
| gmax == gmin (datar total) | Warning + hasilkan heightmap flat valid |

## 5. Reference Snippet (titik kritis — boleh dikembangkan)

Normalisasi global (jangan pernah per-tile):
```python
mask = dem > cfg.nodata_threshold
dem[~mask] = dem[mask].min()
gmin, gmax = float(dem.min()), float(dem.max())
norm = (dem - gmin) / (gmax - gmin) if gmax > gmin else np.zeros_like(dem)
img16 = np.clip(np.rint(norm * 65535), 0, 65535).astype(np.uint16)
```

Pemotongan dengan overlap (konsep):
```python
# batas kolom untuk tile ix, dengan overlap_px di sisi kanan kecuali tile terakhir
x0 = ix * base_w
x1 = min(W, (ix + 1) * base_w + overlap_px)
tile = img16[z0:z1, x0:x1]
assert tile.shape[1] <= cfg.max_tile_px and tile.shape[0] <= cfg.max_tile_px
```

Tulis PNG 16-bit:
```python
import imageio.v3 as iio
iio.imwrite(path, tile)   # tile dtype uint16 -> PNG 16-bit grayscale
```

## 6. Smoke Test (wajib ada)

Buat `test_pipeline.py` yang **tidak** butuh file SRTM asli:
- Bangun DEM sintetis (mis. gradient + bukit `np.sin`) berukuran kecil (mis. 400×260).
- Jalankan pipeline.
- Assert: jumlah tile benar, tiap PNG uint16 & ≤ max_px, manifest valih, position simetris (sum ≈ 0), dan **nilai di kolom overlap dua tile bersebelahan identik** (membuktikan normalisasi global + overlap benar).
