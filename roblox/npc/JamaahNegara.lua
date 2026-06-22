--!strict
-- JamaahNegara.lua — jamaah berbagai negara di luar mataf: BERDOA (idle) di Arafah/wukuf, atau
-- BERJALAN di Mina. Sebagian bisa diajak bicara (info budaya). Melengkapi JamaahTawaf (orbit mataf).
-- Pemilik: Nabil (kerumunan; GAME_DESIGN §3.1). NpcFramework via ctx.framework.
--
-- ctx:
--   ctx.framework : NpcFramework (WAJIB)
--   ctx.mode      : "pray" | "walk"  (default "pray")
--   ctx.position  : Vector3?  (pray: titik diam; walk: titik awal/ waypoints[1])
--   ctx.waypoints : { Vector3 }?  (mode walk)
--   ctx.country   : string?   default "Internasional"
--   ctx.prayAnimId: string?   animasi berdoa (mode pray)
--   ctx.dialog    : Dialog.Tree?  bila diberi → NPC talkable (info budaya). nil = diam.
--   ctx.speed     : number?

local M = {}
M.id = "JamaahNegara"

local function defaultCultureDialog(country: string): any
	return {
		speaker = "Jamaah " .. country,
		start = "root",
		nodes = {
			root = { text = ("Saya datang dari %s. Pertama kali ke sini?"):format(country), choices = {
				{ text = "Cerita tentang negaramu?", to = "budaya" },
				{ text = "Salam, lanjut.", to = "close" },
			} },
			budaya = { text = "Di negara kami, jamaah berangkat berkelompok dengan seragam khas. Subhanallah, di sini kita semua satu.", choices = {
				{ text = "Masya Allah.", to = "close" },
			} },
		},
	}
end

local state: { [any]: any } = {}

function M.spawn(ctx: any): any
	local F = assert(ctx and ctx.framework, "[JamaahNegara] ctx.framework wajib.")
	local mode = ctx.mode or "pray"
	local country = ctx.country or "Internasional"
	local pos = ctx.position or (ctx.waypoints and ctx.waypoints[1]) or Vector3.new(0, 0, 0)
	local npc = F.newDummy({ name = "Jamaah_" .. country, position = pos, color = ctx.bodyColor })
	local s = { mode = mode }
	if mode == "walk" and ctx.waypoints and #ctx.waypoints > 0 then
		s.patrol = F.patrol(npc, ctx.waypoints, { speed = ctx.speed or 4, pause = 0.5 })
	elseif mode == "pray" and ctx.prayAnimId then
		F.playLoop(npc, ctx.prayAnimId) -- berdoa di tempat (Studio)
	end
	if ctx.dialog or ctx.talkable then
		F.makeTalkable(npc, ctx.dialog or defaultCultureDialog(country), { actionText = "Sapa Jamaah", objectText = "Jamaah " .. country })
	end
	state[npc] = s
	return npc
end

function M.update(npc: any, dt: number)
	local s = state[npc]
	if s and s.patrol then s.patrol.step(dt) end -- mode pray: diam (tak ada stepper)
end

return M
