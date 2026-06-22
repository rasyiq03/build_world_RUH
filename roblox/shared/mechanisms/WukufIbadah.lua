--!strict
-- WukufIbadah.lua — amalan saat wukuf di Arafah (talbiyah, istighfar, doa, dzikir, shalawat).
-- BUKAN tahap tersendiri di Flows: DIDORONG oleh Wukuf.lua, karena MechanismRegistry hanya
-- mengaktifkan SATU mekanisme per tahap. Modul ini mencatat progres amalan pemain selama
-- wukuf (umpan balik/skor) dan TIDAK memblok isDone wukuf. Tetap mematuhi kontrak
-- mechanisms/_TEMPLATE.lua agar lolos MechanismRegistry.load(). Pemilik: Nabil (§9).

local Notify = require(script.Parent.Parent.Notify)

local M = {}
M.id = "WukufIbadah"

-- Amalan dianjurkan saat wukuf (judul singkat untuk UI Panduan milik Devi).
local AMALAN: { [string]: string } = {
	talbiyah = "Talbiyah",
	istighfar = "Istighfar",
	doa = "Doa (menghadap kiblat)",
	dzikir = "Dzikir & tahmid",
	shalawat = "Shalawat",
}

local counts: { [string]: number } = {}
local active = false

local function reset()
	counts = {}
	for k in pairs(AMALAN) do
		counts[k] = 0
	end
end

function M.init()
	reset()
end

function M.begin(_ctx: any?)
	active = true
	reset()
end
M.activate = M.begin

-- Dipanggil dari UI/RemoteEvent (via Wukuf.recordDeed) saat pemain berdoa/berzikir.
function M.recordDeed(p: Player?, deedId: string): boolean
	if not active then
		return false
	end
	if not AMALAN[deedId] then
		warn("[WukufIbadah] amalan tak dikenal: " .. tostring(deedId))
		return false
	end
	counts[deedId] += 1
	if p then
		Notify.toPlayer(p, ("%s (%dx) — diterima."):format(AMALAN[deedId], counts[deedId]))
	end
	return true
end

function M.summary(): { [string]: number }
	local s = {}
	for k, v in pairs(counts) do
		s[k] = v
	end
	return s
end

function M.finish()
	local total = 0
	for _, v in pairs(counts) do
		total += v
	end
	print(("[WukufIbadah] total amalan tercatat saat wukuf: %d."):format(total))
end

function M.deactivate()
	active = false
end

function M.isDone(): boolean
	return true -- non-blok: keabsahan wukuf ditentukan timer di Wukuf.lua.
end

return M
