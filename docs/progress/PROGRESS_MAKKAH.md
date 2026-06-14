# PROGRESS — Zona A: Makkah (Masjidil Haram)

> Skala 4, norm GLOBAL. Box (PROPOSAL): `[39.806, 21.404, 39.846, 21.441]`
> (~4,15 × 4,11 km). Dunia **16.576 × 16.448 studs**, 2×2 = 4 tile, Size_Y 3328.
> Box kupusatkan ke Haram → **Ka'bah ≈ origin (86, −9)**.

## Status: TERRAIN + STRUKTUR INTI HARAM (placeholder prosedural)

Semua berpusat Ka'bah (anchor OSM `الكعبة` @ (86,−9)). Aktivitas inti: Tawaf,
Sa'i, dll. = sekuensial (cocok Quest) — **gameplay belum dibuat, ini struktur**.

## Struktur yang sudah dibuat (placeholder, ganti OBJ nanti)
| Struktur | Detail | Anchor/spec |
|---|---|---|
| **Ka'bah** | kubus hitam + sabuk kiswah emas + pintu emas + Hajar Aswad (perak) | OSM (86,−9), 44×52×51 studs, rot 30° |
| **Mataf** | pelataran marmer putih | r = 200 studs |
| **Maqam Ibrahim** | kubah kaca-emas | ~13 m depan pintu (−z) |
| **Hijr Ismail** | tembok melengkung ½ lingkaran | sisi NW, r ~34 studs |
| **Mas'a** | lorong Safa↔Marwah + 2 bukit batu + zona lampu hijau | ~1600 studs, N-S timur Haram |
| **Abraj Al-Bait** | menara jam + jam hijau 4 sisi | (−134, 1719), tinggi 2404 studs |
| **4 Gerbang** | King Abdulaziz/Fahd/Umrah/Fath | radius 760 dari Ka'bah |
| **Façade** | 168 gedung cincin luar (dinding pembatas) | OSM, radius 1400–4500 studs |

## Pipeline & file (output/A_Makkah/)
- `generate_makkah.py` → `makkah_landmarks.json` + `makkah_facade.json`.
- `to_roblox_module.py --zone A_Makkah` → MakkahLandmarks/Facade/Route `*.module.lua`.
- Build: `roblox_scripts/A_Makkah/build_makkah.lua` → Workspace > **A_Makkah** >
  {Kaaba, Mataf, MaqamIbrahim, HijrIsmail, Masaa, AbrajAlBait, Gerbang, Facade}.
- Rute: `A_Makkah/render_route.lua` + LocalScript `A_Makkah/nav_guide.lua`.

## PENDING / catatan
- [ ] **AKURASI POSISI INNER**: rotasi Ka'bah, letak Maqam Ibrahim/Hijr Ismail/arah
      Mas'a = APPROKSIMASI literatur. Ka'bah & Abraj akurat (anchor OSM). Refine via
      model/koreksi user.
- [ ] **Ganti placeholder → model OBJ** (Masjidil Haram, Ka'bah detail) di `models/`
      (Claude baca OBJ untuk penyatuan).
- [ ] **Gameplay**: Tawaf 7× (mulai/akhir garis Hajar Aswad), Sa'i (lari di green
      zone), isyarat Hajar Aswad, shalat Maqam, Zamzam, Tahallul — fase scripting.
- [ ] Burung merpati, tiang lampu sorot, barbershop (Tahallul) — detail tambahan.
