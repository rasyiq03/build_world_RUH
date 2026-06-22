# Materi Ujian Komputer Grafik — Modeling · Projection · Lighting · Texturing

> Persiapan ujian implementasi pada **Proyek RUH** (simulator manasik haji/umrah, Roblox).
> Tiap topik disusun: **(A) Materi/Teori** · **(B) Implementasi di RUH** (dengan bukti file) · **(C) Poin kunci ujian**.

## 0. Bingkai: Pipeline Grafika 3D

Urutan render klasik — keempat topik ujian adalah tahap-tahapnya:

```
MODELING → Transformasi (model→world) → PROJECTION (3D→2D, kamera)
         → Rasterisasi → LIGHTING/Shading → TEXTURING → citra di layar
```

Di RUH ada **dua "mesin grafika"**:
1. **Pipeline offline (Python)** — data geografi (SRTM/OSM) → terrain & konten. *(Modeling & Projection geografis terjadi di sini.)*
2. **Runtime Roblox (engine)** — render real-time: kamera, lighting PBR, tekstur. *(Projection perspektif, Lighting, Texturing.)*

---

## 1. MODELING

### 1.1 Materi (teori)
- **Definisi:** merepresentasikan objek 3D sebagai geometri.
- **Representasi mesh:** *vertex* (titik), *edge* (rusuk), *face* (muka, umumnya segitiga), *normal* (arah hadap permukaan), *koordinat UV*.
- **Primitive:** kubus, bola, silinder, plane.
- **Teknik:** polygonal/mesh, *procedural*, **CSG** (Constructive Solid Geometry: union/subtract/intersect), sculpting, **heightmap (terrain)**, **voxel**.
- **Transformasi model:** translasi, rotasi, skala (matriks model); ruang *local* vs *world*; *pivot/origin*.
- **Efisiensi:** **instancing** (banyak salinan dari 1 mesh), **LOD** (Level of Detail).

### 1.2 Implementasi di RUH
- **Terrain = heightmap modeling dari data NYATA.** SRTM GeoTIFF (elevasi Mekkah) → heightmap PNG 16-bit → Roblox Terrain. Pipeline `terrain/` + `convert_terrain.py` (normalisasi global → tiling → manifest). *Modeling prosedural dari data, bukan dipahat manual.*
- **Voxel modeling.** Roblox Terrain berbasis **voxel 4×4×4 studs**; ada *voxel budget* per impor (`max_tile_voxels`), grid tile dipilih agar muat (`terrain/tiling.py`).
- **Mesh models (polygonal).** `models/` — `tenda_mina.obj`, `LampMaster.obj`, Ka'bah, Jabal Rahmah, dll. `docs/MODELS.md` menetapkan **skala, up-axis = Y, origin di dasar/pivot** (konvensi modeling agar objek tak rebah/melayang).
- **Instancing.** **7160 tenda Mina = 1 mesh** disebar ribuan instance (bukan 7160 model unik) → `generators/generate_tents.py`. Hemat memori & ukuran file.
- **CSG / Part.** Skrip build (teras, penanda) menyusun `Part`/blok dasar.
- **Transformasi & sistem koordinat.** Skala **4 studs/m** (1 stud = 0.25 m); origin dunia **di tengah**; `Position Y = −Size_Y/2`; tile simetris (SPEC §1, §4).
- **LOD & Streaming.** `RenderFidelity`, `StreamingEnabled` (untuk ribuan objek).

### 1.3 Poin kunci ujian
- "Terrain tidak dimodel manual — kami **generate dari data elevasi SRTM** (heightmap → voxel terrain)."
- Bisa jelaskan beda **mesh vs voxel**, dan kenapa **instancing** dipakai untuk tenda.
- **Origin/pivot & up-axis** adalah bagian modeling yang menentukan penempatan objek.

---

## 2. PROJECTION

### 2.1 Materi (teori)
- **Definisi:** memetakan dunia 3D → bidang 2D (layar).
- **Dua jenis utama:**
  - **Ortografik** — proyeksi paralel, **tanpa foreshortening** (ukuran tak mengecil oleh jarak). Untuk peta, CAD, isometrik.
  - **Perspektif** — ada **titik hilang** & *foreshortening* (realistis). Parameter: **FOV** (field of view), *aspect ratio*, bidang **near/far**, **frustum**.
- **Pipeline koordinat:** Model → World → **View (kamera)** → **Projection** → Clip → NDC → **Viewport (layar)**.
- **Matriks:** Model, View, Projection (**MVP**). Kamera: posisi, arah pandang, *up vector*. **Frustum culling / clipping**.
- **Proyeksi peta (geospasial):** permukaan bumi (lat/lon) → bidang datar (mis. *equirectangular/plate carrée*); longitude dikompres `cos(lat)`.

