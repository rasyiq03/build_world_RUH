# SYSTEMS_DESIGN.md — Sistem Pemain, Waktu, & Panduan (RUH)

> Hasil diskusi desain 2026-06-23. Menjawab 8 celah: waktu siang/malam, jam, PlaceName manual,
> kecepatan pemain, kelengkapan equipment, buku panduan portable, makan/minum & perilaku, player
> state. Anchor: [GAME_DESIGN.md](GAME_DESIGN.md). Status spine/world/NPC: lihat [WORLD_PIPELINE.md](WORLD_PIPELINE.md).

## 0. Pilar desain (keputusan terkunci)
1. **Edukatif terpandu**, bukan survival. Fokus: ajari manasik yang BENAR + showcase Komputer Grafik.
2. **Kepatuhan LEMBUT.** Pelanggaran/kekurangan = status + peringatan mendidik; pemain TETAP boleh lanjut. Tak ada blokir/hukuman keras.
3. **Jam kontinu terkompresi** sebagai jantung waktu (Lighting + adzan + HUD).
4. **Completion di-gate CAPAIAN simulasi, bukan jam.** Time-skip = kenyamanan pemain (boleh ikut waktu nyata-terkompresi, boleh lompat) — selama indikator tahap tercapai.
5. **Perilaku = imersif opsional** (zamzam/istirahat/makan), tanpa sistem needs/stamina.
6. **Player-speed dipisah dari waktu** (setting kenyamanan + fast-travel bus), tak menskala logika ritual.

## 1. ManasikClock (shared) — jantung waktu
- Jam-dunia kontinu, terkompresi (tunable: mis. 1 hari = N menit). Menggerakkan `Lighting.ClockTime`,
  memicu **adzan** (`SoundManager`) saat melewati 5 waktu salat, dan menyuplai **jam HUD**.
- API rencana: `Clock.now()` (hari manasik + jam), `Clock.phase()` (subuh/dzuhur/ashar/maghrib/isya/malam),
  `Clock.advanceTo(target)` (time-skip), `Clock.onPrayer(cb)`.
- **Sinkron ritual:** Wukuf/Mabit TIDAK lagi murni detik-tetap. Selesai saat **capaian** terpenuhi
  (kehadiran di zona + syarat tahap). Pemain boleh:
  - menunggu waktu nyata-terkompresi (jam jalan biasa), ATAU
  - **time-skip**: percepat jam menembus periode (mabit→subuh, wukuf→maghrib). Time-skip TIDAK
    melewati capaian — kehadiran/syarat tetap dicek; ia hanya memajukan jam + langit.
- Headless-testable (jam virtual, seperti pola Wukuf sekarang). Visual Lighting = uji Studio.

## 2. PlayerState (shared) — tulang punggung equipment/aturan/status
- Satu sumber kebenaran per pemain (atribut + tabel server). Field: `ihramWorn`, `niat`, `pebbles`,
  `tahallulState` (sudah ada via Tahallul), `warnings[]`, `lastSafeZone`, dll.
- Mekanisme **menulis** (IhramChange→ihramWorn/niat; PebbleCollect→pebbles; Tahallul→tahallulState);
  UI & IhramRules **membaca**. Menggantikan state yang kini tersebar.
- **Equipment (poin 5)** = turunan PlayerState: "siap tahap ini?" → ditampilkan, TIDAK memblokir (lembut).
- **Di luar aturan (poin 8)** = turunan PlayerState + IhramRules (pelanggaran/dam) + kehadiran zona
  (Wukuf warn) → satu **indikator status** lembut. Bukan gate.
- Headless-testable (pure state + transisi).

## 3. UI Client (Devi) — panduan, jam, status
- **Buku panduan portable** (toggle): baca `ManasikState:current()` + tabel konten per-tahap
  (data-driven seperti Flows: langkah, niat/dua, do/don't). Pengganti Notify sekilas (HajiGuideUI).
- **Jam HUD**: hari manasik + fase (dari ManasikClock). Menara Abraj (model jam di build_makkah) bisa ikut.
- **Status kepatuhan**: indikator lembut dari PlayerState (mis. "Ihram ✓ · Niat ✓ · di Arafah ✓").
- **Kontrol time-skip**: tombol "Lewati ke [maghrib/subuh]" saat ritual-tunggu (memanggil Clock.advanceTo).
- Semua client; logika/data headless-testable, visual = Studio.

## 4. Gerak & kenyamanan (poin 4)
- **Player-speed** = setting kenyamanan (jalan/lari), TIDAK mengubah timer/jam ritual.
- Jarak jauh antar-zona = **fast-travel bus** (BusRide sudah ada), bukan sekadar naikkan speed.
- Tak ada "game-speed" terpadu (rapuh). Jam & ritual tetap otoritatif sendiri.

## 5. Perilaku imersif (poin 7)
- Minum **zamzam** (sudah ada di `ComfortStations`), **istirahat**, **makan** = aksi imersif (animasi/
  efek + mungkin "kesegaran" kosmetik). TANPA meteran haus/lapar yang menghukum.
- Boleh menulis ke PlayerState (mis. `refreshed`) hanya untuk umpan balik, bukan gate.

## 6. Infra — PlaceName (poin 3)
- **Atribut `Workspace.PlaceName` = ACUAN utama/override** (set manual bila perlu jaga-jaga — aman bila
  PlaceId salah/rusak/duplikat). **Bila atribut kosong → otomatis dari `game.PlaceId`** via reverse-lookup
  `Teleport.PLACE_IDS` (diisi). Jadi auto secara default (tak perlu manual), tapi PlaceName selalu bisa
  menimpa. PLACE_IDS terisi 2026-06-23 (10 place).

## 7. Urutan build (rencana, dependensi)
1. **ManasikClock** (shared) + uji headless (jam virtual, fase, prayer events).
2. **PlayerState** (shared) + sambungkan tulisan dari IhramChange/PebbleCollect/Tahallul; uji headless.
3. **Refactor Wukuf/Mabit** → capaian-gated + hook time-skip (pakai ManasikClock + PlayerState); uji headless.
4. **PlaceName auto** (Teleport reverse-lookup) + **player-speed/fast-travel** (cepat).
5. **UI client** (Devi): buku panduan + jam HUD + status + kontrol time-skip (logika headless, visual Studio).
6. **Lighting + adzan**: ManasikClock → `Lighting.ClockTime` + `SoundManager` adzan (uji visual Studio).
7. **Aksi imersif**: zamzam/istirahat/makan → PlayerState (ringan).

## 8. Batas jujur
Logika (clock, state, sync, nav UI, roster) → headless-testable via skill mock-roblox. **Visual**
(Lighting siang/malam, animasi, panel GUI sungguhan, suara adzan) → hanya terverifikasi di **Studio**.
