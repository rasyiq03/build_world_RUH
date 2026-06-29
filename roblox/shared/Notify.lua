--!strict
-- Notify.lua — kanal FEEDBACK ke pemain (mis. "Anda tiba di Miqat Bir Ali", "Tawaf 3/7", peringatan).
-- Mengirim ke client via UiBridge (RemoteEvent "Notify") → ditampilkan client/NotifyClient (toast + log).
-- TETAP `print` juga (debug Studio + terekam harness headless). `kind`: info|warn|success (warna toast).

local UiBridge = require(script.Parent.UiBridge)

local Notify = {}

function Notify.toPlayer(player: Player, message: string, kind: string?)
	print(("[Notify→%s] %s"):format(player.Name, message)) -- debug/headless
	UiBridge.fireTo(player, UiBridge.EVENTS.Notify, message, kind or UiBridge.KIND.info)
end

function Notify.toAll(message: string, kind: string?)
	print(("[Notify→ALL] %s"):format(message))
	UiBridge.fireAll(UiBridge.EVENTS.Notify, message, kind or UiBridge.KIND.info)
end

return Notify
