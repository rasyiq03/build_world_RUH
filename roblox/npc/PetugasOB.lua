--!strict
-- PetugasOB.lua — petugas kebersihan: PATROLI rute + animasi MENYAPU (loop). Ambient, non-interaktif
-- (menambah realisme). Pemilik: Devi (GAME_DESIGN §3.1). Kontrak NPC; NpcFramework via ctx.framework.
--
-- ctx:
--   ctx.framework  : NpcFramework (WAJIB)
--   ctx.waypoints  : { Vector3 } rute (WAJIB)
--   ctx.position   : Vector3?  default waypoints[1]
--   ctx.name       : string?   default "Petugas OB"
--   ctx.speed      : number?   default 5 (santai)
--   ctx.sweepAnimId: string?   animasi menyapu (default = animasi jalan default Roblox bila kosong)

local M = {}
M.id = "PetugasOB"

local state: { [any]: any } = {}

function M.spawn(ctx: any): any
	local F = assert(ctx and ctx.framework, "[PetugasOB] ctx.framework wajib.")
	assert(ctx.waypoints and #ctx.waypoints > 0, "[PetugasOB] ctx.waypoints wajib.")
	local npc = F.newDummy({
		name = ctx.name or "Petugas OB",
		position = ctx.position or ctx.waypoints[1],
		color = Color3.fromRGB(70, 130, 90),
	})
	-- Animasi menyapu looping (Studio; no-op headless). Default Roblox dipakai bila id tak diberi.
	if ctx.sweepAnimId then
		F.playLoop(npc, ctx.sweepAnimId)
	end
	state[npc] = { patrol = F.patrol(npc, ctx.waypoints, { speed = ctx.speed or 5, pause = 1.5 }) }
	return npc
end

function M.update(npc: any, dt: number)
	local s = state[npc]
	if s then s.patrol.step(dt) end
end

return M
