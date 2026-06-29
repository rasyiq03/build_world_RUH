--!strict
-- ManasikBootstrap.server.lua — BOOTSTRAP server per-place (ServerScriptService.Server).
-- Menggerakkan spine: muat mekanisme → (rekonstruksi ManasikState dari TeleportData |
-- default dev) → ManasikRunner menjalankan tahap di place ini.
--
-- Seed oleh Nabil (lead). Titik integrasi dgn DEVI (§9):
--   • `teleport` di bawah = placeholder. Devi mengganti dgn Teleport.toPlace(place, data)
--     (sistem Teleport antar-place = milik Devi).
--   • Lobby mengisi TeleportData = ManasikState:serialize() saat memulai (wiring Lobby = Devi).
-- PLACE_NAME: default "Arafah" (place dev saat ini). Nanti tiap place punya project sendiri.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MechanismRegistry = require(Shared:WaitForChild("MechanismRegistry"))
local ManasikState = require(Shared:WaitForChild("ManasikState"))
local ManasikRunner = require(Shared:WaitForChild("ManasikRunner"))
local Teleport = require(Shared:WaitForChild("Teleport"))
local UiBridge = require(Shared:WaitForChild("UiBridge"))
local PlaceContext = require(script.Parent:WaitForChild("PlaceContext"))

-- PlaceName: ACUAN atribut Workspace.PlaceName (override aman) → fallback otomatis PlaceId. §SYSTEMS_DESIGN.
local PLACE_NAME: string = Teleport.resolvePlaceName("Arafah")
local DEV_IBADAH = "HajiTamattu"
local DEV_MIQAT = "Miqat_BirAli"

-- Lobby BUKAN place ritual (tak ada di Flows). Di sana spine tak dijalankan; pilihan pemain
-- ditangani LobbyServer (places/Lobby). Bootstrap no-op agar tak salah-aktifkan mekanisme.
if PLACE_NAME == "Lobby" then
	print("[Bootstrap] place 'Lobby' — spine ritual tidak dijalankan (lihat LobbyServer).")
	return
end

MechanismRegistry.load()

-- INTENT pemain (UiBridge): time-skip ritual-tunggu + aksi ritual (klik tombol UI → mekanisme aktif).
;(UiBridge.remote(UiBridge.EVENTS.RequestTimeSkip) :: RemoteEvent).OnServerEvent:Connect(function(_player)
	MechanismRegistry.timeSkipActive()
end)

-- Whitelist aksi ritual yang boleh dipicu dari UI (mekanisme tetap memvalidasi argumennya sendiri).
local ALLOWED_ACTIONS = {
	wearIhram = true, makeNiat = true, board = true,
	throw = true, chooseNafar = true, beginSacrifice = true, cukur = true,
}
;(UiBridge.remote(UiBridge.EVENTS.RitualAction) :: RemoteEvent).OnServerEvent:Connect(function(_player, action, ...)
	if type(action) == "string" and ALLOWED_ACTIONS[action] then
		MechanismRegistry.actionActive(action, ...)
	end
end)

-- Resolusi penyedia ctx per-place. Place miqat (Miqat_BirAli/…​) memakai PlaceContext.Miqat generik.
local function contextBuilderFor(placeName: string)
	if PlaceContext[placeName] then
		return PlaceContext[placeName]
	end
	if placeName:sub(1, 6) == "Miqat_" then
		return PlaceContext.Miqat
	end
	return nil
end

-- State default untuk uji dev (tanpa Lobby/teleport nyata): mulai dari tahap pertama yang
-- resolve-nya ke PLACE_NAME, supaya mekanisme place ini langsung aktif saat play solo di Studio.
local function devDefaultState()
	local s = ManasikState.new(DEV_IBADAH, DEV_MIQAT)
	for i = 1, #s.flow do
		s.index = i
		if s:resolvePlace(s.flow[i]) == PLACE_NAME then
			break
		end
	end
	return s
end

local runners: { [Player]: any } = {}

local function onPlayer(player: Player)
	if runners[player] then
		return -- sudah berjalan (mis. respawn) — jangan start ganda.
	end
	local data = player:GetJoinData() and player:GetJoinData().TeleportData
	local state
	if data and (data :: any).ibadahType then
		state = ManasikState.restore(data :: any)
	else
		state = devDefaultState()
		warn(("[Bootstrap] tanpa TeleportData → state dev: %s @ %s (index=%d)."):format(DEV_IBADAH, PLACE_NAME, state.index))
	end

	-- Teleport nyata (milik Devi): pindah place membawa SaveData. Bila PlaceId belum diisi
	-- (Teleport.PLACE_IDS = 0, mis. uji solo satu place), Teleport.toPlace hanya warn — alur dev tetap aman.
	local function teleport(placeName: string, data: any)
		Teleport.toPlace(player, placeName, data)
	end

	local runner = ManasikRunner.new({
		placeName = PLACE_NAME,
		player = player,
		state = state,
		buildContext = contextBuilderFor(PLACE_NAME),
		teleport = teleport,
	})
	runners[player] = runner
	runner:start()
end

Players.PlayerRemoving:Connect(function(player)
	local r = runners[player]
	if r then
		r:stop()
		runners[player] = nil
	end
end)

Players.PlayerAdded:Connect(function(player)
	if player.Character then
		onPlayer(player)
	end
	player.CharacterAdded:Connect(function()
		onPlayer(player)
	end)
end)

print(("[Bootstrap] siap untuk place '%s'. Menunggu pemain."):format(PLACE_NAME))
