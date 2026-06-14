# TUTORIAL — Membangun Zona B (Mina) di Roblox Studio, dari Terrain sampai Beres

Panduan lengkap meng-impor & membangun Mina (skala 4). Ikuti **berurutan** —
banyak langkah memakai *raycast ke terrain*, jadi **terrain harus ada lebih dulu**.

> Semua file ada di `scripting/output/B_Mina/`. Skrip Lua di `scripting/roblox/`.

---

## 0. Persiapan (sekali saja)

1. Buka **Roblox Studio** → **New → Baseplate** (atau Empty). Hapus Baseplate bila ada.
2. Aktifkan **StreamingEnabled** (WAJIB, karena 7.160 tenda):
   - Klik **Workspace** di Explorer → Properties → centang **StreamingEnabled**.
3. Siapkan file output (sudah di-generate tool): 3 PNG tile + 5 file `*.module.lua`.

---

## 1. Impor Terrain (3 tile)

Buka **Terrain Editor** (tab Editor) → **Import**. Untuk **tiap** tile, pilih PNG-nya,
isi Size & Position **persis**, material **Sandstone** (jangan Water), lalu **Import**.

| Tile (PNG)             | Size (X, Y, Z)    | Position (X, Y, Z)          |
| ---------------------- | ----------------- | --------------------------- |
| `RUH_tile_x0_z0.png` | 5224, 3328, 10760 | **−5224**, −1664, 0 |
| `RUH_tile_x1_z0.png` | 5224, 3328, 10760 | **0**, −1664, 0      |
| `RUH_tile_x2_z0.png` | 5224, 3328, 10760 | **+5224**, −1664, 0  |

- **Position Y = −1664 jangan diubah** (= −Size_Y/2, cegah "pulau bolong").
- Setelah 3 tile masuk → terbentuk lembah Mina (15672 × 10760 studs). Elevasi 128–960 m.
- (Opsional) smooth tipis di garis sambung antar-tile.

> Tile-nya kecil (46×87 px) karena SRTM 30 m/piksel — terrain memang halus/kasar;
> area tenda akan **diratakan jadi teras** otomatis di langkah 4.

---

## 2. ModuleScript data (di ReplicatedStorage)

Data besar (tenda, lampu, dll.) disimpan di ModuleScript supaya tak kena batas
100k Command Bar. Untuk **tiap** baris di tabel:

1. Di Explorer, klik kanan **ReplicatedStorage → Insert Object → ModuleScript**.
2. **Rename** persis sesuai kolom "Nama".
3. **Double-click** ModuleScript (buka editor skrip) → **hapus isinya** → **tempel
   SELURUH isi** file `.lua` yang sesuai.

| Nama ModuleScript | Tempel isi file                                                                                         |
| ----------------- | ------------------------------------------------------------------------------------------------------- |
| `MinaTerraces`  | `output/B_Mina/MinaTerraces.module.lua` (besar — warning "script panjang" muncul, **abaikan**) |
| `MinaBarriers`  | `output/B_Mina/MinaBarriers.module.lua`                                                               |
| `MinaJamarat`   | `output/B_Mina/MinaJamarat.module.lua`                                                                |
| `MinaLamps`     | `output/B_Mina/MinaLamps.module.lua`                                                                  |
| `MinaRoute`     | `output/B_Mina/MinaRoute.module.lua`                                                                  |

---

## 3. Mesh Tenda (TentMaster)

1. Tab **Model → Import 3D** → pilih `models/tenda_mina.obj` → Import.
2. Hasilnya **Model** (kain + baja). **Rename → `TentMaster`**.
3. **Set ukuran ~32 studs** (8 m × skala 4): pilih, ubah Size, atau scale ~3.8×
   dari ukuran impor (8.5 → 32). Pastikan **tegak** & duduk di lantai (origin di dasar).
4. **Drag `TentMaster` ke ReplicatedStorage.**
5. (Opsional) Lampu: bila punya mesh lampu, beri nama , taruh di
   ReplicatedStorage. Tanpa itu, lampu jadi part placeholder.

---

## 4. Bangun Mina (teras + tenda + Jamarat + lampu + guardline)

