--!strict
-- IhramHaji.lua — NIAT haji + (kembali) mengenakan ihram. Dipakai HajiTamattu IHRAM_HAJI
-- (Makkah, 8 Dzulhijjah): setelah tahallul umrah, jamaah berihram LAGI untuk haji.
-- Aksi: konfirmasi NIAT (sentuh titik ihram / dipicu tombol UI). Mengembalikan status ihram
-- pemain → "IHRAM" (selaras Tahallul.getState, karena masuk ihram lagi). Ganti KOSTUM ihram =
-- IhramChange (Devi); modul ini fokus NIAT + status. Pemilik: Nabil. Kontrak: _TEMPLATE.lua.
--
-- ctx (disusun place Makkah=Devi):
--   ctx.player  : Player
--   ctx.station : BasePart?  titik niat/ihram; sentuh untuk melakukan. nil → langsung.

local Notify = require(script.Parent.Parent.Notify)
local Players = game:GetService("Players")
local Kit = require(script.Parent._MechanismKit)

local M = {}
M.id = "IhramHaji"

local active = false
local performed = false
local player: Player? = nil
local station: BasePart? = nil
local conns: { any } = {}

local function perform(p: Player)
	if performed then
		return
	end
	performed = true
	local pa = p :: any
	if pa.SetAttribute then
		pa:SetAttribute("TahallulState", "IHRAM") -- masuk ihram lagi untuk haji
		pa:SetAttribute("NiatHaji", true)
	end
	Notify.toPlayer(p, 'Niat haji + berihram. "Labbaik Allahumma hajjan." (kostum ihram: IhramChange/Devi)')
end

function M.init() end

function M.activate(ctx: any?)
	active = true
	performed = false
	player = ctx and ctx.player or nil
	station = ctx and ctx.station or nil

	if station then
		conns[#conns + 1] = station.Touched:Connect(function(hit)
			local p = Players:GetPlayerFromCharacter(hit.Parent)
			if p and (not player or p == player) then
				perform(p)
			end
		end)
		if player then
			Notify.toPlayer(player, "Menuju titik ihram untuk niat haji...")
		end
	elseif player then
		perform(player)
	end
end

function M.deactivate()
	active = false
	Kit.disconnectAll(conns)
end

function M.isDone(): boolean
	return performed
end

return M
