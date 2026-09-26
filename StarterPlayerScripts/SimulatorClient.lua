-- Type d'instance a creer dans Roblox Studio : LocalScript
-- Emplacement : StarterPlayer > StarterPlayerScripts
-- Nom exact : SimulatorClient

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local buyClickUpgradeEvent = remotes:WaitForChild("BuyClickUpgrade")
local buyAutoUpgradeEvent = remotes:WaitForChild("BuyAutoUpgrade")
local buyRebirthEvent = remotes:WaitForChild("BuyRebirth")
local dataUpdatedEvent = remotes:WaitForChild("DataUpdated")

local currentData = {
	Cash = 0,
	ClickLevel = 0,
	AutoLevel = 0,
	Rebirths = 0,
}

-- Construction de l'interface entierement par script
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SimulatorGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 260, 0, 320)
mainFrame.Position = UDim2.new(0, 20, 0.5, -160)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = mainFrame

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 10)
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingRight = UDim.new(0, 10)
padding.Parent = mainFrame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Parent = mainFrame

local function createLabel(text, order)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 28)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Text = text
	label.LayoutOrder = order
	label.Parent = mainFrame
	return label
end

local function createButton(text, order)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, 44)
	button.BackgroundColor3 = Color3.fromRGB(50, 130, 70)
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextScaled = true
	button.Text = text
	button.LayoutOrder = order
	button.Parent = mainFrame

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = button

	return button
end

local cashLabel = createLabel("Cash : 0", 1)
local rebirthLabel = createLabel("Rebirths : 0", 2)
local infoLabel = createLabel("Clic : +1 | Auto : +0/s", 3)
local clickUpgradeButton = createButton("Ameliorer le clic (10)", 4)
local autoUpgradeButton = createButton("Acheter un auto-clicker (25)", 5)
local rebirthButton = createButton("Rebirth (1000)", 6)

local function formatNumber(n)
	n = math.floor(n)
	if n >= 1000000 then
		return string.format("%.2fM", n / 1000000)
	elseif n >= 1000 then
		return string.format("%.2fK", n / 1000)
	end
	return tostring(n)
end

local function refreshDisplay()
	cashLabel.Text = "Cash : " .. formatNumber(currentData.Cash)
	rebirthLabel.Text = "Rebirths : " .. currentData.Rebirths

	local clickCost = GameConfig.GetClickUpgradeCost(currentData.ClickLevel)
	local autoCost = GameConfig.GetAutoUpgradeCost(currentData.AutoLevel)
	local rebirthReq = GameConfig.GetRebirthRequirement(currentData.Rebirths)

	clickUpgradeButton.Text = "Ameliorer le clic (" .. formatNumber(clickCost) .. ")"
	autoUpgradeButton.Text = "Acheter un auto-clicker (" .. formatNumber(autoCost) .. ")"
	rebirthButton.Text = "Rebirth (" .. formatNumber(rebirthReq) .. ")"

	local clickValue = GameConfig.GetClickValue(currentData.ClickLevel, currentData.Rebirths)
	local autoValue = GameConfig.GetAutoIncome(currentData.AutoLevel, currentData.Rebirths)
	infoLabel.Text = string.format("Clic : +%d | Auto : +%d/s", clickValue, autoValue)
end

dataUpdatedEvent.OnClientEvent:Connect(function(data)
	currentData = data
	refreshDisplay()
end)

clickUpgradeButton.MouseButton1Click:Connect(function()
	buyClickUpgradeEvent:FireServer()
end)

autoUpgradeButton.MouseButton1Click:Connect(function()
	buyAutoUpgradeEvent:FireServer()
end)

rebirthButton.MouseButton1Click:Connect(function()
	buyRebirthEvent:FireServer()
end)

refreshDisplay()
