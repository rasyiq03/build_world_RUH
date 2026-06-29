--!strict
-- PlayerState.lua — STATE pemain terpusat (SYSTEMS_DESIGN §2). Tulang punggung "kelengkapan
-- equipment" + "di luar aturan" — semuanya LEMBUT (status/peringatan, TAK memblokir).
-- Mekanisme MENULIS (IhramChange→ihramWorn/niat, PebbleCollect→pebbles, Tahallul→tahallulState via
-- atribut), UI & IhramRules MEMBACA. Field penting dicermin ke atribut pemain agar client/lain baca.
--
-- KONTRAK BERSAMA. Edukatif: check() hanya MENGINFORMASIKAN kekurangan, bukan gerbang.

local PlayerState = {}

type State = {
	ihramWorn: boolean,
	niat: boolean,
	pebbles: number,
	refreshed: boolean,
	warnings: { string },
}

local store: { [any]: State } = {}

local function attr(player: any, key: string, value: any)
	pcall(function()
		(player :: any):SetAttribute(key, value)
	end)
end

local function readAttr(player: any, key: string): any
	local ok, v = pcall(function()
		return (player :: any):GetAttribute(key)
	end)
	return ok and v or nil
end

-- Ambil (atau buat) state pemain.
function PlayerState.get(player: any): State
	local s = store[player]
	if not s then
		s = { ihramWorn = false, niat = false, pebbles = 0, refreshed = false, warnings = {} }
		store[player] = s
	end
	return s
end

-- tahallulState milik modul Tahallul (atribut "TahallulState"): IHRAM|AWAL|COMPLETE. Dibaca lewat sini.
function PlayerState.tahallulState(player: any): string
	local v = readAttr(player, "TahallulState")
	return (type(v) == "string" and v) or "IHRAM"
end

function PlayerState.set(player: any, key: string, value: any)
	local s = PlayerState.get(player) :: any
	s[key] = value
	attr(player, "PS_" .. key, value) -- cermin ke atribut (client/UI baca)
end

function PlayerState.incPebbles(player: any, n: number): number
	local s = PlayerState.get(player)
	s.pebbles += (n or 1)
	attr(player, "PS_pebbles", s.pebbles)
	return s.pebbles
end

-- Catat peringatan LEMBUT (di-cap agar tak membengkak). Bukan gate.
function PlayerState.addWarning(player: any, msg: string)
	local s = PlayerState.get(player)
	s.warnings[#s.warnings + 1] = msg
	while #s.warnings > 12 do
		table.remove(s.warnings, 1)
	end
end

function PlayerState.clearWarnings(player: any)
	PlayerState.get(player).warnings = {}
end

-- Apakah pemain dalam keadaan ihram (worn+niat, belum tahallul penuh)?
function PlayerState.inIhram(player: any): boolean
	local s = PlayerState.get(player)
	return s.ihramWorn and s.niat and PlayerState.tahallulState(player) ~= "COMPLETE"
end

-- Syarat (SOFT) tiap tahap — untuk status/peringatan, BUKAN gerbang. id = Flows stage id (atau prefix).
local REQUIREMENTS: { [string]: { string } } = {
	IHRAM = { "ihramWorn", "niat" },
	IHRAM_UMRAH = { "ihramWorn", "niat" },
	IHRAM_HAJI = { "ihramWorn", "niat" },
	IHRAM_QIRAN = { "ihramWorn", "niat" },
	JUMRAH_AQABAH = { "pebbles>=7" },
	MABIT_MINA_2 = { "pebbles>=7" },
}

-- check(player, stageId) → { ok = boolean, missing = {string} }. Untuk panduan/status (lembut).
function PlayerState.check(player: any, stageId: string): any
	local req = REQUIREMENTS[stageId]
	local missing = {}
	if req then
		local s = PlayerState.get(player)
		for _, r in ipairs(req) do
			if r == "ihramWorn" and not s.ihramWorn then
				missing[#missing + 1] = "kenakan ihram"
			elseif r == "niat" and not s.niat then
				missing[#missing + 1] = "berniat"
			elseif r == "pebbles>=7" and s.pebbles < 7 then
				missing[#missing + 1] = ("kumpulkan kerikil (%d/7)"):format(s.pebbles)
			end
		end
	end
	return { ok = #missing == 0, missing = missing }
end

-- Ringkasan status untuk HUD (lembut): "Ihram ✓ · Niat ✓ · Kerikil 7 · Tahallul: IHRAM".
function PlayerState.summary(player: any): string
	local s = PlayerState.get(player)
	local function mark(b) return b and "✓" or "✗" end
	return ("Ihram %s · Niat %s · Kerikil %d · Tahallul: %s"):format(
		mark(s.ihramWorn), mark(s.niat), s.pebbles, PlayerState.tahallulState(player))
end

function PlayerState.reset(player: any)
	store[player] = nil
end

return PlayerState
