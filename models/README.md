# models/ — Aset 3D (mesh) sumber untuk impor ke Roblox

Folder ini hanya **tempat menyimpan file mesh sumber** (mis. `tent.fbx`) untuk
version control. **TIDAK dipakai oleh script Python mana pun** — pipeline terrain/OSM
bekerja dengan PNG/JSON, bukan mesh. Mesh diimpor langsung di Roblox Studio.

## Tenda Mina (TentMaster)

### 1. Ekspor dari Blender
- Format: **`.fbx`** (disarankan) atau `.obj` / `.glb`.
- Sebelum ekspor:
  - **Join semua jadi 1 objek** (`Ctrl+J`) → terimpor sebagai SATU MeshPart
    (bukan Model multi-part). Ini wajib agar instancing 2.445 tenda tetap ringan.
  - **Apply All Transforms** (`Ctrl+A`) → skala/rotasi tidak kacau saat impor.
  - **Set Origin** di dasar-tengah tenda → mendarat rapi via raycast.
  - Jaga **low-poly** (tenda sederhana; ribuan instance).
- FBX export: centang "Apply Transform", up-axis Y bila ada opsi (Roblox = Y-up).

### 2. Impor ke Studio
- Tab **Model → Import 3D** (3D Importer) → pilih file → Import (mesh di-upload
  sebagai asset Roblox; geometri TIDAK menambah ukuran .rbxl, hanya instance-nya).
- Hasil = **MeshPart**. Kalau jadi Model multi-part, berarti belum di-join → ulangi.

### 3. Pasang
- Rename MeshPart → **`TentMaster`**.
- Pindahkan ke **ReplicatedStorage**.
- Sesuaikan **Size** ke ~16 studs (≈ 8 m pada skala 2). 
- Jalankan `roblox_scripts/place_tents.lua` → clone TentMaster ke tiap titik
  `mina_tents.json` (raycast ke terrain).

### Cek cepat
- [ ] Satu MeshPart (bukan Model banyak part)?
- [ ] Berdiri tegak (tidak rebah/miring)? Kalau rebah: perbaiki up-axis di importer
      atau rotasi MeshPart 90°.
- [ ] Duduk di tanah (tidak melayang/terbenam)? Atur `SINK` di place_tents.lua.
- [ ] Tris wajar (puluhan–ratusan, bukan ribuan)?

> Alternatif tanpa Blender: `roblox_scripts/build_tent_master.lua` (bangun via
> Part + Union di Studio), atau ambil 1 mesh tenda dari Toolbox.
