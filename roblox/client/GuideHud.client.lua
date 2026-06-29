--!strict
-- GuideHud.client.lua — HUD pemain (SYSTEMS_DESIGN §3): JAM (hari+jam+fase) + STATUS kepatuhan
-- (lembut) + BUKU PANDUAN portable (toggle G) per tahap + tombol TIME-SKIP (ritual-tunggu) + setting
-- KECEPATAN. Membaca data ter-replikasi (Lighting.ClockTime, atribut pemain/Workspace) — tak akses
-- state server langsung. Taruh di StarterPlayerScripts. UI: Devi.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Clock = require(Shared:WaitForChild("ManasikClock"))
local GuideContent = require(Shared:WaitForChild("GuideContent"))
local UiBridge = require(Shared:WaitForChild("UiBridge"))

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local skipRemote = ReplicatedStorage:WaitForChild(UiBridge.EVENTS.RequestTimeSkip)
local speedRemote = ReplicatedStorage:WaitForChild(UiBridge.EVENTS.SetWalkSpeed)

-- Aksi ritual per KELUARGA tahap (klik → INTENT RitualAction). RitualAction dibuat server di place ritual
-- (di-FindFirstChild lazy: di Lobby tak ada → tombol tak muncul karena tak ada stage ritual).
local ACTIONS = {
	ihram = { { l = "Kenakan Ihram", a = "wearIhram" }, { l = "Niat", a = "makeNiat" } },
	bus = { { l = "Naik Bus", a = "board" } },
	jumrah = {
		{ l = "Lempar Ula", a = "throw", args = { "Ula" } },
		{ l = "Lempar Wustha", a = "throw", args = { "Wustha" } },
		{ l = "Lempar Aqabah", a = "throw", args = { "Aqabah" } },
		{ l = "Nafar Awwal", a = "chooseNafar", args = { "awwal" } },
		{ l = "Nafar Tsani", a = "chooseNafar", args = { "tsani" } },
	},
	qurban = { { l = "Sembelih Hadyu", a = "beginSacrifice", args = { "kambing" } } },
	tahallul = { { l = "Cukur (Tahallul)", a = "cukur" } },
}
local function fireAction(action: string, args: any)
	local r = ReplicatedStorage:FindFirstChild(UiBridge.EVENTS.RitualAction)
	if r then
		r:FireServer(action, table.unpack(args or {}))
	end
end

-- Keluarga tahap yang punya time-skip (ritual-tunggu).
local SKIPPABLE = { wukuf = true, muzdalifah = true, mabit_mina = true }

-- ── GUI ──
local gui = Instance.new("ScreenGui")
gui.Name = "GuideHud"
gui.ResetOnSpawn = false
gui.Parent = pg

local function label(parent, size, pos, txt, sz, bold)
	local l = Instance.new("TextLabel")
	l.Size = size; l.Position = pos
	l.BackgroundTransparency = 1
	l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	l.TextSize = sz or 15
	l.TextColor3 = Color3.fromRGB(240, 240, 245)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = txt or ""
	l.Parent = parent
	return l
end

-- Panel jam + status (kanan atas)
local top = Instance.new("Frame")
top.Size = UDim2.fromOffset(300, 56)
top.Position = UDim2.new(1, -312, 0, 12)
top.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
top.BackgroundTransparency = 0.15
top.BorderSizePixel = 0
top.Parent = gui
Instance.new("UICorner").Parent = top
local clockLbl = label(top, UDim2.new(1, -16, 0, 24), UDim2.fromOffset(10, 6), "—", 16, true)
clockLbl.TextColor3 = Color3.fromRGB(240, 210, 120)
local statusLbl = label(top, UDim2.new(1, -16, 0, 20), UDim2.fromOffset(10, 30), "—", 13)

-- Tombol buka panduan (kiri bawah)
local openBtn = Instance.new("TextButton")
openBtn.Size = UDim2.fromOffset(150, 34)
openBtn.Position = UDim2.new(0, 12, 1, -46)
openBtn.BackgroundColor3 = Color3.fromRGB(46, 54, 70)
openBtn.BorderSizePixel = 0
openBtn.Font = Enum.Font.GothamBold
openBtn.TextSize = 14
openBtn.TextColor3 = Color3.fromRGB(235, 235, 240)
openBtn.Text = "📖 Panduan (G)"
Instance.new("UICorner").Parent = openBtn
openBtn.Parent = gui

-- Panel panduan (tengah kiri, awalnya tersembunyi)
local panel = Instance.new("Frame")
panel.Size = UDim2.fromScale(0.34, 0.6)
panel.Position = UDim2.fromScale(0.02, 0.2)
panel.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
Instance.new("UICorner").Parent = panel
local gTitle = label(panel, UDim2.new(1, -20, 0, 30), UDim2.fromOffset(14, 10), "", 19, true)
gTitle.TextColor3 = Color3.fromRGB(240, 210, 120)
local gBody = label(panel, UDim2.new(1, -28, 1, -210), UDim2.fromOffset(14, 44), "", 15)
gBody.TextWrapped = true
gBody.TextYAlignment = Enum.TextYAlignment.Top

