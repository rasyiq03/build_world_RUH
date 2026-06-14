--!strict
-- NpcFramework.lua — dasar spawn & gerak NPC. Behavior spesifik (Askar, jamaah,
-- medis, TNI, jamaah-jalur-tawaf) ditulis per tipe di roblox/npc/ (lihat GAME_DESIGN §3).
--
-- Kontrak modul behavior (di roblox/npc/<Nama>.lua):
--   M.id : string
--   M.spawn(ctx) -> Model           -- buat 1 NPC
--   M.update(npc, dt)               -- (opsional) tiap frame/heartbeat
-- NpcFramework menyediakan util gerak; behavior memutuskan KE MANA.

local PathfindingService = game:GetService("PathfindingService")

local NpcFramework = {}

-- Gerakkan humanoid mengikuti jalur ke `dest` (raycast/pathfinding sederhana).
function NpcFramework.walkTo(npc: Model, dest: Vector3)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then return end
	local path = PathfindingService:CreatePath()
	local ok = pcall(function() path:ComputeAsync(root.Position, dest) end)
	if ok and path.Status == Enum.PathStatus.Success then
		for _, wp in ipairs(path:GetWaypoints()) do
			humanoid:MoveTo(wp.Position)
			humanoid.MoveToFinished:Wait()
		end
	else
		humanoid:MoveTo(dest) -- fallback lurus
	end
end

return NpcFramework
