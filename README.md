# RUH — Route to Umrah & Hajj

Repo **perancangan & pembangunan** simulator manasik haji/umrah di Roblox (proyek EAS
Komputer Grafik, tim 3 orang): pipeline terrain, generator konten, kode game Lua (Rojo),
dan dokumen rancangan.

> **Mulai dari [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md)** — anchor: alur manasik, 4 zona,
> 4 jenis ibadah, ritual, pembagian tim. Bagian di bawah fokus **pipeline terrain** (satu
> lapisan): GeoTIFF SRTM → tile PNG 16-bit + manifest untuk Terrain Importer. Kontrak terrain:
> [`AGENTS.md`](AGENTS.md), [`docs/SPEC.md`](docs/SPEC.md) (otoritatif), [`docs/PIPELINE.md`](docs/PIPELINE.md), [`docs/PLAYBOOK.md`](docs/PLAYBOOK.md).

## Struktur repo

| Path | Isi |
|---|---|
| `convert_terrain.py` · `terrain/` | CLI + paket pipeline terrain (root, entry utama) |
| `generators/` | generator konten: OSM, tenda, teras, route, JSON→Lua (`generate_*.py`, dll.) |
| `tools/` | utilitas: `make_demo_dem.py`, visualisasi |
| `roblox/` | kode Lua in-game (proyek Rojo): `shared/`, `places/`, `npc/` + zona lama |
| `docs/` | `GAME_DESIGN.md` (anchor), `SPEC`, `PIPELINE`, `PLAYBOOK`, `MODELS`, `COMPUTER_GRAPHICS` + `progress/`, `studio/` |
| `models/` | folder tujuan model 3D per area (lihat `docs/MODELS.md`) |
| `tests/` | `test_pipeline.py` (smoke test) |
| `output/` · `data/` | artefak (gitignored) |

## Kenapa di-tile & 16-bit?

- Roblox **tidak bisa membaca `.tif`** — hanya PNG/JPG. Importer terrain juga maksimal
  **4096×4096 px**, dan **membatasi volume satu impor** (jumlah voxel 4×4×4 — bila
  terlalu besar muncul *"region volume is too large"*) → dunia besar **dipotong**.
- Output **WAJIB PNG 16-bit** (`uint16`). 8-bit membuat lereng berundak (terracing).
- Normalisasi elevasi **GLOBAL** (min/max seluruh DEM) dilakukan **sebelum** memotong,
  agar ketinggian antar-tile satu sistem (tanpa tebing patah di sambungan).
- Tile bersebelahan **berbagi 1 piksel tepi** (overlap) → tanpa celah/jahitan.

## Instalasi

```bash
python -m venv .venv
# Windows: .venv\Scripts\activate   |  Linux/Mac: source .venv/bin/activate
pip install -r requirements.txt
```
Butuh Python 3.10+ (`numpy`, `tifffile`, `imageio`).

## Konfigurasi (`config.json`)

Field **wajib** dibiarkan kosong agar gagal-aman — isi dulu sebelum jalan:

| Field | Wajib | Arti |
|---|---|---|
| `input_tif` | ✅ | Path GeoTIFF SRTM (mis. dari OpenTopography). |
| `box_width_km` | ✅ | Lebar bounding box rute (km, sumbu X Barat–Timur). |
| `box_height_km` | ✅ | Tinggi bounding box (km, sumbu Z Utara–Selatan). |
| `scale_studs_per_m` | — | Default `2.0` (1 stud = 0.5 m). |
| `nodata_threshold` | — | Default `-500.0`; nilai ≤ ini dianggap NoData. |
| `overlap_px` | — | Default `1` (overlap antar-tile). |
| `max_tile_studs` / `max_tile_px` | — | `16384` / `4096` (batas studs/piksel per-sumbu). |
| `max_tile_voxels` | — | Default `4_200_000_000` (≈2³², dari uji lapangan). Batas volume satu impor (jumlah voxel 4×4×4). Importer menolak region terlalu besar (*"region volume is too large"*); grid otomatis dinaikkan agar `(X/4)(Y/4)(Z/4) ≤ nilai ini`. |
| `output_prefix` | — | Default `RUH_tile`. |
| `flip_z` | — | `true` bila Utara–Selatan terbalik di Studio (konfirmasi dulu). |

## Cara Pakai

```bash
# Mode config
python convert_terrain.py --config config.json

# Mode cepat (override tanpa config)
python convert_terrain.py --input data/output_srtm.tif --box 26 16 --scale 2

# Rencana saja, tanpa menulis PNG (cek angka Size/Position dulu)
python convert_terrain.py --config config.json --dry-run
```
Flag CLI (`--input`, `--box`, `--scale`, `--output`) menimpa nilai config.

Output ke `output/`:
- `RUH_tile_x{ix}_z{iz}.png` — heightmap 16-bit per tile.
- `import_manifest.json` — Size & Position tiap tile (machine-readable, SPEC §6).
- `IMPORT_GUIDE.md` — langkah impor per-tile dengan angka persis.

## Impor ke Roblox Studio

1. Buka **Terrain Editor → Import** (atau `Terrain:ImportHeightmap`).
2. Untuk **tiap** tile, pilih PNG-nya dan ketik **Size X/Y/Z** & **Position X/Y/Z**
   persis dari `IMPORT_GUIDE.md` / manifest.
3. **Position Y negatif** (= −Size_Y/2) sudah dihitung — jangan diubah (cegah "pulau bolong").
4. Material non-air: `Sandstone`/`Rock`/`Sand` (**bukan Water**).
5. Setelah semua tile masuk, smooth tipis di sambungan bila perlu (overlap 1 px sudah
   meminimalkan jahitan).

## Verifikasi / QA

```bash
python tests/test_pipeline.py  # smoke test (tanpa SRTM asli)
```
Membuktikan: output uint16, **normalisasi global** (kolom/baris overlap antar-tile
identik), overlap 1 px, jumlah tile benar, tiap PNG ≤ 4096 px, Position simetris
(Σ ≈ 0), `Position Y = −Size_Y/2`, dan manifest valid.

Mau coba tanpa data SRTM nyata? Buat GeoTIFF sintetis lebih dulu:
```bash
python tools/make_demo_dem.py  # -> data/demo_srtm.tif (elev 210..1014 m)
python convert_terrain.py --input data/demo_srtm.tif --box 26 16 --scale 2 --dry-run
```

## Aturan Emas (invarian)

PNG 16-bit · normalisasi **global** sebelum tiling · overlap 1 px · tiap tile ≤ 4096 px ·
skala seragam · origin di tengah (tile simetris) · `Position Y = −Size_Y/2` · terrain
dibentuk via Importer (bukan script) · deterministik. Detail di `AGENTS.md §3` & `SPEC.md`.
