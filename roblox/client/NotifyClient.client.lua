--!strict
-- NotifyClient.client.lua — tampilan FEEDBACK pemain: TOAST (muncul ~4 dtk lalu hilang) + LOG ringkas
-- (riwayat, toggle L). Dengar RemoteEvent "Notify" (UiBridge, dari Notify.toPlayer/server). Warna per
-- kind (info/warn/success). Taruh di StarterPlayerScripts. UI: Devi.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local UiBridge = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiBridge"))
local remote = ReplicatedStorage:WaitForChild(UiBridge.EVENTS.Notify)
local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local COLORS = {
	info = Color3.fromRGB(46, 54, 70),
	warn = Color3.fromRGB(150, 90, 30),
	success = Color3.fromRGB(40, 90, 55),
}

local gui = Instance.new("ScreenGui")
gui.Name = "NotifyGui"
gui.ResetOnSpawn = false
gui.Parent = pg

-- Wadah toast (atas-tengah)
local toastBox = Instance.new("Frame")
toastBox.Size = UDim2.fromScale(0.4, 0.4)
toastBox.Position = UDim2.fromScale(0.3, 0.06)
toastBox.BackgroundTransparency = 1
toastBox.Parent = gui
local tl = Instance.new("UIListLayout")
tl.HorizontalAlignment = Enum.HorizontalAlignment.Center
tl.VerticalAlignment = Enum.VerticalAlignment.Top
tl.Padding = UDim.new(0, 6)
tl.Parent = toastBox

-- Panel log (kiri bawah, toggle L)
local logPanel = Instance.new("Frame")
logPanel.Size = UDim2.fromScale(0.28, 0.32)
logPanel.Position = UDim2.fromScale(0.012, 0.6)
logPanel.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
logPanel.BackgroundTransparency = 0.2
logPanel.BorderSizePixel = 0
logPanel.Visible = false
logPanel.Parent = gui
Instance.new("UICorner").Parent = logPanel
local logList = Instance.new("ScrollingFrame")
logList.Size = UDim2.new(1, -10, 1, -10)
logList.Position = UDim2.fromOffset(5, 5)
logList.BackgroundTransparency = 1
logList.BorderSizePixel = 0
logList.ScrollBarThickness = 4
logList.AutomaticCanvasSize = Enum.AutomaticSize.Y
logList.CanvasSize = UDim2.new()
logList.Parent = logPanel
local ll = Instance.new("UIListLayout")
ll.Padding = UDim.new(0, 3)
ll.Parent = logList

local function addLog(message: string, color: Color3)
	local item = Instance.new("TextLabel")
	item.Size = UDim2.new(1, -6, 0, 0)
	item.AutomaticSize = Enum.AutomaticSize.Y
	item.BackgroundTransparency = 1
	item.Font = Enum.Font.Gotham
	item.TextSize = 13
	item.TextWrapped = true
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextColor3 = color
	item.Text = "• " .. message
	item.LayoutOrder = os.clock() * 1000 // 1
	item.Parent = logList
	-- cap riwayat
	local items = {}
	for _, c in ipairs(logList:GetChildren()) do
		if c:IsA("TextLabel") then items[#items + 1] = c end
	end
	if #items > 30 then items[1]:Destroy() end
end

local function showToast(message: string, kind: string)
	local color = COLORS[kind] or COLORS.info
	addLog(message, Color3.fromRGB(220, 220, 225))

	local toast = Instance.new("Frame")
	toast.Size = UDim2.new(1, 0, 0, 0)
	toast.AutomaticSize = Enum.AutomaticSize.Y
	toast.BackgroundColor3 = color
	toast.BackgroundTransparency = 0.05
	toast.BorderSizePixel = 0
	toast.Parent = toastBox
	Instance.new("UICorner").Parent = toast
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6); pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 10); pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = toast
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 0)
	lbl.AutomaticSize = Enum.AutomaticSize.Y
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextSize = 15
	lbl.TextWrapped = true
	lbl.TextColor3 = Color3.fromRGB(245, 245, 248)
	lbl.Text = message
	lbl.Parent = toast

	-- auto-hilang setelah 4 dtk (fade)
	task.delay(4, function()
		pcall(function()
			TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(lbl, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end)
		task.wait(0.45)
		toast:Destroy()
	end)
end

remote.OnClientEvent:Connect(function(message: string, kind: string)
	if type(message) == "string" then
		showToast(message, kind or "info")
	end
end)

UserInputService.InputBegan:Connect(function(input, gp)
	if not gp and input.KeyCode == Enum.KeyCode.L then
		logPanel.Visible = not logPanel.Visible
	end
end)
