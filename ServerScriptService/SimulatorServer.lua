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

-- GetDataStore echoue si le jeu n'est pas publie ou si l'acces API Studio
-- n'est pas active : dans ce cas, on continue quand meme sans sauvegarde.
local playerDataStore
do
	local success, result = pcall(function()
		return DataStoreService:GetDataStore("SimulatorData_v1")
	end)
	if success then
		playerDataStore = result
	else
		warn("DataStore indisponible (jeu non publie ou 'Enable Studio Access to API Services' desactive). La progression ne sera pas sauvegardee.")
	end
end

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
	if not playerDataStore then
		return getDefaultData()
	end
	local success, result = pcall(function()
		return playerDataStore:GetAsync("Player_" .. player.UserId)
	end)
	if success and result then
		return result
	end
	return getDefaultData()
end

local function saveData(player)
	if not playerDataStore then
		return
	end
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
