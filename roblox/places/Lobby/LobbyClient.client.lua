--!strict
-- LobbyClient.client.lua — GUI PEMILIH di Lobby (GAME_DESIGN §2.1). Pemain pilih JENIS IBADAH + MIQAT
-- → tombol "Mulai" → fire INTENT StartManasik(ibadahType, chosenMiqat) (kontrak UiBridge). Server
-- (LobbyServer) memvalidasi (LobbyStart) lalu Teleport ke miqat. Taruh di StarterPlayerScripts (place Lobby).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiBridge = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiBridge"))
local startRemote = ReplicatedStorage:WaitForChild(UiBridge.EVENTS.StartManasik)
local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

-- Data pilihan (key = kunci Flows / LobbyStart.MIQATS).
local IBADAH = {
	{ key = "Umrah", label = "Umrah", desc = "Ihram → Tawaf → Sa'i → Tahallul." },
	{ key = "HajiTamattu", label = "Haji Tamattu'", desc = "Umrah penuh dulu, lalu haji. Wajib dam (hadyu)." },
	{ key = "HajiIfrad", label = "Haji Ifrad", desc = "Haji saja, tanpa umrah. Tanpa dam." },
	{ key = "HajiQiran", label = "Haji Qiran", desc = "Umrah + haji sekaligus, 1 ihram. Wajib dam." },
}
local MIQAT = {
	{ key = "Miqat_BirAli", label = "Bir Ali (Dzulhulaifah)", wave = "Gel. I — via Madinah" },
	{ key = "Miqat_Yalamlam", label = "Yalamlam", wave = "Gel. II — langsung Makkah" },
	{ key = "Miqat_QarnulManazil", label = "Qarnul Manazil (As-Sayl)", wave = "Gel. II / Najd" },
	{ key = "Miqat_Juhfah", label = "Juhfah (Rabigh)", wave = "Mesir / Syam" },
	{ key = "Miqat_DzatuIrq", label = "Dzatu 'Irq", wave = "Iraq" },
}

local chosenIbadah: string? = nil
local chosenMiqat: string? = nil

-- ── GUI ──
local gui = Instance.new("ScreenGui")
gui.Name = "LobbyGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = pg

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(12, 16, 24)
bg.BackgroundTransparency = 0.15
bg.BorderSizePixel = 0
bg.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 50)
title.Position = UDim2.fromOffset(0, 24)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 30
title.TextColor3 = Color3.fromRGB(240, 210, 120)
title.Text = "RUH — Pilih Ibadah & Miqat"
title.Parent = bg

local function header(txt, y)
	local h = Instance.new("TextLabel")
	h.Size = UDim2.new(1, -80, 0, 26); h.Position = UDim2.fromOffset(40, y)
	h.BackgroundTransparency = 1; h.Font = Enum.Font.GothamBold; h.TextSize = 18
	h.TextColor3 = Color3.fromRGB(220, 220, 230); h.TextXAlignment = Enum.TextXAlignment.Left
	h.Text = txt; h.Parent = bg
	return h
end

local mulaiBtn -- fwd

local function refreshMulai()
	local ready = chosenIbadah ~= nil and chosenMiqat ~= nil
	mulaiBtn.AutoButtonColor = ready
	mulaiBtn.BackgroundColor3 = ready and Color3.fromRGB(40, 120, 70) or Color3.fromRGB(50, 56, 66)
	mulaiBtn.Text = ready and "▶ Mulai Manasik" or "Pilih ibadah & miqat dulu"
end

-- Bangun baris kartu pilihan; onPick(key) + highlight eksklusif.
local function buildRow(items, y, height, onPick): { [string]: TextButton }
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -80, 0, height); row.Position = UDim2.fromOffset(40, y)
	row.BackgroundTransparency = 1; row.Parent = bg
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 10); layout.Parent = row
	local btns: { [string]: TextButton } = {}
	for _, it in ipairs(items) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, 220, 1, 0)
		b.BackgroundColor3 = Color3.fromRGB(34, 40, 52)
		b.BorderSizePixel = 0; b.AutoButtonColor = true
		b.Font = Enum.Font.Gotham; b.TextYAlignment = Enum.TextYAlignment.Top
		b.TextXAlignment = Enum.TextXAlignment.Left; b.TextWrapped = true
		b.TextSize = 14; b.TextColor3 = Color3.fromRGB(235, 235, 240)
		b.Text = ("  %s\n  %s"):format(it.label, it.desc or it.wave or "")
		Instance.new("UICorner").Parent = b
		b.Parent = row
		btns[it.key] = b
		b.Activated:Connect(function()
			for k, other in pairs(btns) do
				other.BackgroundColor3 = (k == it.key) and Color3.fromRGB(40, 90, 120) or Color3.fromRGB(34, 40, 52)
			end
			onPick(it.key)
			refreshMulai()
		end)
	end
	return btns
end

header("1. Jenis Ibadah", 84)
buildRow(IBADAH, 112, 70, function(k) chosenIbadah = k end)

header("2. Miqat (titik mulai ihram)", 200)
buildRow(MIQAT, 228, 64, function(k) chosenMiqat = k end)

mulaiBtn = Instance.new("TextButton")
mulaiBtn.Size = UDim2.fromOffset(300, 48)
mulaiBtn.Position = UDim2.new(0.5, -150, 0, 320)
mulaiBtn.BorderSizePixel = 0
mulaiBtn.Font = Enum.Font.GothamBold
mulaiBtn.TextSize = 18
mulaiBtn.TextColor3 = Color3.fromRGB(245, 245, 248)
Instance.new("UICorner").Parent = mulaiBtn
mulaiBtn.Parent = bg
refreshMulai()

mulaiBtn.Activated:Connect(function()
	if chosenIbadah and chosenMiqat then
		startRemote:FireServer(chosenIbadah, chosenMiqat)
		mulaiBtn.Text = "Memulai…"
		mulaiBtn.AutoButtonColor = false
		-- Lobby akan teleport; tutup overlay.
		task.delay(1.5, function() gui.Enabled = false end)
	end
end)
