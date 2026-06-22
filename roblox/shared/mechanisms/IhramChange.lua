--!strict
-- IhramChange.lua — ganti kostum ihram + niat di Miqat. Pemilik: Devi. Kontrak: _TEMPLATE.lua.
--
-- Dua langkah → selesai:
--   1) KENAKAN kain ihram (2 helai putih tanpa jahitan; pria kepala terbuka).
--   2) NIAT sesuai jenis ibadah (Umrah / Haji / Qiran=keduanya).
-- isDone() true setelah keduanya. Setelah niat, pemain MASUK keadaan ihram → larangan berlaku
-- (lihat mechanisms/IhramRules). Modul ini hanya menandai; spine/place yang menyalakan IhramRules.
--
-- KOSTUM: di game asli ganti penampilan via Humanoid:ApplyDescription / Shirt+Pants ihram. Bagian
-- visual dijaga pcall (kelas mungkin tak ada headless) — logika langkah tetap berjalan.
--
-- ctx:
--   ctx.player     : Player
--   ctx.ibadahType : "Umrah"|"HajiTamattu"|"HajiIfrad"|"HajiQiran" (dari ManasikState). Menentukan niat.
--   ctx.config     : { auto: boolean? }?  auto=true → langsung selesai (untuk uji alur spine).

local Notify = require(script.Parent.Parent.Notify)

local Ctx = require(script.Parent.Parent.Ctx)

local M = {}
M.id = "IhramChange"

-- Lafaz niat per jenis ibadah (ringkas; teks lengkap bisa ditambah di UI Panduan).
local NIAT = {
	Umrah = "Labbaika 'umratan — niat UMRAH.",
	HajiTamattu = "Labbaika 'umratan — niat UMRAH (tamattu', haji menyusul setelah tahallul).",
	HajiIfrad = "Labbaika hajjan — niat HAJI (ifrad).",
	HajiQiran = "Labbaika hajjan wa 'umratan — niat HAJI & UMRAH sekaligus (qiran).",
}

-- state
local active = false
local player: Player? = nil
local ibadahType = "Umrah"
local worn = false
local niatDone = false

local function notify(msg: string)
	if player then
		Notify.toPlayer(player, msg)
	end
end

-- Terapkan penampilan ihram (kosmetik). Aman dipanggil headless.
local function applyIhramAppearance()
	local p = player
	if not p then return end
	pcall(function()
		local char = p.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			-- Placeholder: di Studio, ganti dgn HumanoidDescription kain ihram. Tandai via atribut.
			char:SetAttribute("Ihram", true)
		end
	end)
end

-- API publik: kenakan kain ihram.
function M.wearIhram()
	if not active or worn then return end
	worn = true
	applyIhramAppearance()
	notify("Kain ihram dikenakan (2 helai putih tanpa jahitan). Selanjutnya: niat.")
end

-- API publik: ucapkan/teguhkan niat.
function M.makeNiat()
	if not active or niatDone then return end
	if not worn then
		notify("Kenakan kain ihram dulu sebelum niat.")
		return
	end
	niatDone = true
	notify(NIAT[ibadahType] or NIAT.Umrah)
	notify("Anda kini dalam keadaan IHRAM — perhatikan larangan ihram.")
end

function M.init() end

function M.activate(ctx: Ctx.IhramChange?)
	active = true
	worn = false
	niatDone = false
	player = ctx and ctx.player or nil
	ibadahType = (ctx and ctx.ibadahType) or "Umrah"

	notify("Di Miqat: kenakan kain ihram lalu berniat. (Langkah: wearIhram → makeNiat.)")

	-- Mode auto utk uji alur spine (tanpa interaksi pemain).
	if ctx and ctx.config and ctx.config.auto then
		M.wearIhram()
		M.makeNiat()
	end
end

function M.deactivate()
	active = false
end

-- Status untuk debug/uji.
function M.isWorn(): boolean
	return worn
end

function M.isDone(): boolean
	return worn and niatDone
end

return M
