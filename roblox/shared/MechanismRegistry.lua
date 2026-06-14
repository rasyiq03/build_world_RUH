--!strict
-- MechanismRegistry.lua — memuat semua modul di shared/mechanisms/ lalu
-- activate/deactivate sesuai tahap manasik (lihat docs/GAME_DESIGN.md §6).
--
-- Modul mekanisme harus mematuhi kontrak di mechanisms/_TEMPLATE.lua.

local mechanismsFolder = script.Parent:WaitForChild("mechanisms")

local Registry = {}
Registry._mods = {} :: { [string]: any }
Registry._active = nil :: any

-- Muat semua ModuleScript di mechanisms/ (abaikan yang berawalan "_", mis. _TEMPLATE).
function Registry.load()
	for _, m in ipairs(mechanismsFolder:GetChildren()) do
		if m:IsA("ModuleScript") and m.Name:sub(1, 1) ~= "_" then
			local ok, mod = pcall(require, m)
			if ok and type(mod) == "table" and mod.id then
				Registry._mods[mod.id] = mod
				if mod.init then mod.init() end
			else
				warn("[MechanismRegistry] gagal memuat: " .. m.Name)
			end
		end
	end
end

-- Aktifkan mekanisme `id` untuk tahap saat ini (menonaktifkan yang sebelumnya).
function Registry.activate(id: string, ctx: any?)
	Registry.deactivateCurrent()
	local mod = Registry._mods[id]
	if not mod then
		warn("[MechanismRegistry] mekanisme tak terdaftar: " .. tostring(id))
		return
	end
	if mod.activate then mod.activate(ctx) end
	Registry._active = mod
end

function Registry.deactivateCurrent()
	if Registry._active and Registry._active.deactivate then
		Registry._active.deactivate()
	end
	Registry._active = nil
end

-- Untuk Stage.next == "on_ritual_done": apakah mekanisme aktif sudah selesai?
function Registry.isActiveDone(): boolean
	if Registry._active and Registry._active.isDone then
		return Registry._active.isDone()
	end
	return true
end

return Registry
