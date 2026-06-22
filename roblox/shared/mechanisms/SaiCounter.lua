--!strict
-- SaiCounter.lua — menghitung 7 perjalanan (syawt) Sa'i antara bukit Shafa & Marwah. Pemilik: Devi.
-- Kontrak: mechanisms/_TEMPLATE.lua.
--
-- FIKIH: Sa'i = 7 perjalanan SATU-ARAH, MULAI di Shafa, BERAKHIR di Marwah.
--   Shafa→Marwah = perjalanan 1, Marwah→Shafa = 2, … hingga 7 (berakhir di Marwah).
-- Jadi tiba di ujung LAWAN dari ujung terakhir = +1 perjalanan. Tiba lagi di ujung yang sama
-- (belum menyeberang) tidak menambah.
--
-- DETEKSI = kedekatan ke dua titik ujung (Shafa & Marwah). Tiap Heartbeat baca posisi pemain;
-- bila masuk radius salah satu ujung & itu ujung yang ditunggu → catat perjalanan. Headless:
-- skenario memanggil M.reach("Shafa"|"Marwah") langsung (atau M.update(pos)).
--
-- ctx (disusun skrip place Makkah):
--   ctx.player      : Player
--   ctx.shafa       : Vector3 | BasePart   titik/penanda bukit Shafa. WAJIB di game asli.
--   ctx.marwah      : Vector3 | BasePart   titik/penanda bukit Marwah. WAJIB.
--   ctx.getPosition : (() -> Vector3)?      baca posisi pemain. Bila diberi, pasang Heartbeat sendiri.
--   ctx.config      : { target: number?=7, reachRadius: number?=12 }?

local RunService = game:GetService("RunService")
local Notify = require(script.Parent.Parent.Notify)

local M = {}
M.id = "SaiCounter"

local DEFAULT_TARGET = 7
local DEFAULT_REACH_RADIUS = 12

-- state
local active = false
local done = false
local player: Player? = nil
local target = DEFAULT_TARGET
local reachRadius = DEFAULT_REACH_RADIUS
local shafaPos: Vector3? = nil
local marwahPos: Vector3? = nil
local getPosition: (() -> Vector3)? = nil

local trips = 0
local lastEnd = "Shafa" -- mulai dianggap di Shafa; perjalanan pertama harus tiba di Marwah.
local heartbeatConn: any = nil

local function notify(msg: string)
	if player then
		Notify.toPlayer(player, msg)
	end
end

-- Terima Vector3 atau BasePart (ambil .Position). Tahan untuk Roblox asli & harness headless
-- (di mana Vector3 = tabel biasa, typeof-nya bukan "Vector3").
local function toPos(v: any): Vector3?
	if v == nil then
		return nil
	end
	-- BasePart? (punya :IsA). Vector3 tak punya IsA → dijaga pcall.
	local ok, isPart = pcall(function()
		return v.IsA ~= nil and v:IsA("BasePart")
	end)
	if ok and isPart then
		return v.Position
	end
	-- Vector3-like (asli/mock): punya komponen numerik X & Z.
	local hasXZ = pcall(function()
		return v.X + v.Z
	end)
	if hasXZ then
		return v
	end
	return nil
end

local function dist2D(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- API publik: pemain tiba di ujung `name` ("Shafa"|"Marwah"). Dipanggil M.update / ProximityPrompt
-- / skenario uji. Menambah perjalanan hanya bila menyeberang dari ujung lawan.
function M.reach(name: string)
	if not active or done then
		return
	end
	if name ~= "Shafa" and name ~= "Marwah" then
		return
	end
	if name == lastEnd then
		return -- belum menyeberang; mengabaikan kedatangan berulang di ujung yang sama.
	end

	trips += 1
	lastEnd = name
	if trips >= target then
		done = true
		notify(("Sa'i selesai — %d/%d perjalanan (berakhir di Marwah)."):format(target, target))
	else
		notify(("Sa'i %d/%d — tiba di %s."):format(trips, target, name))
	end
end

-- Suntik posisi pemain; bila dalam radius salah satu ujung, catat kedatangan.
function M.update(pos: Vector3)
	if not active or done then
		return
	end
	if shafaPos and dist2D(pos, shafaPos) <= reachRadius then
		M.reach("Shafa")
	elseif marwahPos and dist2D(pos, marwahPos) <= reachRadius then
		M.reach("Marwah")
	end
end

function M.init() end

function M.activate(ctx: any?)
	active = true
	done = false
	trips = 0
	lastEnd = "Shafa"
	player = ctx and ctx.player or nil
	shafaPos = ctx and toPos(ctx.shafa) or nil
	marwahPos = ctx and toPos(ctx.marwah) or nil
	getPosition = ctx and ctx.getPosition or nil
	local config = ctx and ctx.config
	target = (config and config.target) or DEFAULT_TARGET
	reachRadius = (config and config.reachRadius) or DEFAULT_REACH_RADIUS

	if not shafaPos or not marwahPos then
		warn("[SaiCounter] ctx.shafa / ctx.marwah kosong — perjalanan tak terdeteksi via posisi (M.reach tetap bisa).")
	end

	notify(("Mulai Sa'i — dari Shafa menuju Marwah, 0/%d perjalanan."):format(target))

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
function M.trips(): number
	return trips
end

function M.isDone(): boolean
	return done
end

return M
