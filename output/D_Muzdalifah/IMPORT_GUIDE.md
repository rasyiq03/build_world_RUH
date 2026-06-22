# IMPORT_GUIDE.md — Impor Terrain RUH Main Place ke Roblox Studio

Tool ini menyiapkan heightmap PNG 16-bit + parameter Size/Position. Pembentukan tanah dilakukan di **Studio Terrain Importer** (bukan via script). Impor tiap tile satu per satu dengan angka di bawah.

## Ringkasan

- Skala: **4 studs/m** (seragam semua tile).
- Origin: tengah rute (0,0,0); tile simetris terhadap origin.
- Elevasi: **128–960 m** (delta 832 m).
- Ukuran dunia: **16592 x 15216 studs**, grid **2 x 2** = 4 tile.
- Size Y (relief): **3328 studs**.
- flip_z: **False**.

> **Catatan tiling:**
> - voxel_align: Size disnap ke kelipatan 8 studs; dunia 16585.1x15213.7 -> 16592x15216, Size_Y 3328 -> 3328 (geser <0.04%).
> - Grid dinaikkan ke 2x2=4 tile agar voxel/tile (3.28e+09) <= max_tile_voxels (4.2e+09). Batas studs saja hanya butuh 2 tile.
> - Tinggi DEM 123px tidak habis dibagi 2 tile; sisa 1px diserap ke tile Z terakhir.

## Langkah Umum (tiap tile)

1. Buka **Terrain Editor → Import** (atau Terrain:ImportHeightmap).
2. Pilih file PNG tile yang sesuai.
3. Masukkan **Size X/Y/Z** dan **Position X/Y/Z** persis seperti blok tile.
4. Material: gunakan non-air, mis. **Sandstone** (boleh Rock di puncak, Sand di dataran). **Jangan Water.**
5. **Position Y negatif** (= -Size_Y/2) sudah diperhitungkan — jangan diubah, ini mencegah "pulau bolong".
6. Setelah semua tile masuk, **smooth** sedikit di garis sambung bila perlu (overlap 1 px sudah meminimalkan jahitan).

## Tile

### RUH_tile_x0_z0.png  (ix=0, iz=0)

- Piksel sumber: 73 x 62 px
- **Size**:  X = `8296`,  Y = `3328`,  Z = `7608`  (studs)
- **Position**:  X = `-4148`,  Y = `-1664`,  Z = `-3804`  (studs)
- Material: `Sandstone`

### RUH_tile_x1_z0.png  (ix=1, iz=0)

- Piksel sumber: 72 x 62 px
- **Size**:  X = `8296`,  Y = `3328`,  Z = `7608`  (studs)
- **Position**:  X = `4148`,  Y = `-1664`,  Z = `-3804`  (studs)
- Material: `Sandstone`

### RUH_tile_x0_z1.png  (ix=0, iz=1)

- Piksel sumber: 73 x 62 px
- **Size**:  X = `8296`,  Y = `3328`,  Z = `7608`  (studs)
- **Position**:  X = `-4148`,  Y = `-1664`,  Z = `3804`  (studs)
- Material: `Sandstone`

### RUH_tile_x1_z1.png  (ix=1, iz=1)

- Piksel sumber: 72 x 62 px
- **Size**:  X = `8296`,  Y = `3328`,  Z = `7608`  (studs)
- **Position**:  X = `4148`,  Y = `-1664`,  Z = `3804`  (studs)
- Material: `Sandstone`
