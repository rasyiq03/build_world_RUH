# MODELS.md — Daftar & Spesifikasi Model 3D (direkonsiliasi dgn kode)

> Model = **pekerjaan tim 3D**. Repo menyiapkan **folder tujuan + spec + WIRING** (node Workspace /
> sistem yang membacanya). Mesh besar di-`.gitignore`; folder (`.gitkeep`) & dok ini di-commit.
> Sumber wiring: [WORLD_PIPELINE.md](WORLD_PIPELINE.md) (node hasil build), [SYSTEMS_DESIGN.md](SYSTEMS_DESIGN.md).

## 1. Konvensi WAJIB (cegah "tenda rebah / origin melayang")
| Aspek | Aturan |
|---|---|
| **Up-axis** | **Y ke atas** (import: Up=Y; jika software Z-up, rotasi 90°). |
| **Origin/pivot** | **dasar-tengah** objek (raycast-to-terrain mendudukkannya pas; tak terbenam/melayang). |
| **Skala** | dunia **4 studs/m** (SPEC.md). Cantumkan tinggi nyata (m); skrip menskalakan. |
| **Format** | `.obj`+`.mtl` atau `.fbx`. **1 mesh** > ratusan part. Aset masif (tenda/kerikil) = **1 mesh, banyak instance**. |
| **Nama file** | huruf kecil `snake_case` deskriptif (mis. `kabah.obj`). |
| **Karakter** | rig **R15** (animasi default Roblox dipakai — lihat SYSTEMS_DESIGN). |

## 2. Prioritas
- **P1 — dibaca LOGIKA / inti ritual** (node Workspace tertentu; tanpa ini = placeholder kasar). Kerjakan dulu.
- **P2 — landmark/suasana penting**. **P3 — dekor**.

> **Cara wiring:** model harus berakhir SEBAGAI / DI DALAM node Workspace bernama yang dibaca kode
> (kolom "Dibaca kode"). Ganti placeholder di build script dgn mesh, atau taruh mesh di node itu.

---

