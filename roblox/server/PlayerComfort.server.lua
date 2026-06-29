--!strict
-- PlayerComfort.server.lua — setting KECEPATAN JALAN pemain (SYSTEMS_DESIGN §4). Zona ~16k studs →
-- pemain perlu opsi cepat. DIPISAH dari waktu: ubah speed TIDAK menyentuh timer/jam ritual (jam &
-- ritual tetap otoritatif). Client kirim via RemoteEvent "SetWalkSpeed"; preferensi disimpan atribut.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DEFAULT_SPEED = 16
local MIN_SPEED, MAX_SPEED = 8, 60

local remote = ReplicatedStorage:FindFirstChild("SetWalkSpeed")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "SetWalkSpeed"
	remote.Parent = ReplicatedStorage
end

local function applySpeed(player: Player, speed: any)
	local v = math.clamp(tonumber(speed) or DEFAULT_SPEED, MIN_SPEED, MAX_SPEED)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		(hum :: Humanoid).WalkSpeed = v
	end
	player:SetAttribute("WalkSpeedPref", v)
end

(remote :: RemoteEvent).OnServerEvent:Connect(function(player: Player, speed: any)
	applySpeed(player, speed)
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		applySpeed(player, player:GetAttribute("WalkSpeedPref") or DEFAULT_SPEED)
	end)
end)

print("[PlayerComfort] siap — RemoteEvent SetWalkSpeed (8..60). Speed terpisah dari waktu ritual.")
