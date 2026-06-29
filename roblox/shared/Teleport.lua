--!strict
-- Teleport.lua — perpindahan antar-place (lihat docs/GAME_DESIGN.md §2,§9).
-- Tiap place = Roblox place terpisah dalam 1 Experience. ManasikState memutuskan
-- KAPAN & KE MANA; modul ini mengeksekusi via TeleportService.
-- Pemilik: Devi (keputusan §9).

local TeleportService = game:GetService("TeleportService")

local Teleport = {}

-- PlaceId hasil publish (diisi 2026-06-23). Mengaktifkan teleport antar-place + resolvePlaceName otomatis.
Teleport.PLACE_IDS = {
	Lobby = 79374115830204,
	Miqat_BirAli = 113143272151436,
	Miqat_Juhfah = 74551325991958,
	Miqat_DzatuIrq = 91587948581858,
	Miqat_QarnulManazil = 94936719891572,
	Miqat_Yalamlam = 131791680798575,
	Makkah = 97208840151896,
	Mina = 113068017410086,
	Muzdalifah = 135368186858728,
	Arafah = 74819541386960,
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

-- Reverse-lookup: PlaceId → nama place (SYSTEMS_DESIGN §6). Menghapus kebutuhan set atribut
-- Workspace.PlaceName manual: sekali PLACE_IDS terisi (wajib utk teleport), nama place otomatis.
function Teleport.placeNameFor(placeId: number): string?
	for name, id in pairs(Teleport.PLACE_IDS) do
		if id ~= 0 and id == placeId then
			return name
		end
	end
	return nil
end

-- Nama place efektif. PRIORITAS atribut Workspace.PlaceName sebagai ACUAN/override (aman bila PlaceId
-- salah/rusak/duplikat) → bila atribut kosong, otomatis dari PlaceId → default. Auto secara default,
-- tapi PlaceName SELALU bisa menimpa (set manual di place untuk jaga-jaga).
function Teleport.resolvePlaceName(default: string?): string
	local attr = workspace:GetAttribute("PlaceName") :: string?
	if attr and attr ~= "" then
		return attr
	end
	return Teleport.placeNameFor(game.PlaceId) or default or "Arafah"
end

return Teleport
