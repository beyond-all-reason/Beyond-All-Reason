TaskShpHST = class(Module)

function TaskShpHST:Name()
	return "TaskShpHST"
end

function TaskShpHST:internalName()
	return "taskshphst"
end


function TaskShpHST:Init()
	self.DebugEnabled = false
end
--LEVEL 1

function TaskShpHST:ConShip()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corcs"
	else
		unitName = "armcs"
	end
	local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName) + self.ai.taskshst:GetMtypedLv('correcl') --need count sub too
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 5) + 2, self.ai.conUnitPerTypeLimit))
end

function TaskShpHST:RezSub1()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "correcl"
	else
		unitName = "armrecl"
	end
	local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName) + self.ai.taskshst:GetMtypedLv('armcs') --need count shp too
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 8) + 2, self.ai.conUnitPerTypeLimit))
end

function TaskShpHST:Lvl1ShipRaider()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corsub"
	else
		unitName = "armsub"
	end
	return self.ai.taskshst:BuildRaiderIfNeeded(unitName)
end

function TaskShpHST:Lvl1ShipDestroyerOnly()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corroy"
	else
		unitName = "armroy"
	end
	local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName) + self.ai.taskshst:GetMtypedLv('armcs')
	return self.ai.taskshst:BuildWithLimitedNumber(unitName,mtypedLv * 0.7)
end

function TaskShpHST:Lvl1ShipBattle()
	local unitName = ""
	if self.ai.Metal.full < 0.5 then
		if  self.ai.side == self.ai.armyhst.CORESideName then
			unitName = "coresupp"
		else
			unitName = "armdecade"
		end
	else
		if  self.ai.side == self.ai.armyhst.CORESideName then
			unitName = "corroy"
		else
			unitName = "armroy"
		end
	end
	return self.ai.taskshst:BuildBattleIfNeeded(unitName)
end

function TaskShpHST:ScoutShip()
	local unitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corpt"
	else
		unitName = "armpt"
	end
	local scout = self.ai.taskshst:BuildWithLimitedNumber(unitName, 1)
	if scout == self.ai.armyhst.DummyUnitName then
		return self.ai.taskshst:BuildAAIfNeeded(unitName)
	else
		return unitName
	end
end

--LEVEL 2
function TaskShpHST:ConAdvSub()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "coracsub"
	else
		unitName = "armacsub"
	end
	local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName) + self.ai.taskshst:GetMtypedLv('cormls') --need count shp too
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 2, self.ai.conUnitPerTypeLimit))
end

function TaskShpHST:Lvl2ShipAssist()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "cormls"
	else
		unitName = "armmls"
	end
	local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName) + self.ai.taskshst:GetMtypedLv('coracsub') --need count sub too
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 2, self.ai.conUnitPerTypeLimit))
end

function TaskShpHST:Lvl2ShipBreakthrough()
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corbats"
	else
		unitName = "armbats"
	end
	return self.ai.taskshst:BuildBreakthroughIfNeeded(unitName)
end

function TaskShpHST:Lvl2ShipMerl()
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "cormship"
	else
		unitName = "armmship"
	end
	return self.ai.taskshst:BuildSiegeIfNeeded(unitName)
end

function TaskShpHST:MegaShip()
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corblackhy"
	else
		unitName = "armepoch"
	end
	return self.ai.taskshst:BuildBreakthroughIfNeeded(self.ai.taskshst:BuildWithLimitedNumber(unitName, 1))
end

function TaskShpHST:Lvl2ShipRaider()
	local unitName = ""
		if  self.ai.side == self.ai.armyhst.CORESideName then
			unitName = "corshark"
		else
			unitName = "armsubk"
		end

	return self.ai.taskshst:BuildRaiderIfNeeded(unitName)
end

function TaskShpHST:Lvl2SubWar()
	local unitName = self.ai.armyhst.DummyUnitName
		if  self.ai.side == self.ai.armyhst.CORESideName then
			unitName = "corssub"
		else
			unitName = "armserp"
		end

	return self.ai.taskshst:BuildBattleIfNeeded(unitName)
end

function TaskShpHST:Lvl2ShipBattle()
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corcrus"
	else
		unitName = "armcrus"
	end
	return self.ai.taskshst:BuildBattleIfNeeded(unitName)
end

function TaskShpHST:Lvl2AAShip()
	if  self.ai.side == self.ai.armyhst.CORESideName then
		return self.ai.taskshst:BuildAAIfNeeded("corarch")
	else
		return self.ai.taskshst:BuildAAIfNeeded("armaas")
	end
end

