--!strict
-- _TEMPLATE.lua — KONTRAK mekanisme (lihat docs/GAME_DESIGN.md §6).
-- Salin file ini, ganti nama (TANPA awalan "_"), isi bodinya.
-- MechanismRegistry memuat semua file di folder ini KECUALI yang berawalan "_".
--
-- ctx = { player = Player, place = string, ... } (disusun pemanggil = server/PlaceContext).
-- TIPE ctx: definisikan/ pakai dari shared/Ctx.lua (mis. `function M.activate(ctx: Ctx.Tawaf?)`),
-- supaya salah-eja field ketahuan luau-analyze. Mekanisme baru: tambah tipe di Ctx.lua lalu pakai.

local M = {}

M.id = "TEMPLATE" -- WAJIB unik; dipakai di Flows.lua (kolom `ritual`).

-- Dipanggil sekali saat place load (pasang trigger, ambil referensi objek).
function M.init() end

-- Dipanggil saat tahap manasik mengaktifkan mekanisme ini.
function M.activate(ctx: any?) end

-- Dipanggil saat tahap selesai / pindah place (lepas koneksi, sembunyikan UI).
function M.deactivate() end

-- Untuk Stage dgn next = "on_ritual_done": true bila ritual sudah tuntas.
function M.isDone(): boolean
	return false
end

return M
