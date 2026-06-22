--!strict
-- TNI.lua — petugas TNI (Indonesia): BERDIRI/PATROLI sebagai penjaga ketertiban; HADAP pemain saat
-- didekati; SAPA = info logistik & keamanan ibadah. Pemilik: Nabil (GAME_DESIGN §3.1).
-- NpcFramework via ctx.framework.
--
-- ctx:
--   ctx.framework : NpcFramework (WAJIB)
--   ctx.post      : Vector3?   pos diam (bila tanpa waypoints)
--   ctx.waypoints : { Vector3 }?  rute patroli (opsional)
--   ctx.radius    : number?   (default 16)
--   ctx.dialog    : Dialog.Tree?
--   ctx.getPlayers: (() -> {Player})?

local M = {}
M.id = "TNI"

local DEFAULT_DIALOG = {
	speaker = "Petugas TNI",
	start = "root",
	nodes = {
		root = { text = "Tetap di rombongan, ikuti arahan ketua kloter. Ada yang ditanyakan?", choices = {
			{ text = "Titik kumpul rombongan?", to = "kumpul" },
			{ text = "Lapor kehilangan?", to = "lapor" },
			{ text = "Siap, terima kasih.", to = "close" },
		} },
		kumpul = { text = "Titik kumpul ada di gerbang berbendera Indonesia. Jangan berpencar saat ramai.", choices = { { text = "Baik.", to = "root" } } },
		lapor = { text = "Lapor ke pos terdekat atau petugas berseragam. Bawa identitas kloter Anda.", choices = { { text = "Mengerti.", to = "root" } } },
	},
}

local state: { [any]: any } = {}

local function playerPos(pl: any): any
	local ch = pl and pl.Character
	local h = ch and ch:FindFirstChild("HumanoidRootPart")
	return h and h.Position or nil
end

function M.spawn(ctx: any): any
	local F = assert(ctx and ctx.framework, "[TNI] ctx.framework wajib.")
	local start = ctx.post or (ctx.waypoints and ctx.waypoints[1]) or Vector3.new(0, 0, 0)
	local npc = F.newDummy({ name = "Petugas TNI", position = start, color = Color3.fromRGB(90, 110, 70) })
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
	F.makeTalkable(npc, ctx.dialog or DEFAULT_DIALOG, { actionText = "Tanya TNI", objectText = "Petugas TNI" })
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
