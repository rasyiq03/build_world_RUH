--!nocheck
-- Skenario tingkat-SPINE (lanjutan dari Arafah): ManasikRunner di place "Muzdalifah".
-- Tahap MABIT_MUZDALIFAH → PebbleCollect (pungut 7 kerikil) → selesai → ADVANCE →
-- JUMRAH_AQABAH @ Mina → memanggil `teleport("Mina", …)`. Global: `h`, `Vector3`, `meta`.

meta("mechanism", "ManasikRunner → PebbleCollect")
meta("title", "Spine lanjut: PebbleCollect di Muzdalifah → serah-terima ke Mina")

local ManasikRunner = h.require("ManasikRunner")
local ManasikState = h.require("ManasikState")

local player = h.spawnPlayer("Nabil")

-- 7 kerikil (part kecil yang bisa disentuh).
local pebbles = {}
for i = 1, 7 do
	pebbles[i] = h.newZone({ name = "Kerikil" .. i, center = Vector3.new(i * 6, 0, 0), size = Vector3.new(2.5, 2.5, 2.5) })
end

-- State HajiTamattu di tahap MABIT_MUZDALIFAH (seolah baru teleport dari Arafah).
local state = ManasikState.new("HajiTamattu", "Miqat_BirAli")
while state:current() and state:current().id ~= "MABIT_MUZDALIFAH" do
	state:advance()
end
h.event("note", { text = "Tiba di Muzdalifah pada tahap " .. state:current().id })

local teleportedTo = nil
local runner = ManasikRunner.new({
	placeName = "Muzdalifah",
	player = player,
	state = state,
	buildContext = function(_stage, _st, pl)
		return { player = pl, place = "Muzdalifah", pebbles = pebbles, config = { target = 7 } }
	end,
	teleport = function(place, data)
		teleportedTo = place
		h.event("teleport", { to = place, index = data.index, ibadah = data.ibadahType })
	end,
})

runner:start()

-- Pemain memungut kerikil satu per satu (sentuh tiap part).
for i = 1, 7 do
	h.enter(pebbles[i], player)
	h.advance(1, 1) -- jeda + beri kesempatan runner memantau penyelesaian
end

h.advance(2, 1) -- biar runner sempat advance setelah kerikil ke-7
h.event("note", { text = "Tujuan setelah PebbleCollect = " .. tostring(teleportedTo) })
