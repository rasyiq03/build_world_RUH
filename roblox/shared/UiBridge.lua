--!strict
-- UiBridge.lua — KONTRAK seam UI↔Logic (satu sumber kebenaran). Nama RemoteEvent (event server→client
-- & intent client→server) + key atribut STATE ter-replikasi + helper fire/get. Server & client SAMA-
-- SAMA require ini supaya tak ada string channel di-hardcode tersebar. Aman headless (pcall).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiBridge = {}

-- Nama RemoteEvent. server→client: Notify, NpcDialog. client→server: StartManasik, RequestTimeSkip, SetWalkSpeed.
UiBridge.EVENTS = {
	Notify = "Notify", -- server→client: pesan feedback (toast+log)
	NpcDialog = "NpcDialog", -- server→client: buka dialog NPC
	StartManasik = "StartManasik", -- client→server: pilih ibadah+miqat (Lobby)
	RequestTimeSkip = "RequestTimeSkip", -- client→server: lewati waktu ritual
	SetWalkSpeed = "SetWalkSpeed", -- client→server: setting kecepatan
	RitualAction = "RitualAction", -- client→server: aksi ritual (wearIhram/makeNiat/throw/dll)
}

-- Key atribut STATE ter-replikasi (server SET, client BACA). PlayerState mencermin PS_<field>.
UiBridge.STATE = {
	stage = "ManasikStage", -- atribut pemain: id tahap Flows berjalan
	ibadah = "ManasikIbadah", -- atribut pemain: jenis ibadah
	day = "ManasikDay", -- atribut Workspace: hari Dzulhijjah
	tahallul = "TahallulState", -- atribut pemain: IHRAM|AWAL|COMPLETE
	psPrefix = "PS_", -- prefix mirror PlayerState (PS_ihramWorn, PS_niat, PS_pebbles, PS_outfit, ...)
}

-- Severity feedback (untuk warna toast).
UiBridge.KIND = { info = "info", warn = "warn", success = "success" }

-- Ambil/buat RemoteEvent by name (idempoten, pcall aman headless).
function UiBridge.remote(name: string): any
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r then
		pcall(function()
			r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = ReplicatedStorage
		end)
	end
	return r
end

-- server→client (satu pemain).
function UiBridge.fireTo(player: any, name: string, ...: any)
	local r = UiBridge.remote(name)
	if r then
		local args = table.pack(...)
		pcall(function()
			r:FireClient(player, table.unpack(args, 1, args.n))
		end)
	end
end

-- server→client (semua).
function UiBridge.fireAll(name: string, ...: any)
	local r = UiBridge.remote(name)
	if r then
		local args = table.pack(...)
		pcall(function()
			r:FireAllClients(table.unpack(args, 1, args.n))
		end)
	end
end

return UiBridge
