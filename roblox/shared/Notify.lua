--!strict
-- Notify.lua — notifikasi/panduan ke pemain (mis. "Anda tiba di Miqat Bir Ali",
-- "Tawaf 3/7"). Stub: kirim teks; UI sebenarnya digarap sisi client (Devi: UI Panduan).
-- TODO: ganti print dgn RemoteEvent -> GUI client.

local Notify = {}

function Notify.toPlayer(player: Player, message: string)
	-- TODO: FireClient ke GUI. Sementara: log.
	print(("[Notify→%s] %s"):format(player.Name, message))
end

function Notify.toAll(message: string)
	for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
		Notify.toPlayer(p, message)
	end
end

return Notify
