--!strict
-- TawafCounter.lua — CONTOH mekanisme (kontrak: _TEMPLATE.lua). Pemilik: Devi (§9).
-- Menghitung 7 putaran mengelilingi Ka'bah. Selesai saat putaran = 7.
-- TODO: deteksi putaran nyata (sudut kumulatif terhadap pusat Ka'bah); ini kerangka.

local Notify = require(script.Parent.Parent.Notify)

local M = {}
M.id = "TawafCounter"

local TARGET = 7
local laps = 0
local active = false

function M.init()
	-- TODO: ambil referensi Part pusat Ka'bah dari Workspace; siapkan pelacakan sudut.
end

function M.activate(ctx: any?)
	laps = 0
	active = true
	if ctx and ctx.player then
		Notify.toPlayer(ctx.player, ("Mulai Tawaf — 0/%d putaran"):format(TARGET))
	end
end

-- Dipanggil saat 1 putaran terdeteksi (oleh pelacak sudut — TODO).
function M.onLap(player: Player)
	if not active then return end
	laps += 1
	Notify.toPlayer(player, ("Tawaf %d/%d"):format(laps, TARGET))
end

function M.deactivate()
	active = false
end

function M.isDone(): boolean
	return laps >= TARGET
end

return M
