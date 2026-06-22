--!strict
-- Qurban.lua — menyembelih hadyu/dam di Mina pada hari nahar (10 Dzulhijjah). Pemilik: Praditama.
-- Kontrak: mechanisms/_TEMPLATE.lua.
--
-- DAM (hadyu) WAJIB pada Haji Tamattu' & Qiran; Haji Ifrad TANPA dam. Saat tak wajib, mekanisme
-- langsung `isDone` (tidak menghambat alur) tetapi qurban sunnah tetap boleh dilakukan.
--
-- Hewan & jatah (edukatif): kambing/domba = 1 orang; sapi = 1/7; unta = 1/7.
--
-- Interaksi (proximity + klik): tugu/area sembelih punya ProximityPrompt → M.beginSacrifice(hewan).
-- Proses disembelih memakai akumulasi RunService.Heartbeat (pola Mabit) agar deterministik & teruji
-- headless; selesai → tinggalkan PENANDA di area.
--
-- ctx (disusun server/PlaceContext.Mina):
--   ctx.player      : Player
--   ctx.damRequired : boolean?   true = wajib (Tamattu'/Qiran). default false.
--   ctx.station     : BasePart?  area sembelih (untuk ProximityPrompt & penanda).
--   ctx.config      : { processSeconds: number?, defaultAnimal: string? }?

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Notify = require(script.Parent.Parent.Notify)
local Kit = require(script.Parent._MechanismKit)

local M = {}
M.id = "Qurban"

local DEFAULT_PROCESS = 6 -- detik (dipercepat)
local DEFAULT_ANIMAL = "kambing"

local ANIMAL_SHARE = {
	kambing = 1, -- 1 orang
	domba = 1,
	sapi = 7, -- berjamaah 7 orang
	unta = 7,
}

-- state
local active = false
local done = false
local damRequired = false
local processing = false
local elapsed = 0
local duration = DEFAULT_PROCESS
local animal = DEFAULT_ANIMAL
local player: Player? = nil
local station: BasePart? = nil
local conns: { any } = {}

local function notify(msg: string)
	if player then
		Notify.toPlayer(player, msg)
	end
end

local function placePenanda()
	if not station then
		return
	end
	local ok, _ = pcall(function()
		local tag = Instance.new("Part")
		tag.Name = "PenandaQurban"
		tag.Anchored = true
		tag.CanCollide = false
		tag.Size = Vector3.new(3, 0.2, 3)
		tag.Material = Enum.Material.Neon
		tag.Color = Color3.fromRGB(120, 200, 120)
		tag.Position = (station :: BasePart).Position + Vector3.new(0, 6, 0)
		tag.Parent = station
	end)
end

-- API publik: mulai menyembelih hewan (dipanggil ProximityPrompt / UI / skenario).
function M.beginSacrifice(animalType: string?)
	if not active or done or processing then
		return
	end
	local chosen = animalType or animal
	if ANIMAL_SHARE[chosen] == nil then
		notify("Hewan tidak dikenal: " .. tostring(chosen) .. " (kambing/domba/sapi/unta).")
		return
	end
	animal = chosen
	processing = true
	elapsed = 0
	local share = ANIMAL_SHARE[chosen]
	if share > 1 then
		notify(("Menyembelih %s (hadyu berjamaah, 1/%d). Berlangsung..."):format(chosen, share))
	else
		notify(("Menyembelih %s (hadyu). Berlangsung..."):format(chosen))
	end
end

function M.step(dt: number)
	if not active or done or not processing then
		return
	end
	elapsed += dt
	if elapsed >= duration then
		processing = false
		done = true
		placePenanda()
		notify(("Qurban %s selesai. Dam (hadyu) tertunaikan — lanjut tahallul."):format(animal))
	end
end

function M.init() end

function M.activate(ctx: any?)
	active = true
	done = false
	processing = false
	elapsed = 0
	player = ctx and ctx.player or nil
	damRequired = (ctx and ctx.damRequired) or false
	station = ctx and ctx.station or nil
	local config = ctx and ctx.config
	duration = (config and config.processSeconds) or DEFAULT_PROCESS
	animal = (config and config.defaultAnimal) or DEFAULT_ANIMAL

	if not damRequired then
		-- Haji Ifrad / umrah: tak ada kewajiban dam → tidak menghambat alur.
		done = true
		notify("Tidak ada kewajiban dam (qurban) pada jenis ibadah ini.")
		return
	end

	-- Pasang ProximityPrompt di area sembelih (game asli). Headless: station boleh nil.
	if not station then
		warn("[Qurban] tanpa ctx.station — tanpa ProximityPrompt (logika tetap via M.beginSacrifice).")
	else
		conns[#conns + 1] = Kit.attachPrompt(station, "Sembelih Hadyu", "Tempat Qurban", 18, function(plr)
			if not player or plr == player then
				M.beginSacrifice(nil)
			end
		end)
	end

	conns[#conns + 1] = RunService.Heartbeat:Connect(function(dt)
		M.step(dt)
	end)

	notify("Hari nahar: tunaikan dam (hadyu) di tempat qurban — dekati lalu sembelih.")
end

function M.deactivate()
	active = false
	processing = false
	Kit.disconnectAll(conns)
end

function M.isDone(): boolean
	return done
end

return M
