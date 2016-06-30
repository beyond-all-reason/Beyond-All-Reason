 DebugEnabled = false

local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("taskVeh: " .. inStr)
	end
end


--LEVEL 1

function ConVehicleAmphibious()
	local unitName = DummyUnitName
	if ai.mySide == CORESideName then
		unitName = "cormuskrat"
	else
		unitName = "armbeaver"
	end
	local mtypedLvAmph = GetMtypedLv(unitName)
	local mtypedLvGround = GetMtypedLv('armcv')
	local mtypedLv = math.max(mtypedLvAmph, mtypedLvGround) --workaround for get the best counter
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 1, ai.conUnitPerTypeLimit))
end

function ConGroundVehicle()
	local unitName = DummyUnitName
	if ai.mySide == CORESideName then
		unitName = "corcv"
	else
		unitName = "armcv"
	end
	local mtypedLv = GetMtypedLv(unitName)
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 1, ai.conUnitPerTypeLimit))
end

function ConVehicle()
	local unitName = DummyUnitName
	if ai.situation.needAmphibiousCons then
		unitName = ConVehicleAmphibious()
	else
		unitName = ConGroundVehicle()
	end
	return unitName
end

function Lvl1VehBreakthrough(self)
	if ai.mySide == CORESideName then
		return BuildBreakthroughIfNeeded("corlevlr")
	else
		-- armjanus isn't very a very good defense unit by itself
		local output = BuildSiegeIfNeeded("armjanus")
		if output == DummyUnitName then
			output = BuildBreakthroughIfNeeded("armstump")
		end
		return output
	end
end

function Lvl1VehArty()
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "corwolv"
	else
		unitName = "tawf013"
	end
	return BuildSiegeIfNeeded(unitName)
end

function AmphibiousRaider(self)
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "corgarp"
	else
		unitName = "armpincer"
	end
	return BuildRaiderIfNeeded(unitName)
end

function Lvl1VehRaider(self)
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "corgator"
	else
		unitName = "armflash"
	end
	return BuildRaiderIfNeeded(unitName)
end

function Lvl1VehBattle(self)
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "corraid"
	else
		unitName = "armstump"
	end
	return BuildBattleIfNeeded(unitName)
end

function Lvl1VehRaiderOutmoded(self)
	if ai.mySide == CORESideName then
		return BuildRaiderIfNeeded("corgator")
	else
		return DummyUnitName
	end
end

function Lvl1AAVeh()
	if ai.mySide == CORESideName then
		return BuildAAIfNeeded("cormist")
	else
		return BuildAAIfNeeded("armsam")
	end
end

function ScoutVeh()
	local unitName
	if ai.mySide == CORESideName then
		unitName = "corfav"
	else
		unitName = "armfav"
	end
	return BuildWithLimitedNumber(unitName, 1)
end

--LEVEL 2

function ConAdvVehicle()
	local unitName = DummyUnitName
	if ai.mySide == CORESideName then
		unitName = "coracv"
	else
		unitName = "armacv"
	end
	local mtypedLv = GetMtypedLv(unitName)
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 10) + 1, ai.conUnitAdvPerTypeLimit))
end

function Lvl2VehAssist()
	if ai.mySide == CORESideName then
		return DummyUnitName
	else
		unitName = 'consul'
		local mtypedLv = GetMtypedLv(unitName)
		return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 8) + 1, ai.conUnitPerTypeLimit))
	end
end

function Lvl2VehBreakthrough(self)
	local unitName = ""
	if ai.mySide == CORESideName then
		return BuildBreakthroughIfNeeded("corgol")
	else
		-- armmanni isn't very a very good defense unit by itself
		local output = BuildSiegeIfNeeded("armmanni")
		if output == DummyUnitName then
			output = BuildBreakthroughIfNeeded("armbull")
		end
		return output
	end
end

function Lvl2VehArty(self)
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "cormart"
	else
		unitName = "armmart"
	end
	return BuildSiegeIfNeeded(unitName)
end

-- because core doesn't have a lvl2 vehicle raider or a lvl3 raider


function Lvl2VehRaider(self)
	if ai.mySide == CORESideName then
		return BuildRaiderIfNeeded("corseal")
	else
		return BuildRaiderIfNeeded("armlatnk")
	end
end



function AmphibiousBattle(self)
	local unitName = DummyUnitName
	if ai.mySide == CORESideName then
		if ai.Metal.full < 0.5 then	
			unitName = "corseal" 
		else
			unitName = "corparrow" 
		end
			
	else
		unitName = "armcroc"
	end
	return BuildBattleIfNeeded(unitName)
end

function AmphibiousBreakthrough(self)
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "corparrow"
	else
		unitName = "armcroc"
	end
	BuildBreakthroughIfNeeded(unitName)
end

function Lvl2VehBattle(self)
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "correap"
	else
		unitName = "armbull"
	end
	return BuildBattleIfNeeded(unitName)
end

function Lvl2AAVeh()
	if ai.mySide == CORESideName then
		return BuildAAIfNeeded("corsent")
	else
		return BuildAAIfNeeded("armyork")
	end
end

function Lvl2VehMerl()
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "corvroc"
	else
		unitName = "armmerl"
	end
	return BuildSiegeIfNeeded(unitName)
end




