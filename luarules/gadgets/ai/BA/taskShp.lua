 DebugEnabled = false

local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("taskShp: " .. inStr)
	end
end
--LEVEL 1

function ConShip()
	local unitName = DummyUnitName
	if ai.mySide == CORESideName then
		unitName = "corcs"
	else
		unitName = "armcs"
	end
	local mtypedLv = GetMtypedLv(unitName) + GetMtypedLv('correcl') --need count sub too
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 5) + 2, ai.conUnitPerTypeLimit))
end

function RezSub1(self)
	local unitName = DummyUnitName
	if ai.mySide == CORESideName then
		unitName = "correcl"
	else
		unitName = "armrecl"
	end
	local mtypedLv = GetMtypedLv(unitName) + GetMtypedLv('armcs') --need count shp too
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 8) + 2, ai.conUnitPerTypeLimit))
end

function Lvl1ShipRaider(self)
	local unitName = DummyUnitName
	if ai.mySide == CORESideName then
		unitName = "corsub"
	else
		unitName = "armsub"
	end
	return BuildRaiderIfNeeded(unitName)
end

function Lvl1ShipDestroyerOnly(self)
	local unitName = DummyUnitName
	if ai.mySide == CORESideName then
		unitName = "corroy"
	else
		unitName = "armroy"
	end
	local mtypedLv = GetMtypedLv(unitName) + GetMtypedLv('armcs')
	return BuildWithLimitedNumber(unitName,mtypedLv * 0.7)
end

function Lvl1ShipBattle(self)
	local unitName = ""
	if ai.Metal.full < 0.5 then
		if ai.mySide == CORESideName then
			unitName = "coresupp"
		else
			unitName = "decade"
		end
	else
		if ai.mySide == CORESideName then
			unitName = "corroy"
		else
			unitName = "armroy"
		end
	end
	return BuildBattleIfNeeded(unitName)
end

function ScoutShip()
	local unitName
	if ai.mySide == CORESideName then
		unitName = "corpt"
	else
		unitName = "armpt"
	end
	local scout = BuildWithLimitedNumber(unitName, 1)
	if scout == DummyUnitName then
		return BuildAAIfNeeded(unitName)
	else
		return unitName
	end
end

--LEVEL 2
function ConAdvSub()
	local unitName = DummyUnitName
	if ai.mySide == CORESideName then
		unitName = "coracsub"
	else
		unitName = "armacsub"
	end
	local mtypedLv = GetMtypedLv(unitName) + GetMtypedLv('cormls') --need count shp too
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 2, ai.conUnitPerTypeLimit))
end

function Lvl2ShipAssist()
	local unitName = DummyUnitName
	if ai.mySide == CORESideName then
		unitName = "cormls"
	else
		unitName = "armmls"
	end
	local mtypedLv = GetMtypedLv(unitName) + GetMtypedLv('coracsub') --need count sub too
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 2, ai.conUnitPerTypeLimit))
end

function Lvl2ShipBreakthrough(self)
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "corbats"
	else
		unitName = "armbats"
	end
	return BuildBreakthroughIfNeeded(unitName)
end

function Lvl2ShipMerl(self)
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "cormship"
	else
		unitName = "armmship"
	end
	return BuildSiegeIfNeeded(unitName)
end

function MegaShip()
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "corblackhy"
	else
		unitName = "aseadragon"
	end
	return BuildBreakthroughIfNeeded(BuildWithLimitedNumber(unitName, 1))
end

function Lvl2ShipRaider(self)
	local unitName = ""
		if ai.mySide == CORESideName then
			unitName = "corshark"
		else
			unitName = "armsubk"
		end

	return BuildRaiderIfNeeded(unitName)
end

function Lvl2SubWar(self)
	local unitName = DummyUnitName
		if ai.mySide == CORESideName then
			unitName = "corssub"
		else
			unitName = "tawf009"
		end

	return BuildBattleIfNeeded(unitName)
end

function Lvl2ShipBattle(self)
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "corcrus"
	else
		unitName = "armcrus"
	end
	return BuildBattleIfNeeded(unitName)
end

function Lvl2AAShip()
	if ai.mySide == CORESideName then
		return BuildAAIfNeeded("corarch")
	else
		return BuildAAIfNeeded("armaas")
	end
end

