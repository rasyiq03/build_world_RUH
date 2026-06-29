--!strict
-- NpcRoster.lua — KONFIGURASI NPC per-place (data, bukan logika). Place → daftar spek NPC.
-- Spawner (server/NpcSpawner) menurunkan waypoints/pos/center dari DUNIA hasil build, roster ini
-- hanya menyatakan "NPC apa, berapa, mode apa" per zona (GAME_DESIGN §3.1). KONTRAK BERSAMA.
--
-- Spek: { id, count?=1, kind = "patrol"|"post"|"orbit"|"pray"|"walk", talkable?, country? }
--   patrol = patroli ring di sekitar center · post = diam dekat center · orbit = mengelilingi center
--   (JamaahTawaf) · pray/walk = JamaahNegara mode.

local NpcRoster = {}

NpcRoster.byPlace = {
	Lobby = {
		{ id = "PetugasOB", kind = "patrol" },
		{ id = "Askar", kind = "patrol", talkable = true },
	},
	Makkah = {
		{ id = "Askar", kind = "patrol", talkable = true },
		{ id = "PetugasOB", kind = "patrol" },
		{ id = "PendorongKursiRoda", kind = "patrol" },
		{ id = "JamaahTawaf", count = 12, kind = "orbit" }, -- kerumunan mataf
	},
	Arafah = {
		{ id = "PetugasMedis", kind = "post", talkable = true },
		{ id = "TNI", kind = "post", talkable = true },
		{ id = "JamaahNegara", count = 8, kind = "pray" },
	},
	Muzdalifah = {
		{ id = "PetugasMedis", kind = "post", talkable = true },
		{ id = "JamaahNegara", count = 8, kind = "pray" },
	},
	Mina = {
		{ id = "Askar", kind = "patrol", talkable = true },
		{ id = "PetugasMedis", kind = "post", talkable = true },
		{ id = "JamaahNegara", count = 8, kind = "walk" },
	},
}

-- Daftar NPC untuk sebuah place. Place miqat (Miqat_*) → Askar penjaga gerbang.
function NpcRoster.forPlace(placeName: string): { any }
	if NpcRoster.byPlace[placeName] then
		return NpcRoster.byPlace[placeName]
	end
	if placeName:sub(1, 6) == "Miqat_" then
		return { { id = "Askar", kind = "patrol", talkable = true } }
	end
	return {}
end

return NpcRoster
