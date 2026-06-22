--!strict
-- LobbyStart.lua — LOGIKA entry Lobby (GAME_DESIGN §2.1, §9). Pemilik: Devi (UI di client, LOGIKA
-- di shared). Mengubah pilihan pemain (jenis ibadah + miqat) menjadi TeleportData (= ManasikState
-- :serialize) yang dibawa ke place miqat; bootstrap di sana merekonstruksi state & menjalankan flow.
--
-- Dipisah dari skrip server agar bisa diuji headless (lihat scenarios/lobby_start.luau).
-- KONTRAK BERSAMA — ubah signature dgn koordinasi tim.

local Flows = require(script.Parent.Flows)
local ManasikState = require(script.Parent.ManasikState)

local LobbyStart = {}

-- Kelima miqat yang bisa dipilih (token "Miqat" di Flows di-resolve ke salah satu ini). Nama harus
-- sama persis dgn Teleport.PLACE_IDS & nama place Studio (GAME_DESIGN §8.4).
LobbyStart.MIQATS = { "Miqat_BirAli", "Miqat_Juhfah", "Miqat_DzatuIrq", "Miqat_QarnulManazil", "Miqat_Yalamlam" }

local MIQAT_SET: { [string]: boolean } = {}
for _, m in ipairs(LobbyStart.MIQATS) do
	MIQAT_SET[m] = true
end

-- Validasi pilihan. Mengembalikan (true) atau (false, pesan).
function LobbyStart.validate(ibadahType: string, chosenMiqat: string): (boolean, string?)
	if type(ibadahType) ~= "string" or not Flows[ibadahType] then
		return false, "Jenis ibadah tak dikenal: " .. tostring(ibadahType)
	end
	if type(chosenMiqat) ~= "string" or not MIQAT_SET[chosenMiqat] then
		return false, "Miqat tak dikenal: " .. tostring(chosenMiqat)
	end
	return true
end

-- Bangun TeleportData dari pilihan pemain. Mengembalikan (SaveData) atau (nil, pesan).
function LobbyStart.buildData(ibadahType: string, chosenMiqat: string): (ManasikState.SaveData?, string?)
	local ok, err = LobbyStart.validate(ibadahType, chosenMiqat)
	if not ok then
		return nil, err
	end
	local state = ManasikState.new(ibadahType, chosenMiqat)
	return state:serialize()
end

return LobbyStart
