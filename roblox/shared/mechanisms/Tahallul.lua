--!strict
-- Tahallul.lua — CUKUR (tahallul): melepas ihram. Mekanisme LINTAS-AREA (Nabil, §9):
--   • Umrah : tahallul TUNGGAL di Makkah (setelah Sa'i) → lepas ihram PENUH (umrah selesai).
--   • Haji  : tahallul AWAL di Mina (setelah Jumrah Aqabah) → semua larangan halal KECUALI
--             hubungan suami-istri; tahallul TSANI (penuh) setelah Tawaf Ifadah.
--
-- PENTING (fikih): "tsani" BUKAN cukur kedua — ia status yang menjadi LENGKAP saat Tawaf Ifadah
-- selesai. Maka mekanisme ini (aksi cukur) hanya menangani mode "umrah"/"awal"; place Makkah
-- memanggil Tahallul.markTsani(player) seusai Tawaf Ifadah untuk menaikkan AWAL → COMPLETE.
-- PENEGAKAN larangan ihram = IhramRules (Devi). Modul ini hanya AKSI cukur + STATUS rilis
-- (disimpan sebagai atribut pemain "TahallulState" agar IhramRules/UI bisa membacanya).
-- Kontrak: mechanisms/_TEMPLATE.lua.
--
-- ctx (disusun place pemilik stage — Makkah=Devi / Mina=Praditama):
--   ctx.player  : Player
--   ctx.mode    : "umrah" | "awal"  (pakai Tahallul.modeForStage(stage.id))
--   ctx.station : BasePart?  tempat cukur; sentuh untuk melakukan. nil → langsung (mis. tombol UI).

local Notify = require(script.Parent.Parent.Notify)
local Players = game:GetService("Players")
local Kit = require(script.Parent._MechanismKit)

local Ctx = require(script.Parent.Parent.Ctx)

local M = {}
M.id = "Tahallul"

export type TahallulState = "IHRAM" | "AWAL" | "COMPLETE"

local active = false
local performed = false
local player: Player? = nil
local mode = "umrah"
local station: BasePart? = nil
local viaUI = false -- bila true & tanpa station: tunggu tombol UI (M.cukur), jangan auto-perform
local conns: { any } = {}

local function setState(p: Player?, s: TahallulState)
	if p and (p :: any).SetAttribute then
		(p :: any):SetAttribute("TahallulState", s)
	end
end

-- Baca status rilis ihram pemain (default IHRAM). Dipakai IhramRules (Devi) / UI.
function M.getState(p: Player?): TahallulState
	if p and (p :: any).GetAttribute then
		return ((p :: any):GetAttribute("TahallulState") :: TahallulState?) or "IHRAM"
	end
	return "IHRAM"
end

-- Pemetaan id tahap Flows → mode aksi cukur (dipakai place pemilik saat menyusun ctx).
-- Qurban kini tahap tersendiri (ritual "Qurban") sebelum TAHALLUL_AWAL — bukan lagi gabungan
-- QURBAN_TAHALLUL. Jadi tahallul haji = "awal" (TAHALLUL_AWAL); selain itu umrah.
function M.modeForStage(stageId: string): string
	if stageId == "TAHALLUL_AWAL" then
		return "awal"
	end
	return "umrah" -- TAHALLUL, TAHALLUL_UMRAH
end

local function perform(p: Player)
	if performed then
		return
	end
	performed = true
	if mode == "awal" then
		setState(p, "AWAL")
		Notify.toPlayer(
			p,
			"Tahallul AWAL: rambut dicukur. Semua larangan ihram halal KECUALI hubungan suami-istri. Lanjut Tawaf Ifadah."
		)
	else
		setState(p, "COMPLETE")
		Notify.toPlayer(p, "Tahallul: rambut dicukur, ihram dilepas — umrah selesai. Tahallaltum!")
	end
end

function M.init() end

function M.activate(ctx: Ctx.Tahallul?)
	active = true
	performed = false
	player = ctx and ctx.player or nil
	mode = (ctx and ctx.mode) or "umrah"
	station = ctx and ctx.station or nil
	viaUI = (ctx and ctx.viaUI) == true

	if station then
		conns[#conns + 1] = station.Touched:Connect(function(hit)
			local p = Players:GetPlayerFromCharacter(hit.Parent)
			if p and (not player or p == player) then
				perform(p)
			end
		end)
		if player then
			Notify.toPlayer(player, "Menuju tempat cukur untuk tahallul...")
		end
	elseif player and not viaUI then
		-- tanpa station & bukan via UI → langsung (alur otomatis / uji headless).
		perform(player)
	elseif player then
		-- via UI: tunggu tombol "Cukur" (RitualAction "cukur" → M.cukur).
		Notify.toPlayer(player, "Saatnya tahallul — klik tombol Cukur di buku panduan.")
	end
end

-- API publik: lakukan cukur (tahallul) dari TOMBOL UI (RitualAction "cukur"). Aman dipanggil ulang.
function M.cukur()
	if active and not performed and player then
		perform(player)
	end
end

-- LINTAS-AREA: dipanggil place Makkah setelah Tawaf Ifadah selesai (Tamattu'/Ifrad/Qiran).
-- Menaikkan status AWAL → COMPLETE (tahallul tsani). Tidak ada aksi cukur tambahan.
function M.markTsani(p: Player)
	setState(p, "COMPLETE")
	Notify.toPlayer(p, "Tahallul TSANI: seluruh larangan ihram kini halal. Haji menuju paripurna.")
end

function M.deactivate()
	active = false
	Kit.disconnectAll(conns)
end

function M.isDone(): boolean
	return performed
end

return M