### 2.2 Implementasi di RUH (dua sisi)
**a. Proyeksi GEOGRAFIS (offline) — lat/lon → studs** *(implementasi projection paling konkret & khas proyek ini):*
- Data SRTM & OSM dalam koordinat geografis (lon/lat). `terrain/geo.py` memetakannya ke piksel → studs.
- Rumus di `import_manifest.json` (`geo_note`):
  `x = (lon − lon_min)/(lon_max − lon_min) · world_x − world_x/2`, `z` analog dari lat (sumbu Z dibalik: utara = atas).
- **Longitude dikompres `cos(lat)`** agar jarak km true-ground (proyeksi equirectangular berskala). **Origin di tengah (0,0)**.
- Semua generator (jalan/bangunan OSM, tenda) memproyeksikan lon/lat → X/Z dengan **membaca manifest, tanpa hardcode**.

**b. Proyeksi PERSPEKTIF (runtime) — kamera Roblox:**
- Roblox merender **perspektif** (FOV, frustum, near/far). Kamera orang-pertama/ketiga; rencana **kamera sinematik orbit** saat Tawaf.
- **Presisi float32 ↔ projection:** skala dikompres (2–4 studs/m) agar koordinat ≤ ±~20.000 studs → mencegah *jitter* floating-point saat proyeksi koordinat ekstrem (SPEC §1).

**c. Proyeksi ORTOGRAFIK (2D):** peta HTML `Visualisasi_Spasial_Roblox.html` (Leaflet) = pandangan atas/ortografik 4 zona; `route_map.html` memproyeksikan jalur.

### 2.3 Poin kunci ujian
- Bedakan **ortografik vs perspektif** (sebut FOV, frustum, near/far, foreshortening).
- Tunjukkan **proyeksi peta lat/lon → studs** (rumus manifest, kompresi `cos(lat)`) sebagai implementasi projection nyata.
- Hubungkan **skala koordinat ↔ presisi float** (alasan dunia dikompres).

---

## 3. LIGHTING

### 3.1 Materi (teori)
- **Jenis cahaya:** *ambient*, *directional* (matahari), *point*, *spot*, *area*.
- **Model refleksi:**
  - **Phong / Blinn-Phong** = **ambient + diffuse + specular**.
    - Diffuse (Lambert): `I_d = k_d · (N · L)`.
    - Specular: `I_s = k_s · (R · V)^n` (Phong) atau `(N · H)^n` (Blinn).
  - **PBR (Physically Based Rendering):** *albedo, metalness, roughness*, *Fresnel*, konservasi energi (microfacet BRDF).
- **Shading:** *flat* (per-face), **Gouraud** (per-vertex, diinterpolasi), **Phong** (per-pixel, paling halus).
- **Bayangan:** *shadow mapping*; **Global Illumination / Ambient Occlusion** (cahaya tak langsung).
- **Vektor kunci:** Normal **N**, arah cahaya **L**, pandang **V**, half **H**, refleksi **R**.

### 3.2 Implementasi di RUH
- **Lighting Roblox = PBR + bayangan real-time** (teknologi *Future* = per-pixel + shadows). Matahari (directional) dikendalikan **`Lighting.ClockTime`**.
- **Time-of-day DINAMIS per momen manasik** *(showcase utama):* **Arafah** siang terik (wukuf dzuhur–maghrib) · **Muzdalifah** malam (mabit) · subuh berangkat → transisi `ClockTime` terprogram.
- **Sumber cahaya buatan:** **ribuan lampu Mina** (PointLight/SpotLight/SurfaceLight) → gabungan *lighting + instancing*.
- **Atmosphere & fog:** `Atmosphere` (density, haze ≈ hamburan cahaya), `ArafahMist` (kabut), langit malam berbintang Muzdalifah.
- **Post-processing terkait cahaya:** **Bloom** (sumber terang menyebar), **SunRays** (god-rays matahari), **ColorCorrection** (mood/tone), **DepthOfField**.
- **Tanggung jawab per orang** (`docs/COMPUTER_GRAPHICS.md` §3): tiap anggota meng-*lighting* zonanya.

### 3.3 Poin kunci ujian
- Tulis **persamaan Phong** (ambient + diffuse + specular) & jelaskan tiap suku + vektor N/L/V/R.
- Beda **Gouraud vs Phong shading**; **directional vs point light**.
- Tunjuk **`ClockTime`/time-of-day** & **Atmosphere** sebagai lighting nyata + naratif (Arafah siang, Muzdalifah malam).

---

## 4. TEXTURING

