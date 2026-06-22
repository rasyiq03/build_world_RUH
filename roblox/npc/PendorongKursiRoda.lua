--!strict
-- PendorongKursiRoda.lua — petugas mendorong KURSI RODA menyusuri jalur (jamaah lansia/difabel).
-- Pemilik: Devi (GAME_DESIGN §3.1). NpcFramework via ctx.framework. Ambient (non-interaktif).
--
-- ctx:
--   ctx.framework : NpcFramework (WAJIB)
--   ctx.waypoints : { Vector3 } jalur (WAJIB)
--   ctx.position  : Vector3?  default waypoints[1]
--   ctx.speed     : number?   default 4 (pelan, mendorong)

local M = {}
M.id = "PendorongKursiRoda"

local state: { [any]: any } = {}

local function makeWheelchair(npc: any, pos: any): any
	local chair: any = nil
	pcall(function()
		chair = Instance.new("Part")
		chair.Name = "KursiRoda"
		chair.Size = Vector3.new(2.5, 3, 3)
		chair.Anchored = true
		chair.CanCollide = false
		chair.Color = Color3.fromRGB(140, 140, 150)
		chair.Position = pos
		chair.Parent = npc
	end)
	return chair
end

function M.spawn(ctx: any): any
	local F = assert(ctx and ctx.framework, "[PendorongKursiRoda] ctx.framework wajib.")
	assert(ctx.waypoints and #ctx.waypoints > 0, "[PendorongKursiRoda] ctx.waypoints wajib.")
	local start = ctx.position or ctx.waypoints[1]
	local npc = F.newDummy({ name = "PendorongKursiRoda", position = start, color = Color3.fromRGB(110, 120, 130) })
	state[npc] = {
		patrol = F.patrol(npc, ctx.waypoints, { speed = ctx.speed or 4 }),
		chair = makeWheelchair(npc, start),
	}
	return npc
end

function M.update(npc: any, dt: number)
	local s = state[npc]
	if not s then return end
	s.patrol.step(dt)
	-- Kursi mengikuti DI DEPAN pendorong (mengikuti orientasi HRP). pcall: CFrame mul Studio-only.
	if s.chair then
		local hrp = npc:FindFirstChild("HumanoidRootPart")
		if hrp then
			pcall(function() s.chair.CFrame = hrp.CFrame * CFrame.new(0, -1, -3) end)
		end
	end
end

return M
