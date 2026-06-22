--!nocheck
-- INTEGRASI PENUH — satu playthrough HajiTamattu LENGKAP (dari tahap 1) lewat ManasikRunner,
-- melintasi Miqat → Makkah → Mina → Arafah → Muzdalifah → Mina → Makkah, menggerakkan SELURUH
-- mekanisme ketiga pemilik dengan handoff teleport:
--   Devi      : IhramChange, TawafCounter, SaiCounter
--   Praditama : BusRide, JumrahThrow, Qurban
--   Nabil     : IhramHaji, Mabit, Wukuf, PebbleCollect, Tahallul
-- Di akhir: assert SEMUA mekanisme tersentuh + flow tuntas. Durasi dipercepat. Global: `h`, `Vector3`, `meta`.

meta("mechanism", "INTEGRASI — HajiTamattu lengkap, 3 pemilik")
meta("title", "Integrasi penuh: Miqat → Makkah → Armuzna → Makkah, semua mekanisme")

local ManasikRunner = h.require("ManasikRunner")
local ManasikState = h.require("ManasikState")
local Tahallul = h.require("mechanisms/Tahallul")

local player = h.spawnPlayer("Tim")

-- Aset uji per place (meniru PlaceContext milik pemilik).
local zones = {
	Arafah = h.newZone({ name = "ZonaArafah", center = Vector3.new(0, 0, 0), size = Vector3.new(17000, 1000, 16000) }),
	Mina = h.newZone({ name = "ZonaMina", center = Vector3.new(0, 0, 0), size = Vector3.new(8000, 1000, 8000) }),
}
local pebbles = {}
for i = 1, 7 do
	pebbles[i] = h.newZone({ name = "Kerikil" .. i, center = Vector3.new(i * 6, 0, 0), size = Vector3.new(2.5, 2.5, 2.5) })
end
local KABAH = Vector3.new(0, 0, 0)
local SHAFA, MARWAH = Vector3.new(0, 0, 120), Vector3.new(0, 0, 420)

-- Catat mekanisme yang tersentuh (untuk assert cakupan). Direkam di buildCtx — dipanggil runner
-- untuk SETIAP tahap ritual sebelum activate, jadi menangkap mekanisme selesai-seketika sekalipun.
local seen = {}

-- ctx per ritual (meniru PlaceContext.Makkah/Miqat/Mina/Arafah/Muzdalifah).
local function buildCtx(place, stage, state, pl)
	local r = stage.ritual
	if r then
		seen[r] = true
	end
	if r == "IhramChange" then
		return { player = pl, place = place, ibadahType = state.ibadahType }
	elseif r == "BusRide" then
		return { player = pl, place = place, destinationLabel = "Makkah", config = { rideSeconds = 2 } }
	elseif r == "TawafCounter" then
		return { player = pl, place = place, center = KABAH, config = { target = 7, maxRadius = 60 } }
	elseif r == "SaiCounter" then
		return { player = pl, place = place, shafa = SHAFA, marwah = MARWAH, config = { target = 7, reachRadius = 12 } }
	elseif r == "Tahallul" then
		return { player = pl, place = place, mode = Tahallul.modeForStage(stage.id) } -- station nil → langsung
	elseif r == "IhramHaji" then
		return { player = pl, place = place } -- langsung
	elseif r == "Wukuf" then
		return { player = pl, place = place, zonePart = zones.Arafah, config = { wukufSeconds = 2 }, startPresent = true }
	elseif r == "Mabit" then
		return { player = pl, place = place, zonePart = zones.Mina, config = { mabitSeconds = 2 }, startPresent = true, label = "Mina" }
	elseif r == "PebbleCollect" then
		return { player = pl, place = place, pebbles = pebbles, config = { target = 7 } }
	elseif r == "JumrahThrow" then
		local mode = (stage.id == "MABIT_MINA_2") and "three_pillars" or "aqabah_only"
		return { player = pl, place = place, mode = mode, config = { throwsPerPillar = 7, hitChance = 1 } }
	elseif r == "Qurban" then
		return { player = pl, place = place, damRequired = true, config = { processSeconds = 1 } }
	end
	return { player = pl, place = place }