### 4.1 Materi (teori)
- **Definisi:** menempelkan detail gambar 2D ke permukaan 3D.
- **UV mapping:** *unwrap* permukaan 3D → ruang **UV** (u,v ∈ [0,1]); tiap vertex punya koordinat tekstur.
- **Peta tekstur (PBR):** *albedo/diffuse* (warna dasar), **normal map** (detail tonjolan tanpa menambah geometri), *roughness*, *metalness*, *height/displacement*, *ambient occlusion*, *emissive*.
- **Filtering:** *nearest, bilinear, trilinear*, **mipmapping** (anti-alias saat tekstur mengecil/minifikasi), *anisotropic*.
- **Wrapping:** *repeat/tile*, *clamp*, *mirror*.
- Tekstur **prosedural vs gambar**; *decal*; *texture atlas*; *texel*.

### 4.2 Implementasi di RUH
- **SurfaceAppearance (PBR)** pada model: *albedo + normal + roughness + metalness* (mis. tekstur Ka'bah, batu, pasir).
- **Material terrain Roblox + MaterialVariants:** tiap tile diberi **Sandstone / Rock / Sand** (manifest `"material"`), **bukan Water**.
- **Colormap PROSEDURAL dari data** (`generators/roads_to_colormap.py`): rasterisasi jalan OSM → PNG colormap → **auto-paint Aspal** di terrain. *(Texturing prosedural berbasis data — poin kuat.)*
- **Heightmap sebagai data-texture:** PNG 16-bit *grayscale* = tinggi terenkode → dipakai Terrain Importer sebagai *height/displacement map*. *(Tekstur tidak selalu berarti warna.)*
- **Tiling/wrapping:** tekstur terrain & kain tenda berulang (*repeat*).
- **Filtering/mipmap:** ditangani engine (sebut sebagai konsep yang berlaku).

### 4.3 Poin kunci ujian
- Jelaskan **UV mapping** & guna **normal map** (detail tanpa menambah poligon).
- **Mipmapping** untuk apa (anti-alias saat minifikasi).
- Tunjuk **colormap jalan** & **material per-tile** sebagai texturing nyata; **heightmap = tekstur data**.

---

## 5. Tabel Ringkas (hafalan cepat)

| Topik | Inti teori | Bukti di RUH |
|---|---|---|
| **Modeling** | mesh/voxel, vertex-face-normal, transformasi, instancing, LOD | SRTM heightmap→voxel terrain · `models/` · 7160 tenda instan |
| **Projection** | ortografik vs perspektif, MVP, frustum/FOV, proyeksi peta | lat/lon→studs (`geo.py`/manifest, `cos(lat)`) · kamera Roblox · peta 2D |
| **Lighting** | Phong/PBR, ambient-diffuse-specular, jenis cahaya, shadow | `ClockTime` time-of-day · `Atmosphere`/fog · lampu Mina · Bloom/SunRays |
| **Texturing** | UV, peta PBR (albedo/normal/roughness), mipmap, wrapping | `SurfaceAppearance` · material per-tile · colormap jalan · heightmap-as-texture |

## 6. Kemungkinan Pertanyaan & Jawaban Singkat

- **Bagaimana terrain dibuat?** → SRTM heightmap → normalisasi **global** 16-bit → tiling (voxel budget) → Roblox Terrain (voxel 4×4×4).
- **Proyeksi apa yang dipakai?** → *Runtime*: perspektif (kamera, FOV/frustum). *Pipeline*: proyeksi geografis lat/lon→studs (equirectangular, longitude × cos lat).
- **Bagaimana realisme cahaya dicapai?** → PBR + shadow real-time; matahari via `ClockTime` (Arafah siang / Muzdalifah malam); `Atmosphere` + fog; post-FX Bloom/SunRays.
- **Bagaimana tekstur diterapkan?** → `SurfaceAppearance` PBR pada mesh; material terrain per-tile; colormap prosedural untuk jalan; normal map untuk detail.
- **Kenapa skala dunia dikompres (4 studs/m)?** → presisi **float32** — koordinat ekstrem memicu jitter saat proyeksi; dikompres agar ≤ ±~20.000 studs.
- **Apa itu instancing & kenapa dipakai?** → banyak salinan 1 mesh (tenda) → hemat memori/serialisasi vs ribuan model unik.
- **Beda Gouraud vs Phong shading?** → Gouraud hitung cahaya **per-vertex** lalu interpolasi warna; Phong interpolasi **normal** lalu hitung cahaya **per-pixel** (lebih halus, specular akurat).
- **Apa fungsi normal map?** → memberi ilusi detail permukaan (tonjolan/lekuk) dengan memanipulasi normal, **tanpa menambah geometri**.

---

> Sumber implementasi di repo: `terrain/` · `convert_terrain.py` · `generators/` (`generate_tents.py`, `roads_to_colormap.py`) · `tools/` (peta) · `docs/COMPUTER_GRAPHICS.md` · `docs/MODELS.md` · `output/<zona>/import_manifest.json`.
