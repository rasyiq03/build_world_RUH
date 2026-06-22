--!strict
-- Wukuf.lua — RUKUN HAJI terpenting (Arafah, 9 Dzulhijjah, dzuhur→maghrib).
-- Pemain WAJIB HADIR di zona Arafah selama rentang wukuf; waktu diakumulasi HANYA saat hadir
-- (keluar zona = timer berhenti). Timer dipercepat untuk game. Selesai (isDone) bila durasi
-- wukuf tercapai. Mendorong WukufIbadah (amalan) selama wukuf. Pemilik: Nabil (§9).
-- Kontrak: mechanisms/_TEMPLATE.lua.
--
-- ctx (disusun ServerScript C_Arafah; lihat aturan §8.3 — zona dari boundary.json, JANGAN hardcode):
--   ctx.player   : Player      alur single-player
--   ctx.zonePart : BasePart?   zona kehadiran Arafah (AABB dari boundary.json). Bila nil,
--                              kehadiran dianggap selalu benar (mode tanpa zona) + warn.
--   ctx.config   : { wukufSeconds: number? }?  durasi wukuf dipercepat (default DEFAULT_SECONDS).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Notify = require(script.Parent.Parent.Notify)
local WukufIbadah = require(script.Parent.WukufIbadah)
local Kit = require(script.Parent._MechanismKit)

local M = {}
M.id = "Wukuf"

local DEFAULT_SECONDS = 180

local active = false
local done = false
local elapsed = 0
local duration = DEFAULT_SECONDS
local present = false
local player: Player? = nil
local lastMilestone = -1
local conns: { any } = {}

function M.init()
	-- Tanpa side-effect saat load; zona dipasang di activate (butuh ctx).
end

function M.activate(ctx: any?)
	active = true
	done = false
	elapsed = 0
	present = false
	lastMilestone = -1
	player = ctx and ctx.player or nil
	duration = (ctx and ctx.config and ctx.config.wukufSeconds) or DEFAULT_SECONDS

	local zonePart = ctx and ctx.zonePart
	if not zonePart then
		warn("[Wukuf] tanpa zonePart — kehadiran dianggap selalu benar.")
		present = true
	else
		-- Pemain yang sudah berada di dalam zona saat diaktifkan (mis. spawn di Arafah):
		-- Touched takkan terpicu ulang, jadi pemanggil bisa set ctx.startPresent = true.
		if ctx and ctx.startPresent then
			present = true
		end
		conns[#conns + 1] = zonePart.Touched:Connect(function(hit)
			local p = Players:GetPlayerFromCharacter(hit.Parent)
			if p and (not player or p == player) and not present then
				present = true
				Notify.toPlayer(p, "Anda berada di Arafah — wukuf berlangsung.")
			end
		end)
		conns[#conns + 1] = zonePart.TouchEnded:Connect(function(hit)
			local p = Players:GetPlayerFromCharacter(hit.Parent)
			if p and (not player or p == player) and present then
				present = false
				Notify.toPlayer(p, "PERINGATAN: Anda keluar dari Arafah! Wukuf terhenti — kembalilah.")
			end
		end)
	end

	conns[#conns + 1] = RunService.Heartbeat:Connect(function(dt)
		M.step(dt)
	end)

	WukufIbadah.begin(ctx)
	if player then
		Notify.toPlayer(player, ("Wukuf dimulai — hadirlah di Arafah hingga maghrib (%ds)."):format(duration))
	end
end

-- Dipisah agar dapat diuji & dipanggil tiap Heartbeat. Akumulasi hanya saat hadir.
function M.step(dt: number)
	if not active or done or not present then
		return
	end
	elapsed += dt
	local pct = math.clamp(math.floor(elapsed / duration * 100), 0, 100)
	local milestone = pct - (pct % 25)
	if milestone > lastMilestone and milestone < 100 then
		lastMilestone = milestone
		if player then
			Notify.toPlayer(player, ("Wukuf %d%% — %ds/%ds di Arafah."):format(pct, math.floor(elapsed), duration))
		end
	end
	if elapsed >= duration then
		done = true
		if player then
			Notify.toPlayer(player, "Wukuf 100% — maghrib tiba. Wukuf SAH. Bersiap ke Muzdalifah.")
		end
		WukufIbadah.finish()
	end
end

-- Diteruskan ke WukufIbadah (dipanggil UI/RemoteEvent saat pemain berdoa/berzikir).
function M.recordDeed(p: Player, deedId: string): boolean
	return WukufIbadah.recordDeed(p, deedId)
end

function M.deactivate()
	active = false
	present = false
	Kit.disconnectAll(conns)
	WukufIbadah.deactivate()
end

function M.isDone(): boolean
	return done
end

return M
