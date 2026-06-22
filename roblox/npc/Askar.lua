--!strict
-- Askar.lua — NPC keamanan: PATROLI; BERHENTI & HADAP pemain saat didekati; SAPA = dialog
-- info/panduan area. Pemilik: Devi/Nabil (GAME_DESIGN §3.1).
-- Kontrak: M.id, M.spawn(ctx)->Model, M.update(npc, dt). NpcFramework di-inject via ctx.framework
-- (DI — hindari require lintas-folder npc→shared yang rapuh; spawner place yang menyuntik).
--
-- ctx:
--   ctx.framework : NpcFramework (WAJIB)
--   ctx.waypoints : { Vector3 } rute patroli (WAJIB, >=1)
--   ctx.position  : Vector3?  posisi awal (default waypoints[1])
--   ctx.name      : string?   default "Askar"
--   ctx.radius    : number?   radius sapa/berhenti (default 16)
--   ctx.speed     : number?   laju patroli (default 7)
--   ctx.dialog    : Dialog.Tree?  override dialog
--   ctx.getPlayers: (() -> {Player})?  (uji headless)

local M = {}
M.id = "Askar"

local DEFAULT_DIALOG = {
	speaker = "Askar",
	start = "root",
	nodes = {
		root = { text = "Assalamu'alaikum. Ada yang bisa saya bantu?", choices = {
			{ text = "Arah area ibadah?", to = "arah" },
			{ text = "Aturan di sini?", to = "aturan" },
			{ text = "Terima kasih.", to = "close" },
		} },
		arah = { text = "Ikuti jalur berpapan hijau menuju area utama. Tetap di jalur, ya.", choices = {
			{ text = "Baik.", to = "root" },
		} },
		aturan = { text = "Jaga ketertiban, ikuti panduan ihram, dan dahulukan jamaah lansia.", choices = {
			{ text = "Mengerti.", to = "root" },
		} },
	},
}

local state: { [any]: any } = {}

local function playerPos(pl: any): any
	local ch = pl and pl.Character
	local h = ch and ch:FindFirstChild("HumanoidRootPart")
	return h and h.Position or nil
end

function M.spawn(ctx: any): any
	local F = assert(ctx and ctx.framework, "[Askar] ctx.framework (NpcFramework) wajib.")
	assert(ctx.waypoints and #ctx.waypoints > 0, "[Askar] ctx.waypoints wajib.")
	local npc = F.newDummy({
		name = ctx.name or "Askar",
		position = ctx.position or ctx.waypoints[1],
		color = Color3.fromRGB(60, 80, 120),
	})
	local s = { F = F, near = nil }
	s.patrol = F.patrol(npc, ctx.waypoints, { speed = ctx.speed or 7 })
	s.prox = F.watchProximity(npc, {
		radius = ctx.radius or 16,
		getPlayers = ctx.getPlayers,
		onEnter = function(pl) s.near = pl end,
		onLeave = function() s.near = nil end,
	})
	F.makeTalkable(npc, ctx.dialog or DEFAULT_DIALOG, { actionText = "Tanya Askar", objectText = "Askar" })
	state[npc] = s
	return npc
end

function M.update(npc: any, dt: number)
	local s = state[npc]
	if not s then return end
	s.prox.step(dt)
	if s.near then
		local pp = playerPos(s.near) -- berhenti patroli & hadap pemain
		if pp then s.F.faceTarget(npc, pp) end
	else
		s.patrol.step(dt)
	end
end

function M.isNearPlayer(npc: any): boolean
	return state[npc] ~= nil and state[npc].near ~= nil
end

return M
