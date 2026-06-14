# roblox/ — Kode Lua in-game (proyek Rojo)

Sumber kebenaran **kode** = git (lewat Rojo). Terrain & mesh tetap di Studio/`.rbxl`
(lihat [`../docs/GAME_DESIGN.md`](../docs/GAME_DESIGN.md) §7-8).

## Alur kerja Rojo
1. `aftman install` (sekali) → dapat Rojo versi terkunci (`../aftman.toml`).
2. `rojo serve` di folder repo.
3. Studio → plugin **Rojo** → **Connect**. Edit `.lua` di VS Code → tersinkron ke Studio.

`../default.project.json` memetakan:
| Folder | → Studio |
|---|---|
| `shared/` | `ReplicatedStorage.Shared` (state machine, registry, util — dipakai semua place) |
| `npc/` | `ReplicatedStorage.Npc` (behavior NPC per tipe) |
| `server/` | `ServerScriptService.Server` (bootstrap server per place) |
| `client/` | `StarterPlayer.StarterPlayerScripts` (UI/nav/kamera) |

## Struktur
```
roblox/
├── shared/        # KONTRAK BERSAMA (ubah dgn koordinasi tim)
│   ├── Flows.lua            # data alur 4 jenis ibadah (GAME_DESIGN §5)
│   ├── ManasikState.lua     # SPINE: state machine data-driven
│   ├── MechanismRegistry.lua# loader + dispatcher mekanisme
│   ├── Teleport.lua  TriggerZone.lua  Notify.lua  SoundManager.lua  NpcFramework.lua
│   └── mechanisms/          # 1 file per mekanisme (_TEMPLATE.lua = kontrak)
├── npc/           # behavior NPC (Askar, jamaah, medis, ...)
├── server/  client/         # bootstrap server / skrip client
├── places/        # skrip per-place BARU (Lobby, Miqat_*, ...) — diisi saat dibangun
└── A_Makkah/ B_Mina/ C_Arafah/ common/   # skrip ZONA LAMA (edit-time Command Bar)
```

## Multi-place (~10 place)
Satu Experience berisi Lobby + 5 Miqat + 4 zona ritual. `default.project.json` ini =
**place dasar** (kode bersama). Tiap place nanti punya project file sendiri
(mis. `places/Makkah.project.json`) yang me-`$path` ke `shared/` + skrip place-nya.
Untuk sekarang, kembangkan spine `shared/` di satu place dev dulu.

## Skrip zona lama (`A_Makkah/`, `B_Mina/`, `C_Arafah/`, `common/`)
Ini **skrip edit-time** (dijalankan manual di Command Bar untuk *memmaterialkan* dunia:
teras, tenda, rute). BUKAN skrip runtime — jadi tidak disinkron Rojo sebagai instance.
Saat zona dikonversi ke alur ibadah penuh, pindahkan bagian runtime-nya ke `places/`.
