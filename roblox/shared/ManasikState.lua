--!strict
-- ManasikState.lua — SPINE game (lihat docs/GAME_DESIGN.md §4).
-- State machine DATA-DRIVEN di atas Flows: tahap saat ini -> place aktif ->
-- mekanisme di-activate -> tunggu selesai -> tahap berikutnya (mungkin teleport).
--
-- Kepemilikan: spine bersama. Ubah signature dgn koordinasi tim.

local Flows = require(script.Parent.Flows)

local ManasikState = {}
ManasikState.__index = ManasikState

export type State = typeof(setmetatable({} :: {
	ibadahType: string,
	chosenMiqat: string,
	flow: { Flows.Stage },
	index: number,
}, ManasikState))

-- ibadahType: "Umrah" | "HajiTamattu" | "HajiIfrad" | "HajiQiran"
-- chosenMiqat: id place miqat pilihan pemain di Lobby (resolusi token "Miqat")
function ManasikState.new(ibadahType: string, chosenMiqat: string): State
	local flow = Flows[ibadahType]
	assert(flow, "Jenis ibadah tak dikenal: " .. tostring(ibadahType))
	return setmetatable({
		ibadahType = ibadahType,
		chosenMiqat = chosenMiqat,
		flow = flow,
		index = 1,
	}, ManasikState)
end

function ManasikState.current(self: State): Flows.Stage?
	return self.flow[self.index]
end

-- Resolve token place ke nama place konkret (Miqat -> miqat pilihan).
function ManasikState.resolvePlace(self: State, stage: Flows.Stage): string
	if stage.place == "Miqat" then
		return self.chosenMiqat
	end
	return stage.place
end

-- Maju ke tahap berikutnya. Kembalikan stage baru, atau nil bila sudah selesai.
function ManasikState.advance(self: State): Flows.Stage?
	if self.index < #self.flow then
		self.index += 1
		return self.flow[self.index]
	end
	return nil
end

function ManasikState.isComplete(self: State): boolean
	return self.index >= #self.flow
end

return ManasikState
