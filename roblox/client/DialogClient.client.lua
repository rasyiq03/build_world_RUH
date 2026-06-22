--!strict
-- DialogClient.client.lua — render panel DIALOG NPC BERPILIHAN. Dengar RemoteEvent "NpcDialog"
-- (dari Dialog.open server) → tampilkan speaker + teks + tombol pilihan; navigasi LOKAL via
-- Dialog.choose (pilih → node berikut atau "close"). Taruh di StarterPlayerScripts. UI: Devi.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Dialog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Dialog"))
local remote = ReplicatedStorage:WaitForChild("NpcDialog")
local player = Players.LocalPlayer

-- ── bangun GUI sekali ──
local gui = Instance.new("ScreenGui")
gui.Name = "NpcDialogGui"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.fromScale(0.5, 0.28)
panel.Position = UDim2.fromScale(0.25, 0.66)
panel.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner").Parent = panel

local speaker = Instance.new("TextLabel")
speaker.Size = UDim2.new(1, -20, 0, 28)
speaker.Position = UDim2.fromOffset(14, 8)
speaker.BackgroundTransparency = 1
speaker.Font = Enum.Font.GothamBold
speaker.TextSize = 20
speaker.TextColor3 = Color3.fromRGB(240, 210, 120)
speaker.TextXAlignment = Enum.TextXAlignment.Left
speaker.Parent = panel

local body = Instance.new("TextLabel")
body.Size = UDim2.new(1, -28, 0.42, 0)
body.Position = UDim2.fromOffset(14, 40)
body.BackgroundTransparency = 1
body.Font = Enum.Font.Gotham
body.TextSize = 16
body.TextWrapped = true
body.TextColor3 = Color3.fromRGB(235, 235, 240)
body.TextXAlignment = Enum.TextXAlignment.Left
body.TextYAlignment = Enum.TextYAlignment.Top
body.Parent = panel

local choices = Instance.new("Frame")
choices.Size = UDim2.new(1, -28, 0.42, -6)
choices.Position = UDim2.fromScale(0, 0.56)
choices.Position = UDim2.new(0, 14, 0.56, 0)
choices.BackgroundTransparency = 1
choices.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.FillDirection = Enum.FillDirection.Vertical
layout.Parent = choices

local function clearChoices()
	for _, c in ipairs(choices:GetChildren()) do
		if c:IsA("TextButton") then c:Destroy() end
	end
end

local function close()
	gui.Enabled = false
	clearChoices()
end

local function render(tree: any, nodeId: string)
	local node = Dialog.node(tree, nodeId)
	if not node then close(); return end
	speaker.Text = tree.speaker or "NPC"
	body.Text = node.text or ""
	clearChoices()
	local list = node.choices or { { text = "Tutup", to = "close" } }
	for i, ch in ipairs(list) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 0, 30)
		btn.BackgroundColor3 = Color3.fromRGB(46, 54, 70)
		btn.BorderSizePixel = 0
		btn.Font = Enum.Font.Gotham
		btn.TextSize = 15
		btn.TextColor3 = Color3.fromRGB(230, 230, 235)
		btn.Text = ch.text
		btn.LayoutOrder = i
		Instance.new("UICorner").Parent = btn
		btn.Parent = choices
		btn.Activated:Connect(function()
			local to = Dialog.choose(tree, nodeId, i)
			if not to or to == "close" then
				close()
			else
				render(tree, to)
			end
		end)
	end
	gui.Enabled = true
end

remote.OnClientEvent:Connect(function(tree)
	if tree and tree.start then
		render(tree, tree.start)
	end
end)
