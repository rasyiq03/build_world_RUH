# Tutorial Implementasi RUH di Roblox Studio (tim 3 orang)

> Panduan **langkah demi langkah** memindahkan kode + dunia RUH ke Roblox Studio, dari nol sampai
> bisa dimainkan lintas-place. Anchor desain: [GAME_DESIGN.md](GAME_DESIGN.md). Kontrak kode:
> [../AGENTS.md](../AGENTS.md) §3–4. Status spine: SUDAH terintegrasi & teruji headless (Lobby →
> teleport → 11 mekanisme lintas 9 place). Yang tersisa = pekerjaan **Studio**: dunia, model,
> publish PlaceId, GUI, NPC, lighting.

---

## 0. Sekali per mesin (SEMUA orang)

1. **Pasang alat (Aftman)** — di folder repo: `aftman install`. Mengunci **Rojo 7.4.4** + **Lune**
   (lihat [../aftman.toml](../aftman.toml)). Bila `aftman` belum ada: unduh dari rilis Aftman, taruh
   di PATH.
2. **Plugin Rojo di Studio** — di Studio: **Plugins → Manage Plugins → cari "Rojo" → Install**
   (atau `rojo plugin install`).
3. **Studio settings** — aktifkan **Game Settings → Security → Allow HTTP Requests** & **Enable
   Studio Access to API Services** (dibutuhkan teleport antar-place & beberapa build script).

---

## 1. Pahami arsitektur dulu (10 menit, hemat berjam-jam)

- **1 Experience, ~10 place.** Lobby + 5 Miqat + 4 zona ritual (Makkah/Mina/Muzdalifah/Arafah).
  Tiap place = satu `.rbxl` terpisah; pindah place via `TeleportService`.
- **Kode = git (via Rojo). Dunia = `.rbxl` (Studio).** Terrain, mesh, model, lighting di-simpan di
  place; skrip `.lua` disinkron dari repo. JANGAN tulis logika di Studio — tulis di VS Code → Rojo
  sync. (AGENTS.md §4.)
- **Spine data-driven.** Pemain memilih di **Lobby** → `ManasikState` dibangun → `TeleportData`
  dibawa → di place tujuan **ManasikBootstrap** merekonstruksi state & menjalankan tahap
  ([Flows.lua](../roblox/shared/Flows.lua)). Tiap place tahu dirinya dari **atribut Workspace
  `PlaceName`**.
- **Mekanisme baca DUNIA, bukan hardcode.** Tiap `PlaceContext.<Place>`
  ([PlaceContext.lua](../roblox/server/PlaceContext.lua)) mencari objek hasil build di Workspace
  (mis. `A_Makkah.Kaaba.Kaaba`). Kalau objek belum ada → **placeholder otomatis** dibuat supaya
  tetap bisa dimainkan. Jadi: **boleh main sebelum model jadi.**

### Peta folder repo → Studio (Rojo)
| Folder repo | → Lokasi Studio | Isi |
|---|---|---|
| `roblox/shared/` | `ReplicatedStorage.Shared` | spine + mekanisme (dipakai semua place) |
| `roblox/npc/` | `ReplicatedStorage.Npc` | behavior NPC |
| `roblox/server/` | `ServerScriptService.Server` | `ManasikBootstrap` (per place) |
| `roblox/client/` | `StarterPlayer.StarterPlayerScripts` | UI/nav/kamera |
| `roblox/places/Lobby/` | (khusus place Lobby) | `LobbyServer`/`LobbyClient` |
| `roblox/A_Makkah/` `B_Mina/` `C_Arafah/` `common/` | **edit-time** (Command Bar) | build dunia (BUKAN runtime) |

---

## 2. Resep BAKU membangun satu place (dipakai berulang)

Lakukan ini untuk **tiap** place yang kamu pegang:

1. **Buat place baru** di Studio (atau buka `.rbxl` place itu).
2. **Set identitas place** — klik `Workspace` → panel **Properties → Attributes → +** →
   tambah atribut **`PlaceName`** (tipe **String**) = nama place (lihat tabel §3, mis. `Makkah`,
   `Miqat_BirAli`). Ini yang dibaca `ManasikBootstrap`.
