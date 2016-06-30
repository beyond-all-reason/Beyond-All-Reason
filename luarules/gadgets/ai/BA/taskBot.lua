ocal DebugEnabled = false

local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("taskBot: " .. inStr)
	end
end


--LEVEL 1

function ConBot()
	local unitName = DummyUnitName
	if ai.mySide == CORESideName then
		unitName = "corck"
	else
		unitName = "armck"
	end
	local mtypedLv = GetMtypedLv(unitName)
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 1, ai.conUnitPerTypeLimit))
end

function RezBot1(self)
	local unitName = DummyUnitName
	if ai.mySide == CORESideName then
		unitName = "cornecro"
	else
		unitName = "armrectr"
	end
	local mtypedLv = GetMtypedLv(unitName)
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 8) + 1 , ai.conUnitPerTypeLimit))
end

function Lvl1BotRaider(self)
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "corak"
	else
		unitName = "armpw"
	end
	return BuildRaiderIfNeeded(unitName)
end

function Lvl1BotBreakthrough(self)
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "corthud"
	else
		unitName = "armwar"
	end
	return BuildBreakthroughIfNeeded(unitName)
end

function Lvl1BotBattle(self)
	local unitName = ""
	local r = math.random(1, 2)
	if r == 1 then
		if ai.mySide == CORESideName then
			unitName = "corthud"
		else
			unitName = "armham"
		end
	else
		if ai.mySide == CORESideName then
			unitName = "corstorm"
		else
			unitName = "armrock"
		end
	end
	return BuildBattleIfNeeded(unitName)
end

function Lvl1AABot()
	if ai.mySide == CORESideName then
		return BuildAAIfNeeded("corcrash")
	else
		return BuildAAIfNeeded("armjeth")
	end
end

function ScoutBot()
	local unitName
	if ai.mySide == CORESideName then
		return DummyUnitName
	else
		unitName = "armflea"
	end
	return BuildWithLimitedNumber(unitName, 1)
end

--LEVEL 2

function ConAdvBot()
	local unitName = DummyUnitName
	if ai.mySide == CORESideName then
		unitName = "corack"
	else
		unitName = "armack"
	end
	local mtypedLv = GetMtypedLv(unitName)
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 10) + 1, ai.conUnitAdvPerTypeLimit))
end


function Lvl2BotAssist()
	unitName = DummyUnitName
	if ai.mySide == CORESideName then
		unitName = "corfast"
	else
		unitName = "armfark"
	end
	local mtypedLv = GetMtypedLv(unitName)
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 8) + 1, ai.conUnitPerTypeLimit))
end

function NewCommanders(self)
	local unitName = DummyUnitName
	if ai.mySide == CORESideName then
		unitName = 'commando'
	else
		unitName = DummyUnitName
	end
	return unitName
end
	
function Decoy(self)
	local unitName = DummyUnitName
	if ai.mySide == CORESideName then
		unitName = 'cordecom'
	else
		unitName = 'armdecom'
	end
	return unitName
end


function Lvl2BotBreakthrough(self)
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "corsumo"
	else
		unitName = "armfboy"
	end
	return BuildBreakthroughIfNeeded(unitName)
end

function Lvl2BotArty(self)
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "cormort"
	else
		unitName = "armfido"
	end
	return BuildSiegeIfNeeded(unitName)
end

function Lvl2BotLongRange(self)
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "corhrk"
	else
		unitName = "armsnipe"
	end
	return BuildSiegeIfNeeded(unitName)
end

function Lvl2BotRaider(self)
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "corpyro"
	else
		unitName = "armfast"
	end
	return BuildRaiderIfNeeded(unitName)
end

function Lvl2BotCorRaiderArmArty(self)
	if ai.mySide == CORESideName then
		return Lvl2BotRaider(self)
	else
		return Lvl2BotArty(self)
	end
end

function Lvl2BotAllTerrain(self)
	local unitName=DummyUnitName
	if ai.mySide == CORESideName then
		unitName = 'cortermite'
	else
		unitName = "armsptk"
	end
	return unitName
end

function Lvl2BotBattle(self)
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "corcan"
	else
		unitName = "armzeus"
	end
	return BuildBattleIfNeeded(unitName)
end

function Lvl2BotMedium(self)
	local unitName=DummyUnitName
	if ai.mySide == CORESideName then
		unitName = 'corcan'
	else
		unitName = "armmav"
	end
	return unitName
end

function Lvl2AmphBot(self)
	local unitName=DummyUnitName
	if ai.mySide == CORESideName then
		unitName = 'coramph'
	else
		unitName = 'armamph'
	end
	return unitName
end

function Lvl2AABot()
	if ai.mySide == CORESideName then
		return BuildAAIfNeeded("coraak")
	else
		return BuildAAIfNeeded("armaak")
	end
end
