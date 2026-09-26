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
