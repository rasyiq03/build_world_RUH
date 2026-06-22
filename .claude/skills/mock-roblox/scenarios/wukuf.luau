--!nocheck
-- Skenario: Wukuf di Arafah (durasi dipercepat 60 dtk).
-- Menunjukkan: gating KEHADIRAN (timer hanya jalan di dalam zona), milestone progres,
-- amalan WukufIbadah, dan penyelesaian (isDone). Global tersedia: `h`, `Vector3`, `meta`.

meta("mechanism", "Wukuf")
meta("title", "Wukuf di Arafah — gating kehadiran + timer + amalan")

local player = h.spawnPlayer("Nabil")

-- Zona kehadiran Arafah: AABB dari output/C_Arafah/boundary.json
-- (x ∈ [-8812, 8683], z ∈ [-8472, 8472] → pusat ~(-64, 0), lebar ~17495 x 16944).
local zone = h.newZone({
	name = "ZonaArafah",
	center = Vector3.new(-64.5, 0, 0),
	size = Vector3.new(17495, 1000, 16944),
})

local ctx = {
	player = player,
	place = "Arafah",
	zonePart = zone,
	config = { wukufSeconds = 60 },
}

h.activate("Wukuf", ctx)

-- 1) Di LUAR Arafah: 8 dtk berlalu, timer tak boleh jalan.
h.event("note", { text = "Pemain di luar Arafah — timer wukuf belum jalan" })
h.advance(8, 1)
h.isDone() -- false

-- 2) MASUK Arafah → wukuf mulai + beberapa amalan.
h.enter(zone, player)
h.advance(20, 1)
h.mech("Wukuf").recordDeed(player, "talbiyah")
h.mech("Wukuf").recordDeed(player, "doa")
h.advance(10, 1) -- total hadir 30 dtk (~50%)
h.isDone() -- false

-- 3) KELUAR sebentar → timer berhenti, 10 dtk di luar.
h.leave(zone, player)
h.event("note", { text = "Keluar Arafah — wukuf TERHENTI (timer beku)" })
h.advance(10, 1)
h.isDone() -- masih false

-- 4) KEMBALI → selesaikan sisa durasi.
h.enter(zone, player)
h.mech("Wukuf").recordDeed(player, "istighfar")
h.advance(35, 1) -- 30 + 35 = 65 dtk hadir ≥ 60 → SAH
h.isDone() -- true

-- 5) Tahap manasik selesai → deactivate.
h.deactivate()
