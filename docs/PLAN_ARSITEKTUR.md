# PLAN_ARSITEKTUR.md — Catatan Keputusan: Terrain + Bangunan dalam Anggaran Roblox

> Dokumen pikir-dulu (bukan eksekusi). Tujuannya: memberi gambaran trade-off
> supaya kamu bisa memutuskan scope RUH Main Place dengan tenang. Angka MB di sini
> **estimasi** — yang menentukan tetap pengukuran nyata (`Save to File → .rbxl`).
> Belum ada kode yang diubah atas dasar dokumen ini.

---

## 1. Tiga batas yang berbeda (jangan dicampur)

| Batas                                        | Apa                                         | Status                                          | Penanggulangan                                      |
| -------------------------------------------- | ------------------------------------------- | ----------------------------------------------- | --------------------------------------------------- |
| **Volume per impor** (~2³² voxel)    | Importer tolak satu impor terlalu besar     | ✅ SUDAH dipecahkan (tiling voxel-budget-aware) | otomatis di tool                                    |
| **Place 100 MB** (serialisasi publish) | Total seluruh isi 1 place saat Save/Publish | ⬅️**isu sekarang**                      | **arsitektur** (multi-place) + konten ramping |
| **Memori/perf runtime**                | Lag saat ribuan objek aktif                 | nanti                                           | StreamingEnabled + instancing + LOD                 |

**Penting:** StreamingEnabled menolong **runtime** (load objek dekat pemain), **bukan**
memperkecil file place 100 MB. Dua hal beda.

---

## 2. Insight inti: anggaran 100 MB itu DIBAGI

Terrain hanyalah "lantai". Yang akan memakan mayoritas anggaran adalah **bangunan**:
Masjidil Haram detail, **ribuan tenda Mina**, area Jumrah, lampu, pilar.

Kalau terrain saja sudah ~100% (skala 2, box 26 km penuh), **tidak ada ruang untuk
bangunan**. Maka satu place untuk seluruh 20 km **mustahil** — bukan karena terrain,
tapi karena total konten.

### Apa sebenarnya yang bikin terrain berat?

Bukan tebal tanah di bawah (itu solid seragam → kompres bagus). Pendorong utamanya
**luas permukaan topografi** = footprint. Footprint ∝ (box × skala)².

---

## 3. Konsekuensi: memecah geografi membuat terrain ringan

Kalau **tiap place hanya memuat terrain zona-nya** (bukan 26 km penuh), footprint
kecil → terrain ringan, **bahkan di skala 2**. Angka terhitung:

| Zona    | Skala | Dunia (studs) | Voxel-permukaan | % beban box penuh |
| ------- | ----- | ------------- | --------------- | ----------------- |
| 3×3 km | 2.0   | 6 000²       | 2,2 jt          | **1,7%**    |
| 4×4 km | 2.0   | 8 000²       | 4,0 jt          | **3,1%**    |
| 5×5 km | 2.0   | 10 000²      | 6,2 jt          | **4,8%**    |
| 5×5 km | 1.5   | 7 500²       | 3,5 jt          | 2,7%              |

(Baseline box penuh skala 2 ≈ 129 juta voxel-permukaan.)

→ **Terrain satu zona 5×5 km hanya ~5% beban.** Multi-place bukan downgrade detail;
justru memungkinkan **mempertahankan detail tinggi** karena tiap world kecil.

---

## 4. Estimasi anggaran MB per place (ASUMSI — wajib diverifikasi .rbxl)

> Konversi voxel→MB tidak pasti; ini kerangka berpikir, bukan janji.

Misal terrain box-penuh skala 2 ≈ 60–100 MB (perlu ukur). Maka per zona:

| Komponen                            | Estimasi kasar         | Catatan                                                |
| ----------------------------------- | ---------------------- | ------------------------------------------------------ |
| Terrain zona (5×5 km, skala 2)     | ~3–6 MB               | ~5% dari penuh                                         |
| Mesh bangunan (Haram, tenda)        | **0 MB di file** | geometri mesh = asset (rbxassetid), di-upload terpisah |
| Instance bangunan (tree)            | bervariasi besar       | tiap Part/Union/MeshPart ~ratusan byte serialisasi     |
| 1 tenda = 1 MeshPart × 3 000       | ~1–4 MB               | kalau single-mesh instance                             |
| 1 tenda = model multi-part × 3 000 | ~15–40 MB             | kalau tiap tenda banyak part →**mahal**         |
| Masjidil Haram (union/part tree)    | ~10–40 MB             | tergantung cara model dibuat                           |

**Pelajaran:** biaya bangunan **didominasi jumlah & struktur INSTANCE**, bukan terrain.
Kunci hemat: tenda = **satu mesh, ribuan instance murah** (bukan model multi-part);
Haram = mesh tunggal/ber-LOD, hindari ribuan union.

---

## 5. Peta zona (alur manasik) — usulan 3 place

Pusat zona (lat, lon) — semua di dalam SRTM box (lat 21.312–21.489, lon 39.765–40.018):

