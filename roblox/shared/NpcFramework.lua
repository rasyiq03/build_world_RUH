--!strict
-- NpcFramework.lua — primitif spawn, gerak, & interaksi NPC. Behavior spesifik (Askar, OB, Jamaah,
-- KursiRoda, Medis, TNI) = file tipis di roblox/npc/<Nama>.lua yang MENYUSUN primitif ini + datanya
-- (rute patroli, baris dialog, pos). Lihat GAME_DESIGN §3.1.
--
-- Kontrak modul behavior (roblox/npc/<Nama>.lua):
--   M.id : string
--   M.spawn(ctx) -> Model            -- buat 1 NPC (pakai NpcFramework.newDummy)
--   M.update(npc, dt)                -- (opsional) tiap Heartbeat: jalankan stepper patroli/proximity
--
-- DESAIN: gerak KINEMATIK (HRP di-anchor + CFrame per update) — murah utk kerumunan & DETERMINISTIK
-- (bisa diuji headless lewat skill mock-roblox). `walkTo` (pathfinding Humanoid) disediakan untuk NPC
-- individual yang butuh navmesh nyata. Semua API khusus-Studio (Humanoid, ProximityPrompt, Animator)
-- dibungkus pcall → logika tetap jalan & teruji tanpa Studio. Matematika vektor MANUAL (mock Vector3
-- tak punya .Magnitude/.Unit).

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")

local NpcFramework = {}

-- ── util internal (headless-safe) ──
local function dist2D(ax, az, bx, bz): number
	local dx, dz = ax - bx, az - bz
	return math.sqrt(dx * dx + dz * dz)
end

local function getHRP(npc: any): any
	return npc and npc:FindFirstChild("HumanoidRootPart")
end

-- Hadapkan NPC ke titik dunia (kinematik). Aman bila titik = posisi sekarang (tak memutar).
function NpcFramework.faceTarget(npc: any, worldPos: any)
	local hrp = getHRP(npc)
	if not hrp then return end
	local p = hrp.Position
	if math.abs(p.X - worldPos.X) < 1e-4 and math.abs(p.Z - worldPos.Z) < 1e-4 then
		return
	end
	hrp.CFrame = CFrame.lookAt(Vector3.new(p.X, p.Y, p.Z), Vector3.new(worldPos.X, p.Y, worldPos.Z))
end

-- ── newDummy: rangka NPC standar (Model + HRP anchored + Humanoid opsional) ──
-- opts: { name, size: Vector3?, color: Color3?, position: Vector3? }
function NpcFramework.newDummy(opts: any): any
	opts = opts or {}
	local npc = Instance.new("Model")
	npc.Name = opts.name or "NPC"
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = opts.size or Vector3.new(2, 5, 1)
	hrp.Anchored = true
	hrp.CanCollide = false
	if opts.color then hrp.Color = opts.color end
	if opts.position then hrp.Position = opts.position end
	hrp.Parent = npc
	pcall(function() -- Humanoid utk animasi default Studio; tak wajib utk gerak kinematik.
		local hum = Instance.new("Humanoid")
		hum.Parent = npc
	end)
	npc.PrimaryPart = hrp
	return npc
end

