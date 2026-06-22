--!nocheck
-- Skenario LINTAS-AREA: Tahallul. Jalur HajiTamattu:
--   tahap TAHALLUL_AWAL @ Mina → cukur (status AWAL) → runner advance → TAWAF_IFADAH @ Makkah
--   → teleport(Makkah). Lalu simulasi place Makkah: markTsani(player) → status COMPLETE.
-- Menelusuri status: IHRAM → AWAL → COMPLETE. Global: `h`, `Vector3`, `meta`.

meta("mechanism", "Tahallul (awal → tsani)")
meta("title", "Tahallul awal di Mina → teleport Makkah → markTsani (lintas-area)")

local ManasikRunner = h.require("ManasikRunner")
local ManasikState = h.require("ManasikState")
local Tahallul = h.require("mechanisms/Tahallul")

local player = h.spawnPlayer("Nabil")
local station = h.newZone({ name = "TempatCukur", center = Vector3.new(0, 0, 0), size = Vector3.new(10, 10, 10) })

h.event("state", { phase = "awal-mula", tahallul = Tahallul.getState(player) }) -- IHRAM

local state = ManasikState.new("HajiTamattu", "Miqat_BirAli")
while state:current() and state:current().id ~= "TAHALLUL_AWAL" do
	state:advance()
end
h.event("note", { text = "Di Mina pada tahap " .. state:current().id })

local teleportedTo = nil
local runner = ManasikRunner.new({
	placeName = "Mina",
	player = player,
	state = state,
	buildContext = function(stage, _st, pl)
		return { player = pl, place = "Mina", mode = Tahallul.modeForStage(stage.id), station = station }
	end,
	teleport = function(place, data)
		teleportedTo = place
		h.event("teleport", { to = place, index = data.index })
	end,
})

runner:start()
h.advance(1, 1)
h.event("state", { phase = "sebelum-cukur", tahallul = Tahallul.getState(player) }) -- IHRAM

h.enter(station, player) -- aksi cukur
h.event("state", { phase = "setelah-cukur", tahallul = Tahallul.getState(player) }) -- AWAL

h.advance(2, 1) -- runner advance → TAWAF_IFADAH @ Makkah → teleport
h.event("note", { text = "Teleport setelah Tahallul awal = " .. tostring(teleportedTo) })

-- Simulasi place Makkah: Tawaf Ifadah selesai → tahallul tsani (tanpa cukur ulang).
Tahallul.markTsani(player)
h.event("state", { phase = "setelah-tawaf-ifadah", tahallul = Tahallul.getState(player) }) -- COMPLETE
