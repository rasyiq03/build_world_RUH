--!nocheck
-- INTEGRASI ENTRY LOBBY (Devi) — menutup loop Lobby → TeleportData → bootstrap → flow.
-- (A) validasi pilihan (tolak jenis/miqat salah). (B) buildData → restore → jalankan UMRAH PENUH
--     lewat ManasikRunner lintas Miqat_BirAli → Makkah (IhramChange, BusRide, Tawaf, Sai, Tahallul).
-- Membuktikan TeleportData yang DIHASILKAN Lobby benar-benar bisa direkonstruksi & dijalankan.
-- Global: `h`, `Vector3`, `meta`.

meta("mechanism", "LobbyStart + spine (Umrah)")
meta("title", "Lobby → TeleportData → bootstrap → Umrah tuntas")

local LobbyStart = h.require("LobbyStart")
local ManasikState = h.require("ManasikState")
local ManasikRunner = h.require("ManasikRunner")
local Tahallul = h.require("mechanisms/Tahallul")

local player = h.spawnPlayer("Devi")

----------------------------------------------------------------------------------------------------
-- BAGIAN A — validasi.
----------------------------------------------------------------------------------------------------
local _, e1 = LobbyStart.validate("Foo", "Miqat_BirAli")
h.event("note", { text = "Jenis salah ditolak? err=" .. tostring(e1) })
local _, e2 = LobbyStart.validate("Umrah", "Miqat_Salah")
h.event("note", { text = "Miqat salah ditolak? err=" .. tostring(e2) })
local okV = LobbyStart.validate("Umrah", "Miqat_BirAli")
h.event("note", { text = "Pilihan sah diterima? ok=" .. tostring(okV) })

----------------------------------------------------------------------------------------------------
-- BAGIAN B — buildData (= yang dikirim ke TeleportData) → restore → jalankan.
----------------------------------------------------------------------------------------------------
local data, err = LobbyStart.buildData("Umrah", "Miqat_BirAli")
h.event("note", { text = "TeleportData: ibadah=" .. tostring(data and data.ibadahType) .. " miqat=" .. tostring(data and data.chosenMiqat) .. " index=" .. tostring(data and data.index) .. (err and (" err=" .. err) or "") })

local KABAH = Vector3.new(0, 0, 0)
local SHAFA, MARWAH = Vector3.new(0, 0, 120), Vector3.new(0, 0, 420)

local function buildCtx(place, stage, state, pl)
	local r = stage.ritual
	if r == "IhramChange" then
		return { player = pl, place = place, ibadahType = state.ibadahType }
	elseif r == "BusRide" then
		return { player = pl, place = place, destinationLabel = "Makkah", config = { rideSeconds = 2 } }
	elseif r == "TawafCounter" then
		return { player = pl, place = place, center = KABAH, config = { target = 7, maxRadius = 60 } }
	elseif r == "SaiCounter" then
		return { player = pl, place = place, shafa = SHAFA, marwah = MARWAH, config = { target = 7, reachRadius = 12 } }
	elseif r == "Tahallul" then
		return { player = pl, place = place, mode = Tahallul.modeForStage(stage.id) }
	end
	return { player = pl, place = place }
end

-- Rekonstruksi state PERSIS seperti bootstrap di place tujuan: ManasikState.restore(TeleportData).
local state = ManasikState.restore(data)
h.event("note", { text = "Bootstrap restore → tahap " .. state:current().id .. " @ " .. state:resolvePlace(state:current()) })

local completed = false
local runAt
runAt = function(placeName, st)
	local runner = ManasikRunner.new({
		placeName = placeName,
		player = player,
		state = st,
		buildContext = function(stage, s, pl)
			return buildCtx(placeName, stage, s, pl)
		end,
		teleport = function(nextPlace, d)
			h.event("teleport", { to = nextPlace, index = d.index })
			runAt(nextPlace, ManasikState.restore(d))
		end,
		onComplete = function()
			completed = true
			h.event("done", { text = "Umrah tuntas (dari pilihan Lobby)" })
		end,
	})
	runner:start()
end

runAt(state:resolvePlace(state:current()), state)

for _ = 1, 600 do
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
			local ang = 0
			act.update(Vector3.new(20, 0, 0))
			for _ = 1, 520 do
				ang = ang - 0.1
				act.update(Vector3.new(math.cos(ang) * 20, 0, math.sin(ang) * 20))
			end
		elseif act.id == "SaiCounter" then
			for _ = 1, 7 do
				act.reach("Marwah")
				act.reach("Shafa")
			end
		end
	end
	h.advance(1, 1)
end

h.event("note", { text = "Umrah dari Lobby tuntas? isComplete=" .. tostring(completed) .. (completed and " ✅" or " ❌") })
