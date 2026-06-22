--!nocheck
-- Skenario INTEGRASI: jalur HAJI dari HajiTamattu (mulai IHRAM_HAJI) lewat ManasikRunner,
-- melintasi place Makkah→Mina→Arafah→Muzdalifah→Mina→Makkah. Membuktikan spine men-thread
-- seluruh mekanisme milik Nabil + meng-handoff teleport antar-place.
--
-- Pump-loop menggerakkan mekanisme yang sedang aktif:
--   • Wukuf/Mabit  : timer berbasis kehadiran (durasi dipercepat, startPresent) — jalan otomatis.
--   • IhramHaji/Tahallul : tanpa station → aksi langsung saat activate.
--   • PebbleCollect: pump menyentuh kerikil.
--   • TawafCounter (Devi): pump meng-orbit posisi pemain mengelilingi pusat (≥7 putaran).
--   • JumrahThrow (Praditama): pump melempar Ula/Wustha/Aqabah (mech menegakkan urutan) + nafar awwal.
--   • Qurban (Praditama): pump memanggil beginSacrifice (dam Tamattu').
-- Catatan: jalur haji HajiTamattu (mulai IHRAM_HAJI) tak memuat SaiCounter sbg tahap (Sa'i umrah
--   ada di fase umrah; integrasi penuhnya di scenarios/integrasi_penuh.luau).
-- Global: `h`, `Vector3`, `meta`.

meta("mechanism", "ManasikRunner — jalur HAJI HajiTamattu")
meta("title", "Integrasi spine: IHRAM_HAJI → Mina → Arafah → Muzdalifah → … (lintas place)")

local ManasikRunner = h.require("ManasikRunner")
local ManasikState = h.require("ManasikState")
local Tahallul = h.require("mechanisms/Tahallul")

local player = h.spawnPlayer("Nabil")

-- Aset uji per place.
local zones = {
	Arafah = h.newZone({ name = "ZonaArafah", center = Vector3.new(0, 0, 0), size = Vector3.new(17000, 1000, 16000) }),
	Mina = h.newZone({ name = "ZonaMina", center = Vector3.new(0, 0, 0), size = Vector3.new(8000, 1000, 8000) }),
}
local pebbles = {}
for i = 1, 7 do
	pebbles[i] = h.newZone({ name = "Kerikil" .. i, center = Vector3.new(i * 6, 0, 0), size = Vector3.new(2.5, 2.5, 2.5) })
end

-- ctx per place (meniru PlaceContext milik pemilik place; durasi dipercepat utk uji).
local function buildCtx(place, stage, pl)
	local r = stage.ritual
	if r == "Wukuf" then
		return { player = pl, place = place, zonePart = zones.Arafah, config = { wukufSeconds = 3 }, startPresent = true }
	elseif r == "Mabit" then
		return { player = pl, place = place, zonePart = zones.Mina, config = { mabitSeconds = 3 }, startPresent = true, label = "Mina" }
	elseif r == "PebbleCollect" then
		return { player = pl, place = place, pebbles = pebbles, config = { target = 7 } }
	elseif r == "Tahallul" then
		return { player = pl, place = place, mode = Tahallul.modeForStage(stage.id) } -- station nil → langsung
	elseif r == "IhramHaji" then
		return { player = pl, place = place } -- station nil → langsung
	elseif r == "TawafCounter" then
		return { player = pl, place = place, center = Vector3.new(0, 0, 0), config = { target = 7, maxRadius = 0 } }
	elseif r == "JumrahThrow" then
		local mode = (stage.id == "MABIT_MINA_2") and "three_pillars" or "aqabah_only"
		return { player = pl, place = place, mode = mode, config = { throwsPerPillar = 7, hitChance = 1 } }
	elseif r == "Qurban" then
		return { player = pl, place = place, damRequired = true, config = { processSeconds = 2 } }
	end
	return { player = pl, place = place }
end

-- State HajiTamattu, mulai dari IHRAM_HAJI (awal jalur haji).
local state = ManasikState.new("HajiTamattu", "Miqat_BirAli")
while state:current() and state:current().id ~= "IHRAM_HAJI" do
	state:advance()
end
h.event("note", { text = "Mulai jalur haji di tahap " .. state:current().id })

local completed = false
local runAt
runAt = function(placeName, st)
	local runner = ManasikRunner.new({
		placeName = placeName,
		player = player,
		state = st,
		buildContext = function(stage, _s, pl)
			return buildCtx(placeName, stage, pl)
		end,
		teleport = function(nextPlace, data)
			h.event("teleport", { to = nextPlace, index = data.index })
			runAt(nextPlace, ManasikState.restore(data)) -- lanjut di place berikutnya
		end,
		onComplete = function()
			completed = true
			h.event("done", { text = "Seluruh jalur haji tuntas" })
		end,
	})
	runner:start()
end

-- Pemain mulai di Makkah (IHRAM_HAJI @ Makkah).
runAt("Makkah", state)

-- Pump: gerakkan mekanisme aktif tiap langkah hingga flow selesai.
for _ = 1, 400 do
	if completed then
		break
	end
	local act = h.registry._active
	if act and not act.isDone() then
		if act.id == "PebbleCollect" then
			for _, peb in ipairs(pebbles) do
				h.enter(peb, player)
			end
		elseif act.id == "TawafCounter" then
			-- Orbit pemain mengelilingi pusat (0,0,0), arah tawaf (-1 → angle turun), ~8 putaran.
			local ang = 0
			act.update(Vector3.new(20, 0, 0)) -- set lastAngle awal
			for _ = 1, 520 do
				ang = ang - 0.1
				act.update(Vector3.new(math.cos(ang) * 20, 0, math.sin(ang) * 20))
			end
		elseif act.id == "JumrahThrow" then
			-- Lempar ke semua pilar; mech menegakkan urutan & hari. Nafar awwal agar selesai hari 12.
			for _ = 1, 7 do
				act.throw("Ula")
				act.throw("Wustha")
				act.throw("Aqabah")
			end
			act.chooseNafar("awwal")
		elseif act.id == "Qurban" then
			act.beginSacrifice("kambing")
		end
	end
	h.advance(1, 1)
end

h.event("note", { text = completed and "SELESAI: jalur haji tuntas" or "BELUM selesai (cek log)" })
