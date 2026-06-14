# Panduan Tugas — Praditama Ajmal Hasan (241524023)

> Baca dulu [GAME_DESIGN.md](../GAME_DESIGN.md) + [../../AGENTS.md](../../AGENTS.md). Patuhi kontrak `roblox/shared/`.

## Misi
**Mina + transportasi.** Kamu memegang **Miqat Qarnul Manazil & Yalamlam** (miqat utama jemaah
Indonesia Gel. II), dan **kawasan Mina** — **3 pilar Jumrah** (Aqabah/Wustha/Ula), **Tempat Qurban**,
plus mekanisme **Bus** (shared) yang menyambung miqat→Makkah & antar-Armuzna.

## Yang kamu miliki (GAME_DESIGN §3)
- **Place:** Miqat Qarnul Manazil, Miqat Yalamlam, Mina.
- **Mekanisme:** **JumrahThrow** (counter lemparan **per pilar per hari** + umpan balik; perhatikan
  **nafar awwal hari 12 vs tsani hari 13**, lihat Flows.lua), trigger **zamzam / kursi roda / area istirahat**,
  **Qurban**, **BusRide** (shared — transisi miqat→Makkah & Armuzna).
- **NPC:** Jamaah berbagai negara **mengikuti jalur Tawaf otomatis** (berjalan melingkar di Makkah —
  *lintas-area*, koordinasi dgn Devi soal spawn & path).
- **CG (COMPUTER_GRAPHICS.md):** lighting Mina (**ribuan lampu, instancing**), debu area jumrah, material pilar.

## File milikmu
- `roblox/places/Miqat_QarnulManazil/`, `Miqat_Yalamlam/`, `Mina/`
- `roblox/shared/mechanisms/`: `JumrahThrow.lua`, `Qurban.lua`, `BusRide.lua`, `ZamzamTrigger.lua` (+ kursi roda/istirahat)
- `roblox/npc/`: `JamaahTawaf.lua` (path melingkar di Makkah)
- Model → `models/miqat/qarnul_manazil/`, `models/miqat/yalamlam/`, `models/mina/*` (jamarat, qurban, lamps, tents)

## Rencana build (urut)
1. **Rojo**: `aftman install` → `rojo serve` → Studio Connect.
2. **Mina**: impor terrain `B_Mina` (sudah teruji) → tenda/jamarat/lampu (skrip lama `roblox/B_Mina/` bisa jadi acuan; tenda & LampMaster sudah ada di models/).
3. **JumrahThrow**: 3 pilar (Aqabah/Wustha/Ula), hitung 7 lemparan/pilar, aturan per hari (10: aqabah; 11–13: 3 pilar), umpan balik kena/tidak. Tambah pilihan **nafar awal/tsani**.
4. **Qurban**: area + proses (animasi/penanda) hari nahar.
5. **BusRide** (shared): kendaraan transisi antar-place (sepakati pemicu dgn Devi/Nabil).
6. **Trigger** zamzam/kursi roda/istirahat + **NPC** jalur Tawaf + **CG pass** (lampu Mina, debu).

## Prompt kickoff (tempel ke Claude Code)
```
Saya Praditama (241524023). Baca docs/tasks/PRADITAMA.md, docs/GAME_DESIGN.md, dan AGENTS.md.
Bantu aku membangun slice-ku, MULAI dari Mina + mekanisme JumrahThrow (3 pilar, per hari).
Patuhi kontrak roblox/shared/. Konfirmasi rencana singkat dulu sebelum eksekusi.
```

## Selesai bila
Mina terbangun · JumrahThrow: 3 pilar, 7 lemparan/pilar, aturan per-hari + nafar awal/tsani ·
Qurban & BusRide jalan · 2 miqat punya trigger+ihram · NPC jalur Tawaf + lighting Mina terpasang.
