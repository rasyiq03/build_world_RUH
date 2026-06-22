--!strict
-- Mabit.lua — bermalam (mabit). Dipakai MABIT_MINA_1 (Mina, malam Tarwiyah 8→9 Dzulhijjah).
-- Pemain wajib HADIR di zona selama rentang malam; waktu diakumulasi HANYA saat hadir (pola
-- sama Wukuf, lebih ringkas). Timer dipercepat. Pemilik: Nabil. Kontrak: mechanisms/_TEMPLATE.lua.
--
-- ctx (disusun place pemilik — Mina=Praditama / Muzdalifah=Nabil bila dipakai di sana):
--   ctx.player      : Player
--   ctx.zonePart    : BasePart?  zona mabit; nil → kehadiran dianggap selalu benar + warn.
--   ctx.config      : { mabitSeconds: number? }?  default DEFAULT_SECONDS.
--   ctx.label       : string?   nama lokasi untuk pesan (default "Mina").
--   ctx.startPresent: boolean?  pemain sudah di dalam zona saat mulai (spawn/teleport).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Notify = require(script.Parent.Parent.Notify)
local Kit = require(script.Parent._MechanismKit)

local M = {}
M.id = "Mabit"

local DEFAULT_SECONDS = 90

local active = false
local done = false
local elapsed = 0
local duration = DEFAULT_SECONDS
local present = false
local halfway = false
local player: Player? = nil
local label = "Mina"
local conns: { any } = {}

function M.init() end

function M.activate(ctx: any?)
	active = true
	done = false
	elapsed = 0
	present = false
	halfway = false
	player = ctx and ctx.player or nil
	duration = (ctx and ctx.config and ctx.config.mabitSeconds) or DEFAULT_SECONDS
	label = (ctx and ctx.label) or "Mina"

	local zonePart = ctx and ctx.zonePart
	if not zonePart then
		warn("[Mabit] tanpa zonePart — kehadiran dianggap selalu benar.")
		present = true
	else
		if ctx and ctx.startPresent then
			present = true
		end
		conns[#conns + 1] = zonePart.Touched:Connect(function(hit)
			local p = Players:GetPlayerFromCharacter(hit.Parent)
			if p and (not player or p == player) and not present then
				present = true
				Notify.toPlayer(p, ("Anda bermalam di %s."):format(label))
			end
		end)
		conns[#conns + 1] = zonePart.TouchEnded:Connect(function(hit)
			local p = Players:GetPlayerFromCharacter(hit.Parent)
			if p and (not player or p == player) and present then
				present = false
				Notify.toPlayer(p, ("Anda meninggalkan %s — mabit terhenti, kembalilah."):format(label))
			end
		end)
	end

	conns[#conns + 1] = RunService.Heartbeat:Connect(function(dt)
		M.step(dt)
	end)

	if player then
		Notify.toPlayer(player, ("Mabit di %s — bermalam hingga subuh (%ds)."):format(label, duration))
	end
end

function M.step(dt: number)
	if not active or done or not present then
		return
	end
	elapsed += dt
	if not halfway and elapsed >= duration / 2 then
		halfway = true
		if player then
			Notify.toPlayer(player, ("Tengah malam di %s..."):format(label))
		end
	end
	if elapsed >= duration then
		done = true
		if player then
			Notify.toPlayer(player, ("Subuh tiba. Mabit di %s selesai."):format(label))
		end
	end
end

function M.deactivate()
	active = false
	present = false
	Kit.disconnectAll(conns)
end

function M.isDone(): boolean
	return done
end

return M
