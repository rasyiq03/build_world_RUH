--!strict
-- PebbleCollect.lua — ambil 7 kerikil di Muzdalifah (Masy'aril Haram) untuk Jumrah.
-- Pemain memungut kerikil dengan menyentuhnya; selesai bila terkumpul = target. Pemilik: Nabil.
-- Kontrak: mechanisms/_TEMPLATE.lua.
--
-- Catatan fikih: 7 kerikil = minimum (Jumrah Aqabah hari 10). Hari 11–13 butuh lebih banyak
-- (21/hari); itu disuplai ulang/diperbanyak di mekanisme JumrahThrow (Praditama) bila perlu.
--
-- ctx (disusun PlaceContext.Muzdalifah):
--   ctx.player  : Player
--   ctx.pebbles : { BasePart }  daftar part kerikil yang bisa dipungut.
--   ctx.config  : { target: number? }?  default DEFAULT_TARGET.

local Players = game:GetService("Players")
local Notify = require(script.Parent.Parent.Notify)
local Kit = require(script.Parent._MechanismKit)

local Ctx = require(script.Parent.Parent.Ctx)
local PlayerState = require(script.Parent.Parent.PlayerState)

local M = {}
M.id = "PebbleCollect"

local DEFAULT_TARGET = 7

local active = false
local collected = 0
local target = DEFAULT_TARGET
local player: Player? = nil
local picked: { [any]: boolean } = {}
local conns: { any } = {}

function M.init() end

function M.activate(ctx: Ctx.Pebble?)
	active = true
	collected = 0
	picked = {}
	player = ctx and ctx.player or nil
	target = (ctx and ctx.config and ctx.config.target) or DEFAULT_TARGET

	local pebbles = ctx and ctx.pebbles
	if not pebbles or #pebbles == 0 then
		warn("[PebbleCollect] tanpa ctx.pebbles — tak ada kerikil untuk dipungut.")
	else
		for _, peb in ipairs(pebbles) do
			conns[#conns + 1] = peb.Touched:Connect(function(hit)
				local p = Players:GetPlayerFromCharacter(hit.Parent)
				if not (active and p and (not player or p == player)) then
					return
				end
				if picked[peb] or collected >= target then
					return
				end
				-- NON-KONSUMTIF: kerikil TIDAK disembunyikan/dihapus — tanah Muzdalifah berkerikil tak
				-- habis. Memungut hanya menambah counter; kerikil tetap ada untuk pemain lain. `picked`
				-- mencegah satu kerikil yang sama dihitung dua kali oleh pemain ini.
				picked[peb] = true
				collected += 1
				PlayerState.set(p, "pebbles", collected)
				Notify.toPlayer(p, ("Kerikil %d/%d terkumpul."):format(collected, target))
				if collected >= target then
					Notify.toPlayer(p, ("%d kerikil siap untuk Jumrah. Bersiap ke Mina."):format(target))
				end
			end)
		end
	end

	if player then
		Notify.toPlayer(player, ("Kumpulkan %d kerikil di Muzdalifah (Masy'aril Haram)."):format(target))
	end
end

function M.collectedCount(): number
	return collected
end

function M.deactivate()
	active = false
	Kit.disconnectAll(conns)
end

function M.isDone(): boolean
	return collected >= target
end

return M
