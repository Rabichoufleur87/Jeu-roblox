-- SCRIPT A COLLER DANS LA BARRE DE COMMANDE DE ROBLOX STUDIO (View > Command Bar)
-- Il cree automatiquement les 3 scripts necessaires (GameConfig, SimulatorServer, SimulatorClient)
-- avec le bon type et au bon endroit. Colle tout ce fichier d'un coup, puis appuie sur Entree.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local function upsert(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local inst = Instance.new(className)
	inst.Name = name
	return inst, parent
end

local gameConfig = upsert(ReplicatedStorage, "ModuleScript", "GameConfig")
gameConfig.Source = [====[
-- Type d'instance a creer dans Roblox Studio : ModuleScript
-- Emplacement : ReplicatedStorage
-- Nom exact : GameConfig

local GameConfig = {}

-- Valeurs de base
GameConfig.BaseClickValue = 1
GameConfig.AutoTickSeconds = 1

-- Amelioration "clic"
GameConfig.ClickUpgradeBaseCost = 10
GameConfig.ClickUpgradeCostGrowth = 1.6
GameConfig.ClickUpgradeBonus = 1 -- +1 cash par clic et par niveau

-- Amelioration "auto-clicker" (revenu passif)
GameConfig.AutoBaseCost = 25
GameConfig.AutoUpgradeCostGrowth = 1.7
GameConfig.AutoIncomePerLevel = 2 -- +2 cash/seconde par niveau

-- Rebirth (prestige)
GameConfig.RebirthBaseRequirement = 1000
GameConfig.RebirthRequirementGrowth = 2.2
GameConfig.RebirthMultiplierPerRebirth = 0.5 -- +50% de gains par rebirth

function GameConfig.GetClickUpgradeCost(level)
	return math.floor(GameConfig.ClickUpgradeBaseCost * (GameConfig.ClickUpgradeCostGrowth ^ level))
end

function GameConfig.GetAutoUpgradeCost(level)
	return math.floor(GameConfig.AutoBaseCost * (GameConfig.AutoUpgradeCostGrowth ^ level))
end

function GameConfig.GetRebirthRequirement(rebirths)
	return math.floor(GameConfig.RebirthBaseRequirement * (GameConfig.RebirthRequirementGrowth ^ rebirths))
end

function GameConfig.GetRebirthMultiplier(rebirths)
	return 1 + (rebirths * GameConfig.RebirthMultiplierPerRebirth)
end

function GameConfig.GetClickValue(clickLevel, rebirths)
	local base = GameConfig.BaseClickValue + (clickLevel * GameConfig.ClickUpgradeBonus)
	return math.max(1, math.floor(base * GameConfig.GetRebirthMultiplier(rebirths)))
end

function GameConfig.GetAutoIncome(autoLevel, rebirths)
	if autoLevel <= 0 then
		return 0
	end
	local base = autoLevel * GameConfig.AutoIncomePerLevel
	return math.floor(base * GameConfig.GetRebirthMultiplier(rebirths))
end

return GameConfig
]====]
gameConfig.Parent = ReplicatedStorage

