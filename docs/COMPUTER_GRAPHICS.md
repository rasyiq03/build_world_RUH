# COMPUTER_GRAPHICS.md — Peta Keilmuan Komputer Grafik dalam RUH

> **Ini inti penilaian mata kuliah.** Tujuan dokumen: membuat kontribusi grafis **terbaca &
> bisa dipertahankan** saat dinilai. Tiap konsep dipetakan ke fitur konkret, sisi pengerjaan
> (model vs scripting/Studio), pemilik, momen manasik, dan status + bukti (screenshot).

## 1. Pembagian sisi: model vs scripting/Studio

- **Sisi MODEL (pekerjaan terpisah):** geometri mesh, UV unwrap, baked texture/PBR map aset.
- **Sisi SCRIPTING/STUDIO (repo ini — sebagian besar showcase dinamis):** lighting, time-of-day,
  atmosphere, post-processing, particles/VFX, penerapan material/PBR & terrain colormap,
  LOD/streaming, kamera, geometri prosedural (terrain + instancing). **Ini yang dinilai dari sisi kita.**

## 2. Matriks konsep → implementasi

| Konsep CG | Fitur konkret (Roblox) | Sisi | Momen manasik | Status |
|---|---|---|---|---|
| **Lighting & shading (PBR)** | `Lighting` Future, PointLight/SpotLight/SurfaceLight, shadows | Studio | lampu Mina malam, lentera | ⬜ |
| **Time-of-day dinamis** | `Lighting.ClockTime`/`TimeOfDay` transisi terprogram | Script | Arafah siang terik · Muzdalifah malam · subuh berangkat | ⬜ |
| **Atmosphere & fog** | `Atmosphere` (density, haze, glare), `Sky` custom | Studio | kabut Arafah (`ArafahMist`), langit berbintang Muzdalifah | 🟡 ada modal |
| **Post-processing** | `BloomEffect`, `SunRaysEffect`, `DepthOfFieldEffect`, `ColorCorrectionEffect` | Script | bloom tawaf malam, mood per zona, tone mapping | ⬜ |
| **Particles / VFX** | `ParticleEmitter`, `Beam`, `Trail` | Studio/Script | debu Mina, heat-haze Arafah, air zamzam | 🟡 ArafahMist |
| **Texturing prosedural** | `SurfaceAppearance` (albedo/normal/roughness/metalness), `MaterialVariants` | Studio | tekstur Ka'bah, pasir, batu | ⬜ |
| **Terrain material/colormap** | rasterize jalan → auto-paint Asphalt (`roads_to_colormap.py`) | Script | jalan Mina/Makkah | 🟡 tool ada |
| **Geometri prosedural** | heightmap SRTM → mesh terrain (pipeline `terrain/`) | Script | seluruh dunia | ✅ selesai |
| **Instancing & culling** | 7160 tenda 1-mesh banyak instance, `StreamingEnabled` | Script | lautan tenda Mina | 🟡 ada |
| **LOD** | `MeshPart.RenderFidelity`, LOD streaming | Studio | performa 4 zona besar | ⬜ |
| **Kamera & proyeksi** | FOV, kamera sinematik orbit, `TweenService` | Script | kamera mengitari Ka'bah saat tawaf | ⬜ |

Status: ✅ selesai · 🟡 ada modal/sebagian · ⬜ belum.

## 3. Tanggung jawab CG per orang (mengikuti area di GAME_DESIGN §3)

Tiap orang menggarap **lighting + texturing + atmosphere area-nya sendiri**, di atas **infra CG
bersama** (di `roblox/shared/` — dirintis bersama):
- **Devi** — lighting interior Masjidil Haram, PBR Ka'bah, bloom tawaf, lighting Lobby & Bir Ali.
- **Nabil** — lighting siang terik Arafah + heat-haze + SunRays, langit malam + kabut Muzdalifah, DoF Jabal Rahmah.
- **Praditama** — lighting Mina (ribuan lampu, instancing), debu area jumrah, material pilar.

**Infra CG bersama (reusable):** controller time-of-day, pustaka post-processing per-mood,
pustaka particle, util colormap terrain. Letakkan di `shared/` agar konsisten lintas zona.

## 4. Cara mengisi dokumen ini
Saat sebuah baris matriks selesai: ubah status → ✅, tambahkan **1 baris bukti** (nama screenshot
di `image/`, atau path skrip). Saat demo/laporan, dokumen ini = daftar klaim grafis + buktinya.
