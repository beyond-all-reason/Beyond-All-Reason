TaskShpHST = class(Module)

function TaskShpHST:Name()
	return "TaskShpHST"
end

function TaskShpHST:Init()
	self.DebugEnabled = false
end
--LEVEL 1

function TaskShpHST:ConShip()
	local unitName = UnitiesHST.DummyUnitName
	if self.side == UnitiesHST.CORESideName then
		unitName = "corcs"
	else
		unitName = "armcs"
	end
	local mtypedLv = GetMtypedLv(unitName) + GetMtypedLv('correcl') --need count sub too
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 5) + 2, self.ai.conUnitPerTypeLimit))
end

function TaskShpHST:RezSub1()
	local unitName = UnitiesHST.DummyUnitName
	if self.side == UnitiesHST.CORESideName then
		unitName = "correcl"
	else
		unitName = "armrecl"
	end
	local mtypedLv = GetMtypedLv(unitName) + GetMtypedLv('armcs') --need count shp too
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 8) + 2, self.ai.conUnitPerTypeLimit))
end

function TaskShpHST:Lvl1ShipRaider()
	local unitName = UnitiesHST.DummyUnitName
	if self.side == UnitiesHST.CORESideName then
		unitName = "corsub"
	else
		unitName = "armsub"
	end
	return BuildRaiderIfNeeded(unitName)
end

function TaskShpHST:Lvl1ShipDestroyerOnly()
	local unitName = UnitiesHST.DummyUnitName
	if self.side == UnitiesHST.CORESideName then
		unitName = "corroy"
	else
		unitName = "armroy"
	end
	local mtypedLv = GetMtypedLv(unitName) + GetMtypedLv('armcs')
	return BuildWithLimitedNumber(unitName,mtypedLv * 0.7)
end

function TaskShpHST:Lvl1ShipBattle()
	local unitName = ""
	if self.ai.Metal.full < 0.5 then
		if self.side == UnitiesHST.CORESideName then
			unitName = "coresupp"
		else
			unitName = "armdecade"
		end
	else
		if self.side == UnitiesHST.CORESideName then
			unitName = "corroy"
		else
			unitName = "armroy"
		end
	end
	return BuildBattleIfNeeded(unitName)
end

function TaskShpHST:ScoutShip()
	local unitName
	if self.side == UnitiesHST.CORESideName then
		unitName = "corpt"
	else
		unitName = "armpt"
	end
	local scout = BuildWithLimitedNumber(unitName, 1)
	if scout == UnitiesHST.DummyUnitName then
		return BuildAAIfNeeded(unitName)
	else
		return unitName
	end
end

--LEVEL 2
function TaskShpHST:ConAdvSub()
	local unitName = UnitiesHST.DummyUnitName
	if self.side == UnitiesHST.CORESideName then
		unitName = "coracsub"
	else
		unitName = "armacsub"
	end
	local mtypedLv = GetMtypedLv(unitName) + GetMtypedLv('cormls') --need count shp too
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 2, self.ai.conUnitPerTypeLimit))
end

function TaskShpHST:Lvl2ShipAssist()
	local unitName = UnitiesHST.DummyUnitName
	if self.side == UnitiesHST.CORESideName then
		unitName = "cormls"
	else
		unitName = "armmls"
	end
	local mtypedLv = GetMtypedLv(unitName) + GetMtypedLv('coracsub') --need count sub too
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 2, self.ai.conUnitPerTypeLimit))
end

function TaskShpHST:Lvl2ShipBreakthrough()
	local unitName = ""
	if self.side == UnitiesHST.CORESideName then
		unitName = "corbats"
	else
		unitName = "armbats"
	end
	return BuildBreakthroughIfNeeded(unitName)
end

function TaskShpHST:Lvl2ShipMerl()
	local unitName = ""
	if self.side == UnitiesHST.CORESideName then
		unitName = "cormship"
	else
		unitName = "armmship"
	end
	return BuildSiegeIfNeeded(unitName)
end

function TaskShpHST:MegaShip()
	local unitName = ""
	if self.side == UnitiesHST.CORESideName then
		unitName = "corblackhy"
	else
		unitName = "armepoch"
	end
	return BuildBreakthroughIfNeeded(BuildWithLimitedNumber(unitName, 1))
end

function TaskShpHST:Lvl2ShipRaider()
	local unitName = ""
		if self.side == UnitiesHST.CORESideName then
			unitName = "corshark"
		else
			unitName = "armsubk"
		end

	return BuildRaiderIfNeeded(unitName)
end

function TaskShpHST:Lvl2SubWar()
	local unitName = UnitiesHST.DummyUnitName
		if self.side == UnitiesHST.CORESideName then
			unitName = "corssub"
		else
			unitName = "armserp"
		end

	return BuildBattleIfNeeded(unitName)
end

function TaskShpHST:Lvl2ShipBattle()
	local unitName = ""
	if self.side == UnitiesHST.CORESideName then
		unitName = "corcrus"
	else
		unitName = "armcrus"
	end
	return BuildBattleIfNeeded(unitName)
end

function TaskShpHST:Lvl2AAShip()
	if self.side == UnitiesHST.CORESideName then
		return BuildAAIfNeeded("corarch")
	else
		return BuildAAIfNeeded("armaas")
	end
end

