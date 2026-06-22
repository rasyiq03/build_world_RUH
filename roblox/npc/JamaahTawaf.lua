--!strict
-- JamaahTawaf.lua — NPC jamaah berbagai negara yang mengelilingi Ka'bah (Tawaf) di mataf Makkah.
-- Pemilik: Praditama (NPC lintas-area; spawn & path dikoordinasikan dgn Devi, pemilik Makkah).
-- Kontrak NPC (lihat shared/NpcFramework): M.id, M.spawn(ctx) -> Model, M.update(npc, dt).
--
-- Berbeda dari NPC walkTo (pathfinding ke satu titik), JamaahTawaf BERGERAK MELINGKAR terus-
-- menerus. Geraknya KINEMATIK (HumanoidRootPart di-Anchor lalu di-CFrame tiap update) — murah
-- untuk kerumunan besar (ribuan), tak bergantung physics/pathfinding. Itu sebabnya modul ini
-- TIDAK me-require NpcFramework: orbit ditangani sendiri.
--
-- Arah Tawaf: BERLAWANAN arah jarum jam dilihat dari atas (Ka'bah di kiri jamaah). Default
-- direction = -1; balik tanda di ctx bila orientasi sumbu place membuatnya searah jarum jam.
--
-- ctx (disusun skrip place Makkah / spawner — koordinasi dgn Devi soal center & jumlah):
--   ctx.center    : Vector3   pusat Ka'bah (titik orbit). WAJIB.
--   ctx.radius    : number?   jari-jari lintasan (default 30). Beri tiap NPC radius beda = "lajur".
--   ctx.speed     : number?   laju tangensial studs/detik (default 6).
--   ctx.startAngle: number?   sudut awal radian (default acak deterministik via index).
--   ctx.direction : number?   +1 / -1 (default -1, berlawanan jarum jam).
--   ctx.country   : string?   asal negara (variasi nama/warna). default "Internasional".
--   ctx.bodyColor : Color3?   warna placeholder badan.

local M = {}
M.id = "JamaahTawaf"

local TWO_PI = math.pi * 2
local DEFAULT_RADIUS = 30
local DEFAULT_SPEED = 6

-- Motion state per-NPC (kunci = Model). Disimpan di modul agar update tak perlu cari child.
local motion: { [any]: any } = {}
local spawnCount = 0

function M.spawn(ctx: any): any
	assert(ctx and ctx.center, "[JamaahTawaf] ctx.center (posisi Ka'bah) wajib.")
	spawnCount += 1
	local idx = spawnCount
	local radius = ctx.radius or DEFAULT_RADIUS
	local speed = ctx.speed or DEFAULT_SPEED
	local direction = ctx.direction or -1
	local country = ctx.country or "Internasional"
	-- Sudut awal deterministik bila tak diberi: sebar merata berdasar indeks spawn.
	local angle = ctx.startAngle or ((idx * 0.61803398875) % 1) * TWO_PI

	local npc = Instance.new("Model")
	npc.Name = ("Jamaah_%s_%d"):format(country, idx)

	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 5, 1)
	hrp.Anchored = true
	hrp.CanCollide = false
	if ctx.bodyColor then
		hrp.Color = ctx.bodyColor
	end
	hrp.Parent = npc

	-- Humanoid opsional (animasi/rig nanti di Studio); dijaga pcall — gerak tak bergantung padanya.
	pcall(function()
		local hum = Instance.new("Humanoid")
		hum.Parent = npc
	end)

	npc.PrimaryPart = hrp

	local cx, cy, cz = ctx.center.X, ctx.center.Y, ctx.center.Z
	hrp.Position = Vector3.new(cx + math.cos(angle) * radius, cy, cz + math.sin(angle) * radius)

	motion[npc] = {
		hrp = hrp,
		center = ctx.center,
		radius = radius,
		angularSpeed = speed / radius, -- rad/detik
		angle = angle,
		direction = direction,
		totalAngle = 0,
		country = country,
	}
	return npc
end

function M.update(npc: any, dt: number)
	local m = motion[npc]
	if not m then
		return
	end
	local step = m.angularSpeed * dt
	m.angle = (m.angle + m.direction * step) % TWO_PI
	m.totalAngle += step

	local c = m.center
	local r = m.radius
	local px = c.X + math.cos(m.angle) * r
	local pz = c.Z + math.sin(m.angle) * r
	local pos = Vector3.new(px, c.Y, pz)

	-- Hadap arah gerak (tangen lingkaran). CFrame.lookAt nyata di Studio; dummy headless.
	local tx = -math.sin(m.angle) * m.direction
	local tz = math.cos(m.angle) * m.direction
	local look = Vector3.new(px + tx, c.Y, pz + tz)
	m.hrp.CFrame = CFrame.lookAt(pos, look)
	m.hrp.Position = pos
end

-- Putaran tawaf yang sudah ditempuh NPC (7 = tawaf lengkap). Untuk debug/uji/penanda progres.
function M.lapsOf(npc: any): number
	local m = motion[npc]
	return m and math.floor(m.totalAngle / TWO_PI) or 0
end

function M.angleOf(npc: any): number
	local m = motion[npc]
	return m and m.angle or 0
end

function M.positionOf(npc: any): any
	local m = motion[npc]
	return m and m.hrp.Position or nil
end

-- Lepas NPC dari simulasi (mis. streaming out / despawn).
function M.despawn(npc: any)
	motion[npc] = nil
	if npc and npc.Destroy then
		npc:Destroy()
	end
end

return M
