--!nocheck
-- Skenario SPINE — leg Mina hari-10 (Haji Tamattu') menyatukan mekanisme Nabil & Praditama:
--   JUMRAH_AQABAH (JumrahThrow, Praditama) → QURBAN (Qurban, Praditama, dam wajib) →
--   TAHALLUL_AWAL (Tahallul, Nabil) → ADVANCE ke TAWAF_IFADAH (Makkah) → teleport("Makkah").
-- Membuktikan tahap QURBAN baru di Flows ter-wiring & gating antar-mekanisme benar.
-- buildContext meniru server/PlaceContext.Mina. Global: `h`, `Vector3`, `meta`.

meta("mechanism", "Spine: JumrahThrow → Qurban → Tahallul")
meta("title", "Leg Mina hari-10 Tamattu' (Jumrah → Qurban dam → Tahallul awal → Makkah)")

local ManasikRunner = h.require("ManasikRunner")
local ManasikState = h.require("ManasikState")
local Tahallul = h.require("mechanisms/Tahallul")

local DAM_REQUIRED = { HajiTamattu = true, HajiQiran = true }

local player = h.spawnPlayer("Praditama")
local state = ManasikState.new("HajiTamattu", "Miqat_QarnulManazil")
while state:current() and state:current().id ~= "JUMRAH_AQABAH" do
	state:advance()
end
h.event("note", { text = "Mulai di tahap " .. state:current().id })

local teleportedTo = nil
local runner = ManasikRunner.new({
	placeName = "Mina",
	player = player,
	state = state,
	-- meniru PlaceContext.Mina (server/), yang tak ter-mount di harness.
	buildContext = function(stage, st, pl)
		if stage.ritual == "JumrahThrow" then
			local mode = (stage.id == "MABIT_MINA_2") and "three_pillars" or "aqabah_only"
			return { player = pl, place = "Mina", mode = mode, config = { throwsPerPillar = 7, hitChance = 1 } }
		elseif stage.ritual == "Qurban" then
			return { player = pl, place = "Mina", damRequired = DAM_REQUIRED[st.ibadahType] == true, config = { processSeconds = 2 } }
		elseif stage.ritual == "Tahallul" then
			return { player = pl, place = "Mina", mode = Tahallul.modeForStage(stage.id) } -- tanpa station → cukur langsung
		end
		return { player = pl, place = "Mina" }
	end,
	teleport = function(place, data)
		teleportedTo = place
		h.event("teleport", { to = place, index = data.index, ibadah = data.ibadahType })
	end,
})

runner:start()

-- 1) JUMRAH_AQABAH: lempar Aqabah 7x.
for _ = 1, 7 do h.mech("JumrahThrow").throw("Aqabah") end
h.heartbeat(0.1) -- runner pantau isDone → advance ke QURBAN
h.event("note", { text = "Setelah jumrah, tahap = " .. state:current().id .. " (harus QURBAN)" })

-- 2) QURBAN: sembelih hadyu (dam wajib Tamattu').
h.mech("Qurban").beginSacrifice("kambing")
h.advance(3, 1) -- proses selesai → advance ke TAHALLUL_AWAL → (tanpa station) cukur langsung → advance
h.event("note", { text = "Setelah qurban+tahallul, tahap = " .. tostring(state:current() and state:current().id) })
h.event("note", { text = "TahallulState pemain = " .. tostring(player:GetAttribute("TahallulState")) .. " (harus AWAL)" })
h.event("note", { text = "teleportedTo = " .. tostring(teleportedTo) .. " (harus Makkah, tahap TAWAF_IFADAH)" })
