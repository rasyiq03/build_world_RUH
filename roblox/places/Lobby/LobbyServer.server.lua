--!strict
-- LobbyServer.server.lua — ENTRY SPINE di place Lobby (GAME_DESIGN §2.1). Pemilik: Devi (§9).
-- Terima pilihan pemain via RemoteEvent → bangun TeleportData (shared/LobbyStart) → Teleport ke
-- miqat terpilih. Place tujuan (miqat) menjalankan ManasikBootstrap yang membaca TeleportData.
--
-- Letakkan di ServerScriptService place Lobby (mapping Rojo). UI/pemilih = LobbyClient (client).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LobbyStart = require(Shared:WaitForChild("LobbyStart"))
local Teleport = require(Shared:WaitForChild("Teleport"))
local UiBridge = require(Shared:WaitForChild("UiBridge"))

-- Kontrak RemoteEvent Lobby→server (client fire: ibadahType, chosenMiqat). Nama via UiBridge.
local remote = UiBridge.remote(UiBridge.EVENTS.StartManasik)

;(remote :: RemoteEvent).OnServerEvent:Connect(function(player: Player, ibadahType: any, chosenMiqat: any)
	local data, err = LobbyStart.buildData(ibadahType, chosenMiqat)
	if not data then
		warn(("[Lobby] pilihan %s ditolak: %s"):format(player.Name, tostring(err)))
		return
	end
	print(("[Lobby] %s memulai %s via %s → teleport."):format(player.Name, ibadahType, chosenMiqat))
	Teleport.toPlace(player, chosenMiqat, data)
end)

print("[Lobby] siap. Menunggu pilihan ibadah + miqat dari pemain.")
