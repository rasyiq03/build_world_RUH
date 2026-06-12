--[[ nav_guide.lua — LocalScript (taruh di StarterPlayer > StarterPlayerScripts)

  Penunjuk navigasi MELAYANG untuk manasik: panah arah + jarak (meter) + ETA,
  mengikuti jalur rute (ModuleScript "MinaRoute" di ReplicatedStorage).
  WalkSpeed realistis; tahan SHIFT = PERCEPAT (ETA ikut memendek otomatis).

  Skala dunia: 4 studs = 1 meter (skala 4).
]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local SCALE = 4              -- studs per meter
local WALK_REAL = 6          -- ~1.5 m/s (realistis)
local WALK_FAST = 24         -- percepat ~6 m/s
local REACH = 30             -- jarak dianggap "sampai" waypoint (studs)

local player = Players.LocalPlayer

-- Ambil jalur navigasi: segmen ritual Mina (utamakan yang ada "Jumrah").
local routeMod = RS:FindFirstChild("MinaRoute")
if not routeMod then warn("[Nav] 'MinaRoute' tak ada."); return end
local data = HttpService:JSONDecode(require(routeMod))
local seg
for _, s in ipairs(data.segments or {}) do
	if string.find(s.ritual or "", "Jumrah") then seg = s; break end
end
seg = seg or (data.segments and data.segments[1])
if not seg or not seg.path or #seg.path < 2 then warn("[Nav] jalur kosong."); return end

local WP = seg.path                       -- {x,z,tunnel}
local target = seg.ritual ~= "" and seg.ritual or ("menuju " .. (seg.to or "tujuan"))

-- Jarak kumulatif sisa dari tiap waypoint ke akhir (studs).
local cum = {}
do
	cum[#WP] = 0
	for i = #WP - 1, 1, -1 do
		local a, b = WP[i], WP[i + 1]
		cum[i] = cum[i + 1] + math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
	end
end

-- ===== GUI =====
local gui = Instance.new("ScreenGui")
gui.Name = "NavGuide"; gui.ResetOnSpawn = false; gui.Parent = player:WaitForChild("PlayerGui")
local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0); frame.Position = UDim2.new(0.5, 0, 0, 12)
frame.Size = UDim2.new(0, 280, 0, 64); frame.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
frame.BackgroundTransparency = 0.15; frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
local arrow = Instance.new("TextLabel")
arrow.BackgroundTransparency = 1; arrow.Size = UDim2.new(0, 48, 1, 0); arrow.Position = UDim2.new(0, 6, 0, 0)
arrow.Text = "➤"; arrow.TextScaled = true; arrow.TextColor3 = Color3.fromRGB(120, 220, 120); arrow.Parent = frame
local lblTarget = Instance.new("TextLabel")
lblTarget.BackgroundTransparency = 1; lblTarget.Position = UDim2.new(0, 58, 0, 6); lblTarget.Size = UDim2.new(1, -64, 0, 24)
lblTarget.Font = Enum.Font.GothamBold; lblTarget.TextSize = 15; lblTarget.TextXAlignment = Enum.TextXAlignment.Left
lblTarget.TextColor3 = Color3.fromRGB(240, 240, 240); lblTarget.Text = target; lblTarget.Parent = frame
local lblInfo = Instance.new("TextLabel")
lblInfo.BackgroundTransparency = 1; lblInfo.Position = UDim2.new(0, 58, 0, 30); lblInfo.Size = UDim2.new(1, -64, 0, 26)
lblInfo.Font = Enum.Font.Gotham; lblInfo.TextSize = 14; lblInfo.TextXAlignment = Enum.TextXAlignment.Left
lblInfo.TextColor3 = Color3.fromRGB(200, 210, 230); lblInfo.Text = "..."; lblInfo.Parent = frame

-- ===== WalkSpeed + percepat =====
local function hum()
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end
local fast = false
UIS.InputBegan:Connect(function(i, gp) if not gp and i.KeyCode == Enum.KeyCode.LeftShift then fast = true end end)
UIS.InputEnded:Connect(function(i) if i.KeyCode == Enum.KeyCode.LeftShift then fast = false end end)

local idx = 1
RunService.Heartbeat:Connect(function()
	local h = hum(); if not h then return end
	local hrp = h.Parent and h.Parent:FindFirstChild("HumanoidRootPart"); if not hrp then return end
	local speed = fast and WALK_FAST or WALK_REAL
	h.WalkSpeed = speed
	local pos = hrp.Position

	-- maju waypoint bila sudah dekat
	while idx < #WP do
		local w = WP[idx]
		if (Vector3.new(w.x, pos.Y, w.z) - pos).Magnitude < REACH then idx += 1 else break end
	end
	local w = WP[idx]
	local wpos = Vector3.new(w.x, pos.Y, w.z)

	-- jarak sisa = ke waypoint + kumulatif sesudahnya
	local rem = (wpos - pos).Magnitude + (cum[idx] or 0)
	local meters = rem / SCALE
	local eta = rem / speed  -- detik
	local mm = math.floor(eta / 60); local ss = math.floor(eta % 60)
	lblInfo.Text = string.format("%d m  •  ±%d:%02d%s", math.floor(meters), mm, ss, fast and "  (cepat)" or "")

	-- rotasi panah relatif kamera
	local cam = workspace.CurrentCamera
	if cam then
		local rel = cam.CFrame:VectorToObjectSpace(wpos - pos)
		arrow.Rotation = math.deg(math.atan2(rel.X, -rel.Z))
	end
	if idx >= #WP and (wpos - pos).Magnitude < REACH then
		lblTarget.Text = "Tiba: " .. target
		lblInfo.Text = "lanjut ritual berikutnya"
	end
end)
print("[Nav] panduan aktif: " .. target)
