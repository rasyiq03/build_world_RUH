# START_PROMPT.md — Prompt Pemicu Implementasi

Salin teks di bawah ini ke Claude Code (dijalankan dari dalam direktori `make_main_place/`).

---

Kamu bekerja di direktori `make_main_place/`. Mulai dengan membaca `AGENTS.md` lalu `SPEC.md`, `PIPELINE.md`, dan `TASKS.md` — itu adalah konteks dan kontrak proyek. Patuhi "Aturan Emas" di AGENTS.md §3 di atas preferensi gaya apa pun.

Tugasmu: membangun CLI tool Python yang mengubah satu GeoTIFF SRTM menjadi beberapa tile PNG 16-bit + manifest impor untuk Roblox Terrain Importer, sesuai SPEC & PIPELINE.

Kerjakan mengikuti urutan di `TASKS.md`, tahap demi tahap. Aturan main:
1. Sebelum menulis kode, konfirmasi rencanamu singkat (struktur file + tahap mana yang dikerjakan dulu).
2. Jangan menebak `input_tif`, `box_width_km`, atau `box_height_km`. Buat `config.json` dengan field wajib dikosongkan + validasi gagal-aman, dan tanyakan nilai aktualnya kepadaku bila perlu untuk uji nyata.
3. Yang paling kritis dan harus benar sejak awal: (a) output PNG 16-bit, (b) normalisasi elevasi GLOBAL sebelum tiling, (c) overlap 1 piksel antar-tile, (d) origin di tengah & Position Y = -(Size_Y/2).
4. Setelah pipeline jadi, jalankan `test_pipeline.py` dengan DEM sintetis (tanpa file SRTM asli) untuk membuktikan normalisasi global & overlap benar. Tunjukkan hasilnya.
5. Akhiri dengan `--dry-run` memakai contoh config default (box 26×16 km, skala 2) dan tampilkan rencana tile + ringkasannya, supaya aku bisa memeriksa angka Size/Position sebelum memproses GeoTIFF asli.

Mulai dari Tahap 0.
