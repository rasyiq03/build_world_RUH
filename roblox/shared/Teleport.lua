--!strict
-- Teleport.lua — perpindahan antar-place (lihat docs/GAME_DESIGN.md §2,§9).
-- Tiap place = Roblox place terpisah dalam 1 Experience. ManasikState memutuskan
-- KAPAN & KE MANA; modul ini mengeksekusi via TeleportService.
-- Pemilik: Devi (keputusan §9).

local TeleportService = game:GetService("TeleportService")

local Teleport = {}

-- TODO: isi dengan PlaceId hasil publish tiap place.
Teleport.PLACE_IDS = {
	Lobby = 0,
	Miqat_BirAli = 0, Miqat_Juhfah = 0, Miqat_DzatuIrq = 0,
	Miqat_QarnulManazil = 0, Miqat_Yalamlam = 0,
	Makkah = 0, Mina = 0, Muzdalifah = 0, Arafah = 0,
} :: { [string]: number }

-- Pindahkan pemain ke `placeName`. `data` dibawa lintas-place (mis. ibadahType,
-- chosenMiqat, index manasik) supaya ManasikState bisa dilanjutkan di place tujuan.
function Teleport.toPlace(player: Player, placeName: string, data: { [string]: any }?)
	local id = Teleport.PLACE_IDS[placeName]
	if not id or id == 0 then
		warn("[Teleport] PlaceId belum diisi untuk: " .. tostring(placeName))
		return
	end
	local opts = Instance.new("TeleportOptions")
	if data then opts:SetTeleportData(data) end
	TeleportService:TeleportAsync(id, { player }, opts)
end

return Teleport