| Place       | Zona                    | Pusat                                        | Karakter konten                             |
| ----------- | ----------------------- | -------------------------------------------- | ------------------------------------------- |
| **A** | Makkah & Masjidil Haram | 21.4225, 39.8262                             | bangunan terberat, terrain kecil            |
| **B** | Mina & Jumrah           | 21.413, 39.893 (Mina), Jumrah ~21.422,39.873 | **ribuan tenda** (instance terbanyak) |
| **C** | Muzdalifah & Arafah     | 21.383,39.937 / 21.355,39.984                | lapang, terrain dominan, bangunan ringan    |

Jarak nyata: Haram→Mina ~7 km, Mina→Muzdalifah ~4 km, Muzdalifah→Arafah ~6 km.
**Teleport antar-place = naratif tepat** (perjalanan antar-ritus yang nyatanya
berjam-jam), bukan sekadar work-around.

### Konsistensi tinggi lintas place

Terrain tiap zona dipotong dari SRTM yang **dinormalisasi GLOBAL** (gmin/gmax full
DEM) dan **Size_Y global** → elevasi absolut antar-zona konsisten & realistis
(Mina lebih tinggi dari Makkah, dst.), sambungan teleport tidak terasa "loncat tinggi".

---

## 6. Opsi arsitektur dibandingkan

|                          | Single place (turun skala)     | **Multi-place per zona**         |
| ------------------------ | ------------------------------ | -------------------------------------- |
| Place 100 MB             | sulit (terrain+bangunan 20 km) | ✅ tiap zona muat                      |
| Detail                   | harus dikompromikan            | ✅ bisa tinggi per zona                |
| Jalan menerus            | ✅ mulus                       | ❌ ada transisi loading (tapi naratif) |
| Kerja Studio             | ringan                         | berat (teleport + 3 setup)             |
| Skala koordinat          | perlu hati-hati                | ✅ tiap world kecil                    |
| Cocok untuk konten berat | ❌                             | ✅                                     |

---

## 7. Urutan kerja bertahap (realistis untuk tugas akademik)

Membangun 3 place penuh + ribuan tenda + Haram detail **sangat ambisius** untuk
EAS. Saran: **bukti satu zona solid > tiga zona setengah jadi.**

- **Tahap 1 — 1 zona unggulan end-to-end.** Pilih zona (mis. Mina = paling khas
  manasik, atau Haram = paling ikonik). Generate terrain zona (crop + norm global)
  → impor → tambah **beberapa** bangunan sampel → **Save .rbxl, ukur split**
  terrain vs model. Ini memberi data nyata untuk semua keputusan berikutnya.
- **Tahap 2 — Generator penempatan massal** (Fase 2 TASKS.md): JSON skema tenda/
  lampu/pilar + `MinaTents_placement.lua` (raycast-to-terrain). Uji instancing
  murah vs perf.
- **Tahap 3 — Zona ke-2 & teleport** (jika waktu cukup): replikasi pola, sistem
  teleport antar-place, spawn di perbatasan.
- **Tahap 4 — Zona ke-3, polish, StreamingEnabled, LOD.**

Hentikan di tahap mana pun dan tetap punya artefak yang utuh & demoable.

---

## 8. Yang tool SUDAH punya vs perlu ditambah

Sudah ada (`convert_terrain.py`):

- normalisasi global 16-bit, tiling overlap, voxel-budget, voxel-align, manifest+guide.

Perlu ditambah (kecil) untuk multi-place:

- **Crop sub-region**: parameter pilih sub-rectangle (geo/piksel) untuk satu zona,
  tetap pakai gmin/gmax & Size_Y **global** → tinggi konsisten lintas place.
- Opsional: output per-zona berlabel (folder/prefix per place) + manifest gabungan.

Belum tercakup tool (kerja Studio/scripting-mu, bisa kuscaffold):

- model bangunan, sistem teleport, StreamingEnabled, LOD, penempatan tenda runtime.

---

## 9. Risiko & yang HARUS diukur (jangan optimasi buta)

1. **Ukuran terrain box-penuh sebenarnya** — export `.rbxl` sekarang, catat MB.
   Ini mengkalibrasi semua estimasi di §4.
2. **Biaya 1 tenda** — impor 1 tenda final, duplikat ×100, ukur kenaikan MB →
   ekstrapolasi ke target jumlah tenda.
3. **Biaya Masjidil Haram** — tergantung sumber model; mesh tunggal jauh lebih
   hemat daripada ribuan union.
4. **Orientasi (flip_z)** — pastikan Utara–Selatan benar sebelum replikasi pola.

---

## 10. Keputusan yang menunggu kamu

- [ ] **Scope**: 1 zona unggulan dulu, atau langsung rancang 3 place?
- [ ] **Zona pertama**: Makkah/Haram (ikonik) vs Mina/Jumrah (paling khas manasik)?
- [ ] **Skala**: tetap 2 (detail) per zona kecil, atau 1.5 (lebih hemat lagi)?
- [ ] **Model bangunan**: sumbernya dari mana (buat sendiri, Creator Store, impor)?
- [ ] **Target jumlah tenda Mina** (ratusan? ribuan?) — menentukan strategi instancing.
- [ ] Setuju **ukur `.rbxl` dulu** sebelum komit arah?

> Rekomendasiku tetap: **arsitektur multi-place, tapi eksekusi 1 zona unggulan dulu
>
> + ukur nyata**. Itu menyeimbangkan ambisi dengan realita deadline akademik.