## 3. Makkah (Devi) — `models/makkah/`
| Model | Folder | Tinggi | Dibaca kode (node / sistem) | Prio |
|---|---|---|---|---|
| **Ka'bah** | `kabah/` | ~15 m | `Workspace.A_Makkah.Kaaba.Kaaba` = **pusat Tawaf** (`WorldProviders.makkahMarks`) | **P1** |
| **Bukit Shafa** | `shafa_marwah/` | ~10 m | `A_Makkah.Masaa.Bukit_Safa` = **ujung Sa'i** | **P1** |
| **Bukit Marwah** | `shafa_marwah/` | ~10 m | `A_Makkah.Masaa.Bukit_Marwah` = ujung Sa'i | **P1** |
| Hajar Aswad | `hajar_aswad/` | — | penanda mulai tawaf (sudut Ka'bah) | P2 |
| Maqam Ibrahim | `maqam_ibrahim/` | — | landmark mataf | P2 |
| Hijr Ismail | `hijr_ismail/` | — | tembok melengkung NW Ka'bah | P3 |
| Mataf (lantai) | `masjidil_haram/` | — | pelataran tawaf (jalur JamaahTawaf orbit) | P2 |
| Masjidil Haram (struktur) | `masjidil_haram/` | — | shell/fasad (LOD; hindari ribuan union) | P2 |
| Menara Abraj + jam | `abraj/` | tinggi | dekor + bisa jadi jam visual | P3 |

## 4. Mina (Praditama) — `models/mina/`
| Model | Folder | Dibaca kode | Prio |
|---|---|---|---|
| **3 Tugu Jamarat** (Ula/Wustha/Aqabah) + jembatan | `jamarat/` | `Workspace.Jamarat.Jamratul_Ula` / `Jamratul_Wusta` / `Jamratul_Aqabah` = **target JumrahThrow** | **P1** |
| **Tempat Qurban** | `qurban/` | `Workspace.TempatQurban` = **stasiun Qurban** | **P1** |
| **Tenda Mina** (1 mesh) | `tents/` | clone `TentMaster` (build_mina/place_from_modules), ribuan instance | **P1** |
| Lampu/lentera (1 mesh) | `lamps/` | clone `LampMaster` | P3 |
| Pembatas/guardline | `jamarat/` | dinding pembatas jalur | P3 |

## 5. Arafah (Nabil) — `models/arafah/`
> **Wukuf di-gate oleh KEHADIRAN di zona `C_Arafah.BatasArafah`, BUKAN Jabal Rahmah.** Jadi mekanik
> wukuf jalan hanya dgn terrain + zona (prosedural). Jabal Rahmah = **landmark visual** (ikon Arafah):
> bukit boleh dari **terrain + sculpt + material batu**, tapi **TUGU putih WAJIB model** (terrain tak bisa).
| Model | Folder | Dibaca kode | Prio |
|---|---|---|---|
| **Tugu Jabal Rahmah** (putih ~8 m) | `jabal_rahmah/` | ditaruh di `C_Arafah.JabalRahmah` (penanda; bukit = terrain) | **P1 (tugu)** |
| Bukit Jabal Rahmah (opsional) | `jabal_rahmah/` | terrain+sculpt bisa menggantikan; model = lebih ikonik | P2 |
| Masjid Namirah | `masjid_namirah/` | landmark wukuf | P2 |
| Gapura "Batas Arafah" | `batas/` | `C_Arafah.BatasArafah` (penanda batas sah wukuf) | P2 |
| Tenda Arafah (1 mesh) | `tenda_arafah/` | instance kemah | P2 |
| Tiang mist (1 mesh) | `mist/` | penyemprot kabut sepanjang rute | P3 |

## 6. Muzdalifah (Nabil) — `models/muzdalifah/`
| Model | Folder | Dibaca kode | Prio |
|---|---|---|---|
| **Masy'aril Haram** (masjid/monumen) | `masyaril_haram/` | `D_Muzdalifah.MasyarilHaram` | **P1** |
| **Kerikil** (1 mesh kecil ~Ø8 cm) | `kerikil/` | disebar `WorldProviders.muzdalifahPebbles` di **`D_Muzdalifah.AreaKerikil`** (PebbleCollect) | **P1** |
| Gapura "Batas Muzdalifah" | `batas/` | `D_Muzdalifah.BatasMuzdalifah` | P3 |

## 7. Lobby & Miqat — `models/lobby/`, `models/miqat/<x>/`
| Model | Folder | Dibaca kode | Prio |
|---|---|---|---|
| **Bus** (1 mesh) | `vehicles/bus/` | `Workspace.Bus` = **target BusRide** (build_miqat), tiap miqat | **P1** |
| Masjid/peron miqat (×5) | `miqat/{bir_ali,juhfah,dzatu_irq,qarnul_manazil,yalamlam}/` | area ihram+niat | P2 |
| Papan panduan miqat | `miqat/` | `Workspace.Miqat.Papan` (penanda) | P3 |
| Bangunan keberangkatan Lobby + gate | `lobby/` | latar pemilih ibadah | P2 |

## 8. Karakter & NPC (bersama) — `models/characters/npc/`
> Rig **R15** + appearance per tipe. Crowd (jamaah) = 1 rig + variasi warna/baju. Behavior di
> `roblox/npc/` (NpcFramework spawn pakai placeholder HRP sampai mesh dipasang).

| Model | Dipakai kode | Prio |
|---|---|---|
| **Askar** (keamanan) | `npc/Askar.lua` | **P1** |
| **Petugas OB** (kebersihan + sapu) | `npc/PetugasOB.lua` | P2 |
| **Jamaah multinegara** (rig + variasi) | `npc/JamaahNegara.lua` & `npc/JamaahTawaf.lua` (orbit mataf) | **P1** |
| **Pendorong kursi roda** | `npc/PendorongKursiRoda.lua` (+ model kursi, lihat §10) | P2 |
| **Petugas medis** | `npc/PetugasMedis.lua` | P2 |
| **TNI** | `npc/TNI.lua` | P3 |

## 9. Pakaian pemain (Wardrobe) — `models/characters/`
> Dipakai `shared/Wardrobe.lua` (`OUTFITS.ihram`/`normal`). Isi sebagai **Shirt+Pants template** ATAU
> **HumanoidDescription** → masukkan asset id ke `Wardrobe.OUTFITS[...].shirt/pants/descId`.

| Model | Folder | Dibaca kode | Prio |
|---|---|---|---|
| **Kain Ihram** (rida' + izar, putih) | `characters/ihram/` | `Wardrobe.OUTFITS.ihram` (IhramChange → apply) | **P1** |
| Pakaian biasa | `characters/pakaian_biasa/` | `Wardrobe.OUTFITS.normal` (pasca-tahallul) | P2 |

## 10. Props, stasiun, kendaraan (bersama) — `models/props/`, `models/vehicles/`
| Model | Folder | Dibaca kode | Prio |
|---|---|---|---|
| **Kursi roda** | `props/kursi_roda/` | `ComfortStations.wheelchair` + NPC PendorongKursiRoda | P2 |
| **Stasiun ganti baju** | `props/ganti_baju/` | `Workspace.GantiBaju` (WardrobeStations) | P2 |
| **Dispenser Zamzam** | `props/zamzam/` | `ComfortStations.zamzam` | P2 |
| **Warung/area makan** | `props/warung/` | `ComfortStations.foodStall` (aksi makan) | P3 |
| Tenda/area istirahat | `props/istirahat/` | `ComfortStations.restArea` | P3 |
| Blok MCK/toilet | `props/mck/` | `Fasilitas` (Arafah/Muzdalifah) | P3 |
| Papan/penunjuk arah | `props/papan/` | nav/penanda | P3 |

## 11. Aset master & yang SUDAH ada
- **Pola master-mesh** (hemat instance): `TentMaster` & `LampMaster` = 1 mesh di ReplicatedStorage, di-`Clone` per titik (build_mina/place_from_modules/place_tents). **Kerikil** sebaiknya ikut pola ini (1 mesh, di-clone WorldProviders).
- Sudah ada: `models/tenda_mina.obj`+`.mtl` → pindah ke `models/mina/tents/`; `models/LampMaster.obj`+`.mtl` → `models/mina/lamps/`.

## 12. Ringkas P1 (kerjakan dulu — dibaca logika / inti ritual)
Ka'bah · Bukit Shafa & Marwah · 3 Tugu Jamarat · Tempat Qurban · Tenda Mina (mesh) · Tugu Jabal Rahmah ·
Masy'aril Haram · Kerikil (mesh) · Bus (mesh) · Kain Ihram · rig Jamaah + Askar.
(Bukit Jabal Rahmah & massa zona Arafah = terrain, bukan model.)