3. **Connect Rojo** — di repo: `rojo serve` (untuk place ritual/miqat pakai
   [../default.project.json](../default.project.json); untuk Lobby pakai
   `places/Lobby.project.json`, lihat §4-Devi). Di Studio: plugin **Rojo → Connect**. Skrip muncul
   di `ReplicatedStorage.Shared`, `ServerScriptService.Server`, dst.
4. **Bangun terrain** — impor heightmap zona via **Terrain Importer** (lihat `output/<zona>/
   IMPORT_GUIDE.md` & [SPEC.md](SPEC.md)). Ikuti Aturan Emas (AGENTS.md §3).
5. **Bangun dunia (Command Bar)** — tempel skrip build zona-mu ke **View → Command Bar** lalu
   Enter (lihat §4 per orang). Output muncul sebagai Folder di `Workspace`.
6. **Playtest (F5)** — `ManasikBootstrap` jalan, baca `PlaceName`, aktifkan mekanisme tahap. Lihat
   **Output** untuk log `[Notify→...]`. Tanpa `TeleportData`, bootstrap pakai *state dev*
   (`HajiTamattu` @ place ini) supaya bisa diuji solo.
7. **Publish** — **File → Publish to Roblox As…** → buat place dalam Experience RUH. Catat
   **PlaceId** (URL place). Nanti diisi ke `Teleport.PLACE_IDS` (§5).

> **Tip uji tanpa Studio:** sebelum/di sela langkah di atas, jalankan mekanisme headless via skill
> `mock-roblox` (lihat [../.claude/skills/mock-roblox/SKILL.md]). Sudah ada skenario per fitur +
> integrasi penuh (`scenarios/integrasi_penuh.luau`).

---

## 3. Daftar place, pemilik & atribut `PlaceName`

| `PlaceName` | Pemilik | Build script (Command Bar) | Node dunia yang dibaca PlaceContext |
|---|---|---|---|
| `Lobby` | **Devi** | — (GUI pilih ibadah/miqat) | — (spine ritual TIDAK jalan di Lobby) |
| `Miqat_BirAli` | **Devi** | `common/build_miqat.lua` | `Workspace.Bus` (BusRide) |
| `Makkah` | **Devi** | `A_Makkah/build_makkah.lua` | `A_Makkah.Kaaba.Kaaba`, `A_Makkah.Masaa.Bukit_Safa`/`Bukit_Marwah` |
| `Miqat_DzatuIrq` | **Nabil** | `common/build_miqat.lua` | `Workspace.Bus` |
| `Miqat_Juhfah` | **Nabil** | `common/build_miqat.lua` | `Workspace.Bus` |
| `Arafah` | **Nabil** | `C_Arafah/build_arafah.lua` | `Workspace.C_Arafah.BatasArafah` |
| `Muzdalifah` | **Nabil** | (terrain saja) | kerikil dibuat otomatis PlaceContext (cincin) |
| `Miqat_QarnulManazil` | **Praditama** | `common/build_miqat.lua` | `Workspace.Bus` |
| `Miqat_Yalamlam` | **Praditama** | `common/build_miqat.lua` | `Workspace.Bus` |
| `Mina` | **Praditama** | `B_Mina/build_mina.lua` | `Workspace.Jamarat.Jamratul_Ula/Wusta/Aqabah`, `Workspace.TempatQurban` |

> `common/build_miqat.lua` GENERIK: skrip sama dipakai kelima miqat, label dari atribut `PlaceName`.
> Membuat `Workspace.Bus` + `Workspace.Miqat{Peron,Papan}`. `TempatQurban` kini dibuat
> `build_mina.lua`. Tahallul = sub-lokasi Makkah (umrah) & Mina (haji), `station` opsional (nil → UI).

---

## 4. Tugas per orang (urut kerja)

### 🟢 DEVI — Lobby (entry spine), Bir Ali, Makkah
Panduan rinci: [tasks/DEVI.md](tasks/DEVI.md). Mekanisme milikmu **sudah jadi & teruji headless**
(TawafCounter, SaiCounter, IhramChange, IhramRules). Tinggal materialkan di Studio.

