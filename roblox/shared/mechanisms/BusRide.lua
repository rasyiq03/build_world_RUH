--!strict
-- BusRide.lua — transisi naik bus antar-place. Pemilik: Praditama (shared, keputusan §9).
-- Kontrak: mechanisms/_TEMPLATE.lua. Dipakai tahap KE_MAKKAH (miqat→Makkah, alur Umrah) dan
-- bisa dipakai ulang untuk transisi Armuzna bila tim menambah tahap bus eksplisit.
--
-- PENTING: BusRide TIDAK memanggil TeleportService. Ia hanya GERBANG — pemain naik bus →
-- perjalanan singkat → `isDone()` true → ManasikRunner yang melanjutkan & memanggil Teleport
-- (milik Devi) ke place tahap berikutnya. Pemisahan ini menjaga kontrak spine.
--
-- Interaksi (proximity + klik): pintu bus punya ProximityPrompt → M.board(). Setelah naik, jam
-- perjalanan berakumulasi (RunService.Heartbeat) lalu selesai.
--
-- ctx (disusun PlaceContext place asal — mis. Miqat_QarnulManazil):
--   ctx.player           : Player
--   ctx.busPart          : BasePart?  pintu/badan bus (untuk ProximityPrompt).
--   ctx.destinationLabel : string?    nama tujuan untuk pesan (default "Makkah").
--   ctx.config           : { rideSeconds: number?, autoBoard: boolean? }?
--                          autoBoard=true → langsung berangkat tanpa menunggu naik (mis. transisi
--                          otomatis); default false (pemain naik sendiri).

local RunService = game:GetService("RunService")
local Notify = require(script.Parent.Parent.Notify)

local M = {}
M.id = "BusRide"

local DEFAULT_RIDE = 8 -- detik (dipercepat)

-- state
local active = false
local done = false
local boarded = false
local riding = false
local elapsed = 0
local duration = DEFAULT_RIDE
local player: Player? = nil
local destination = "Makkah"
local conns: { any } = {}

local function notify(msg: string)
	if player then
		Notify.toPlayer(player, msg)
	end
end

local function disconnectAll()
	for _, c in ipairs(conns) do
		if c and c.Disconnect then
			c:Disconnect()
		end
	end
	table.clear(conns)
end

-- API publik: pemain naik bus (dipanggil ProximityPrompt / skenario).
function M.board()
	if not active or done or boarded then
		return
	end
	boarded = true
	riding = true
	elapsed = 0
	notify(("Bus berangkat menuju %s. Duduklah, nikmati perjalanan."):format(destination))
end

function M.step(dt: number)
	if not active or done or not riding then
		return
	end
	elapsed += dt
	if elapsed >= duration then
		riding = false
		done = true
		notify(("Bus tiba di %s. Bersiap turun."):format(destination))
	end
end

function M.init() end

function M.activate(ctx: any?)
	active = true
	done = false
	boarded = false
	riding = false
	elapsed = 0
	player = ctx and ctx.player or nil
	destination = (ctx and ctx.destinationLabel) or "Makkah"
	local config = ctx and ctx.config
	duration = (config and config.rideSeconds) or DEFAULT_RIDE

	-- Pasang ProximityPrompt di pintu bus (game asli). Headless: busPart boleh nil.
	local busPart = ctx and ctx.busPart
	if busPart then
		local ok = pcall(function()
			local p = Instance.new("ProximityPrompt")
			p.ActionText = "Naik Bus"
			p.ObjectText = "Bus ke " .. destination
			p.MaxActivationDistance = 14
			p.Parent = busPart
			conns[#conns + 1] = p.Triggered:Connect(function(plr)
				if not player or plr == player then
					M.board()
				end
			end)
		end)
		if not ok then
			warn("[BusRide] ProximityPrompt tak tersedia (headless) — pakai M.board.")
		end
	else
		warn("[BusRide] tanpa ctx.busPart — tanpa ProximityPrompt (logika tetap via M.board).")
	end

	conns[#conns + 1] = RunService.Heartbeat:Connect(function(dt)
		M.step(dt)
	end)

	if config and config.autoBoard then
		notify(("Menaiki bus menuju %s..."):format(destination))
		M.board()
	else
		notify(("Bus menuju %s siap. Dekati dan naiklah."):format(destination))
	end
end

function M.deactivate()
	active = false
	riding = false
	disconnectAll()
end

function M.isDone(): boolean
	return done
end

return M
