OverviewHandler = class(Module)

function OverviewHandler:Name()
	return "OverviewHandler"
end

function OverviewHandler:internalName()
	return "overviewhandler"
end

function OverviewHandler:Init()
	self.DebugEnabled = false

	self.heavyPlasmaLimit = 3
	self.AAUnitPerTypeLimit = 3
	self.nukeLimit = 1
	self.tacticalNukeLimit = 1

	self.lastCheckFrame = 0
	self.lastEconCheckFrame = 0

	self:StaticEvaluate()
	self:Evaluate()
end

function OverviewHandler:Update()
	self:Evaluate()
end

function OverviewHandler:Evaluate()
	local f = self.game:Frame()
	if f > self.lastCheckFrame + 240 then
		self:EvaluateSituation()
		self.lastCheckFrame = f
	end
	if f > self.lastEconCheckFrame + 22 then
		self:SetEconomyAliases()
		self.lastEconCheckFrame = f
	end
end

function OverviewHandler:EvaluateSituation()
	self.ai.haveAdvFactory = self.ai.factoriesAtLevel[3] and #self.ai.factoriesAtLevel[3] ~= 0
	self.ai.haveExpFactory = self.ai.factoriesAtLevel[5] and #self.ai.factoriesAtLevel[5] ~= 0
	
	self.ai.needToReclaim = self.ai.Metal.full < 0.5 and self.ai.wreckCount > 0
	self.AAUnitPerTypeLimit = math.ceil(self.ai.turtlehandler:GetTotalPriority() / 4)
	self.heavyPlasmaLimit = math.ceil(self.ai.combatCount / 10)
	self.nukeLimit = math.ceil(self.ai.combatCount / 50)
	self.tacticalNukeLimit = math.ceil(self.ai.combatCount / 40)

	local attackCounter = self.ai.attackhandler:GetCounter()
	local couldAttack = self.ai.couldAttack >= 1 or self.ai.couldBomb >= 1
	local bombingTooExpensive = self.ai.bomberhandler:GetCounter() == maxBomberCounter
	local attackTooExpensive = attackCounter == maxAttackCounter
	local controlMetalSpots = self.ai.mexCount > #self.ai.mobNetworkMetals["air"][1] * 0.4
	local needUpgrade = couldAttack or bombingTooExpensive or attackTooExpensive

	self.keepCommanderSafe = self.ai.totalEnemyThreat > 3000 -- turn commander into assistant, for now above paranoidCommander because the assistant behaviour isn't helpful or safe
	self.paranoidCommander = self.ai.totalEnemyThreat > 2500 -- move commander to safest place assisting a factory

	self:EchoDebug(self.ai.totalEnemyThreat .. " " .. self.ai.totalEnemyImmobileThreat .. " " .. self.ai.totalEnemyMobileThreat)
	-- build siege units if the enemy is turtling, if a lot of our attackers are getting destroyed, or if we control over 40% of the metal spots
	self.plasmaRocketBotRatio = 1
	if self.ai.totalEnemyMobileThreat and self.ai.totalEnemyMobileThreat > 0 and self.ai.totalEnemyImmobileThreat and self.ai.totalEnemyImmobileThreat > 0 then
		self.plasmaRocketBotRatio = 1 - ((self.ai.totalEnemyImmobileThreat / self.ai.totalEnemyThreat) / 2.5)
		self:EchoDebug("plasma/rocket bot ratio: " .. self.plasmaRocketBotRatio)
	end
	self.needSiege = (self.ai.totalEnemyImmobileThreat > self.ai.totalEnemyMobileThreat * 3.5 and self.ai.totalEnemyImmobileThreat > 50000) or attackCounter >= siegeAttackCounter or controlMetalSpots
	local needAdvanced = (self.ai.Metal.income > 18 or controlMetalSpots) and self.ai.factories > 0 and (needUpgrade or self.ai.lotsOfMetal)
	if needAdvanced ~= self.ai.needAdvanced then
		self.ai.needAdvanced = needAdvanced
		self.ai.factorybuildershandler:UpdateFactories()
	end
	self.ai.needAdvanced = needAdvanced
	local needExperimental
	self.ai.needNukes = false
	if self.ai.Metal.income > 50 and self.ai.haveAdvFactory and (needUpgrade or self.ai.BigEco) and self.ai.enemyBasePosition then
		if not self.ai.haveExpFactory then
			for i, factory in pairs(self.ai.factoriesAtLevel[self.ai.maxFactoryLevel]) do
				for expFactName, _ in pairs(expFactories) do
					for _, mtype in pairs(factoryMobilities[expFactName]) do
						local myNet = self.ai.maphandler:MobilityNetworkHere(mtype, factory.position)
						local enemyNet = self.ai.maphandler:MobilityNetworkHere(mtype, self.ai.enemyBasePosition)
						if myNet and enemyNet and myNet == enemyNet then
							needExperimental = true
							break
						end
					end
				end
			end
		end
		self.ai.needNukes = true
	end
	if needExperimental ~= self.ai.needExperimental then
		self.ai.factorybuildershandler:UpdateFactories()
	end
	self.ai.needExperimental = needExperimental
	self:EchoDebug("need experimental? " .. tostring(self.ai.needExperimental) .. ", need nukes? " .. tostring(self.ai.needNukes) .. ", have advanced? " .. tostring(self.ai.haveAdvFactory) .. ", need upgrade? " .. tostring(needUpgrade) .. ", have enemy base position? " .. tostring(self.ai.enemyBasePosition))
	self:EchoDebug("metal income: " .. self.ai.Metal.income .. "  combat units: " .. self.ai.combatCount)
	self:EchoDebug("have advanced? " .. tostring(self.ai.haveAdvFactory) .. " have experimental? " .. tostring(self.ai.haveExpFactory))
	self:EchoDebug("need advanced? " .. tostring(self.ai.needAdvanced) .. "  need experimental? " .. tostring(self.ai.needExperimental))
	self:EchoDebug("need advanced? " .. tostring(self.ai.needAdvanced) .. ", need upgrade? " .. tostring(needUpgrade) .. ", have attacked enough? " .. tostring(couldAttack) .. " (" .. self.ai.couldAttack .. "), have " .. self.ai.factories .. " factories, " .. math.floor(self.ai.Metal.income) .. " metal income")
