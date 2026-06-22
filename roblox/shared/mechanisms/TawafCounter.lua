--!strict
-- TawafCounter.lua — menghitung 7 putaran Tawaf mengelilingi Ka'bah. Pemilik: Devi (§9).
-- Kontrak: mechanisms/_TEMPLATE.lua.
--
-- DETEKSI PUTARAN = SUDUT KUMULATIF terhadap pusat Ka'bah (bukan trigger zona tunggal — itu mudah
-- dicurangi & tak tahu arah). Tiap Heartbeat kita baca posisi pemain, hitung sudut atan2 relatif
-- pusat, akumulasi selisih sudut DALAM ARAH TAWAF. 2π terkumpul = 1 putaran; 7 = selesai.
--
-- Arah Tawaf: BERLAWANAN arah jarum jam dilihat dari atas (Ka'bah di kiri jamaah) → default
-- direction = -1 (konsisten dgn npc/JamaahTawaf). Gerak mundur MENGURANGI progres (dijaga ≥ 0),
-- jadi diam/putar-balik tak menambah hitungan.
--
-- ctx (disusun skrip place Makkah — koordinasi center dgn JamaahTawaf milik Praditama):
--   ctx.player      : Player
--   ctx.center      : Vector3   pusat Ka'bah (titik orbit). WAJIB di game asli.
--   ctx.getPosition : (() -> Vector3)?  baca posisi pemain (mis. HumanoidRootPart.Position).
--                     Bila diberi, modul memasang Heartbeat sendiri. Headless: nil → pakai M.update.
--   ctx.direction   : number?   +1/-1 (default -1, berlawanan jarum jam).
--   ctx.config      : {
--       target    : number?  putaran (default 7)
--       maxRadius : number?  hanya hitung bila pemain dlm radius ini dari pusat (default 60; abaikan gate bila 0)
--   }?

local RunService = game:GetService("RunService")
local Notify = require(script.Parent.Parent.Notify)

local M = {}
M.id = "TawafCounter"

local TWO_PI = math.pi * 2
local DEFAULT_TARGET = 7
local DEFAULT_MAX_RADIUS = 60

-- state
local active = false
local player: Player? = nil
local center: Vector3? = nil
local direction = -1
local target = DEFAULT_TARGET
local maxRadius = DEFAULT_MAX_RADIUS
local getPosition: (() -> Vector3)? = nil

local cumulative = 0 -- radian maju (arah tawaf), diklem ≥ 0
local laps = 0
local done = false
local lastAngle: number? = nil
local heartbeatConn: any = nil

local function notify(msg: string)
	if player then
		Notify.toPlayer(player, msg)
	end
end

-- Selisih sudut terpendek a→b dinormalkan ke (-π, π].
local function angleDelta(from: number, to: number): number
	local d = to - from
	while d > math.pi do d -= TWO_PI end
	while d < -math.pi do d += TWO_PI end
	return d
end

-- Suntik posisi pemain saat ini. Dipanggil tiap Heartbeat (server) atau oleh skenario (headless).
function M.update(pos: Vector3)
	if not active or done or not center then
		return
	end
	local c = center
	local dx, dz = pos.X - c.X, pos.Z - c.Z

	-- Gate radius: di luar mataf (mis. berdiri di pusat / jauh) tak dihitung.
	if maxRadius > 0 then
		local r = math.sqrt(dx * dx + dz * dz)
		if r > maxRadius then
			lastAngle = nil -- jangan jembatani lompatan sudut saat kembali masuk
			return
		end
	end

	local ang = math.atan2(dz, dx)
	if lastAngle == nil then
		lastAngle = ang
		return
	end

	-- Selisih × arah → maju positif bila bergerak sesuai arah tawaf.
	local forward = angleDelta(lastAngle, ang) * direction
	lastAngle = ang
	cumulative = math.max(0, cumulative + forward)

	local newLaps = math.floor(cumulative / TWO_PI)
	if newLaps > laps then
		laps = math.min(newLaps, target)
		if laps >= target then
			done = true
			notify(("Tawaf selesai — %d/%d putaran. Lanjut Sa'i."):format(target, target))
		else
			notify(("Tawaf %d/%d putaran."):format(laps, target))
		end
	end
end

function M.init() end

function M.activate(ctx: any?)
	active = true
	cumulative = 0
	laps = 0
	done = false
	lastAngle = nil
	player = ctx and ctx.player or nil
	center = ctx and ctx.center or nil
	direction = (ctx and ctx.direction) or -1
	local config = ctx and ctx.config
	target = (config and config.target) or DEFAULT_TARGET
	maxRadius = (config and config.maxRadius) or DEFAULT_MAX_RADIUS
	getPosition = ctx and ctx.getPosition or nil

	if not center then
		warn("[TawafCounter] ctx.center (pusat Ka'bah) kosong — putaran tak dapat dihitung sampai diisi.")
	end

	notify(("Mulai Tawaf — kelilingi Ka'bah 0/%d (berlawanan arah jarum jam)."):format(target))

	-- Game asli: pasang Heartbeat membaca posisi pemain. Headless (tanpa getPosition): skenario
	-- menyuntik posisi via M.update — koneksi tak dibuat.
	if getPosition then
		heartbeatConn = RunService.Heartbeat:Connect(function()
			if active and getPosition then
				M.update(getPosition())
			end
		end)
	end
end

function M.deactivate()
	active = false
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
end

-- Progres untuk debug/uji.
function M.laps(): number
	return laps
end

function M.isDone(): boolean
	return laps >= target
end

return M
