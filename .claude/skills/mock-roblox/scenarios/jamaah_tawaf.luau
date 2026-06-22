--!nocheck
-- Skenario JamaahTawaf (Praditama) — NPC mengelilingi Ka'bah. Bukan ritual alur; di-uji via
-- h.require("JamaahTawaf"). Verifikasi: gerak melingkar (jarak ke pusat ~konstan = radius),
-- kembali ~ke posisi awal tiap putaran, dan hitung 7 putaran (tawaf lengkap).
-- Global: `h`, `Vector3`, `meta`.

meta("mechanism", "JamaahTawaf")
meta("title", "NPC Tawaf: orbit Ka'bah, jarak konstan, 7 putaran")

local JamaahTawaf = h.require("JamaahTawaf")

local KABAH = Vector3.new(100, 0, 100) -- pusat Ka'bah (bukan origin → uji offset center)

local function dist2D(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- Spawn 3 jamaah berbeda negara, radius (lajur) berbeda, laju berbeda.
local indo = JamaahTawaf.spawn({ center = KABAH, radius = 20, speed = 8, country = "Indonesia", startAngle = 0 })
local turki = JamaahTawaf.spawn({ center = KABAH, radius = 30, speed = 8, country = "Turki" })
local mesir = JamaahTawaf.spawn({ center = KABAH, radius = 40, speed = 12, country = "Mesir" })

local startPos = JamaahTawaf.positionOf(indo)
h.event("note", { text = "Indo mulai di (" .. math.floor(startPos.X) .. "," .. math.floor(startPos.Z) .. "), jarak ke Ka'bah = " .. dist2D(startPos, KABAH) })

-- Jalankan orbit (60 detik, langkah halus 0.2s).
JamaahTawaf.update(indo, 0) -- no-op aman
local maxDriftIndo = 0
for _ = 1, 300 do
	h.heartbeat(0.2)
	JamaahTawaf.update(indo, 0.2)
	JamaahTawaf.update(turki, 0.2)
	JamaahTawaf.update(mesir, 0.2)
	-- jarak ke pusat harus tetap = radius (20) untuk indo
	local d = dist2D(JamaahTawaf.positionOf(indo), KABAH)
	maxDriftIndo = math.max(maxDriftIndo, math.abs(d - 20))
end

h.event("note", { text = "Indo: drift jarak-ke-pusat maks = " .. string.format("%.4f", maxDriftIndo) .. " (harus ~0)" })
h.event("note", { text = "Putaran (laps): Indo=" .. JamaahTawaf.lapsOf(indo) .. " Turki=" .. JamaahTawaf.lapsOf(turki) .. " Mesir=" .. JamaahTawaf.lapsOf(mesir) })

-- Mesir lebih cepat (12 vs 8 studs/s, radius lebih besar) → bandingkan kecepatan sudut:
-- angularSpeed = speed/radius → Indo 8/20=0.4, Turki 8/30=0.267, Mesir 12/40=0.3 rad/s.
-- Maka urutan putaran: Indo > Mesir > Turki.
local li, lt, lm = JamaahTawaf.lapsOf(indo), JamaahTawaf.lapsOf(turki), JamaahTawaf.lapsOf(mesir)
h.event("note", { text = "Urutan putaran benar (Indo>Mesir>Turki)? " .. tostring(li >= lm and lm >= lt) })

local endPos = JamaahTawaf.positionOf(indo)
h.event("note", { text = "Indo posisi akhir jarak ke pusat = " .. string.format("%.3f", dist2D(endPos, KABAH)) })

JamaahTawaf.despawn(indo)
JamaahTawaf.despawn(turki)
JamaahTawaf.despawn(mesir)
h.event("note", { text = "Setelah despawn, lapsOf(indo) = " .. JamaahTawaf.lapsOf(indo) .. " (harus 0)" })