1. **Lobby (PRIORITAS — ini pintu masuk semua orang):**
   - Buat place `Lobby`, set atribut `PlaceName = "Lobby"`.
   - Rojo: pakai **`places/Lobby.project.json`** → `rojo serve places/Lobby.project.json` → Connect.
     Ini memetakan `LobbyServer` (ServerScriptService) + `LobbyClient` (StarterPlayerScripts) +
     `shared`. (`ManasikBootstrap` sengaja TIDAK ada di Lobby; spine ritual tak jalan di sini.)
   - **Bangun GUI** (StarterGui / dari `LobbyClient`): 4 kartu jenis ibadah (Umrah/Tamattu'/Ifrad/
     Qiran) + pilihan miqat (Gel. I → Bir Ali; Gel. II → Yalamlam/Qarnul Manazil) + tombol **Mulai**.
   - Tombol Mulai → panggil `LobbyClient.start(ibadahType, chosenMiqat)`
     ([LobbyClient](../roblox/places/Lobby/LobbyClient.client.lua)) → fire RemoteEvent `StartManasik`
     → `LobbyServer` validasi (`shared/LobbyStart`) → `Teleport.toPlace(miqat, data)`.
   - Nilai valid: `ibadahType` ∈ kunci [Flows](../roblox/shared/Flows.lua); `chosenMiqat` ∈
     `LobbyStart.MIQATS` ([LobbyStart](../roblox/shared/LobbyStart.lua)).

2. **Miqat Bir Ali:** place `Miqat_BirAli`. Set `PlaceName = "Miqat_BirAli"` → Command Bar jalankan
   **`common/build_miqat.lua`** (membuat `Workspace.Bus` + peron/papan; label otomatis dari
   `PlaceName`). IhramChange + IhramRules aktif otomatis (tahap IHRAM). BusRide pasang ProximityPrompt
   di part `Bus`.

3. **Makkah:** place `Makkah`, `PlaceName = "Makkah"`.
   - Impor terrain `A_Makkah` (`output/A_Makkah/IMPORT_GUIDE.md`).
   - Command Bar: jalankan **`A_Makkah/build_makkah.lua`** → membuat `Workspace.A_Makkah` (Kaaba,
     Mataf, Masaa/Safa-Marwah, dll). **Inilah yang dibaca `PlaceContext.Makkah`** untuk pusat Tawaf
     (`Kaaba`) & ujung Sa'i (`Bukit_Safa`/`Bukit_Marwah`) — sudah diselaraskan namanya.
   - Playtest: Tawaf = kelilingi Ka'bah 7× (deteksi sudut kumulatif); Sa'i = bolak-balik Safa↔Marwah
     7×. Lihat Output untuk hitungan.
4. **NPC:** Askar, Petugas OB, Pendorong kursi roda ([npc/](../roblox/npc/), kontrak NpcFramework).
5. **CG pass:** lighting interior Masjidil Haram, PBR Ka'bah, Bloom saat Tawaf, lighting Lobby & Bir
   Ali (lihat [COMPUTER_GRAPHICS.md](COMPUTER_GRAPHICS.md)).

### 🔵 NABIL — Dzatu 'Irq, Juhfah, Arafah, Muzdalifah, Tahallul (lead)
Panduan rinci: [tasks/NABIL.md](tasks/NABIL.md). Mekanisme (IhramHaji/Wukuf/Mabit/PebbleCollect/
WukufIbadah/Tahallul) sudah ada & teruji.

1. **Arafah:** place `Arafah` (default state dev = Arafah, paling mudah diuji). Impor terrain →
   Command Bar **`C_Arafah/build_arafah.lua`** → membuat `Workspace.C_Arafah.BatasArafah` yang
   dibaca `PlaceContext.Arafah` jadi **zona kehadiran Wukuf**. Tanpa itu → Wukuf tanpa gating zona.
2. **Muzdalifah:** place `Muzdalifah`. Terrain saja cukup — `PlaceContext.Muzdalifah` menyebar **7
   kerikil** otomatis dalam cincin di origin (PebbleCollect). Tambah model `Masy'aril Haram` (CG).
