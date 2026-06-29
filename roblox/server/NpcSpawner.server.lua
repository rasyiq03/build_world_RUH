--!strict
-- NpcSpawner.server.lua — BOOTSTRAP NPC per-place. Baca PlaceName → roster (NpcRoster) → spawn
-- (logika di shared/NpcSpawner) → loop update via Heartbeat. Modul NPC dimuat otomatis dari
-- ReplicatedStorage.Npc (pola MechanismRegistry). Center diturunkan dari dunia hasil build.
--
-- Berjalan di tiap place berdampingan dgn ManasikBootstrap (spine ritual) — independen.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NpcFramework = require(Shared:WaitForChild("NpcFramework"))
local NpcRoster = require(Shared:WaitForChild("NpcRoster"))
local NpcSpawner = require(Shared:WaitForChild("NpcSpawner"))
local Teleport = require(Shared:WaitForChild("Teleport"))
local WorldProviders = require(script.Parent:WaitForChild("WorldProviders"))

local PLACE_NAME: string = Teleport.resolvePlaceName("Arafah") -- atribut PlaceName (acuan) → fallback PlaceId

-- Muat semua modul behavior NPC dari ReplicatedStorage.Npc (id → modul).
local modules: { [string]: any } = {}
local npcFolder = ReplicatedStorage:WaitForChild("Npc")
for _, m in ipairs(npcFolder:GetChildren()) do
	if m:IsA("ModuleScript") then
		local ok, mod = pcall(require, m)
		if ok and type(mod) == "table" and mod.id then
			modules[mod.id] = mod
		else
			warn("[NpcSpawner] gagal memuat NPC: " .. m.Name)
		end
	end
end

-- Center per-place dari dunia hasil build (fallback origin). Makkah = Ka'bah (pusat mataf untuk orbit).
local center = Vector3.new(0, 0, 0)
pcall(function()
	if PLACE_NAME == "Makkah" then
		center = WorldProviders.makkahMarks().Kabah.Position
	elseif PLACE_NAME == "Muzdalifah" then
		local area = workspace:FindFirstChild("D_Muzdalifah")
		area = area and area:FindFirstChild("AreaKerikil")
		if area then center = area.Position end
	end
end)

local parent = Instance.new("Folder")
parent.Name = "NPCs"
parent.Parent = workspace

local roster = NpcRoster.forPlace(PLACE_NAME)
local active = NpcSpawner.spawnRoster(roster, {
	framework = NpcFramework,
	modules = modules,
	center = center,
	parent = parent,
	getPlayers = function() return Players:GetPlayers() end,
})

RunService.Heartbeat:Connect(function(dt)
	NpcSpawner.updateAll(active, dt)
end)

print(("[NpcSpawner] place '%s': %d NPC di-spawn (center %.0f,%.0f)."):format(PLACE_NAME, #active, center.X, center.Z))
