

local DebugEnabled = false

local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("taskBot: " .. inStr)
	end
end


--LEVEL 1

function ConBot()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "corck"
	else
		unitName = "armck"
	end
	local mtypedLv = GetMtypedLv(unitName)
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 1, ai.conUnitPerTypeLimit))
end

function RezBot1(tskqbhvr)
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "cornecro"
	else
		unitName = "armrectr"
	end
	local mtypedLv = GetMtypedLv(unitName)
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 8) + 1 , ai.conUnitPerTypeLimit))
end

function Lvl1BotRaider(tskqbhvr)
	local unitName = ""
	if MyTB.side == CORESideName then
		unitName = "corak"
	else
		unitName = "armpw"
	end
	return BuildRaiderIfNeeded(unitName)
end

function Lvl1BotBreakthrough(tskqbhvr)
	local unitName = ""
	if MyTB.side == CORESideName then
		unitName = "corthud"
	else
		unitName = "armwar"
	end
	return BuildBreakthroughIfNeeded(unitName)
end

function Lvl1BotBattle(tskqbhvr)
	local unitName = ""
	local r = math.random()
	local compare = ai.overviewhandler.plasmaRocketBotRatio or 1
	if compare >= 1 or math.random() < compare then
		if MyTB.side == CORESideName then
			unitName = "corthud"
		else
			unitName = "armham"
		end
	else
		if MyTB.side == CORESideName then
			unitName = "corstorm"
		else
			unitName = "armrock"
		end
	end
	return BuildBattleIfNeeded(unitName)
end

function Lvl1AABot()
	if MyTB.side == CORESideName then
		return BuildAAIfNeeded("corcrash")
	else
		return BuildAAIfNeeded("armjeth")
	end
end

function ScoutBot()
	local unitName
	if MyTB.side == CORESideName then
		return DummyUnitName
	else
		unitName = "armflea"
	end
	return BuildWithLimitedNumber(unitName, 1)
end

--LEVEL 2

function ConAdvBot()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "corack"
	else
		unitName = "armack"
	end
	local mtypedLv = GetMtypedLv(unitName)
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 10) + 1, ai.conUnitAdvPerTypeLimit))
end


function Lvl2BotAssist()
	unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "corfast"
	else
		unitName = "armfark"
	end
	local mtypedLv = GetMtypedLv(unitName)
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 8) + 1, ai.conUnitPerTypeLimit))
end

function NewCommanders(tskqbhvr)
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = 'commando'
	else
		unitName = DummyUnitName
	end
	return unitName
end
	
function Decoy(tskqbhvr)
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = 'cordecom'
	else
		unitName = 'armdecom'
	end
	return unitName
end


function Lvl2BotBreakthrough(tskqbhvr)
	local unitName = ""
	if MyTB.side == CORESideName then
		unitName = "corsumo"
	else
		unitName = "armfboy"
	end
	return BuildBreakthroughIfNeeded(unitName)
end

function Lvl2BotArty(tskqbhvr)
	local unitName = ""
	if MyTB.side == CORESideName then
		unitName = "cormort"
	else
		unitName = "armfido"
	end
	return BuildSiegeIfNeeded(unitName)
end

function Lvl2BotLongRange(tskqbhvr)
	local unitName = ""
	if MyTB.side == CORESideName then
		unitName = "corhrk"
	else
		unitName = "armsnipe"
	end
	return BuildSiegeIfNeeded(unitName)
end

function Lvl2BotRaider(tskqbhvr)
	local unitName = ""
	if MyTB.side == CORESideName then
		unitName = "corpyro"
	else
		unitName = "armfast"
	end
	return BuildRaiderIfNeeded(unitName)
end

function Lvl2BotCorRaiderArmArty(tskqbhvr)
	if MyTB.side == CORESideName then
		return Lvl2BotRaider(tskqbhvr)
	else
		return Lvl2BotArty(tskqbhvr)
	end
end

function Lvl2BotAllTerrain(tskqbhvr)
	local unitName=DummyUnitName
	if MyTB.side == CORESideName then
		unitName = 'cortermite'
	else
		unitName = "armsptk"
	end
	return unitName
end

function Lvl2BotBattle(tskqbhvr)
	local unitName = ""
	if MyTB.side == CORESideName then
		unitName = "corcan"
	else
		unitName = "armzeus"
	end
	return BuildBattleIfNeeded(unitName)
end

function Lvl2BotMedium(tskqbhvr)
	local unitName=DummyUnitName
	if MyTB.side == CORESideName then
		unitName = 'corcan'
	else
		unitName = "armmav"
	end
	return unitName
end

function Lvl2AmphBot(tskqbhvr)
	local unitName=DummyUnitName
	if MyTB.side == CORESideName then
		unitName = 'coramph'
	else
		unitName = 'armamph'
	end
	return unitName
end

function Lvl2AABot()
	if MyTB.side == CORESideName then
		return BuildAAIfNeeded("coraak")
	else
		return BuildAAIfNeeded("armaak")
	end
end
