# Panduan Tugas — Devi Maulani (241524007)

> Baca dulu [GAME_DESIGN.md](../GAME_DESIGN.md) + [../../AGENTS.md](../../AGENTS.md). Patuhi kontrak `roblox/shared/`.

## Misi
**Pintu masuk game + Makkah.** Kamu memegang **Lobby**, **Miqat Bir Ali**, dan **area Tawaf & Sa'i
(Masjidil Haram)** — plus sebagian **spine bersama** (UI Panduan, wiring pilih-ibadah, Teleport).
Slice-mu adalah jalur kritis integrasi: koordinasi dekat dengan Nabil (lead).

## Yang kamu miliki (GAME_DESIGN §3)
- **Place:** Lobby, Miqat Bir Ali, Makkah.
- **Mekanisme:** IhramChange (ganti kostum), IhramRules (larangan ihram), HajiGuideUI,
  SoundManager (adzan/jamaah), **TawafCounter (7×)**, **SaiCounter (7×)**,
  **wiring Lobby→ManasikState + Teleport (shared)**.
- **NPC:** Askar, Petugas OB, Pendorong kursi roda.
- **CG (COMPUTER_GRAPHICS.md):** lighting interior Masjidil Haram, PBR Ka'bah, Bloom tawaf, lighting Lobby & Bir Ali.

## File milikmu
- `roblox/places/Lobby/`, `roblox/places/Miqat_BirAli/`, `roblox/places/Makkah/`
- `roblox/shared/mechanisms/`: `IhramChange.lua`, `IhramRules.lua`, `TawafCounter.lua` (skeleton sudah ada), `SaiCounter.lua`
- `roblox/client/` (UI Panduan), `roblox/npc/`: `Askar.lua`, `PetugasOB.lua`, `PendorongKursiRoda.lua`
- Model → `models/lobby/`, `models/miqat/bir_ali/`, `models/makkah/*` (lihat MODELS.md)

## Rencana build (urut)
1. **Rojo**: `aftman install` → `rojo serve` → Studio Connect.
2. **Lobby (UX §2.1)**: UI pilih jenis ibadah + miqat → `ManasikState.new(jenis, miqat)` →
   `Teleport.toPlace(miqat, data)`. **Ini spine — sepakati bentuk `data`/atribut dgn Nabil.**
3. **Penerima di place tujuan**: baca `TeleportData` → rekonstruksi ManasikState → `MechanismRegistry.activate(stage.ritual)`.
4. **Makkah**: impor terrain `A_Makkah` (output/A_Makkah/IMPORT_GUIDE.md) → pasang Ka'bah & Shafa-Marwah
   (placeholder dulu) → trigger tawaf & sa'i.
5. **Mekanisme**: isi `TawafCounter` (deteksi 7 putaran via sudut kumulatif keliling pusat Ka'bah) &
   `SaiCounter` (7 trip Shafa↔Marwah); `IhramChange` + `IhramRules` di Bir Ali.
6. **NPC** (Askar/OB/kursi roda) + **CG pass** (lighting interior, PBR Ka'bah, Bloom tawaf).

## Prompt kickoff (tempel ke Claude Code)
```
Saya Devi (241524007). Baca docs/tasks/DEVI.md, docs/GAME_DESIGN.md (§2.1, §3, §4-6), dan AGENTS.md.
Bantu aku membangun slice-ku, MULAI dari Lobby + spine wiring (ManasikState + Teleport).
Patuhi kontrak roblox/shared/. Konfirmasi rencana singkat dulu sebelum eksekusi.
```

## Selesai bila
Lobby memilih ibadah+miqat → teleport jalan · Makkah: tawaf 7× & sa'i 7× terhitung benar ·
IhramChange + IhramRules aktif di Bir Ali · NPC & lighting area terpasang.
