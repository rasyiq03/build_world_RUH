--!strict
-- NpcSpawner.lua — LOGIKA spawn NPC dari roster + jalankan update. Deps DI-INJECT (framework, modul
-- NPC, center, parent) → bisa diuji headless. Wrapper tipis server/NpcSpawner.server.lua menyuntik
-- service & modul nyata. Menurunkan waypoints/pos dari `center` (dunia hasil build), bukan hardcode.

local NpcSpawner = {}

local GOLDEN = 2.399963229728653 -- sudut emas (sebaran alami deterministik)

-- Ring waypoints deterministik di sekitar center (untuk patroli & walk).
function NpcSpawner.ring(center: any, radius: number, n: number): { any }
	local pts = {}
	for i = 1, n do
		local a = (i / n) * math.pi * 2
		pts[i] = Vector3.new(center.X + math.cos(a) * radius, center.Y, center.Z + math.sin(a) * radius)
	end
	return pts
end

-- Titik tersebar deterministik (untuk pos diam / berdoa) agar NPC tak menumpuk.
local function scatter(center: any, i: number, spread: number): any
	local r = spread * (0.25 + ((i * 7) % 10) / 13)
	local a = i * GOLDEN
	return Vector3.new(center.X + math.cos(a) * r, center.Y, center.Z + math.sin(a) * r)
end

-- Bangun ctx untuk satu NPC ke-i dari spek (produsen ctx NPC, analog PlaceContext utk mekanisme).
function NpcSpawner._ctxFor(spec: any, i: number, deps: any): any
	local center = deps.center or Vector3.new(0, 0, 0)
	local ctx: any = { framework = deps.framework, getPlayers = deps.getPlayers }
	local kind = spec.kind
	if kind == "orbit" then
		ctx.center = center
		ctx.radius = 18 + ((i - 1) % 6) * 6 -- lajur berbeda
		ctx.speed = 5 + ((i - 1) % 3)
		ctx.country = spec.country
	elseif kind == "post" then
		ctx.post = scatter(center, i, deps.postSpread or 40)
		ctx.talkable = spec.talkable
	elseif kind == "pray" then
		ctx.mode = "pray"
		ctx.position = scatter(center, i, deps.fieldSpread or 120)
		ctx.country = spec.country
		ctx.talkable = spec.talkable
	elseif kind == "walk" then
		ctx.mode = "walk"
		ctx.waypoints = NpcSpawner.ring(center, deps.patrolRadius or 90, 5)
		ctx.country = spec.country
		ctx.talkable = spec.talkable
	else -- "patrol" (default)
		ctx.waypoints = NpcSpawner.ring(center, deps.patrolRadius or 90, 4)
		ctx.position = scatter(center, i, deps.patrolRadius or 90)
		ctx.talkable = spec.talkable
	end
	return ctx
end

-- Spawn seluruh roster. deps: { framework, modules={id=module}, center, parent?, getPlayers?,
-- patrolRadius?, postSpread?, fieldSpread? }. Kembalikan daftar aktif { {module, npc} }.
function NpcSpawner.spawnRoster(roster: { any }, deps: any): { any }
	local active = {}
	for _, spec in ipairs(roster) do
		local mod = deps.modules and deps.modules[spec.id]
		if not mod then
			warn("[NpcSpawner] modul NPC tak ada: " .. tostring(spec.id))
		else
			for i = 1, (spec.count or 1) do
				local ctx = NpcSpawner._ctxFor(spec, i, deps)
				local ok, npc = pcall(function()
					return mod.spawn(ctx)
				end)
				if ok and npc then
					if deps.parent then
						pcall(function() npc.Parent = deps.parent end)
					end
					active[#active + 1] = { module = mod, npc = npc }
				else
					warn(("[NpcSpawner] gagal spawn %s: %s"):format(spec.id, tostring(npc)))
				end
			end
		end
	end
	return active
end

-- Jalankan update semua NPC aktif (panggil tiap Heartbeat).
function NpcSpawner.updateAll(active: { any }, dt: number)
	for _, e in ipairs(active) do
		if e.module.update then
			e.module.update(e.npc, dt)
		end
	end
end

return NpcSpawner
