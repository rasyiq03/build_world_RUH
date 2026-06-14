# MODELS.md — Daftar & Spesifikasi Model 3D

> Model = **pekerjaan terpisah** (tim 3D). Repo ini hanya menyiapkan **folder tujuan + spec**.
> Simpan tiap model di folder yang sesuai di `models/<area>/<model>/`. **File mesh besar**
> di-`.gitignore` (jangan commit binari berat); struktur folder (`.gitkeep`) & dokumen ini
> tetap di-commit agar tim tahu lokasi & spec.

## 1. Konvensi WAJIB (cegah bug "tenda rebah / origin melayang" yang dulu terjadi)

| Aspek | Aturan |
|---|---|
| **Up-axis** | **Y ke atas** (saat Import 3D, set Up = Y; bila software pakai Z-up, rotasi 90°). |
| **Origin/pivot** | Di **dasar tengah** objek (agar `raycast-to-terrain` mendudukkannya pas, tak terbenam/melayang). |
| **Skala** | Dunia memakai **scale 4 studs/m** (lihat `SPEC.md`). 1 m = 4 studs. Cantumkan tinggi nyata (m) tiap model di bawah; skrip akan menskalakan. |
| **Format** | `.obj`+`.mtl` atau `.fbx`. Mesh tunggal lebih hemat daripada ratusan part (lihat PLAN_ARSITEKTUR). |
| **Pemakaian** | Aset masif (tenda) = **1 mesh, banyak instance** (bukan model multi-part). |
| **Nama file** | huruf kecil, `snake_case`, mendeskripsikan isi (mis. `kabah.obj`). |

## 2. Daftar model per area (pemilik = GAME_DESIGN §3)

### Lobby & Miqat
| Folder | Model | Tinggi nyata acuan | Pemilik |
|---|---|---|---|
| `models/lobby/` | bangunan keberangkatan, papan panduan, gate | — | Devi |
| `models/miqat/bir_ali/` | Masjid Bir Ali (Dzulhulaifah) + lingkungan | — | Devi |
| `models/miqat/juhfah/` | Masjid Miqat Juhfah (Rabigh) | — | Nabil |
| `models/miqat/dzatu_irq/` | Miqat Dzatu 'Irq | — | Nabil |
| `models/miqat/qarnul_manazil/` | Miqat Qarnul Manazil (As-Sayl) | — | Praditama |
| `models/miqat/yalamlam/` | Miqat Yalamlam | — | Praditama |

### Makkah (Devi)
| Folder | Model | Catatan |
|---|---|---|
| `models/makkah/kabah/` | Ka'bah | ~15 m; titik pusat tawaf |
| `models/makkah/hajar_aswad/` | Hajar Aswad | penanda mulai tawaf |
| `models/makkah/maqam_ibrahim/` | Maqam Ibrahim | |
| `models/makkah/shafa_marwah/` | Bukit Shafa & Marwah + lintasan sa'i | jalur sa'i 7× |
| `models/makkah/masjidil_haram/` | struktur Masjidil Haram (mataf, dll.) | mesh ber-LOD; hindari ribuan union |

### Arafah · Muzdalifah · Tahallul (Nabil)
| Folder | Model | Catatan |
|---|---|---|
| `models/arafah/jabal_rahmah/` | Jabal Rahmah + tugu | titik wukuf |
| `models/arafah/masjid_namirah/` | Masjid Namirah | |
| `models/arafah/tenda_arafah/` | tenda jamaah Arafah | instance |
| `models/muzdalifah/masyaril_haram/` | Masy'aril Haram | + area ambil kerikil |
| `models/tahallul/tempat_cukur/` | tempat cukur/tahallul | |

### Mina (Praditama)
| Folder | Model | Catatan |
|---|---|---|
| `models/mina/tents/` | **tenda Mina** | sudah ada `tenda_mina.obj` di `models/` (root) → pindahkan ke sini |
| `models/mina/jamarat/` | 3 pilar Jumrah (Aqabah, Wustha, Ula) + jembatan | target lempar |
| `models/mina/qurban/` | tempat & proses qurban | |
| `models/mina/lamps/` | lampu/lentera | sudah ada `LampMaster.obj` di `models/` (root) → pindahkan ke sini |

### Karakter, NPC, kendaraan, props (bersama)
| Folder | Model | Pemilik |
|---|---|---|
| `models/characters/ihram/` | kain ihram (rida' + izar) — disediakan game | Devi (mekanisme ganti kostum) |
| `models/characters/pakaian_biasa/` | pakaian biasa | Devi |
| `models/characters/npc/` | Askar, Petugas OB, kursi roda, medis, jamaah multinegara, TNI | sesuai NPC §3 |
| `models/vehicles/bus/` | bus (transisi miqat→Makkah) | bersama |
| `models/props/` | zamzam, kursi roda, area istirahat, papan | Praditama/bersama |

## 3. Aset yang SUDAH ada
- `models/tenda_mina.obj` + `.mtl` → akan dipindah ke `models/mina/tents/`.
- `models/LampMaster.obj` + `.mtl` → akan dipindah ke `models/mina/lamps/`.
- (lihat `models/README.md` lama untuk catatan impor sebelumnya.)
