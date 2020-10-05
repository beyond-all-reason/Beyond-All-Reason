TaskBotHST = class(Module)

function TaskBotHST:Name()
	return "TaskBotHST"
end

function TaskBotHST:Init()
	self.DebugEnabled = false
end


--LEVEL 1

function TaskBotHST:ConBot()
	local unitName = UnitiesHST.DummyUnitName
	if self.side == UnitiesHST.CORESideName then
		unitName = "corck"
	else
		unitName = "armck"
	end
	local mtypedLv = GetMtypedLv(unitName)
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 1, ai.conUnitPerTypeLimit))
end

function TaskBotHST:RezBot1()
	local unitName = UnitiesHST.DummyUnitName
	if self.side == UnitiesHST.CORESideName then
		unitName = "cornecro"
	else
		unitName = "armrectr"
	end
	local mtypedLv = GetMtypedLv(unitName)
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 8) + 1 , ai.conUnitPerTypeLimit))
end

function TaskBotHST:Lvl1BotRaider()
	local unitName = ""
	if self.side == UnitiesHST.CORESideName then
		unitName = "corak"
	else
		unitName = "armpw"
	end
	return BuildRaiderIfNeeded(unitName)
end

function TaskBotHST:Lvl1BotBreakthrough()
	local unitName = ""
	if self.side == UnitiesHST.CORESideName then
		unitName = "corthud"
	else
		unitName = "armwar"
	end
	return BuildBreakthroughIfNeeded(unitName)
end

function TaskBotHST:Lvl1BotBattle()
	local unitName = ""
	local r = math.random()
	local compare = self.ai.overviewhst.plasmaRocketBotRatio or 1
	if compare >= 1 or math.random() < compare then
		if self.side == UnitiesHST.CORESideName then
			unitName = "corthud"
		else
			unitName = "armham"
		end
	else
		if self.side == UnitiesHST.CORESideName then
			unitName = "corstorm"
		else
			unitName = "armrock"
		end
	end
	return BuildBattleIfNeeded(unitName)
end

function TaskBotHST:Lvl1AABot()
	if self.side == UnitiesHST.CORESideName then
		return BuildAAIfNeeded("corcrash")
	else
		return BuildAAIfNeeded("armjeth")
	end
end

function TaskBotHST:ScoutBot()
	local unitName
	if self.side == UnitiesHST.CORESideName then
		return UnitiesHST.DummyUnitName
	else
		unitName = "armflea"
	end
	return BuildWithLimitedNumber(unitName, 1)
end

--LEVEL 2

function TaskBotHST:ConAdvBot()
	local unitName = UnitiesHST.DummyUnitName
	if self.side == UnitiesHST.CORESideName then
		unitName = "corack"
	else
		unitName = "armack"
	end
	local mtypedLv = GetMtypedLv(unitName)
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 10) + 3, ai.conUnitAdvPerTypeLimit))
end


function TaskBotHST:Lvl2BotAssist()
	unitName = UnitiesHST.DummyUnitName
	if self.side == UnitiesHST.CORESideName then
		unitName = "corfast"
	else
		unitName = "armfark"
	end
	local mtypedLv = GetMtypedLv(unitName)
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 8) + 1, ai.conUnitPerTypeLimit))
end

function TaskBotHST:NewCommanders()
	local unitName = UnitiesHST.DummyUnitName
	if self.side == UnitiesHST.CORESideName then
		unitName = 'cormando'
	else
		unitName = UnitiesHST.DummyUnitName
	end
	return unitName
end

function TaskBotHST:Decoy()
	local unitName = UnitiesHST.DummyUnitName
	if self.side == UnitiesHST.CORESideName then
		unitName = 'cordecom'
	else
		unitName = 'armdecom'
	end
	return unitName
end


function TaskBotHST:Lvl2BotBreakthrough()
	local unitName = ""
	if self.side == UnitiesHST.CORESideName then
		unitName = "corsumo"
	else
		unitName = "armfboy"
	end
	return BuildBreakthroughIfNeeded(unitName)
end

function TaskBotHST:Lvl2BotArty()
	local unitName = ""
	if self.side == UnitiesHST.CORESideName then
		unitName = "cormort"
	else
		unitName = "armfido"
	end
	return BuildSiegeIfNeeded(unitName)
end

function TaskBotHST:Lvl2BotLongRange()
	local unitName = ""
	if self.side == UnitiesHST.CORESideName then
		unitName = "corhrk"
	else
		unitName = "armsnipe"
	end
	return BuildSiegeIfNeeded(unitName)
end

function TaskBotHST:Lvl2BotRaider()
	local unitName = ""
	if self.side == UnitiesHST.CORESideName then
		unitName = "corpyro"
	else
		unitName = "armfast"
	end
	return BuildRaiderIfNeeded(unitName)
end

function TaskBotHST:Lvl2BotCorRaiderArmArty()
	if self.side == UnitiesHST.CORESideName then
		return Lvl2BotRaider(self)
	else
		return Lvl2BotArty(self)
	end
end

function TaskBotHST:Lvl2BotAllTerrain()
	local unitName=UnitiesHST.DummyUnitName
	if self.side == UnitiesHST.CORESideName then
		unitName = 'cortermite'
	else
		unitName = "armsptk"
	end
	return unitName
end

function TaskBotHST:Lvl2BotBattle()
	local unitName = ""
	if self.side == UnitiesHST.CORESideName then
		unitName = "corcan"
	else
		unitName = "armzeus"
	end
	return BuildBattleIfNeeded(unitName)
end

function TaskBotHST:Lvl2BotMedium()
	local unitName=UnitiesHST.DummyUnitName
	if self.side == UnitiesHST.CORESideName then
		unitName = 'corcan'
	else
		unitName = "armmav"
	end
	return unitName
end

function TaskBotHST:Lvl2AmphBot()
	local unitName=UnitiesHST.DummyUnitName
	if self.side == UnitiesHST.CORESideName then
		unitName = 'coramph'
	else
		unitName = 'armamph'
	end
	return unitName
end

function TaskBotHST:Lvl2AABot()
	if self.side == UnitiesHST.CORESideName then
		return BuildAAIfNeeded("coraak")
	else
		return BuildAAIfNeeded("armaak")
	end
end
