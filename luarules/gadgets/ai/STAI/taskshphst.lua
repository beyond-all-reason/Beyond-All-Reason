TaskShpHST = class(Module)

function TaskShpHST:Name()
	return "TaskShpHST"
end

function TaskShpHST:internalName()
	return "TaskShpHST"
end


function TaskShpHST:Init()
	self.DebugEnabled = false
end
--LEVEL 1

function TaskShpHST:ConShip()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corcs"
	else
		unitName = "armcs"
	end
	local mtypedLv = self.ai.TasksHST:GetMtypedLv(unitName) + self.ai.TasksHST:GetMtypedLv('correcl') --need count sub too
	return self.ai.TasksHST:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 5) + 2, self.ai.conUnitPerTypeLimit))
end

function TaskShpHST:RezSub1()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "correcl"
	else
		unitName = "armrecl"
	end
	local mtypedLv = self.ai.TasksHST:GetMtypedLv(unitName) + self.ai.TasksHST:GetMtypedLv('armcs') --need count shp too
	return self.ai.TasksHST:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 8) + 2, self.ai.conUnitPerTypeLimit))
end

function TaskShpHST:Lvl1ShipRaider()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corsub"
	else
		unitName = "armsub"
	end
	return self.ai.TasksHST:BuildRaiderIfNeeded(unitName)
end

function TaskShpHST:Lvl1ShipDestroyerOnly()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corroy"
	else
		unitName = "armroy"
	end
	local mtypedLv = self.ai.TasksHST:GetMtypedLv(unitName) + self.ai.TasksHST:GetMtypedLv('armcs')
	return self.ai.TasksHST:BuildWithLimitedNumber(unitName,mtypedLv * 0.7)
end

function TaskShpHST:Lvl1ShipBattle()
	local unitName = ""
	if self.ai.Metal.full < 0.5 then
		if self.side == self.ai.UnitiesHST.CORESideName then
			unitName = "coresupp"
		else
			unitName = "armdecade"
		end
	else
		if self.side == self.ai.UnitiesHST.CORESideName then
			unitName = "corroy"
		else
			unitName = "armroy"
		end
	end
	return self.ai.TasksHST:BuildBattleIfNeeded(unitName)
end

function TaskShpHST:ScoutShip()
	local unitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corpt"
	else
		unitName = "armpt"
	end
	local scout = self.ai.TasksHST:BuildWithLimitedNumber(unitName, 1)
	if scout == self.ai.UnitiesHST.DummyUnitName then
		return self.ai.TasksHST:BuildAAIfNeeded(unitName)
	else
		return unitName
	end
end

--LEVEL 2
function TaskShpHST:ConAdvSub()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "coracsub"
	else
		unitName = "armacsub"
	end
	local mtypedLv = self.ai.TasksHST:GetMtypedLv(unitName) + self.ai.TasksHST:GetMtypedLv('cormls') --need count shp too
	return self.ai.TasksHST:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 2, self.ai.conUnitPerTypeLimit))
end

function TaskShpHST:Lvl2ShipAssist()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "cormls"
	else
		unitName = "armmls"
	end
	local mtypedLv = self.ai.TasksHST:GetMtypedLv(unitName) + self.ai.TasksHST:GetMtypedLv('coracsub') --need count sub too
	return self.ai.TasksHST:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 2, self.ai.conUnitPerTypeLimit))
end

function TaskShpHST:Lvl2ShipBreakthrough()
	local unitName = ""
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corbats"
	else
		unitName = "armbats"
	end
	return self.ai.TasksHST:BuildBreakthroughIfNeeded(unitName)
end

function TaskShpHST:Lvl2ShipMerl()
	local unitName = ""
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "cormship"
	else
		unitName = "armmship"
	end
	return self.ai.TasksHST:BuildSiegeIfNeeded(unitName)
end

function TaskShpHST:MegaShip()
	local unitName = ""
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corblackhy"
	else
		unitName = "armepoch"
	end
	return self.ai.TasksHST:BuildBreakthroughIfNeeded(self.ai.TasksHST:BuildWithLimitedNumber(unitName, 1))
end

function TaskShpHST:Lvl2ShipRaider()
	local unitName = ""
		if self.side == self.ai.UnitiesHST.CORESideName then
			unitName = "corshark"
		else
			unitName = "armsubk"
		end

	return self.ai.TasksHST:BuildRaiderIfNeeded(unitName)
end

function TaskShpHST:Lvl2SubWar()
	local unitName = self.ai.UnitiesHST.DummyUnitName
		if self.side == self.ai.UnitiesHST.CORESideName then
			unitName = "corssub"
		else
			unitName = "armserp"
		end

	return self.ai.TasksHST:BuildBattleIfNeeded(unitName)
end

function TaskShpHST:Lvl2ShipBattle()
	local unitName = ""
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corcrus"
	else
		unitName = "armcrus"
	end
	return self.ai.TasksHST:BuildBattleIfNeeded(unitName)
end

function TaskShpHST:Lvl2AAShip()
	if self.side == self.ai.UnitiesHST.CORESideName then
		return self.ai.TasksHST:BuildAAIfNeeded("corarch")
	else
		return self.ai.TasksHST:BuildAAIfNeeded("armaas")
	end
end