-- ── patrol: stepper KINEMATIK melewati waypoints. Kembalikan { step(dt), reset(), index() } ──
-- waypoints: { Vector3 }. opts: { speed?=8, loop?=true, pingpong?=false, pause?=0, arrive?=2 }
-- step(dt) dipanggil tiap Heartbeat; gerak HRP ke waypoint berikutnya, hadap arah jalan.
function NpcFramework.patrol(npc: any, waypoints: { any }, opts: any): any
	opts = opts or {}
	local speed = opts.speed or 8
	local loop = opts.loop ~= false
	local pingpong = opts.pingpong or false
	local pauseT = opts.pause or 0
	local arrive = opts.arrive or 2
	local hrp = getHRP(npc)

	local st = { i = 1, dir = 1, pausing = 0, done = false }

	local function step(dt: number)
		if not hrp or #waypoints == 0 or st.done then return end
		if st.pausing > 0 then
			st.pausing -= dt
			return
		end
		local target = waypoints[st.i]
		local pos = hrp.Position
		local d = dist2D(pos.X, pos.Z, target.X, target.Z)
		local move = speed * dt
		if d <= math.max(move, arrive) then
			-- tiba di waypoint → tempel & maju indeks
			hrp.Position = Vector3.new(target.X, target.Y, target.Z)
			st.pausing = pauseT
			local nextI = st.i + st.dir
			if nextI < 1 or nextI > #waypoints then
				if pingpong then
					st.dir = -st.dir
					nextI = st.i + st.dir
				elseif loop then
					nextI = (st.dir > 0) and 1 or #waypoints
				else
					st.done = true
					return
				end
			end
			st.i = math.clamp(nextI, 1, #waypoints)
		else
			-- gerak menuju target + hadap arah. Set CFrame (orientasi) DAN Position (di Roblox CFrame
			-- mengubah posisi; di harness mock keduanya terpisah — set eksplisit, pola JamaahTawaf).
			local ux, uz = (target.X - pos.X) / d, (target.Z - pos.Z) / d
			local nx, nz = pos.X + ux * move, pos.Z + uz * move
			hrp.CFrame = CFrame.lookAt(Vector3.new(nx, pos.Y, nz), Vector3.new(nx + ux, pos.Y, nz + uz))
			hrp.Position = Vector3.new(nx, pos.Y, nz)
		end
	end

	return {
		step = step,
		reset = function() st.i, st.dir, st.pausing, st.done = 1, 1, 0, false end,
		index = function() return st.i end,
		isDone = function() return st.done end,
	}
end

-- ── watchProximity: deteksi pemain terdekat dalam radius (kinematik, tiap update) ──
-- opts: { radius?=18, onEnter(player), onLeave(player), getPlayers?() }
-- getPlayers default = Players:GetPlayers(); di headless skenario inject daftar manual.
function NpcFramework.watchProximity(npc: any, opts: any): any
	opts = opts or {}
	local radius = opts.radius or 18
	local getPlayers = opts.getPlayers or function() return Players:GetPlayers() end
	local hrp = getHRP(npc)
	local insideNow: any = nil

	local function playerPos(pl: any): any
		local ch = pl and pl.Character
		local h = ch and ch:FindFirstChild("HumanoidRootPart")
		return h and h.Position or nil
	end

	local function step(_dt: number)
		if not hrp then return end
		local p = hrp.Position
		-- pemain terdekat dalam radius
		local nearest, nd = nil, radius
		for _, pl in ipairs(getPlayers()) do
			local pp = playerPos(pl)
			if pp then
				local d = dist2D(p.X, p.Z, pp.X, pp.Z)
				if d <= nd then nd = d; nearest = pl end
			end
		end
		if nearest ~= insideNow then
			if insideNow and opts.onLeave then opts.onLeave(insideNow) end
			if nearest and opts.onEnter then opts.onEnter(nearest) end
			insideNow = nearest
		end
	end

	return { step = step, current = function() return insideNow end }
end

-- ── makeTalkable: pasang pemicu bicara (ProximityPrompt/ClickDetector) → buka Dialog berpilihan ──
-- tree = pohon dialog (lihat shared/Dialog). opts: { actionText?, objectText?, dist?=12 }
-- Mengembalikan koneksi (atau nil headless). Logika headless: panggil NpcFramework.talk(npc, player).
local Dialog = require(script.Parent.Dialog)
local talkTrees: { [any]: any } = {}

function NpcFramework.makeTalkable(npc: any, tree: any, opts: any): any
	opts = opts or {}
	talkTrees[npc] = tree
	local hrp = getHRP(npc)
	local conn: any = nil
	pcall(function()
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = opts.actionText or "Sapa"
		prompt.ObjectText = opts.objectText or npc.Name
		prompt.MaxActivationDistance = opts.dist or 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = hrp
		conn = prompt.Triggered:Connect(function(plr)
			NpcFramework.talk(npc, plr)
		end)
	end)
	return conn
end

-- Picu dialog NPC utk pemain (dipanggil ProximityPrompt / skenario uji).
function NpcFramework.talk(npc: any, player: any)
	local tree = talkTrees[npc]
	if tree then
		Dialog.open(player, tree)
	end
end

-- ── playLoop: animasi looping default (jalan/idle/menyapu/doa). Studio-only, pcall. ──
-- animId mis. "rbxassetid://...". Headless: no-op aman.
function NpcFramework.playLoop(npc: any, animId: string): any
	local track: any = nil
	pcall(function()
		local hum = npc:FindFirstChildOfClass("Humanoid")
		local animator = hum and (hum:FindFirstChildOfClass("Animator") or Instance.new("Animator"))
		if animator and not animator.Parent then animator.Parent = hum end
		local anim = Instance.new("Animation")
		anim.AnimationId = animId
		track = animator:LoadAnimation(anim)
		track.Looped = true
		track:Play()
	end)
	return track
end

-- ── walkTo: pathfinding Humanoid nyata (NPC individual; BLOCKING). Bukan utk kerumunan. ──
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
		humanoid:MoveTo(dest)
	end
end

-- Lepas NPC dari registry interaksi (saat despawn).
function NpcFramework.forget(npc: any)
	talkTrees[npc] = nil
end

return NpcFramework
