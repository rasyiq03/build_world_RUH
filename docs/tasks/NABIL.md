# Panduan Tugas — M. Nabil Syauqi Rasyiq (241524018) · Lead Arsitek

> Baca dulu [GAME_DESIGN.md](../GAME_DESIGN.md) + [../../AGENTS.md](../../AGENTS.md). Kamu juga **steward `roblox/shared/`**.

## Misi
**Puncak ritual haji + 2 miqat.** Kamu memegang **Miqat Dzatu 'Irq & Juhfah**, dan area
**Arafah, Muzdalifah, Tahallul (cukur)** — termasuk **Wukuf** (rukun terpenting) dan mekanisme
ritual tersulit. Sebagai lead, kamu menjaga konsistensi kontrak `shared/` yang dipakai bertiga.

## Yang kamu miliki (GAME_DESIGN §3)
- **Place:** Miqat Dzatu 'Irq, Miqat Juhfah, Arafah, Muzdalifah, (sub-lokasi) Tahallul/cukur.
- **Mekanisme:** IhramHaji, **Wukuf** (timer/doa, dzuhur–maghrib), Mabit, **PebbleCollect** (7 kerikil),
  **Tahallul** (state **awal** & **tsani** — lihat catatan Flows.lua), WukufIbadah.
- **NPC:** Askar, Tenaga medis, Jamaah haji, TNI.
- **CG (COMPUTER_GRAPHICS.md):** lighting **siang terik Arafah** + heat-haze + SunRays;
  **langit malam + kabut Muzdalifah** (ArafahMist sbg modal); DoF Jabal Rahmah.

## File milikmu
- `roblox/places/Miqat_DzatuIrq/`, `Miqat_Juhfah/`, `Arafah/`, `Muzdalifah/`
- `roblox/shared/mechanisms/`: `IhramHaji.lua`, `Wukuf.lua`, `Mabit.lua`, `PebbleCollect.lua`, `Tahallul.lua`, `WukufIbadah.lua`
- `roblox/npc/`: `Askar.lua` (koord. dgn Devi), `TenagaMedis.lua`, `JamaahHaji.lua`, `TNI.lua`
- Model → `models/miqat/dzatu_irq/`, `models/miqat/juhfah/`, `models/arafah/*`, `models/muzdalifah/*`, `models/tahallul/*`

## Rencana build (urut)
1. **Rojo** + (sbg lead) pastikan spine `shared/` stabil; sepakati bentuk `TeleportData` dgn Devi.
2. **Impor terrain** C_Arafah & D_Muzdalifah (output/<zona>/IMPORT_GUIDE.md).
3. **Arafah**: Jabal Rahmah + Masjid Namirah (placeholder) → `Wukuf` (timer wukuf, doa, wajib hadir di zona) + `WukufIbadah`.
4. **Muzdalifah**: Masy'aril Haram → `PebbleCollect` (ambil 7 kerikil) → transisi balik ke Mina.
5. **Tahallul**: modul `Tahallul` 2-state (awal: setelah Jumrah Aqabah; tsani: setelah Tawaf Ifadah) — dipakai lintas-area (Umrah di Makkah jg).
6. **Miqat Dzatu 'Irq & Juhfah**: trigger kedatangan + notifikasi + `IhramHaji`.
7. **NPC** + **CG pass** (terik Arafah, malam Muzdalifah).

## Prompt kickoff (tempel ke Claude Code)
```
Saya Nabil (241524018), lead. Baca docs/tasks/NABIL.md, docs/GAME_DESIGN.md, dan AGENTS.md.
Bantu aku membangun slice-ku, MULAI dari Arafah (impor terrain + mekanisme Wukuf).
Sebagai lead, jaga kontrak roblox/shared/ tetap konsisten. Konfirmasi rencana dulu.
```

## Selesai bila
Arafah: wukuf bisa diselesaikan (timer/hadir) · Muzdalifah: ambil 7 kerikil → lanjut ·
Tahallul awal/tsani benar · 2 miqat punya trigger+ihram · NPC & CG (terik/kabut/malam) terpasang.
