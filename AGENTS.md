# AGENTS.md — Panduan Agent untuk Repo RUH

> Repo ini = perancangan & pembangunan **RUH (Route to Umrah & Hajj)** — simulator manasik
> haji/umrah di Roblox (EAS Komputer Grafik, tim 3 orang). Dulu hanya pipeline terrain; kini
> mencakup seluruh game. **Baca [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) lebih dulu** — itu
> anchor: alur manasik, 4 zona, 4 jenis ibadah, ritual interaktif, pembagian tim.

## 1. Peta repo (di mana segala sesuatu)

| Path | Isi | Catatan |
|---|---|---|
| `convert_terrain.py` · `terrain/` | pipeline terrain (CLI + paket) | entry di root; teruji 34/34 |
| `generators/` | generator konten: OSM, tenda, teras, route, JSON→Lua | jalankan dari root: `python generators/<x>.py` |
| `tools/` | utilitas (`make_demo_dem`, visualisasi) | |
| `roblox/` | kode Lua in-game (proyek **Rojo**) | `shared/` = kontrak bersama; lihat `roblox/README.md` |
| `tests/` | `test_pipeline.py` (smoke test terrain) | `python tests/test_pipeline.py` |
| `docs/` | rancangan & spec | `GAME_DESIGN` (anchor) · `SPEC`/`PIPELINE` (terrain) · `COMPUTER_GRAPHICS` · `MODELS` · `PLAYBOOK` · `progress/` · `reference/` |
| `models/` | folder tujuan model 3D per area | file mesh gitignored; lihat `docs/MODELS.md` |
| `output/` · `data/` | artefak terrain (gitignored) | |

## 2. Lingkungan & alat
- **Python 3.10+** — `pip install -r requirements.txt` (numpy, tifffile, imageio; `imagecodecs` opsional untuk TIF terkompresi).
- **Roblox/Rojo via Aftman** — `aftman install` → `rojo serve` → plugin Rojo di Studio (lihat `roblox/README.md`).

## 3. ATURAN EMAS terrain (invarian — jangan langgar; detail di `docs/SPEC.md`)
1. Output **PNG 16-bit** (`uint16`). 8-bit = lereng berundak.
2. Normalisasi elevasi **GLOBAL** (min/max seluruh DEM) **sebelum** memotong. (Konsekuensi: menambah/ubah satu zona TIDAK mengubah zona lain.)
3. Tile bersebelahan **overlap 1 piksel**.
4. Tiap tile **≤ 4096 px** & **≤ max_tile_voxels** (budget volume impor).
5. **Skala seragam** seluruh dunia (config `scale_studs_per_m`, kini 4).
6. **Origin di tengah**, tile simetris terhadap (0,0,0).
7. **`Position Y = -(Size_Y/2)`** semua tile.
8. Terrain dibentuk via **Terrain Importer** (bukan script).
9. **Deterministik** — input+config sama → output sama.

## 4. Aturan game/kode (detail di `docs/GAME_DESIGN.md` §4-8)
- **Alur manasik = DATA** (`roblox/shared/Flows.lua`), bukan kode bercabang. Tambah jenis ibadah = tambah tabel.
- **`roblox/shared/` = kontrak bersama** — ubah signature dengan koordinasi tim (chat), karena dipakai bertiga.
- **1 mekanisme / 1 NPC = 1 file** (kurangi konflik git).
- Semua skrip jalan/bangunan **baca `output/<zona>/import_manifest.json`** — jangan hardcode koordinat/resolusi.
- **Sumber kebenaran:** git = KODE (via Rojo); Studio/`.rbxl` = terrain + mesh + dunia hasil build.

## 5. Saat ragu
Jangan menebak nilai (box geo, path TIF). Gagal-aman + tanya user. Utamakan invarian §3 di atas konvensi gaya apa pun.

## 6. Onboarding tim (3 orang)
Build dibagi 3. **Jika user memperkenalkan diri** — mis. "Saya Devi", menyebut nama, atau NIM
`241524007/018/023` — maka: buka panduan tugasnya, **ringkas misinya**, lalu **lanjutkan membangun
slice-nya** sesuai panduan itu + kontrak §3–4. Konfirmasi rencana singkat sebelum eksekusi.

| Sebut | NIM | Panduan |
|---|---|---|
| Devi (Maulani) | 241524007 | `docs/tasks/DEVI.md` — Lobby, Bir Ali, Makkah (Tawaf/Sa'i), spine UI/Teleport |
| Nabil (Rasyiq) | 241524018 | `docs/tasks/NABIL.md` — Dzatu 'Irq, Juhfah, Arafah/Muzdalifah/Tahallul (lead) |
| Praditama (Ajmal) | 241524023 | `docs/tasks/PRADITAMA.md` — Qarnul Manazil, Yalamlam, Mina (Jumrah/Qurban) |

Pintu masuk manusia: `docs/ONBOARDING.md`.
