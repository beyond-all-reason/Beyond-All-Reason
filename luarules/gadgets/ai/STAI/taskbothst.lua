TaskBotHST = class(Module)

function TaskBotHST:Name()
	return "TaskBotHST"
end

function TaskBotHST:internalName()
	return "taskbothst"
end

function TaskBotHST:Init()
	self.DebugEnabled = false
end


--LEVEL 1

function TaskBotHST:ConBot( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corck" ) then
		unitName = "corck"
	else if builder:CanBuild( "armck" ) then
		unitName = "armck"
	end
	local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName)
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 1, self.ai.conUnitPerTypeLimit))
end

function TaskBotHST:RezBot1( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "cornecro" ) then
		unitName = "cornecro"
	else if builder:CanBuild( "armrectr" ) then
		unitName = "armrectr"
	end
	local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName)
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 8) + 1 , self.ai.conUnitPerTypeLimit))
end

function TaskBotHST:Lvl1BotRaider( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "corak" ) then
		unitName = "corak"
	else if builder:CanBuild( "armpw" ) then
		unitName = "armpw"
	end
	return self.ai.taskshst:BuildRaiderIfNeeded(unitName)
end

function TaskBotHST:Lvl1BotBreakthrough( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "corthud" ) then
		unitName = "corthud"
	else if builder:CanBuild( "armwar" ) then
		unitName = "armwar"
	end
	return self.ai.taskshst:BuildBreakthroughIfNeeded(unitName)
end

function TaskBotHST:Lvl1BotBattle( taskQueueBehaviour, ai, builder )
	local unitName = ""
	local r = math.random()
	local compare = self.ai.overviewhst.plasmaRocketBotRatio or 1
	if compare >= 1 or math.random() < compare then
		if builder:CanBuild( "corthud" ) then
			unitName = "corthud"
		else if builder:CanBuild( "armham" ) then
			unitName = "armham"
		end
	else
		if builder:CanBuild( "corstorm" ) then
			unitName = "corstorm"
		else if builder:CanBuild( "armrock" ) then
			unitName = "armrock"
		end
	end
	return self.ai.taskshst:BuildBattleIfNeeded(unitName)
end

function TaskBotHST:Lvl1AABot( taskQueueBehaviour, ai, builder )
	if builder:CanBuild( "corcrash" ) then
		return self.ai.taskshst:BuildAAIfNeeded("corcrash")
	else if builder:CanBuild( "armjeth" ) then
		return self.ai.taskshst:BuildAAIfNeeded("armjeth")
	end
	return ""
end

function TaskBotHST:ScoutBot( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "armflea" ) then
		unitName = "armflea"
	end
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, 1)
end

--LEVEL 2

function TaskBotHST:ConAdvBot( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corack" ) then
		unitName = "corack"
	else if builder:CanBuild( "armack" ) then
		unitName = "armack"
	end
	local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName)
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 10) + 3, self.ai.conUnitAdvPerTypeLimit))
end


function TaskBotHST:Lvl2BotAssist( taskQueueBehaviour, ai, builder )
	unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corfast" ) then
		unitName = "corfast"
	else if builder:CanBuild( "armfark" ) then
		unitName = "armfark"
	end
	local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName)
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 8) + 1, self.ai.conUnitPerTypeLimit))
end

function TaskBotHST:NewCommanders( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "cormando" ) then
		unitName = 'cormando'
	end
	return unitName
end

function TaskBotHST:Decoy( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "cordecom" ) then
		unitName = 'cordecom'
	else if builder:CanBuild( "armdecom" ) then
		unitName = 'armdecom'
	end
	return unitName
end


function TaskBotHST:Lvl2BotBreakthrough( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "corsumo" ) then
		unitName = "corsumo"
	else if builder:CanBuild( "armfboy" ) then
		unitName = "armfboy"
	end
	return self.ai.taskshst:BuildBreakthroughIfNeeded(unitName)
end

function TaskBotHST:Lvl2BotArty( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "cormort" ) then
		unitName = "cormort"
	else if builder:CanBuild( "armfido" ) then
		unitName = "armfido"
	end
	return self.ai.taskshst:BuildSiegeIfNeeded(unitName)
end

function TaskBotHST:Lvl2BotLongRange( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "corhrk" ) then
		unitName = "corhrk"
	else if builder:CanBuild( "armsnipe" ) then
		unitName = "armsnipe"
	end
	return self.ai.taskshst:BuildSiegeIfNeeded(unitName)
end

function TaskBotHST:Lvl2BotRaider( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "corpyro" ) then
		unitName = "corpyro"
	else if builder:CanBuild( "armfast" ) then
		unitName = "armfast"
	end
	return self.ai.taskshst:BuildRaiderIfNeeded(unitName)
end

function TaskBotHST:Lvl2BotCorRaiderArmArty( taskQueueBehaviour, ai, builder )
	local unitName = self:Lvl2BotRaider( taskQueueBehaviour, ai, builder )
	if not builder:CanBuild( unitName) then
		unitName = self:Lvl2BotArty( taskQueueBehaviour, ai, builder )
	end
	return unitName
end

function TaskBotHST:Lvl2BotAllTerrain( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "cortermite" ) then
		unitName = 'cortermite'
	else if builder:CanBuild( "armsptk" ) then
		unitName = "armsptk"
	end
	return unitName
end

function TaskBotHST:Lvl2BotBattle( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "corcan" ) then
		unitName = "corcan"
	else if builder:CanBuild( "armzeus" ) then
		unitName = "armzeus"
	end
	return self.ai.taskshst:BuildBattleIfNeeded(unitName)
end

function TaskBotHST:Lvl2BotMedium( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corcan" ) then
		unitName = 'corcan'
	else if builder:CanBuild( "armmav" ) then
		unitName = "armmav"
	end
	return unitName
end

function TaskBotHST:Lvl2AmphBot( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "coramph" ) then
		unitName = 'coramph'
	else if builder:CanBuild( "armamph" ) then
		unitName = 'armamph'
	end
	return unitName
end

function TaskBotHST:Lvl2AABot( taskQueueBehaviour, ai, builder )
	if builder:CanBuild( "coraak" ) then
		return self.ai.taskshst:BuildAAIfNeeded("coraak")
	else if builder:CanBuild( "armaak" ) then
		return self.ai.taskshst:BuildAAIfNeeded("armaak")
	end
end