end

local state = ManasikState.new("HajiTamattu", "Miqat_BirAli")
h.event("note", { text = "Mulai HajiTamattu dari tahap " .. state:current().id .. " @ " .. state:resolvePlace(state:current()) })

local completed = false
local hops = 0
local runAt
runAt = function(placeName, st)
	hops += 1
	local runner = ManasikRunner.new({
		placeName = placeName,
		player = player,
		state = st,
		buildContext = function(stage, s, pl)
			return buildCtx(placeName, stage, s, pl)
		end,
		teleport = function(nextPlace, data)
			h.event("teleport", { to = nextPlace, index = data.index, from = placeName })
			runAt(nextPlace, ManasikState.restore(data))
		end,
		onComplete = function()
			completed = true
			h.event("done", { text = "Seluruh manasik HajiTamattu tuntas" })
		end,
	})
	runner:start()
end

-- Mulai di miqat terpilih (IHRAM_UMRAH @ Miqat_BirAli).
runAt(state:resolvePlace(state:current()), state)

-- Pump: gerakkan mekanisme aktif tiap langkah hingga selesai.
local tawafFed = {}
for _ = 1, 1200 do
	if completed then
		break
	end
	local act = h.registry._active
	if act and not act.isDone() then
		if act.id == "IhramChange" then
			act.wearIhram()
			act.makeNiat()
		elseif act.id == "BusRide" then
			act.board()
		elseif act.id == "TawafCounter" then
			-- Orbit penuh sekali (arah tawaf -1 → angle turun), ~8 putaran.
			local ang = 0
			act.update(Vector3.new(KABAH.X + 20, 0, KABAH.Z))
			for _ = 1, 520 do
				ang = ang - 0.1
				act.update(Vector3.new(KABAH.X + math.cos(ang) * 20, 0, KABAH.Z + math.sin(ang) * 20))
			end
		elseif act.id == "SaiCounter" then
			for _ = 1, 7 do
				act.reach("Marwah")
				act.reach("Shafa")
			end
		elseif act.id == "PebbleCollect" then
			for _, peb in ipairs(pebbles) do
				h.enter(peb, player)
			end
		elseif act.id == "JumrahThrow" then
			for _ = 1, 7 do
				act.throw("Ula")
				act.throw("Wustha")
				act.throw("Aqabah")
			end
			act.chooseNafar("awwal") -- selesai hari 12 (nafar awwal)
		elseif act.id == "Qurban" then
			act.beginSacrifice("kambing")
		end
		-- IhramHaji/Tahallul/Wukuf/Mabit: selesai sendiri (langsung / timer kehadiran).
	end
	h.advance(1, 1)
end

----------------------------------------------------------------------------------------------------
-- ASSERT cakupan & ketuntasan.
----------------------------------------------------------------------------------------------------
local expected = { "IhramChange", "BusRide", "TawafCounter", "SaiCounter", "Tahallul",
	"IhramHaji", "Wukuf", "Mabit", "PebbleCollect", "JumrahThrow", "Qurban" }
local missing = {}
for _, id in ipairs(expected) do
	if not seen[id] then
		missing[#missing + 1] = id
	end
end
local seenList = {}
for id in pairs(seen) do
	seenList[#seenList + 1] = id
end
table.sort(seenList)

h.event("note", { text = "Mekanisme tersentuh (" .. #seenList .. "): " .. table.concat(seenList, ", ") })
h.event("note", { text = #missing == 0 and "Cakupan LENGKAP: 11/11 mekanisme ✅" or ("KURANG: " .. table.concat(missing, ", ") .. " ❌") })
h.event("note", { text = "Flow tuntas? isComplete=" .. tostring(completed) .. " · hop place=" .. hops .. (completed and " ✅" or " ❌") })
