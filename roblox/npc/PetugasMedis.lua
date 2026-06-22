--!strict
-- PetugasMedis.lua — tenaga medis: BERDIRI di pos medis ATAU patroli Arafah/Mina; HADAP pemain
-- saat didekati; SAPA = info kesehatan. Pemilik: Nabil (GAME_DESIGN §3.1). NpcFramework via ctx.framework.
--
-- ctx:
--   ctx.framework : NpcFramework (WAJIB)
--   ctx.post      : Vector3?   pos diam (bila tanpa waypoints)
--   ctx.waypoints : { Vector3 }?  rute patroli (opsional; bila ada → patroli)
--   ctx.radius    : number?   radius hadap/sapa (default 16)
--   ctx.dialog    : Dialog.Tree?  override
--   ctx.getPlayers: (() -> {Player})?

local M = {}
M.id = "PetugasMedis"

local DEFAULT_DIALOG = {
	speaker = "Petugas Medis",
	start = "root",
	nodes = {
		root = { text = "Jaga kesehatan, ya. Cukup minum & istirahat. Ada keluhan?", choices = {
			{ text = "Tips cuaca panas?", to = "panas" },
			{ text = "Lokasi pos medis?", to = "pos" },
			{ text = "Sehat, terima kasih.", to = "close" },
		} },
		panas = { text = "Pakai payung, minum oralit, hindari panas tengah hari. Jangan tahan haus.", choices = { { text = "Baik.", to = "root" } } },
		pos = { text = "Pos medis ada di tiap area bertanda palang merah. Datang bila pusing/lemas.", choices = { { text = "Mengerti.", to = "root" } } },
	},
}

local state: { [any]: any } = {}

local function playerPos(pl: any): any
	local ch = pl and pl.Character
	local h = ch and ch:FindFirstChild("HumanoidRootPart")
	return h and h.Position or nil
end

function M.spawn(ctx: any): any
	local F = assert(ctx and ctx.framework, "[PetugasMedis] ctx.framework wajib.")
	local start = ctx.post or (ctx.waypoints and ctx.waypoints[1]) or Vector3.new(0, 0, 0)
	local npc = F.newDummy({ name = "Petugas Medis", position = start, color = Color3.fromRGB(210, 80, 80) })
	local s = { F = F, near = nil }
	if ctx.waypoints and #ctx.waypoints > 0 then
		s.patrol = F.patrol(npc, ctx.waypoints, { speed = ctx.speed or 6 })
	end
	s.prox = F.watchProximity(npc, {
		radius = ctx.radius or 16,
		getPlayers = ctx.getPlayers,
		onEnter = function(pl) s.near = pl end,
		onLeave = function() s.near = nil end,
	})
	F.makeTalkable(npc, ctx.dialog or DEFAULT_DIALOG, { actionText = "Tanya Medis", objectText = "Petugas Medis" })
	state[npc] = s
	return npc
end

function M.update(npc: any, dt: number)
	local s = state[npc]
	if not s then return end
	s.prox.step(dt)
	if s.near then
		local pp = playerPos(s.near)
		if pp then s.F.faceTarget(npc, pp) end
	elseif s.patrol then
		s.patrol.step(dt)
	end
end

return M
