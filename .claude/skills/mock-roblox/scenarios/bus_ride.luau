--!nocheck
-- Skenario BusRide (Praditama) tingkat-SPINE. Alur Umrah di place Miqat_QarnulManazil:
--   IHRAM (IhramChange — milik Devi, tak terdaftar di sini → auto-advance) →
--   KE_MAKKAH (BusRide: naik bus → perjalanan → selesai) → runner ADVANCE ke TAWAF (Makkah) →
--   place beda → memanggil teleport("Makkah"). Membuktikan BusRide menggerbangi handoff teleport.
-- Global: `h`, `Vector3`, `meta`.

meta("mechanism", "ManasikRunner → BusRide")
meta("title", "Spine: BusRide menggerbangi transisi miqat → Makkah")

local ManasikRunner = h.require("ManasikRunner")
local ManasikState = h.require("ManasikState")

local player = h.spawnPlayer("Praditama")
local state = ManasikState.new("Umrah", "Miqat_QarnulManazil")

local teleportedTo = nil
local runner = ManasikRunner.new({
	placeName = "Miqat_QarnulManazil",
	player = player,
	state = state,
	buildContext = function(stage, _st, pl)
		if stage.ritual == "BusRide" then
			return { player = pl, place = "Miqat_QarnulManazil", destinationLabel = "Makkah", config = { rideSeconds = 4 } }
		end
		return { player = pl, place = "Miqat_QarnulManazil" }
	end,
	teleport = function(place, data)
		teleportedTo = place
		h.event("teleport", { to = place, index = data.index, ibadah = data.ibadahType })
	end,
})

runner:start()
h.advance(1, 1) -- IHRAM (IhramChange tak terdaftar) → auto-advance → BusRide aktif
h.event("note", { text = "Tahap sekarang = " .. state:current().id .. " (harus KE_MAKKAH)" })

-- Pemain naik bus.
h.mech("BusRide").board()
h.advance(5, 1) -- lewati rideSeconds → BusRide selesai → runner advance ke TAWAF (Makkah) → teleport

h.event("note", { text = "teleportedTo = " .. tostring(teleportedTo) .. " (harus Makkah)" })
