# TASKS.md — Urutan Pengerjaan (Pipeline Terrain)

> ⚠️ **Historis / cakupan sempit.** Berkas ini = checklist pipeline TERRAIN awal (sebagian besar
> sudah selesai). Untuk rancangan & roadmap GAME penuh (4 zona, ritual, tim), lihat
> **[GAME_DESIGN.md](GAME_DESIGN.md)** & **[PLAYBOOK.md](PLAYBOOK.md)**.

Kerjakan berurutan. Jangan lompat ke tahap berikut sebelum tahap sebelumnya terverifikasi.

## Tahap 0 — Bootstrap
- [ ] Baca `AGENTS.md`, `SPEC.md`, `PIPELINE.md`.
- [ ] Buat `requirements.txt` (`tifffile`, `numpy`, `imageio`).
- [ ] Buat `config.json` dengan placeholder + komentar; field wajib dikosongkan agar gagal-aman.
- [ ] Buat kerangka `convert_terrain.py` + paket `terrain/` (modul kosong: `config.py`, `io.py`, `normalize.py`, `tiling.py`, `manifest.py`).

## Tahap 1 — Core data
- [ ] `terrain/io.py`: baca GeoTIFF (band 1) → float32; tulis PNG 16-bit.
- [ ] `terrain/normalize.py`: NoData cleanup + **normalisasi global** → uint16 (SPEC §3).
- [ ] Unit kecil: normalisasi DEM sintetis menghasilkan min=0, max=65535, dtype uint16.

## Tahap 2 — Tiling
- [ ] `terrain/tiling.py`: hitung tiles_x/tiles_z, size & position (SPEC §4), potong dengan overlap (SPEC §5).
- [ ] Validasi tiap tile ≤ max_tile_px; error jelas bila tidak.
- [ ] Assert: nilai kolom/baris overlap identik antar-tile bersebelahan.

## Tahap 3 — Manifest & guide
- [ ] `terrain/manifest.py`: tulis `import_manifest.json` (SPEC §6).
- [ ] Generate `IMPORT_GUIDE.md`: satu blok per tile, Size & Position persis, material non-Water, pengingat smooth sambungan & Position Y negatif.

## Tahap 4 — Orkestrasi & UX
- [ ] `convert_terrain.py`: rangkai pipeline (PIPELINE §3), CLI (`--config`, `--input/--box/--scale`, `--dry-run`).
- [ ] Logging progres + ringkasan akhir.
- [ ] Penanganan error tabel PIPELINE §4.

## Tahap 5 — Test & dokumen
- [ ] `test_pipeline.py` (PIPELINE §6) lulus tanpa SRTM asli.
- [ ] `README.md`: instal, contoh jalan, cara pakai output di Roblox Studio.
- [ ] Cek ulang seluruh Aturan Emas (AGENTS §3) & Definition of Done (AGENTS §8).

## Catatan: Fase 2 (opsional, nanti)
Setelah pipeline terrain solid, kandidat tugas lanjutan (jangan dikerjakan sekarang kecuali diminta):
- Generator template `MinaTents_placement.lua` untuk Command Bar Studio (raycast-to-terrain, baca grid/JSON).
- Skema JSON penempatan objek masif (tenda, lampu, pilar Jumrah).