local simulatorServer = upsert(ServerScriptService, "Script", "SimulatorServer")
simulatorServer.Source = [====[
-- Type d'instance a creer dans Roblox Studio : Script
-- Emplacement : ServerScriptService
-- Nom exact : SimulatorServer
--
-- IMPORTANT : dans Studio, active "Enable Studio Access to API Services"
-- (Game Settings > Security) pour que la sauvegarde (DataStore) fonctionne.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local playerDataStore = DataStoreService:GetDataStore("SimulatorData_v1")

-- Cree le dossier des RemoteEvents s'il n'existe pas deja
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function getOrCreateRemote(name)
	local event = remotes:FindFirstChild(name)
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = remotes
	end
	return event
end

local buyClickUpgradeEvent = getOrCreateRemote("BuyClickUpgrade")
local buyAutoUpgradeEvent = getOrCreateRemote("BuyAutoUpgrade")
local buyRebirthEvent = getOrCreateRemote("BuyRebirth")
local dataUpdatedEvent = getOrCreateRemote("DataUpdated")

-- Cree la sphere cliquable si elle n'existe pas deja
local clickPart = workspace:FindFirstChild("ClickPart")
if not clickPart then
	clickPart = Instance.new("Part")
	clickPart.Name = "ClickPart"
	clickPart.Size = Vector3.new(6, 6, 6)
	clickPart.Position = Vector3.new(0, 3, 0)
	clickPart.Anchored = true
	clickPart.BrickColor = BrickColor.new("Bright yellow")
	clickPart.Material = Enum.Material.Neon
	clickPart.Shape = Enum.PartType.Ball
	clickPart.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ClickLabel"
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = clickPart

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "CLIQUE-MOI !"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = billboard
end

local clickDetector = clickPart:FindFirstChildOfClass("ClickDetector")
if not clickDetector then
	clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 32
	clickDetector.Parent = clickPart
end

-- Etat des joueurs en memoire : [UserId] = { Cash, ClickLevel, AutoLevel, Rebirths }
local playerData = {}

local function getDefaultData()
	return {
		Cash = 0,
		ClickLevel = 0,
		AutoLevel = 0,
		Rebirths = 0,
	}
end

local function loadData(player)
	local success, result = pcall(function()
		return playerDataStore:GetAsync("Player_" .. player.UserId)
	end)
	if success and result then
		return result
	end
	return getDefaultData()
end

local function saveData(player)
	local data = playerData[player.UserId]
	if not data then
		return
	end
	local success, err = pcall(function()
		playerDataStore:SetAsync("Player_" .. player.UserId, data)
	end)
	if not success then
		warn("Erreur de sauvegarde pour " .. player.Name .. ": " .. tostring(err))
	end
end

local function updateLeaderstats(player)
	local data = playerData[player.UserId]
	if not data then
		return
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Cash.Value = data.Cash
		leaderstats.Rebirths.Value = data.Rebirths
	end
end

local function refreshPlayer(player)
	local data = playerData[player.UserId]
	if not data then
		return
	end
	updateLeaderstats(player)
	dataUpdatedEvent:FireClient(player, data)
end

Players.PlayerAdded:Connect(function(player)
	local data = loadData(player)
	playerData[player.UserId] = data

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = data.Cash
	cash.Parent = leaderstats

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = data.Rebirths
	rebirths.Parent = leaderstats

	refreshPlayer(player)
end)

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	playerData[player.UserId] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveData(player)
	end
end)

-- Un clic sur la sphere rapporte de l'argent
clickDetector.MouseClick:Connect(function(player)
	local data = playerData[player.UserId]
	if not data then
		return
	end
	local gain = GameConfig.GetClickValue(data.ClickLevel, data.Rebirths)
	data.Cash += gain
	refreshPlayer(player)
end)

-- Achat de l'amelioration "clic"
buyClickUpgradeEvent.OnServerEvent:Connect(function(player)
	local data = playerData[player.UserId]
	if not data then
		return
	end
	local cost = GameConfig.GetClickUpgradeCost(data.ClickLevel)
	if data.Cash >= cost then
		data.Cash -= cost
		data.ClickLevel += 1
		refreshPlayer(player)
	end
end)

-- Achat de l'amelioration "auto-clicker"
buyAutoUpgradeEvent.OnServerEvent:Connect(function(player)
	local data = playerData[player.UserId]
	if not data then
		return
	end
	local cost = GameConfig.GetAutoUpgradeCost(data.AutoLevel)
	if data.Cash >= cost then
		data.Cash -= cost
		data.AutoLevel += 1
		refreshPlayer(player)
	end
end)

-- Rebirth : remet a zero la progression contre un multiplicateur permanent
buyRebirthEvent.OnServerEvent:Connect(function(player)
	local data = playerData[player.UserId]
	if not data then
		return
	end
	local requirement = GameConfig.GetRebirthRequirement(data.Rebirths)
	if data.Cash >= requirement then
		data.Cash = 0
		data.ClickLevel = 0
		data.AutoLevel = 0
		data.Rebirths += 1
		refreshPlayer(player)
	end
end)

-- Revenu passif genere par les auto-clickers
task.spawn(function()
	while true do
		task.wait(GameConfig.AutoTickSeconds)
		for _, player in ipairs(Players:GetPlayers()) do
			local data = playerData[player.UserId]
			if data and data.AutoLevel > 0 then
				data.Cash += GameConfig.GetAutoIncome(data.AutoLevel, data.Rebirths)
				refreshPlayer(player)
			end
		end
	end
end)

-- Sauvegarde automatique periodique (au cas ou le serveur crash)
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in ipairs(Players:GetPlayers()) do
			saveData(player)
		end
	end
end)
]====]
simulatorServer.Parent = ServerScriptService

local simulatorClient = upsert(StarterPlayer.StarterPlayerScripts, "LocalScript", "SimulatorClient")
simulatorClient.Source = [====[
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
]====]
simulatorClient.Parent = StarterPlayer.StarterPlayerScripts

print("Installation terminee : GameConfig, SimulatorServer et SimulatorClient ont ete crees. Appuie sur Play pour tester !")
