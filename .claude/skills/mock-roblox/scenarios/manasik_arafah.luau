--!nocheck
-- Skenario tingkat-SPINE: ManasikRunner menggerakkan FLOWS HajiTamattu di place "Arafah".
-- Menunjukkan: runner meng-activate Wukuf untuk tahap WUKUF, memantau penyelesaian, lalu
-- ADVANCE → tahap berikutnya (MABIT_MUZDALIFAH @ Muzdalifah) → memanggil `teleport` (injeksi).
-- Global tersedia: `h`, `Vector3`, `meta`.

meta("mechanism", "ManasikRunner → Wukuf")
meta("title", "Spine: ManasikRunner menjalankan tahap WUKUF lalu serah-terima teleport")

local ManasikRunner = h.require("ManasikRunner")
local ManasikState = h.require("ManasikState")

local player = h.spawnPlayer("Nabil")
local zone = h.newZone({
	name = "ZonaArafah",
	center = Vector3.new(-64.5, 0, 0),
	size = Vector3.new(17495, 1000, 16944),
})

-- State HajiTamattu, fast-forward ke tahap WUKUF (seolah pemain baru tiba di Arafah).
local state = ManasikState.new("HajiTamattu", "Miqat_BirAli")
while state:current() and state:current().id ~= "WUKUF" do
	state:advance()
end
h.event("note", { text = "Tiba di Arafah pada tahap " .. state:current().id })

local teleportedTo = nil
local runner = ManasikRunner.new({
	placeName = "Arafah",
	player = player,
	state = state,
	buildContext = function(_stage, _st, pl)
		return { player = pl, place = "Arafah", zonePart = zone, config = { wukufSeconds = 40 }, startPresent = true }
	end,
	teleport = function(place, data)
		teleportedTo = place
		h.event("teleport", { to = place, index = data.index, ibadah = data.ibadahType })
	end,
})

runner:start()

-- Jalankan wukuf hingga selesai (40 dtk) + sedikit ekstra agar runner sempat advance.
h.advance(45, 1)

h.event("note", { text = "Tujuan teleport setelah Wukuf = " .. tostring(teleportedTo) })