-- Baris tombol AKSI ritual (diisi per tahap di refreshGuide)
local actionRow = Instance.new("Frame")
actionRow.Size = UDim2.new(1, -28, 0, 90)
actionRow.Position = UDim2.new(0, 14, 1, -204)
actionRow.BackgroundTransparency = 1
actionRow.Parent = panel
local ag = Instance.new("UIGridLayout")
ag.CellSize = UDim2.fromOffset(150, 26)
ag.CellPadding = UDim2.fromOffset(6, 6)
ag.Parent = actionRow

-- Tombol aksi (bawah panel): time-skip + speed
local skipBtn = Instance.new("TextButton")
skipBtn.Size = UDim2.new(1, -28, 0, 32)
skipBtn.Position = UDim2.new(0, 14, 1, -68)
skipBtn.BackgroundColor3 = Color3.fromRGB(70, 110, 90)
skipBtn.BorderSizePixel = 0
skipBtn.Font = Enum.Font.GothamBold
skipBtn.TextSize = 14
skipBtn.TextColor3 = Color3.fromRGB(235, 245, 235)
skipBtn.Text = "⏩ Lewati waktu (time-skip)"
skipBtn.Visible = false
Instance.new("UICorner").Parent = skipBtn
skipBtn.Parent = panel
skipBtn.Activated:Connect(function()
	skipRemote:FireServer()
end)

local speedRow = Instance.new("Frame")
speedRow.Size = UDim2.new(1, -28, 0, 28)
speedRow.Position = UDim2.new(0, 14, 1, -32)
speedRow.BackgroundTransparency = 1
speedRow.Parent = panel
local sl = Instance.new("UIListLayout")
sl.FillDirection = Enum.FillDirection.Horizontal
sl.Padding = UDim.new(0, 6)
sl.Parent = speedRow
for _, opt in ipairs({ { "Jalan", 16 }, { "Cepat", 32 }, { "Kilat", 50 } }) do
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(80, 28)
	b.BackgroundColor3 = Color3.fromRGB(46, 54, 70)
	b.BorderSizePixel = 0
	b.Font = Enum.Font.Gotham
	b.TextSize = 13
	b.TextColor3 = Color3.fromRGB(230, 230, 235)
	b.Text = opt[1]
	Instance.new("UICorner").Parent = b
	b.Parent = speedRow
	b.Activated:Connect(function()
		speedRemote:FireServer(opt[2])
	end)
end

-- ── update fungsi ──
local function refreshClock()
	local hour = Lighting.ClockTime
	local day = workspace:GetAttribute("ManasikDay") or 8
	local hh = math.floor(hour)
	local mm = math.floor((hour - hh) * 60)
	clockLbl.Text = ("%s Dzulhijjah · %02d:%02d (%s)"):format(tostring(day), hh, mm, Clock.phaseFor(hour))
end

local function mark(b) return b and "✓" or "✗" end
local function refreshStatus()
	local function a(k) return player:GetAttribute(k) end
	statusLbl.Text = ("Ihram %s · Niat %s · Kerikil %s · %s"):format(
		mark(a("PS_ihramWorn")), mark(a("PS_niat")), tostring(a("PS_pebbles") or 0),
		tostring(a("TahallulState") or "IHRAM"))
end

local function refreshGuide()
	local stageId = player:GetAttribute("ManasikStage")
	local e = GuideContent.forStage(stageId)
	gTitle.Text = e.title
	local lines = {}
	for i, s in ipairs(e.steps) do lines[#lines + 1] = ("%d. %s"):format(i, s) end
	if e.niat then lines[#lines + 1] = "\n🕋 Niat: " .. e.niat end
	if e.dua then lines[#lines + 1] = "\n🤲 " .. e.dua end
	if e.donts then lines[#lines + 1] = "\n🚫 Larangan: " .. table.concat(e.donts, "; ") end
	gBody.Text = table.concat(lines, "\n")
	-- time-skip hanya untuk ritual-tunggu
	skipBtn.Visible = stageId ~= nil and SKIPPABLE[GuideContent.family(stageId)] == true
	-- tombol aksi ritual per keluarga tahap
	for _, c in ipairs(actionRow:GetChildren()) do
		if c:IsA("TextButton") then c:Destroy() end
	end
	local acts = stageId and ACTIONS[GuideContent.family(stageId)]
	if acts then
		for _, act in ipairs(acts) do
			local b = Instance.new("TextButton")
			b.BackgroundColor3 = Color3.fromRGB(60, 90, 120)
			b.BorderSizePixel = 0
			b.Font = Enum.Font.GothamMedium
			b.TextSize = 13
			b.TextColor3 = Color3.fromRGB(235, 235, 240)
			b.Text = act.l
			Instance.new("UICorner").Parent = b
			b.Parent = actionRow
			b.Activated:Connect(function()
				fireAction(act.a, act.args)
			end)
		end
	end
end

-- ── koneksi ──
Lighting:GetPropertyChangedSignal("ClockTime"):Connect(refreshClock)
player:GetAttributeChangedSignal("ManasikStage"):Connect(refreshGuide)
for _, k in ipairs({ "PS_ihramWorn", "PS_niat", "PS_pebbles", "TahallulState" }) do
	player:GetAttributeChangedSignal(k):Connect(refreshStatus)
end
local function toggle()
	panel.Visible = not panel.Visible
	if panel.Visible then refreshGuide() end
end
openBtn.Activated:Connect(toggle)
UserInputService.InputBegan:Connect(function(input, gp)
	if not gp and input.KeyCode == Enum.KeyCode.G then toggle() end
end)

refreshClock()
refreshStatus()
refreshGuide()
