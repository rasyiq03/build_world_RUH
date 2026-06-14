# ONBOARDING — Mulai Kerja di RUH (Tim 3 Orang)

Proyek ini sudah punya **fondasi siap-build** (lihat [GAME_DESIGN.md](GAME_DESIGN.md)). Pekerjaan build dibagi **3 orang**.

## Cara mulai (tiap anggota)

1. Buka repo ini di **Claude Code** (atau VS Code + Rojo).
2. **Perkenalkan diri**: ketik mis. `Saya Devi` (boleh nama atau NIM-mu).
3. Claude akan membuka **panduan tugasmu** (`docs/tasks/<NAMA>.md`), menjelaskan misimu, lalu
   melanjutkan membangun sesuai panduan + kontrak bersama.
4. Atau baca langsung panduanmu di tabel bawah.

## Siapa mengerjakan apa

| Kamu | Panduan | Misi singkat |
|---|---|---|
| **Devi Maulani (241524007)** | [tasks/DEVI.md](tasks/DEVI.md) | Lobby + Bir Ali + **Makkah (Tawaf/Sa'i)** + spine UI/Teleport |
| **M. Nabil S. Rasyiq (241524018)** | [tasks/NABIL.md](tasks/NABIL.md) | Dzatu 'Irq + Juhfah + **Arafah/Muzdalifah/Tahallul** · lead arsitek |
| **Praditama A. Hasan (241524023)** | [tasks/PRADITAMA.md](tasks/PRADITAMA.md) | Qarnul Manazil + Yalamlam + **Mina (Jumrah/Qurban)** |

## Aturan bersama (WAJIB semua) — ringkas

- Baca **[GAME_DESIGN.md](GAME_DESIGN.md)** (anchor) + **[../AGENTS.md](../AGENTS.md)**.
- **`roblox/shared/` = kontrak bersama** — jangan ubah signature tanpa koordinasi tim.
- **1 mekanisme / 1 NPC = 1 file** (kurangi konflik git).
- Mekanisme ikut kontrak **[`roblox/shared/mechanisms/_TEMPLATE.lua`](../roblox/shared/mechanisms/_TEMPLATE.lua)**.
- Skrip dunia baca **`output/<zona>/import_manifest.json`** — jangan hardcode koordinat.
- Tooling: **`aftman install` → `rojo serve`** (lihat [../roblox/README.md](../roblox/README.md)).
- Sumber kebenaran: **git = kode** (via Rojo), **Studio/.rbxl = terrain + mesh**.

## Alur kerja singkat
`aftman install` → `rojo serve` → Studio (plugin Rojo → Connect) → edit `.lua` di VS Code → tersinkron.
Terrain & model: impor manual di Studio (lihat panduan masing-masing).
