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
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corck"
	else
		unitName = "armck"
	end
	local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName)
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 1, self.ai.conUnitPerTypeLimit))
end

function TaskBotHST:RezBot1( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "cornecro"
	else
		unitName = "armrectr"
	end
	local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName)
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 8) + 1 , self.ai.conUnitPerTypeLimit))
end

function TaskBotHST:Lvl1BotRaider( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corak"
	else
		unitName = "armpw"
	end
	return self.ai.taskshst:BuildRaiderIfNeeded(unitName)
end

function TaskBotHST:Lvl1BotBreakthrough( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corthud"
	else
		unitName = "armwar"
	end
	return self.ai.taskshst:BuildBreakthroughIfNeeded(unitName)
end

function TaskBotHST:Lvl1BotBattle( taskQueueBehaviour, ai, builder )
	local unitName = ""
	local r = math.random()
	local compare = self.ai.overviewhst.plasmaRocketBotRatio or 1
	if compare >= 1 or math.random() < compare then
		if  self.ai.side == self.ai.armyhst.CORESideName then
			unitName = "corthud"
		else
			unitName = "armham"
		end
	else
		if  self.ai.side == self.ai.armyhst.CORESideName then
			unitName = "corstorm"
		else
			unitName = "armrock"
		end
	end
	return self.ai.taskshst:BuildBattleIfNeeded(unitName)
end

function TaskBotHST:Lvl1AABot( taskQueueBehaviour, ai, builder )
	if  self.ai.side == self.ai.armyhst.CORESideName then
		return self.ai.taskshst:BuildAAIfNeeded("corcrash")
	else
		return self.ai.taskshst:BuildAAIfNeeded("armjeth")
	end
end

function TaskBotHST:ScoutBot( taskQueueBehaviour, ai, builder )
	local unitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		return self.ai.armyhst.DummyUnitName
	else
		unitName = "armflea"
	end
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, 1)
end

--LEVEL 2

function TaskBotHST:ConAdvBot( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corack"
	else
		unitName = "armack"
	end
	local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName)
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 10) + 3, self.ai.conUnitAdvPerTypeLimit))
end


function TaskBotHST:Lvl2BotAssist( taskQueueBehaviour, ai, builder )
	unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corfast"
	else
		unitName = "armfark"
	end
	local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName)
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 8) + 1, self.ai.conUnitPerTypeLimit))
end

function TaskBotHST:NewCommanders( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = 'cormando'
	else
		unitName = self.ai.armyhst.DummyUnitName
	end
	return unitName
end

function TaskBotHST:Decoy( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = 'cordecom'
	else
		unitName = 'armdecom'
	end
	return unitName
end


function TaskBotHST:Lvl2BotBreakthrough( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corsumo"
	else
		unitName = "armfboy"
	end
	return self.ai.taskshst:BuildBreakthroughIfNeeded(unitName)
end

function TaskBotHST:Lvl2BotArty( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "cormort"
	else
		unitName = "armfido"
	end
	return self.ai.taskshst:BuildSiegeIfNeeded(unitName)
end

function TaskBotHST:Lvl2BotLongRange( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corhrk"
	else
		unitName = "armsnipe"
	end
	return self.ai.taskshst:BuildSiegeIfNeeded(unitName)
end

function TaskBotHST:Lvl2BotRaider( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corpyro"
	else
		unitName = "armfast"
	end
	return self.ai.taskshst:BuildRaiderIfNeeded(unitName)
end

function TaskBotHST:Lvl2BotCorRaiderArmArty( taskQueueBehaviour, ai, builder )
	if  self.ai.side == self.ai.armyhst.CORESideName then
		return Lvl2BotRaider(self)
	else
		return Lvl2BotArty(self)
	end
end

function TaskBotHST:Lvl2BotAllTerrain( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = 'cortermite'
	else
		unitName = "armsptk"
	end
	return unitName
end

function TaskBotHST:Lvl2BotBattle( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corcan"
	else
		unitName = "armzeus"
	end
	return self.ai.taskshst:BuildBattleIfNeeded(unitName)
end

function TaskBotHST:Lvl2BotMedium( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = 'corcan'
	else
		unitName = "armmav"
	end
	return unitName
end

function TaskBotHST:Lvl2AmphBot( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = 'coramph'
	else
		unitName = 'armamph'
	end
	return unitName
end

function TaskBotHST:Lvl2AABot( taskQueueBehaviour, ai, builder )
	if  self.ai.side == self.ai.armyhst.CORESideName then
		return self.ai.taskshst:BuildAAIfNeeded("coraak")
	else
		return self.ai.taskshst:BuildAAIfNeeded("armaak")
	end
end
