--!strict
-- TriggerZone.lua — util zona pemicu (dipakai semua: kedatangan player,
-- notifikasi miqat, area ritual). Buat dari sebuah Part (Anchored, CanCollide=false).
-- TODO: pertimbangkan pakai library ZonePlus bila butuh deteksi lebih akurat.

local TriggerZone = {}
TriggerZone.__index = TriggerZone

-- part: Part penanda area. onEnter(player): dipanggil sekali saat player masuk.
function TriggerZone.new(part: BasePart, onEnter: (Player) -> ())
	local self = setmetatable({ _part = part, _conn = nil, _seen = {} }, TriggerZone)
	self._conn = part.Touched:Connect(function(hit)
		local char = hit.Parent
		local player = char and game:GetService("Players"):GetPlayerFromCharacter(char)
		if player and not self._seen[player] then
			self._seen[player] = true
			onEnter(player)
		end
	end)
	return self
end

function TriggerZone.destroy(self)
	if self._conn then self._conn:Disconnect() end
end

return TriggerZone