end

function OverviewHandler:SetEconomyAliases()
	self.ai.realMetal = self.ai.Metal.income / self.ai.Metal.usage
	self.ai.realEnergy = self.ai.Energy.income / self.ai.Energy.usage
	self.ai.scaledMetal = self.ai.Metal.reserves * self.ai.realMetal
	self.ai.scaledEnergy = self.ai.Energy.reserves * self.ai.realEnergy
	self.extraEnergy = self.ai.Energy.income - self.ai.Energy.usage
	self.extraMetal = self.ai.Metal.income - self.ai.Metal.usage
	local enoughMetalReserves = math.min(self.ai.Metal.income, self.ai.Metal.capacity * 0.1)
	local lotsMetalReserves = math.min(self.ai.Metal.income * 10, self.ai.Metal.capacity * 0.5)
	local enoughEnergyReserves = math.min(self.ai.Energy.income * 2, self.ai.Energy.capacity * 0.25)
	-- local lotsEnergyReserves = math.min(self.ai.Energy.income * 3, self.ai.Energy.capacity * 0.5)
	self.energyTooLow = self.ai.Energy.reserves < enoughEnergyReserves or self.ai.Energy.income < 40
	self.energyOkay = self.ai.Energy.reserves >= enoughEnergyReserves and self.ai.Energy.income >= 40
	self.metalTooLow = self.ai.Metal.reserves < enoughMetalReserves
	self.metalOkay = self.ai.Metal.reserves >= enoughMetalReserves
	self.metalBelowHalf = self.ai.Metal.reserves < lotsMetalReserves
	self.metalAboveHalf = self.ai.Metal.reserves >= lotsMetalReserves
	local attackCounter = self.ai.attackhandler:GetCounter()
	self.notEnoughCombats = self.ai.combatCount < attackCounter * 0.6
	self.farTooFewCombats = self.ai.combatCount < attackCounter * 0.2
	
	self.ai.underReserves = self.ai.Metal.full < 0.3 or self.ai.Energy.full < 0.3
	self.ai.aboveReserves = self.ai.Metal.full > 0.7 and self.ai.Energy.full > 0.7
	self.ai.normalReserves = self.ai.Metal.full > 0.5 and self.ai.Energy.full > 0.5
	
	self.ai.LittleEco = self.ai.Energy.income < 1000 and self.ai.Metal.income < 30
	self.ai.BigEco = self.ai.Energy.income > 5000 and self.ai.Metal.income > 100 and self.ai.Metal.reserves > 4000 and self.ai.factoryBuilded['air'][1] > 2 and self.ai.combatCount > 40
	self.ai.lotsOfMetal = self.ai.Metal.income > 30 and self.ai.Metal.full > 0.75 and self.ai.mexCount > #self.ai.mobNetworkMetals["air"][1] * 0.5
end

function OverviewHandler:StaticEvaluate()
	self.needAmphibiousCons = self.ai.hasUWSpots and self.ai.mobRating["sub"] > self.ai.mobRating["bot"] * 0.75
end