# SETUP: Terrain → Route per Zona (referensi cepat)

Langkah minimal tiap zona: **import terrain → modul route → gambar jalur (+navigasi)**.
Detail penuh (konten) ada di `../TUTORIAL_MINA.md`. Skala 4, StreamingEnabled ON.

## Pola umum (sama untuk semua zona)
1. **New place** + Workspace.**StreamingEnabled = ON**.
2. **Terrain Importer → Import** tiap tile pakai `output/<ZONA>/IMPORT_GUIDE.md`
   (Size & Position persis, material Sandstone, Position Y jangan diubah).
3. **ModuleScript route** di ReplicatedStorage: buat `<Zona>Route`, tempel
   `output/<ZONA>/<Zona>Route.module.lua`.
4. **Command Bar**: jalankan `roblox_scripts/<ZONA>/render_route.lua` → jalur tergambar.
5. (Opsional) **StarterPlayerScripts** → LocalScript = `roblox_scripts/<ZONA>/nav_guide.lua`.

## Angka tile per zona (Size sama; Position X beda)

### A_Makkah — 16576×16448, 2×2=4 tile (lihat IMPORT_GUIDE untuk Position pasti)
### B_Mina — 15672×10760, 3×1=3 tile
| Tile | Size (X,Y,Z) | Position (X,Y,Z) |
|---|---|---|
| x0_z0 | 5224,3328,10760 | −5224,−1664,0 |
| x1_z0 | 5224,3328,10760 | 0,−1664,0 |
| x2_z0 | 5224,3328,10760 | +5224,−1664,0 |
### C_Arafah — 18656×16944, 2×2=4 tile (lihat IMPORT_GUIDE)

> Untuk A & C (grid 2×2), buka `output/<ZONA>/IMPORT_GUIDE.md` — ada 4 blok tile
> dengan Size/Position persis. Pola sama: impor satu per satu.

## Nama modul route per zona
| Zona | ModuleScript | render_route | nav_guide |
|---|---|---|---|
| A_Makkah | `MakkahRoute` | `A_Makkah/render_route.lua` | `A_Makkah/nav_guide.lua` |
| B_Mina | `MinaRoute` | `B_Mina/render_route.lua` | `B_Mina/nav_guide.lua` |
| C_Arafah | `ArafahRoute` | `C_Arafah/render_route.lua` | `C_Arafah/nav_guide.lua` |

## Catatan
- **Tiap zona = place terpisah** (multi-place). Rute di tiap place punya titik
  KELUAR (gate) → nanti jadi trigger teleport ke zona berikut.
- Konten lain (tenda, Jamarat, landmark Haram, dll.) menyusul lewat build script
  masing-masing zona (`build_mina/arafah/makkah.lua`) — lihat progres per zona di MD.