3. **2 Miqat (Dzatu 'Irq, Juhfah):** seperti resep §2; tambah part `Bus`.
4. **Tahallul (lintas-area):** modul `Tahallul` dipakai di Makkah (umrah, area Devi) & Mina (haji).
   Ia menyimpan atribut pemain **`TahallulState`** (`IHRAM`/`AWAL`/`COMPLETE`) yang **dibaca
   `IhramRules` (Devi)** untuk melonggarkan larangan. Sediakan part `station` cukur bila ingin via
   sentuh (opsional). Sesudah Tawaf Ifadah panggil `Tahallul.markTsani(player)` dari skrip Makkah.
5. **NPC:** Tenaga medis, Jamaah haji, TNI. **CG:** lighting senja Arafah, kabut Muzdalifah malam.

### 🟠 PRADITAMA — Qarnul Manazil, Yalamlam, Mina
Panduan rinci: [tasks/PRADITAMA.md](tasks/PRADITAMA.md). Mekanisme (JumrahThrow/Qurban/BusRide) &
NPC JamaahTawaf sudah ada & teruji.

1. **Mina:** place `Mina`. Impor terrain → Command Bar **`B_Mina/build_mina.lua`** → membuat
   `Workspace.Jamarat.Jamratul_Ula/Wusta/Aqabah` (3 tugu lempar) **dan `Workspace.TempatQurban`**
   (peron sembelih) — keduanya dibaca `PlaceContext.Mina`.
   - Playtest: hari 10 = Jumrah Aqabah 7×; hari 11-13 = 3 pilar berurutan + pilihan Nafar.
2. **2 Miqat (Qarnul Manazil, Yalamlam):** resep §2; Command Bar **`common/build_miqat.lua`** membuat
   part `Bus`. **BusRide** = milikmu (shared) — transisi miqat→Makkah; ia hanya gerbang, teleport
   tetap dijalankan spine.
3. **NPC Jamaah jalur Tawaf:** `JamaahTawaf` mengelilingi Ka'bah otomatis di **Makkah (area Devi)** —
   koordinasi spawn (center Ka'bah = `A_Makkah.Kaaba.Kaaba`). **CG:** kepadatan + LOD jamaah.

---

## 5. Menyatukan jadi 1 Experience (setelah tiap place dipublish)

1. **Satu Experience, banyak place.** Publish Lobby sebagai **start place** Experience; publish
   sisanya sebagai place dalam Experience yang **sama** (Asset Manager → Places, atau Publish As →
   pilih Experience RUH).
2. **Isi PlaceId** — buka [Teleport.lua](../roblox/shared/Teleport.lua), ganti tiap `0` di
   `PLACE_IDS` dengan PlaceId hasil publish (Lobby, 5 Miqat, Makkah, Mina, Muzdalifah, Arafah).
   Commit. Selama masih `0`, `Teleport.toPlace` hanya `warn` (uji solo tetap jalan).
3. **Aktifkan Teleport** — Experience harus **published** & **Studio Access to API Services** ON.
   Teleport antar-place hanya jalan di sesi yang benar-benar di server Roblox (atau Team Test),
   bukan selalu di solo playtest.
4. **Uji rantai penuh:** Lobby → pilih `Umrah` + `Bir Ali` → Mulai → teleport ke Bir Ali (Ihram) →
   bus → Makkah (Tawaf 7× → Sa'i 7× → Tahallul) → "Semoga mabrur". Lalu `HajiTamattu` untuk uji
   Armuzna (Mina/Arafah/Muzdalifah).

---

## 6. Checklist verifikasi (tempel di chat tim, centang bersama)

- [ ] `aftman install` sukses; Rojo Connect hijau di Studio (semua).
- [ ] Tiap place punya atribut Workspace **`PlaceName`** benar.
- [ ] Build script tiap zona menghasilkan node yang diharapkan PlaceContext (cek tabel §3) — TIDAK
      memakai placeholder (cek Output: pesan "diambil dari Workspace…", bukan "placeholder").
- [ ] `common/build_miqat.lua` dijalankan di tiap miqat (`Workspace.Bus` ada); `build_mina.lua`
      membuat `Workspace.TempatQurban`.
- [ ] GUI Lobby memanggil `StartManasik`; pilihan tervalidasi; teleport berangkat.
- [ ] Semua place dipublish dalam **1 Experience**; `Teleport.PLACE_IDS` terisi (tak ada `0`).
- [ ] Rantai Umrah penuh jalan ujung-ke-ujung; lalu HajiTamattu (lintas Armuzna).
- [ ] NPC & CG pass tiap area terpasang.

> **Sumber kebenaran implementasi spine = kode** (`shared/`, `server/`). Bila tutorial ini beda dari
> kode, ikuti kode & perbarui dokumen ini.
