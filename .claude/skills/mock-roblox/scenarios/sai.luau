--!nocheck
-- Skenario SaiCounter (Devi) — 7 perjalanan Shafa↔Marwah, mulai Shafa, berakhir Marwah.
-- Verifikasi: (A) kedatangan berulang di ujung yang sama tak menambah; (B) 7 perjalanan via
-- posisi (M.update) → isDone, berakhir di Marwah; (C) ujung pertama yang sah = Marwah.
-- Global: `h`, `Vector3`, `meta`.

meta("mechanism", "SaiCounter")
meta("title", "Sa'i: 7 perjalanan Shafa↔Marwah via kedekatan ujung")

local player = h.spawnPlayer("Devi")
local sai = h.mech("SaiCounter")

local SHAFA = Vector3.new(0, 0, 0)
local MARWAH = Vector3.new(0, 0, 300) -- ~300 studs antar bukit
local REACH = 12

h.activate("SaiCounter", { player = player, shafa = SHAFA, marwah = MARWAH, config = { target = 7, reachRadius = REACH } })

-- Tiba di Shafa lagi (titik mulai) → tak menambah (lastEnd sudah Shafa).
sai.update(SHAFA)
h.event("note", { text = "Kembali ke Shafa di awal: trips=" .. sai.trips() .. " (harus 0)" })

-- Helper: pindah ke ujung (posisi tepat di titik → dalam radius).
local function goTo(name, pos)
	h.heartbeat(0.5)
	sai.update(pos)
	h.event("step", { text = "Tiba di " .. name .. " → trips=" .. sai.trips(), trips = sai.trips() })
end

-- 7 perjalanan: Shafa(start) → Marwah(1) → Shafa(2) → Marwah(3) → Shafa(4) → Marwah(5) → Shafa(6) → Marwah(7)
local order = { { "Marwah", MARWAH }, { "Shafa", SHAFA }, { "Marwah", MARWAH }, { "Shafa", SHAFA },
	{ "Marwah", MARWAH }, { "Shafa", SHAFA }, { "Marwah", MARWAH } }
for _, e in ipairs(order) do
	-- Sisipkan satu update di tengah jalur (jauh dari kedua ujung) → tak berpengaruh.
	sai.update(Vector3.new(0, 0, 150))
	goTo(e[1], e[2])
end

h.event("note", { text = "Sa'i selesai? isDone=" .. tostring(h.isDone()) .. " trips=" .. sai.trips() .. " (harus 7, berakhir Marwah)" })

-- Setelah selesai, kedatangan lagi tak menambah.
sai.update(SHAFA)
h.event("note", { text = "Setelah selesai, tiba Shafa lagi: trips=" .. sai.trips() .. " (tetap 7)" })
h.deactivate()
