# PROGRESS — Zona C: Arafah

> Skala 4, norm GLOBAL (konsisten lintas place). Box (PROPOSAL): `[39.955, 21.337, 40.0, 21.375]`
> (~4,67 × 4,24 km). Dunia **18.656 × 16.944 studs**, 2×2 = 4 tile, Size_Y 3328.

## Status: TERRAIN + AREA/LANDMARK DITANDAI (placeholder), tenda PENDING

### Karakter zona
Arafah = padang luas, minim bangunan permanen (OSM: 400 jalan, 153 bangunan).
Aktivitas inti **wukuf** (berdiam/refleksi) 9 Zulhijah — bukan pergerakan dinamis.

## Area/landmark yang sudah dibuat
| Area | Hasil (placeholder prosedural) | Anchor |
|---|---|---|
| **Jabal ar-Rahmah** | bukit + tugu putih 8 m | (2877, 584) |
| **Masjid Namirah** | aula + 6 menara + 3 kubah | footprint OSM (−4774, 1301), 1692×1584 studs |
| **Batas Arafah** | 118 gapura kuning keliling konten | bbox bangunan+landmark |
| **Fasilitas MCK** | 360 blok beton | grid 900 studs |
| **Mist** | 214 tiang kuning + emitter kabut | sepanjang rute |
| Rute + navigasi | ArafahRoute (Mina→Arafah→Muzdalifah) | route_local.json |

## Pipeline & file (output/C_Arafah/)
- `generate_arafah.py` → jabal_rahmah/namirah/boundary/facilities/mist.json.
- `to_roblox_module.py --zone C_Arafah` → 6 `*.module.lua` (ArafahJabalRahmah/Namirah/Boundary/Facilities/Mist/Route).
- Build: `roblox_scripts/C_Arafah/build_arafah.lua` → Workspace > **C_Arafah** > {JabalRahmah, MasjidNamirah, BatasArafah, Fasilitas, Mist}.
- Rute: `C_Arafah/render_route.lua` + LocalScript `C_Arafah/nav_guide.lua`.

## Script grouping (per lokasi)
`roblox_scripts/{common, B_Mina, C_Arafah}/` — generik di common, zona di foldernya.

## PENDING
- [ ] **Tenda Arafah** (pavilion/hangar, beda dari kerucut Mina). OSM tak punya
      poligon camp → butuh **area camp** (kotak lon/lat) ATAU isi region tengah padang.
- [ ] **Wadi Uranah** (lembah terlarang wukuf) — tandai (butuh koordinat batas).
- [ ] **Masjid Namirah** → ganti model OBJ (fakta unik: separuh depan di Wadi Uranah).
- [ ] Gameplay wukuf (timer Dzuhur–maghrib, khutbah dari Namira) — fase scripting.
