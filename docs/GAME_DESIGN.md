# GAME_DESIGN.md — RUH: Simulator Manasik Interaktif

> **Dokumen anchor.** Semua dokumen lain (terrain `SPEC.md`/`PIPELINE.md`, `COMPUTER_GRAPHICS.md`,
> `MODELS.md`) menggantung dari sini. Kalau bingung "ini game apa & kenapa", mulai di sini.

## 1. Visi & Tujuan

RUH (Route to Umrah & Hajj) = simulator **manasik haji & umrah** di Roblox untuk EAS Komputer
Grafik. Pemain memilih **jenis ibadah** di lobby (Umrah / Haji Tamattu' / Ifrad / Qiran), lalu
**dipandu menjalankan ritualnya** melintasi dunia nyata berbasis SRTM Mekkah. Dua tujuan sejajar:

1. **Akademik** — menonjolkan keilmuan Komputer Grafik (lihat `COMPUTER_GRAPHICS.md`).
2. **Berkelanjutan** — repo rapi, git + Rojo, dokumentasi hidup, dikerjakan tim 3 orang paralel.

## 2. Peta Experience (~10 place dalam 1 Experience)

```
Lobby  ──► Miqat (×5)  ──[bus]──►  Area Ibadah (Main, 4 zona)
pilih       ganti ihram,            Makkah ⇄ Mina ⇄ Muzdalifah ⇄ Arafah
ibadah      niat, naik bus          (rute SIKLUS, bukan linear)
```

- **Lobby** — pilih jenis ibadah + asal/miqat. UI Panduan.
- **5 Miqat** — Bir Ali (Dzulhulaifah), Juhfah (Rabigh), Qarnul Manazil (As-Sayl), Yalamlam, Dzatu 'Irq.
- **Area Ibadah** — "main place" dipecah jadi 4 zona ritual (terrain dari pipeline SRTM, lihat `SPEC.md`).

Tiap place = satu Roblox *place* dalam satu *Experience*; perpindahan via `TeleportService`,
diorkestrasi `shared/ManasikState` berdasarkan **tahap manasik saat ini** (bukan "next zone").

> **Terrain antar-zona independen.** Karena normalisasi elevasi **global** (gmin/gmax seluruh DEM,
> bukan per-zona — Aturan Emas #2 di `SPEC.md`), **menambah/mengubah satu zona TIDAK mengubah
> terrain zona lain.** Tiap zona = crop independen dari heightmap global yang sama; Size_Y & rentang
> elevasi identik lintas zona (itu yang membuat tinggi nyambung saat teleport). Zona boleh tumpang-
> tindih di sumber (mis. Muzdalifah di antara Mina–Arafah) tanpa masalah.
>
> **Tahallul (cukur) BUKAN zona terrain ke-5** — ia sub-lokasi (bangunan) di dalam **Mina** (tahallul
> haji) & **Makkah** (tahallul umrah). Zona terrain tetap **4**: Makkah, Mina, Muzdalifah, Arafah.

## 2.1 Alur Lobby & onboarding (UX)

Lobby = satu-satunya titik pemain memilih; sesudahnya alur dipandu otomatis oleh `ManasikState`.

```
[Spawn Lobby]
   │
   ├─ 1. Pilih JENIS IBADAH → Umrah · Haji Tamattu' · Haji Ifrad · Haji Qiran
   │       (kartu + deskripsi singkat tiap jenis; set `ibadahType`)
   │
   ├─ 2. Pilih MIQAT / RUTE → (default realisme Indonesia)
   │       • Gelombang I (via Madinah)     → Bir Ali (Dzulhulaifah)
   │       • Gelombang II (langsung Makkah) → Yalamlam / Qarnul Manazil
   │       (set `chosenMiqat`; 5 miqat tetap bisa dipilih utk eksplorasi)
   │
   ├─ 3. UI Panduan singkat (ringkas apa yang akan dijalani) → tombol "Mulai"
   │
   └─ 4. ManasikState.new(ibadahType, chosenMiqat)
          → simpan ke TeleportData → Teleport.toPlace(chosenMiqat, {ibadahType, chosenMiqat, index=1})
```

Di place tujuan: server baca `TeleportData` → rekonstruksi `ManasikState` →
`MechanismRegistry.activate(stage.ritual)`. **UI Panduan** (milik Devi) menampilkan tahap berjalan
sepanjang permainan, dibaca dari `ManasikState:current()`. Pemilik wiring Lobby→state: Devi (§9).

## 3. Pembagian Tugas Tim (kasar — sumber kebenaran penugasan)

| Orang                                    | Place miqat                                  | Area ibadah                                                                      | Mekanisme                                                                                  | NPC                                              |
| ---------------------------------------- | -------------------------------------------- | -------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ | ------------------------------------------------ |
| **Devi Maulani (241524007)**       | Lobby,**Bir Ali**                      | **Makkah**: Tawaf, Sa'i (Ka'bah, Hajar Aswad, Maqam Ibrahim, Shafa-Marwah) | Ganti kostum ihram, UI Panduan, rule larangan ihram, trigger suara adzan/jamaah            | Askar, Petugas OB, Pendorong kursi roda          |
| **M. Nabil S. Rasyiq (241524018)** | **Dzatu 'Irq**, **Juhfah**       | **Arafah, Muzdalifah, Tahallul (cukur)**                                   | Ihram Haji, Wukuf, Mabit, Tahallul, Ambil Kerikil, Ibadah saat wukuf                       | Askar, Tenaga medis, Jamaah haji, TNI            |
| **Praditama A. Hasan (241524023)** | **Qarnul Manazil**, **Yalamlam** | **Mina**: 3 Jumrah (Aqabah/Wustha/Ula), Tempat Qurban                      | Lempar Jumrah (counter/pilar/hari + feedback), trigger zamzam/kursi roda/istirahat, Qurban | Jamaah berbagai negara ikut jalur Tawaf otomatis |

Tiap orang bertanggung jawab penuh atas **aset 3D + tekstur + lighting + script interaksi** area-nya.
Konvensi penamaan place/folder: lihat §7 & `MODELS.md`.

### 3.1 Spec NPC (perilaku ringkas)

Tiap NPC = modul behavior di `roblox/npc/<Nama>.lua` (kontrak di `shared/NpcFramework`). Perilaku minimal:

| NPC | Pemilik | Lokasi | Perilaku ringkas |
|---|---|---|---|
| **Askar** (keamanan) | Devi/Nabil | gerbang, titik ramai | idle berjaga; arahkan / halangi pemain ke area terlarang |
| **Petugas OB** (kebersihan) | Devi | Makkah/Lobby | patroli rute + animasi menyapu |
| **Pendorong kursi roda** | Devi | jalur ritual | dorong "jemaah lansia" menyusuri path |
| **Tenaga medis** | Nabil | pos kesehatan Arafah/Muzdalifah | idle di pos; respon trigger "jemaah sakit" |
| **Jamaah haji** | Nabil | semua zona | kerumunan ambient: idle / jalan acak terbatas |
| **TNI** (petugas Indonesia) | Nabil | titik kumpul rombongan | jaga rombongan, penanda arah |
| **Jamaah jalur Tawaf** | Praditama | Makkah (mataf) | mengelilingi Ka'bah otomatis pada path melingkar |

Semua memakai `NpcFramework.walkTo`/path; kepadatan diatur `StreamingEnabled` + LOD (perf).

## 4. Arsitektur: alur sebagai DATA + state machine

Karena ada **4 jenis ibadah** dengan urutan berbeda dan **rute siklus**, alur TIDAK boleh
di-hardcode. Polanya:

```
FLOWS[jenis] = daftar Stage berurutan
Stage = { id, place, ritual(=mechanism id | nil), day(8..13 | nil), next("auto"|"on_ritual_done"), notes }
ManasikState berjalan di atas FLOWS[jenis]:
   tahap saat ini → set place aktif (teleport bila beda) → activate mechanism → tunggu selesai → tahap berikutnya
```

Menambah jenis ibadah = menambah satu tabel `FLOWS`, **bukan** menulis ulang logika.

## 5. Tabel Alur Manasik — ⚠️ DRAFT, Nabil verifikasi/koreksi (fikih)

> Ini draf pemahaman umum agar kamu **mengoreksi**, bukan menulis dari nol. Periksa urutan,
> hari, dan kewajiban (dam, tahallul awal/tsani). `place` memetakan ke peta §2.

### 5.1 Umrah

| # | id        | place           | ritual             | catatan                 |
| - | --------- | --------------- | ------------------ | ----------------------- |
| 1 | IHRAM     | Miqat           | IhramChange + niat | pakai ihram, niat umrah |
| 2 | KE_MAKKAH | (bus)           | BusRide            | transisi                |
| 3 | TAWAF     | Makkah          | TawafCounter (7×) | mengelilingi Ka'bah     |
| 4 | SAI       | Makkah          | SaiCounter (7×)   | Shafa→Marwah           |
| 5 | TAHALLUL  | Makkah/Tahallul | Tahallul (cukur)   | selesai, lepas ihram    |

### 5.2 Haji Tamattu' (umrah penuh → haji; ada dam)

| #    | id                                | place         | hari                 | ritual                                         |
| ---- | --------------------------------- | ------------- | -------------------- | ---------------------------------------------- |
| 1–5 | (UMRAH penuh spt §5.1, tahallul) |               | sebelum 8 Dzulhijjah |                                                |
| 6    | IHRAM_HAJI                        | Makkah        | 8                    | IhramHaji + niat haji                          |
| 7    | MABIT_MINA_1                      | Mina          | 8→9                 | Mabit                                          |
| 8    | WUKUF                             | Arafah        | 9                    | Wukuf (dzuhur–maghrib) + WukufIbadah          |
| 9    | MABIT_MUZDALIFAH                  | Muzdalifah    | 9→10                | Mabit + PebbleCollect                          |
| 10   | JUMRAH_AQABAH                     | Mina          | 10                   | JumrahThrow (Aqabah)                           |
| 11   | TAHALLUL_AWAL + QURBAN            | Mina/Tahallul | 10                   | Tahallul + Qurban (dam)                        |
| 12   | TAWAF_IFADAH                      | Makkah        | 10+                  | TawafCounter + SaiCounter                      |
| 13   | MABIT_MINA_2 + JUMRAH             | Mina          | 11–13               | Mabit + JumrahThrow (Ula, Wustha, Aqabah)/hari |
| 14   | TAWAF_WADA                        | Makkah        | akhir                | TawafCounter                                   |

### 5.3 Haji Ifrad (haji saja, tanpa umrah,  **tanpa dam** )

Pelaksanaan haji murni. Tawaf Qudum dan Sa'i bisa dilakukan di awal kedatangan, namun jamaah **tidak tahallul** (tetap dalam keadaan ihram) hingga tanggal 10 Dzulhijjah. Tidak diwajibkan membayar dam.

| **#** | **id**     | **place** | **hari**    | **ritual**        | **catatan**                                    |
| ----------- | ---------------- | --------------- | ----------------- | ----------------------- | ---------------------------------------------------- |
| 1           | IHRAM_HAJI       | Miqat           | Sblm/8 Dzulhijjah | IhramChange + niat haji | pakai ihram, niat haji saja                          |
| 2           | TAWAF_QUDUM      | Makkah          | Kedatangan        | TawafCounter (7×)      | tawaf kedatangan (sunnah)                            |
| 3           | SAI_HAJI_AWAL    | Makkah          | Kedatangan        | SaiCounter (7×)        | Sa'i haji,**ihram ditahan (tidak tahallul)**   |
| 4           | MABIT_MINA_1     | Mina            | 8→9              | Mabit                   | sunnah tarwiyah                                      |
| 5           | WUKUF            | Arafah          | 9                 | Wukuf + WukufIbadah     | mulai dzuhur hingga maghrib                          |
| 6           | MABIT_MUZDALIFAH | Muzdalifah      | 9→10             | Mabit + PebbleCollect   | ambil kerikil untuk jumrah                           |
| 7           | JUMRAH_AQABAH    | Mina            | 10                | JumrahThrow (Aqabah)    | melempar jumrah aqabah (7 batu)                      |
| 8           | TAHALLUL_AWAL    | Mina/Tahallul   | 10                | Tahallul (cukur)        | lepas ihram awal,**tanpa qurban/dam**          |
| 9           | TAWAF_IFADAH     | Makkah          | 10+               | TawafCounter (7×)      | rukun haji (jika belum Sa'i di tahap 3, tambah Sa'i) |
| 10          | MABIT_MINA_2     | Mina            | 11–13            | Mabit + JumrahThrow     | mabit & lempar 3 jumrah (Ula, Wustha, Aqabah)/hari   |
| 11          | TAWAF_WADA       | Makkah          | akhir             | TawafCounter (7×)      | tawaf perpisahan sebelum pulang                      |

### 5.4 Haji Qiran (umrah+haji sekaligus, 1 ihram,  **ada dam** )

Menggabungkan niat haji dan umrah. Tawaf Qudum dan Sa'i di awal sudah mencakup umrah dan haji sekaligus. Jamaah **tidak tahallul** hingga tanggal 10 Dzulhijjah. Diwajibkan membayar dam (qurban).

| **#** | **id**     | **place** | **hari**    | **ritual**         | **catatan**                                              |
| ----------- | ---------------- | --------------- | ----------------- | ------------------------ | -------------------------------------------------------------- |
| 1           | IHRAM_QIRAN      | Miqat           | Sblm/8 Dzulhijjah | IhramChange + niat qiran | niat umrah & haji sekaligus                                    |
| 2           | TAWAF_QUDUM      | Makkah          | Kedatangan        | TawafCounter (7×)       | tawaf kedatangan                                               |
| 3           | SAI_QIRAN        | Makkah          | Kedatangan        | SaiCounter (7×)         | Sa'i untuk umrah+haji,**ihram ditahan (tidak tahallul)** |
| 4           | MABIT_MINA_1     | Mina            | 8→9              | Mabit                    | sunnah tarwiyah                                                |
| 5           | WUKUF            | Arafah          | 9                 | Wukuf + WukufIbadah      | mulai dzuhur hingga maghrib                                    |
| 6           | MABIT_MUZDALIFAH | Muzdalifah      | 9→10             | Mabit + PebbleCollect    | ambil kerikil untuk jumrah                                     |
| 7           | JUMRAH_AQABAH    | Mina            | 10                | JumrahThrow (Aqabah)     | melempar jumrah aqabah (7 batu)                                |
| 8           | QURBAN_TAHALLUL  | Mina/Tahallul   | 10                | Qurban (dam) + Tahallul  | **wajib qurban (dam)** , dilanjutkan cukur/tahallul      |
| 9           | TAWAF_IFADAH     | Makkah          | 10+               | TawafCounter (7×)       | rukun haji (Sa'i sudah terpenuhi di tahap 3)                   |
| 10          | MABIT_MINA_2     | Mina            | 11–13            | Mabit + JumrahThrow      | mabit & lempar 3 jumrah (Ula, Wustha, Aqabah)/hari             |
| 11          | TAWAF_WADA       | Makkah          | akhir             |                          |                                                                |

### 5.5 Catatan implementasi alur (untuk codegen `FLOWS`)

- **`place: "Miqat"` = token runtime.** Pemain memilih 1 miqat di Lobby → token "Miqat" di-resolve
  ke place miqat terpilih → berkeliling & ganti ihram di sana → mekanisme → teleport ke Makkah.
  Kelima miqat tetap dibangun (siapa pun bisa terpilih), tapi satu playthrough mengunjungi satu (§9).
- **`place: "…/Tahallul"`** = ritual `Tahallul` dijalankan di sub-lokasi cukur DALAM Mina (haji) /
  Makkah (umrah) — bukan teleport ke zona terpisah. Modul `Tahallul` (milik Nabil) dipanggil
  lintas-area lewat kontrak `shared`.
- **Tamattu' §5.2 baris 1–5** diekspansi jadi tahap eksplisit saat jadi `FLOWS` (IHRAM_UMRAH →
  TAWAF_UMRAH → SAI_UMRAH → TAHALLUL_UMRAH), memakai-ulang tahap Umrah §5.1.
- **`Stage.next`** diturunkan: tahap ritual = `on_ritual_done` (tunggu `mechanism.isDone()`);
  transisi/bus = `auto`/trigger zona.
- **Qiran §5.4 tahap 11 (TAWAF_WADA)**: sel ritual kosong → isi `TawafCounter (7×)`.

### 5.6 Verifikasi alur vs acuan fikih ✅

Dicocokkan dengan [`reference/KITAB_IBADAH_HAJI.md`](reference/KITAB_IBADAH_HAJI.md) (ekstrak PDF).
**Hasil: alur §5.1–5.4 SESUAI.** Terkonfirmasi:
- **3 jenis & dam:** Tamattu' (umrah→haji, wajib hadyu), Qiran (umrah+haji sekaligus, tak tahallul s.d. hari 10, wajib dam), Ifrad (haji saja, tanpa dam). ✓
- **Umrah = Ihram→Thawaf→Sa'i→Tahallul.** ✓
- **5 miqat makani sesuai asal:** Dzulhulaifah (Madinah), Juhfah (Mesir/Syam/Maroko), Qarnul Manazil (Najd/Timur), Yalamlam (Yaman), Dzatu 'Irq (Iraq). ✓ → mendukung "1 miqat sesuai asal" (§9).
- **Urutan hari:** Ihram haji (8) → mabit Mina (Tarwiyah) → wukuf Arafah (9, singgah **Namirah**, s.d. maghrib) → mabit **Muzdalifah** + ambil kerikil (**Masy'aril Haram**) → Jumrah Aqabah (10) → tahallul awal (cukur) + hadyu → Thawaf Ifadah. ✓
- **Sa'i kedua:** Tamattu' WAJIB sa'i lagi setelah Thawaf Ifadah; Ifrad/Qiran cukup sa'i di qudum (tak diulang). ✓ (persis seperti tabel)

Penyempurnaan kecil (opsional, untuk mekanisme):
- **Tahallul awal vs tsani:** setelah Jumrah Aqabah semua larangan halal KECUALI hubungan suami-istri; tahallul *tsani* (lengkap) baru setelah Thawaf Ifadah → bisa jadi 2 state di modul `Tahallul`.
- **Namirah** (Arafah) & **Masy'aril Haram** (Muzdalifah) = sub-lokasi penting; sudah terdaftar di `MODELS.md`. ✓

**Sumber kedua — Tuntunan Manasik Kemenag 2023** ([`reference/TUNTUNAN_MANASIK_HAJI_UMRAH.md`](reference/TUNTUNAN_MANASIK_HAJI_UMRAH.md), OCR) — **juga SESUAI**, plus detail praktis Indonesia:
- **Niat per jenis** persis: Tamattu'→ihram **umrah**, Ifrad→ihram **haji**, Qiran→ihram **umrah+haji**. ✓
- **Miqat jemaah Indonesia:** Gel. I (via Madinah) → **Bir Ali (Dzulhulaifah)**; Gel. II (langsung Makkah) → **Yalamlam / Qarnul Manazil** (diambil di atas pesawat). → memperkuat "pilih 1 miqat sesuai asal/rute" di Lobby (§9).
- **Armuzna:** ambil **7 kerikil** di Muzdalifah & **naik bus** antar-lokasi → memvalidasi mekanisme `PebbleCollect` & `BusRide`. ✓
- **Refinemen:** **Nafar awwal (12 Dz.)** vs **nafar tsani (13 Dz.)** untuk meninggalkan Mina → bisa jadi pilihan di tahap `MABIT_MINA_2`.

> Verifikasi berdasarkan ~250 halaman pertama (bagian manasik); sisa buku = doa/dzikir & panduan lansia.

## 6. Kontrak Mekanisme Modular

Tiap mekanisme = satu ModuleScript di `roblox/shared/mechanisms/<Nama>.lua`:

```lua
local M = {}
M.id = "TawafCounter"
function M.init(ctx)       end  -- sekali saat place load (pasang trigger, ambil refs)
function M.activate(ctx)   end  -- saat tahap manasik mengaktifkannya
function M.deactivate(ctx) end  -- saat tahap selesai/pindah
function M.isDone()  return false end  -- untuk next="on_ritual_done"
return M
```

`shared/MechanismRegistry` memuat semua modul & meng-`activate/deactivate` sesuai tahap dari
`ManasikState`. `ctx` = { state, player, place, signals }. **Menambah mekanisme = drop file + daftar.**

Daftar mekanisme & pemilik → §3. Lokasi file → §7.

**Kepemilikan mekanisme (final, dari keputusan §9):**

| Mekanisme | Pemilik |
|---|---|
| IhramChange (kostum), IhramRules, HajiGuideUI, SoundManager (adzan/jamaah) | Devi |
| **TawafCounter, SaiCounter** | **Devi** |
| **Wiring pilih-ibadah Lobby → ManasikState** + **sistem Teleport (shared)** | **Devi** |
| IhramHaji, Wukuf, Mabit, PebbleCollect, WukufIbadah | Nabil |
| **Tahallul** (dipakai Umrah & haji, lintas-area) | **Nabil** |
| JumrahThrow, trigger zamzam/kursi-roda/istirahat, Qurban | Praditama |
| **BusRide** (transisi miqat→Makkah, shared) | **Praditama** |

## 7. Struktur kode `roblox/` (proyek Rojo)

```
roblox/
├── shared/                 # KONTRAK BERSAMA — ubah dgn koordinasi (jangan sepihak)
│   ├── ManasikState.lua    # state machine + FLOWS (data §5)
│   ├── MechanismRegistry.lua
│   ├── Teleport.lua        # transisi antar-place
│   ├── TriggerZone.lua     # util zona trigger (dipakai semua: kedatangan, notifikasi)
│   ├── NpcFramework.lua    # spawn/path/behavior dasar NPC
│   ├── SoundManager.lua    # adzan/ambience
│   ├── Notify.lua          # notifikasi/UI dasar
│   └── mechanisms/         # 1 file per mekanisme (pemilik di §3)
├── places/
│   ├── Lobby/ Miqat_BirAli/ … Makkah/ Mina/ Muzdalifah/ Arafah/ Tahallul/
│   └── (per place: ServerScript init + LocalScript bila perlu, panggil shared)
└── npc/                    # behavior NPC per tipe (pemilik di §3)
```

## 8. Aturan integrasi (agar 3 orang tak bentrok)

1. **`shared/` adalah kontrak.** Perubahan signature dibicarakan dulu (chat tim), karena dipakai semua.
2. **1 mekanisme/NPC = 1 file.** Kurangi konflik git. Jangan menaruh dua fitur di satu file.
3. **Semua koordinat & ukuran dunia baca dari `output/<zona>/import_manifest.json`** (lihat PLAYBOOK). Jangan hardcode.
4. **Konvensi nama place** = sama persis di `ManasikState`, folder `roblox/places/`, dan nama place Studio.
5. **Model** tak masuk git; lihat `MODELS.md` untuk folder & spec.

## 9. Keputusan terbuka (celah dari pembagian "kasar" — perlu diputuskan)

- [X] **Pemilik counter Tawaf & Sa'i** — area Makkah milik Devi; siapa tulis `TawafCounter`/`SaiCounter`? DEVI
- [X] **Mekanisme Bus** (`BusRide`, transisi miqat→Makkah) — masuk `shared`? siapa rakit? PRADITAMA
- [X] **Wiring pilihan ibadah di Lobby → `ManasikState`** — UI milik Devi, logika `shared`; batasnya? DEVI
- [X] **Sistem Teleport antar-place** — `shared`; siapa seed pertama (usul: Nabil sbg lead)? DEVI
- [X] **NPC jalur Tawaf (Praditama) berjalan di area Makkah (Devi)** — sepakati kontrak NpcFramework + spawn. PRADITA<A
- [X] **Tahallul**: terjadi di Umrah (Makkah, area Devi) DAN haji (area Nabil). Satu modul dipakai dua tempat? NABIL
- [X] **Miqat**: pemain lewat **satu** miqat sesuai asal (dipilih di lobby) atau bisa **jelajah kelima**? Pemain Pilih 1 Miqat Di Loby --> Pindah Ke miqot terpilih --> bisa berkeliling di miqat dan ganti Ihram --> ada mekanisme, langsung teleport ke makkah

## 10. Tautan

- Terrain (angka & rumus): [`SPEC.md`](SPEC.md), [`PIPELINE.md`](PIPELINE.md), [`PLAYBOOK.md`](PLAYBOOK.md)
- Komputer Grafik (inti nilai): [`COMPUTER_GRAPHICS.md`](COMPUTER_GRAPHICS.md)
- Daftar & spec model: [`MODELS.md`](MODELS.md)
