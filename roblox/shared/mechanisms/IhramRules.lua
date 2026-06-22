--!strict
-- IhramRules.lua — penegak LARANGAN IHRAM. Pemilik: Devi. Kontrak: _TEMPLATE.lua.
--
-- Bukan ritual ber-tahap di Flows: ini pengawas PASIF yang menyala selama pemain dalam keadaan
-- ihram (dinyalakan setelah niat di IhramChange, dimatikan saat tahallul). Karena MechanismRegistry
-- hanya menahan SATU mekanisme aktif, IhramRules dipakai sebagai modul mandiri yang di-toggle oleh
-- skrip place / IhramChange — BUKAN diaktifkan oleh ManasikRunner per tahap. Tetap mematuhi kontrak
-- agar bisa dimuat registry.
--
-- Cara pakai: saat suatu aksi pemain hendak terjadi (mis. buka toko parfum, pakai topi), panggil
-- M.attempt(action) → { allowed, message, dam }. Bila dilarang: allowed=false, beri umpan balik,
-- catat pelanggaran (sebagian butuh DAM/fidyah). Aksi paling berat (jima sebelum tahallul awal)
-- membatalkan haji — ditandai severity "batal".
--
-- ctx (opsional, saat di-activate sbg penanda keadaan ihram):
--   ctx.player : Player
--   ctx.gender : "male"|"female"  (default "male"; sebagian larangan khusus pria/wanita)

local Notify = require(script.Parent.Parent.Notify)

local Ctx = require(script.Parent.Parent.Ctx)

local M = {}
M.id = "IhramRules"

-- Larangan: key aksi → { msg, dam(butuh fidyah/dam?), gender(nil=semua), severity }
local PROHIBITIONS: { [string]: any } = {
	potong_rambut   = { msg = "Dilarang mencukur/mencabut rambut saat ihram.", dam = true },
	potong_kuku     = { msg = "Dilarang memotong kuku saat ihram.", dam = true },
	wewangian       = { msg = "Dilarang memakai wewangian saat ihram.", dam = true },
	berburu         = { msg = "Dilarang berburu/membunuh hewan darat saat ihram.", dam = true },
	pakai_jahit     = { msg = "Pria dilarang memakai pakaian berjahit saat ihram.", dam = true, gender = "male" },
	tutup_kepala    = { msg = "Pria dilarang menutup kepala saat ihram.", dam = true, gender = "male" },
	tutup_wajah     = { msg = "Wanita dilarang menutup wajah (niqab) & memakai sarung tangan saat ihram.", dam = true, gender = "female" },
	nikah           = { msg = "Dilarang menikah / menikahkan / melamar saat ihram.", dam = false },
	jima            = { msg = "Dilarang berhubungan suami-istri. Sebelum tahallul awal: MEMBATALKAN haji & wajib dam.", dam = true, severity = "batal" },
}

-- state
local inIhram = false
local gender = "male"
local player: Player? = nil
local violations = 0
local damCount = 0

local function notify(msg: string)
	if player then
		Notify.toPlayer(player, msg)
	end
end

-- Status tahallul pemain. KONTRAK LINTAS-MODUL: mekanisms/Tahallul.lua (Nabil) menyimpan atribut
-- pemain "TahallulState" ∈ "IHRAM"|"AWAL"|"COMPLETE". Kita BACA (bukan require) agar coupling longgar.
--   IHRAM    → seluruh larangan berlaku.
--   AWAL     → setelah tahallul awal: semua larangan HALAL kecuali jima (hubungan suami-istri).
--   COMPLETE → tahallul penuh: tak ada larangan.
local function tahallulState(p: Player?): string
	if not p then
		return "IHRAM"
	end
	local ok, s = pcall(function()
		return (p :: any):GetAttribute("TahallulState")
	end)
	if ok and type(s) == "string" then
		return s
	end
	return "IHRAM"
end

-- Apakah aksi diperbolehkan dalam keadaan ihram? Mengembalikan info & mencatat pelanggaran.
-- result = { allowed: boolean, message: string?, dam: boolean, severity: string? }
function M.attempt(action: string): any
	if not inIhram then
		return { allowed = true, dam = false } -- di luar ihram: tak ada larangan ini.
	end

	-- Pelonggaran sesuai tahap tahallul (fikih §5.6).
	local ts = tahallulState(player)
	if ts == "COMPLETE" then
		return { allowed = true, dam = false } -- tahallul tsani: semua halal.
	end

	local rule = PROHIBITIONS[action]
	if not rule then
		return { allowed = true, dam = false } -- aksi tak termasuk larangan.
	end
	-- Larangan khusus gender tertentu: yang lain tidak terkena.
	if rule.gender and rule.gender ~= gender then
		return { allowed = true, dam = false }
	end
	-- Setelah tahallul AWAL: hanya jima yang masih dilarang; sisanya halal.
	if ts == "AWAL" and action ~= "jima" then
		return { allowed = true, dam = false }
	end

	violations += 1
	if rule.dam then
		damCount += 1
	end
	notify("⚠ Larangan ihram: " .. rule.msg)
	return { allowed = false, message = rule.msg, dam = rule.dam == true, severity = rule.severity }
end

-- Daftar key larangan yang berlaku untuk gender saat ini (utk UI Panduan).
function M.activeProhibitions(): { string }
	local list = {}
	for key, rule in pairs(PROHIBITIONS) do
		if not rule.gender or rule.gender == gender then
			list[#list + 1] = key
		end
	end
	return list
end

function M.init() end

-- activate = pemain MASUK keadaan ihram (dipanggil setelah niat / oleh skrip place).
function M.activate(ctx: Ctx.IhramRules?)
	inIhram = true
	violations = 0
	damCount = 0
	player = ctx and ctx.player or nil
	gender = (ctx and ctx.gender) or "male"
	notify("Keadaan ihram aktif — larangan ihram berlaku hingga tahallul.")
end

-- deactivate = keluar ihram (tahallul).
function M.deactivate()
	inIhram = false
end

function M.isInIhram(): boolean
	return inIhram
end

function M.violationCount(): number
	return violations
end

function M.damCount(): number
	return damCount
end

-- Pengawas pasif: tak pernah "memblokir" kemajuan tahap manasik.
function M.isDone(): boolean
	return true
end

return M
