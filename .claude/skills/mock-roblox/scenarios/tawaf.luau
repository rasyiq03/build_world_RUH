--!nocheck
-- Skenario TawafCounter (Devi) — deteksi 7 putaran via sudut kumulatif terhadap pusat Ka'bah.
-- Verifikasi: (A) gerak mundur/lawan-arah tak menambah (cumulative diklem ≥ 0); (B) orbit penuh
-- arah tawaf = 7 putaran → isDone; (C) gate radius (di luar mataf tak dihitung).
-- Global: `h`, `Vector3`, `meta`.

meta("mechanism", "TawafCounter")
meta("title", "Tawaf: 7 putaran via sudut kumulatif, arah & gate radius")

local player = h.spawnPlayer("Devi")
local tawaf = h.mech("TawafCounter")

local KABAH = Vector3.new(100, 0, 100)
local R = 25
local DIR = -1 -- arah tawaf default (berlawanan jarum jam), konsisten dgn JamaahTawaf.

-- Posisi pemain pada sudut tertentu (jari-jari r) relatif pusat Ka'bah.
local function posAt(angle, r)
	return Vector3.new(KABAH.X + math.cos(angle) * (r or R), 0, KABAH.Z + math.sin(angle) * (r or R))
end

h.activate("TawafCounter", { player = player, center = KABAH, config = { target = 7, maxRadius = 60 } })

----------------------------------------------------------------------------------------------------
-- BAGIAN A — lawan arah (angle NAIK = bukan arah tawaf utk DIR=-1) → tak menambah putaran.
----------------------------------------------------------------------------------------------------
local angle = 0
tawaf.update(posAt(angle)) -- set lastAngle awal
for _ = 1, 30 do
	angle = angle + 0.1 -- arah berlawanan dgn tawaf (DIR=-1)
	h.heartbeat(0.1)
	tawaf.update(posAt(angle))
end
h.event("note", { text = "Setelah 30 langkah LAWAN arah: laps=" .. tawaf.laps() .. " (harus 0, cumulative diklem)" })

----------------------------------------------------------------------------------------------------
-- BAGIAN B — gate radius: lompat jauh keluar mataf, lalu sebuah update di luar → diabaikan.
----------------------------------------------------------------------------------------------------
tawaf.update(Vector3.new(KABAH.X + 500, 0, KABAH.Z)) -- r=500 > maxRadius 60 → reset lastAngle
h.event("note", { text = "Update di luar radius (r=500) diabaikan; lastAngle direset." })

----------------------------------------------------------------------------------------------------
-- BAGIAN C — orbit penuh ARAH tawaf (DIR=-1 → angle TURUN) selama 7+ putaran.
----------------------------------------------------------------------------------------------------
angle = 0
tawaf.update(posAt(angle)) -- set ulang lastAngle setelah keluar-masuk
local prevLaps = 0
local steps = 0
-- 7 putaran = 14π rad; langkah 0.1 → ~440 langkah. Beri margin.
while not h.isDone() and steps < 600 do
	angle = angle + DIR * 0.1 -- arah tawaf: angle menurun
	h.heartbeat(0.1)
	tawaf.update(posAt(angle))
	steps += 1
	local l = tawaf.laps()
	if l ~= prevLaps then
		h.event("lap", { text = "Putaran ke-" .. l, laps = l })
		prevLaps = l
	end
end

h.event("note", { text = "Selesai 7 putaran? isDone=" .. tostring(h.isDone()) .. " laps=" .. tawaf.laps() .. " (langkah=" .. steps .. ")" })
h.deactivate()
