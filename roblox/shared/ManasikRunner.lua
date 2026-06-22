--!strict
-- ManasikRunner.lua — SPINE DRIVER (GAME_DESIGN §4). Menjalankan FLOWS via ManasikState untuk
-- SATU pemain di SATU place:
--   tahap saat ini → resolve place →
--     • place ini  : activate mekanisme (bila ada) → pantau MechanismRegistry.isActiveDone() →
--                    advance ke tahap berikutnya;
--     • place lain : serahkan ke `teleport` (diinject) sambil membawa ManasikState:serialize().
--
-- Seed oleh Nabil (lead, steward shared/). KONTRAK BERSAMA — ubah signature dgn koordinasi.
-- Pemisahan kepemilikan (§9):
--   • Driver tahap↔mekanisme = spine (di sini).
--   • Implementasi `teleport` (Teleport.toPlace) & wiring Lobby→state = DEVI (diinject dari luar).
--   • `buildContext` = pemilik PLACE (mis. Arafah: zona kehadiran utk Wukuf).

local RunService = game:GetService("RunService")
local MechanismRegistry = require(script.Parent.MechanismRegistry)
local Notify = require(script.Parent.Notify)
-- ManasikState hanya untuk tipe; instance state diberikan pemanggil.

local ManasikRunner = {}
ManasikRunner.__index = ManasikRunner

export type Opts = {
	placeName: string,
	player: Player,
	state: any, -- ManasikState.State
	-- ctx mekanisme dari pemilik place (mis. zonePart Arafah). nil → ctx minimal {player, place}.
	buildContext: ((stage: any, state: any, player: Player) -> any)?,
	-- DEVI §9: pindah place membawa SaveData. nil → hanya warn (belum terhubung).
	teleport: ((placeName: string, data: any) -> ())?,
	onComplete: ((player: Player) -> ())?,
}

function ManasikRunner.new(opts: Opts)
	return setmetatable({
		placeName = opts.placeName,
		player = opts.player,
		state = opts.state,
		buildContext = opts.buildContext,
		teleport = opts.teleport,
		onComplete = opts.onComplete,
		_watch = nil,
	}, ManasikRunner)
end

function ManasikRunner._clearWatch(self)
	if self._watch then
		self._watch:Disconnect()
		self._watch = nil
	end
end

function ManasikRunner.start(self)
	self:_enterStage(self.state:current())
end

function ManasikRunner._enterStage(self, stage)
	self:_clearWatch()
	if not stage then
		MechanismRegistry.deactivateCurrent()
		Notify.toPlayer(self.player, "Manasik selesai. Semoga mabrur.")
		if self.onComplete then
			self.onComplete(self.player)
		end
		return
	end

	local resolved = self.state:resolvePlace(stage)
	if resolved ~= self.placeName then
		-- Tahap berikutnya bukan di place ini → hentikan mekanisme & serahkan ke Teleport (Devi).
		MechanismRegistry.deactivateCurrent()
		local data = self.state:serialize()
		if self.teleport then
			self.teleport(resolved, data)
		else
			warn(
				("[ManasikRunner] perlu pindah ke '%s' tapi teleport belum diinject (Devi §9). index=%d"):format(
					resolved,
					data.index
				)
			)
		end
		return
	end

	if stage.ritual then
		local ctx = self.buildContext and self.buildContext(stage, self.state, self.player)
			or { player = self.player, place = resolved }
		MechanismRegistry.activate(stage.ritual, ctx)
		Notify.toPlayer(self.player, ("Tahap: %s — %s"):format(stage.id, stage.ritual))
		self._watch = RunService.Heartbeat:Connect(function()
			if MechanismRegistry.isActiveDone() then
				self:_clearWatch()
				self:_advance()
			end
		end)
	else
		-- Tahap transisi tanpa ritual (mis. KE_MAKKAH bila place-nya sama) → langsung maju.
		self:_advance()
	end
end

function ManasikRunner._advance(self)
	self:_enterStage(self.state:advance())
end

function ManasikRunner.stop(self)
	self:_clearWatch()
	MechanismRegistry.deactivateCurrent()
end

return ManasikRunner