1. Buka **View → Command Bar**.
2. Buka `roblox/build_mina.lua`, **salin seluruhnya**, **tempel ke Command
   Bar**, Enter. (Beberapa detik — meratakan 403 blok + sebar 7.160 tenda.)

Output Console yang diharapkan:

```
[Mina] Teras: 403 blok diratakan. Tenda: 7160 disebar.
[Mina] Pembatas: 4 dinding.
[Mina] Jamarat: penanda 5 lantai di (-3440, -3518).
[Mina] Lampu: 2634 (...).
```

Cek **Workspace**: folder `Mina_Tents`, `Mina_Barriers`, `Jamarat`, `Mina_Lamps`.

---

## 5. Gambar Jalur Manasik

1. Buka `roblox/render_route.lua`, salin, tempel ke **Command Bar**, Enter.
2. Jejak jalan tergambar mengikuti rute; **ruas terowongan ditandai gelap**.
   Cek folder `Mina_Route` di Workspace. Penanda kuning = titik KELUAR (teleport).

---

## 6. Navigasi Melayang (saat Play)

1. Di Explorer: **StarterPlayer → StarterPlayerScripts** → klik kanan → **Insert
   Object → LocalScript**.
2. Buka LocalScript itu → **tempel seluruh isi** `roblox/nav_guide.lua`.
3. (Tak perlu rename.)

Saat **Play**: muncul penunjuk atas-tengah → **"➤ [ritual] — XXX m — ±menit"**.
Panah menunjuk arah tujuan. **WalkSpeed realistis ~1,5 m/s. Tahan SHIFT = percepat**
(ETA otomatis memendek + label "(cepat)").

---

## 7. Spawn & Uji

1. Tambah **SpawnLocation** (Model → Spawn) → letakkan **di atas terrain**, mis.
   di area tenda (sekitar X=−3000, Z=−3500, di permukaan). Naikkan Y bila perlu
   agar tak terbenam.
2. Klik **Play** → kamu muncul di Mina, lihat tenda berundak, jalur, navigasi.
   Coba jalan ikuti panah; tahan **Shift** untuk percepat.

---

## 8. Ukur & Simpan

1. **File → Save to File** (`.rbxl`) → catat ukuran **MB** (target jauh < 100 MB).
2. Simpan juga ke Roblox (**File → Save to Roblox**) bila mau publish/Team Create.

---

## Troubleshooting

| Gejala                         | Sebab                                  | Solusi                                                 |
| ------------------------------ | -------------------------------------- | ------------------------------------------------------ |
| Tenda/jalur "dilewati" banyak  | Terrain belum di-import / posisi salah | Pastikan langkah 1 beres dulu                          |
| Tenda melayang/terbenam        | Origin mesh /`SINK`                  | Set origin TentMaster di dasar; atur `SINK` di skrip |
| Tenda rebah                    | Up-axis impor                          | 3D Importer set Up=Z, atau rotasi 90°                 |
| Lampu jadi balok               | `LampMaster` belum ada               | Normal (placeholder); pasang LampMaster nanti          |
| `MinaTerraces` lag di editor | File 326k satu baris                   | Cosmetic; tetap jalan. Abaikan warning                 |
| Lag saat Play (ribuan tenda)   | StreamingEnabled mati                  | Aktifkan (langkah 0.2)                                 |
| Jamarat penanda kebesaran      | Footprint OSM = kompleks jembatan asli | Wajar; model detail menyusul                           |

---

## Urutan ringkas (cheat-sheet)

```
0. New place + StreamingEnabled ON
1. Terrain Import 3 tile (tabel langkah 1)
2. 5 ModuleScript di ReplicatedStorage (tempel *.module.lua)
3. Import tenda -> TentMaster (~32 studs) -> ReplicatedStorage
4. Command Bar: build_mina.lua        (teras + tenda + jamarat + lampu + pembatas)
5. Command Bar: render_route.lua      (jalur + tunnel ditandai)
6. StarterPlayerScripts: LocalScript = nav_guide.lua
7. SpawnLocation di atas terrain -> Play
8. Save to File (.rbxl) -> ukur MB
```
