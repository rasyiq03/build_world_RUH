---
name: mock-roblox
description: Jalankan mekanisme RUH (roblox/shared/) secara HEADLESS tanpa Studio, pakai harness Lune yang meniru API Roblox (game:GetService, Instance.new, RBXScriptSignal, RunService.Heartbeat via jam virtual, pohon ModuleScript untuk script.Parent/require). Skenario menggerakkan event pemain + waktu; hasilnya log event JSON yang divisualkan di halaman web. Pakai saat ingin menguji/iterasi logika mekanisme (timer, kehadiran zona, counter, state) sebelum/selain uji di Studio via Rojo.
---

# mock-roblox — harness Roblox headless untuk RUH

Menguji mekanisme di `roblox/shared/mechanisms/` **tanpa membuka Roblox Studio**. Berguna untuk
iterasi cepat logika (timer Wukuf, gating kehadiran, counter Tawaf, dll.) dan untuk **melihat
alur program** lewat visualizer web. Uji di Studio via Rojo tetap jadi verifikasi akhir; ini
melengkapi, bukan mengganti.

## Prasyarat
- **Lune** di PATH (`lune --version`). Terdaftar di `aftman.toml` (`lune-org/lune`). Jika belum:
  `aftman install` (butuh jaringan; bila aftman timeout, unduh zip rilis Lune manual lalu taruh
  `lune.exe` di `~/.aftman/bin/`).

## Pakai
```bash
# dari root repo
lune run .claude/skills/mock-roblox/harness/runner.luau .claude/skills/mock-roblox/scenarios/wukuf.luau
```
Lalu buka `.claude/skills/mock-roblox/web/index.html` di browser (data tertanam di `web/data.js`,
tanpa server). Tombol **Putar** menganimasikan alur; scrubber untuk menggeser waktu.

## Struktur
```
.claude/skills/mock-roblox/
├── SKILL.md
├── harness/runner.luau   # mock API Roblox + loader ModuleScript + API skenario + tulis JSON
├── scenarios/            # 1 file per skenario (pakai global `h`, `Vector3`, `meta`)
│   └── wukuf.luau
└── web/                  # visualizer (index.html) + data.js (digenerate, JANGAN commit)
```

## Apa yang ditiru harness
- `game:GetService("Players"|"RunService"|"HttpService"|"ReplicatedStorage"|"Workspace"|…)`
- `Instance.new(...)` (Part/Folder/Model) dengan `.Parent`, anak-by-nama, `:Destroy/:FindFirstChild/:GetChildren/:IsA`
- **RBXScriptSignal**: `:Connect/:Once/:Fire/:Disconnect` — termasuk `.Touched`/`.TouchEnded`
- **Pohon ModuleScript** dari `roblox/shared/`: `script.Parent.X`, `:WaitForChild`, `require(<ModuleScript>)`
- `RunService.Heartbeat` digerakkan **jam virtual** (deterministik) lewat `h.advance/h.heartbeat`
- `Vector3/Vector2/CFrame/Color3/Enum/NumberRange/NumberSequence`, `task`, `tick`, `print/warn` (direkam)

> Mekanisme **tidak boleh tahu** soal harness (di Roblox asli ia tak ada). Visualisasi diturunkan
> dari log `print`/`Notify` + event skenario — bukan hook khusus di mekanisme.

## API skenario (objek global `h`)
| Fungsi | Guna |
|---|---|
| `h.spawnPlayer(name)` | buat Player + Character (HumanoidRootPart) |
| `h.newZone{name,center,size}` | buat Part zona (untuk TriggerZone/kehadiran) |
| `h.enter(zone, player)` / `h.leave(...)` | picu `Touched` / `TouchEnded` |
| `h.heartbeat(dt)` / `h.advance(detik, step)` | majukan jam virtual + fire Heartbeat |
| `h.activate(id, ctx)` / `h.deactivate()` | lewat MechanismRegistry |
| `h.isDone()` | `Registry.isActiveDone()` (direkam) |
| `h.mech(id)` | ambil modul mekanisme (panggil API ekstra, mis. `recordDeed`) |
| `h.event(kind, data)` | tandai event kustom di timeline |
| `meta("key", value)` | metadata run (mis. `meta("title", ...)`) |

## Menambah skenario / mekanisme baru
1. Tulis mekanisme di `roblox/shared/mechanisms/<Nama>.lua` (patuhi `_TEMPLATE.lua`).
2. Salin `scenarios/wukuf.luau` → `<nama>.luau`, susun event-nya.
3. `lune run …/runner.luau …/scenarios/<nama>.luau` → buka `web/index.html`.

## Batas (jujur)
- Tak ada fisika/rendering/yield nyata. `task.wait` tidak benar-benar menunda — mekanisme yang
  butuh waktu sebaiknya pakai akumulasi `RunService.Heartbeat dt` (pola Wukuf), bukan `task.wait`.
- `Touched` dipicu manual oleh skenario (tak ada gerak otomatis). Untuk area luas, presence
  berbasis posisi tiap Heartbeat lebih akurat di game asli (TODO).
- Tujuan: validasi **logika & sinkronisasi antar-modul**, bukan kebenaran visual.
