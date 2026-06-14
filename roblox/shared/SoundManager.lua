--!strict
-- SoundManager.lua — adzan, suara jamaah, ambience per place (lihat GAME_DESIGN §3, Devi).
-- Stub: putar Sound dari id. TODO: ambience per zona + transisi halus.

local SoundManager = {}

-- Putar sound (mis. adzan) one-shot di seluruh game.
function SoundManager.play(soundId: string, looped: boolean?)
	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Looped = looped or false
	s.Parent = workspace
	s:Play()
	if not s.Looped then
		s.Ended:Connect(function() s:Destroy() end)
	end
	return s
end

return SoundManager
