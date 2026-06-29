--!strict
-- WardrobeStations.server.lua — pasang STASIUN ganti baju per place (SYSTEMS_DESIGN). Miqat→ihram,
-- Lobby/Makkah→normal (pasca-tahallul, di-gate Wardrobe.canWear). Memakai part Workspace.GantiBaju
-- bila ada (dari build), else placeholder. Berjalan berdampingan dgn bootstrap/NpcSpawner.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Wardrobe = require(Shared:WaitForChild("Wardrobe"))
local Teleport = require(Shared:WaitForChild("Teleport"))

local place = Teleport.resolvePlaceName("Arafah")

-- Outfit target stasiun per place.
local target: string? = nil
if place:sub(1, 6) == "Miqat_" then
	target = "ihram"
elseif place == "Lobby" or place == "Makkah" then
	target = "normal"
end

if target then
	local part = workspace:FindFirstChild("GantiBaju")
	if not (part and part:IsA("BasePart")) then
		local p = Instance.new("Part")
		p.Name = "GantiBaju"
		p.Anchored = true
		p.CanCollide = true
		p.Size = Vector3.new(6, 8, 6)
		p.Material = Enum.Material.WoodPlanks
		p.Color = Color3.fromRGB(150, 120, 90)
		-- Placeholder di dekat origin; ganti dgn part bernama "GantiBaju" di build place untuk posisi tepat.
		local x, z = -40, 20
		local y = 4
		pcall(function()
			local rp = RaycastParams.new()
			rp.FilterType = Enum.RaycastFilterType.Include
			rp.FilterDescendantsInstances = { workspace.Terrain }
			local r = workspace:Raycast(Vector3.new(x, 9000, z), Vector3.new(0, -18000, 0), rp)
			if r then y = r.Position.Y + 4 end
		end)
		p.Position = Vector3.new(x, y, z)
		p.Parent = workspace
		part = p
	end
	Wardrobe.attachStation(part, target)
	print(("[WardrobeStations] '%s': stasiun ganti baju → %s."):format(place, target))
end
