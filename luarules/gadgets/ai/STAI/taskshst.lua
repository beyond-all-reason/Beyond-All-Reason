TasksHST = class(Module)

function TasksHST:Name()
	return "TasksHST"
end

function TasksHST:Init()
	self.DebugEnabled = false
end

random = math.random
math.randomseed( os.time() + game:GetTeamID() )
random(); random(); random()

function TasksHST:MapHasWater()
	return (self.ai.waterMap or self.ai.hasUWSpots) or false
end

-- this is initialized in maphst
function TasksHST:MapHasUnderwaterMetal()
	return self.ai.hasUWSpots or false
end

function TasksHST:IsSiegeEquipmentNeeded()
	return self.ai.overviewhst.needSiege
end

function TasksHST:IsAANeeded()
	return self.ai.needAirDefense
end

function TasksHST:IsShieldNeeded()
	return self.ai.needShields
end

function TasksHST:IsTorpedoNeeded()
	return self.ai.needSubmergedDefense
end

function TasksHST:IsJammerNeeded()
	return self.ai.needJammers
end

function TasksHST:IsAntinukeNeeded()
	return self.ai.needAntinuke
end

function TasksHST:IsNukeNeeded()
	local nuke = self.ai.needNukes and self.ai.canNuke
	return nuke
end

function TasksHST:IsLandAttackNeeded()
	return self.ai.areLandTargets or self.ai.needGroundDefense
end

function TasksHST:IsWaterAttackNeeded()
	return self.ai.areWaterTargets or self.ai.needSubmergedDefense
end

function TasksHST:GetMtypedLv(unitName)
	local mtype = self.ai.UnitiesHST.unitTable[unitName].mtype
	local level = self.ai.UnitiesHST.unitTable[unitName].techLevel
	local mtypedLv = mtype .. tostring(level)
	local counter = self.ai.mtypeLvCount[mtypedLv] or 0
	EchoDebug('mtypedLvmtype ' .. mtype .. ' '.. level .. ' ' .. counter)
	return counter
end


function TasksHST:BuildAAIfNeeded(unitName)
	if IsAANeeded() then
		if not self.ai.UnitiesHST.unitTable[unitName].isBuilding then
			return BuildWithLimitedNumber(unitName, self.ai.overviewhst.AAUnitPerTypeLimit)
		else
			return unitName
		end
	else
		return UnitiesHST.DummyUnitName
	end
end

function TasksHST:BuildTorpedoIfNeeded(unitName)
	if IsTorpedoNeeded() then
		return unitName
	else
		return UnitiesHST.DummyUnitName
	end
end

function TasksHST:BuildSiegeIfNeeded(unitName)
	if unitName == UnitiesHST.DummyUnitName then return UnitiesHST.DummyUnitName end
	if IsSiegeEquipmentNeeded() then
		if self.ai.siegeCount < (self.ai.battleCount + self.ai.breakthroughCount) * 0.35 then
			return unitName
		end
	end
	return UnitiesHST.DummyUnitName
end

function TasksHST:BuildBreakthroughIfNeeded(unitName)
	if unitName == UnitiesHST.DummyUnitName or unitName == nil then return UnitiesHST.DummyUnitName end
	if IsSiegeEquipmentNeeded() then return unitName end
	local mtype = self.ai.UnitiesHST.unitTable[unitName].mtype
	if mtype == "air" then
		local bomberCounter = self.ai.bomberhst:GetCounter()
		if bomberCounter >= UnitiesHST.breakthroughBomberCounter and bomberCounter < UnitiesHST.maxBomberCounter then
			return unitName
		else
			return UnitiesHST.DummyUnitName
		end
	else
		if self.ai.battleCount <= UnitiesHST.minBattleCount then return UnitiesHST.DummyUnitName end
		local attackCounter = self.ai.attackhst:GetCounter(mtype)
		if attackCounter == UnitiesHST.maxAttackCounter then
			return unitName
		elseif attackCounter >= UnitiesHST.breakthroughAttackCounter then
			return unitName
		else
			return UnitiesHST.DummyUnitName
		end
	end
end

function TasksHST:BuildRaiderIfNeeded(unitName)
	EchoDebug("build raider if needed: " .. unitName)
	if unitName == UnitiesHST.DummyUnitName or unitName == nil then return UnitiesHST.DummyUnitName end
	local mtype = self.ai.UnitiesHST.unitTable[unitName].mtype
	if self.ai.factoriesAtLevel[3] ~= nil and self.ai.factoriesAtLevel[3] ~= {} then
		-- if we have a level 2 factory, don't build raiders until we have some battle units
		local attackCounter = self.ai.attackhst:GetCounter(mtype)
		if self.ai.battleCount + self.ai.breakthroughCount < attackCounter / 2 then
			return UnitiesHST.DummyUnitName
		end
	end
	local counter = self.ai.raidhst:GetCounter(mtype)
	if counter == UnitiesHST.minRaidCounter then return UnitiesHST.DummyUnitName end
	if self.ai.raiderCount[mtype] == nil then
		-- fine
	elseif self.ai.raiderCount[mtype] >= counter then
		unitName = UnitiesHST.DummyUnitName
	end
	return unitName
end

function TasksHST:BuildBattleIfNeeded(unitName)
	if unitName == UnitiesHST.DummyUnitName or unitName == nil then return UnitiesHST.DummyUnitName end
	local mtype = self.ai.UnitiesHST.unitTable[unitName].mtype
	local attackCounter = self.ai.attackhst:GetCounter(mtype)
	EchoDebug(mtype .. " " .. attackCounter .. " " .. UnitiesHST.maxAttackCounter)
	if attackCounter == UnitiesHST.maxAttackCounter and self.ai.battleCount > UnitiesHST.minBattleCount then return UnitiesHST.DummyUnitName end
	if mtype == "veh" and self.side == UnitiesHST.CORESideName and (self.ai.factoriesAtLevel[1] == nil or self.ai.factoriesAtLevel[1] == {}) then
		-- core only has a lvl1 vehicle raider, so this prevents getting stuck
		return unitName
	end
	if self.ai.factoriesAtLevel[3] ~= nil and self.ai.factoriesAtLevel[3] ~= {} then
		-- if we have a level 2 factory, don't wait to build raiders first
		return unitName
	end
	local raidCounter = self.ai.raidhst:GetCounter(mtype)
	EchoDebug(mtype .. " " .. raidCounter .. " " .. UnitiesHST.maxRaidCounter)
	if raidCounter == UnitiesHST.minRaidCounter then return unitName end
	EchoDebug(self.ai.raiderCount[mtype])
	if self.ai.raiderCount[mtype] == nil then
		return unitName
	elseif self.ai.raiderCount[mtype] < raidCounter / 2 then
		return UnitiesHST.DummyUnitName
	else
		return unitName
	end
end

function TasksHST:CountOwnUnits(tmpUnitName)
	if tmpUnitName == UnitiesHST.DummyUnitName then return 0 end -- don't count no-units
	if self.ai.nameCount[tmpUnitName] == nil then return 0 end
	return self.ai.nameCount[tmpUnitName]
end

function TasksHST:BuildWithLimitedNumber(tmpUnitName, minNumber)
	if tmpUnitName == UnitiesHST.DummyUnitName then return UnitiesHST.DummyUnitName end
	if minNumber == 0 then return UnitiesHST.DummyUnitName end
	if self.ai.nameCount[tmpUnitName] == nil then
		return tmpUnitName
	else
		if self.ai.nameCount[tmpUnitName] == 0 or self.ai.nameCount[tmpUnitName] < minNumber then
			return tmpUnitName
		else
			return UnitiesHST.DummyUnitName
		end
	end
end

function TasksHST:GroundDefenseIfNeeded(unitName)
	if not self.ai.needGroundDefense then
		return UnitiesHST.DummyUnitName
	else
		return unitName
	end
end

function TasksHST:BuildBomberIfNeeded(unitName)
	if not IsLandAttackNeeded() then return UnitiesHST.DummyUnitName end
	if unitName == UnitiesHST.DummyUnitName or unitName == nil then return UnitiesHST.DummyUnitName end
	if self.ai.bomberhst:GetCounter() == UnitiesHST.maxBomberCounter then
		return UnitiesHST.DummyUnitName
	else
		return unitName
	end
end

function TasksHST:BuildTorpedoBomberIfNeeded(unitName)
	if not IsWaterAttackNeeded() then return UnitiesHST.DummyUnitName end
	if unitName == UnitiesHST.DummyUnitName or unitName == nil then return UnitiesHST.DummyUnitName end
	if self.ai.bomberhst:GetCounter() == UnitiesHST.maxBomberCounter then
		return UnitiesHST.DummyUnitName
	else
		return unitName
	end
end


function TasksHST:LandOrWater(tskqbhvr, landName, waterName)
	local builder = tskqbhvr.unit:Internal()
	local bpos = builder:GetPosition()
	local waterNet = self.ai.maphst:MobilityNetworkSizeHere("shp", bpos)
	if waterNet ~= nil then
		return waterName
	else
		return landName
	end
end


function TasksHST:ConsulAsFactory(tskqbhvr)
	local unitName = UnitiesHST.DummyUnitName
	local rnd = math.random(1,8)
	if 	rnd == 1 then unitName=ConVehicle(tskqbhvr)
	elseif 	rnd == 2 then unitName=ConShip(tskqbhvr)
	elseif 	rnd == 3 then unitName=Lvl1BotRaider(tskqbhvr)
	elseif 	rnd == 4 then unitName=Lvl1AABot(tskqbhvr)
	elseif 	rnd == 5 then unitName=Lvl2BotArty(tskqbhvr)
	elseif 	rnd == 6 then unitName=Lvl2BotAllTerrain(tskqbhvr)
	elseif 	rnd == 7 then unitName=Lvl2BotMedium(tskqbhvr)
	else unitName = Lvl1ShipDestroyerOnly(tskqbhvr)
	end
	if unitName == nil then unitName = UnitiesHST.DummyUnitName end
	EchoDebug('Consul as factory '..unitName)
	return unitName
end

function TasksHST:FreakerAsFactory(tskqbhvr)
	local unitName = UnitiesHST.DummyUnitName
	local rnd = math.random(1,7)
	if 	rnd == 1 then unitName=ConBot(tskqbhvr)
	elseif 	rnd == 2 then unitName=ConShip(tskqbhvr)
	elseif 	rnd == 3 then unitName=Lvl1BotRaider(tskqbhvr)
	elseif 	rnd == 4 then unitName=Lvl1AABot(tskqbhvr)
	elseif 	rnd == 5 then unitName=Lvl2BotRaider(tskqbhvr)
	elseif 	rnd == 6 then unitName=Lvl2AmphBot(tskqbhvr)
	else unitName = Lvl1ShipDestroyerOnly(tskqbhvr)
	end
	if unitName == nil then unitName = UnitiesHST.DummyUnitName end
	EchoDebug('Freaker as factory '..unitName)
	return unitName
end

function TasksHST:NavalEngineerAsFactory(tskqbhvr)
	local unitName = UnitiesHST.DummyUnitName
	local rnd= math.random(1,6)
	if 	rnd == 1 then unitName=ConShip(tskqbhvr)
	elseif 	rnd == 2 then unitName=ScoutShip(tskqbhvr)
	elseif 	rnd == 3 then unitName=Lvl1ShipDestroyerOnly(tskqbhvr)
	elseif 	rnd == 4 then unitName=Lvl1ShipRaider(tskqbhvr)
	elseif 	rnd == 5 then unitName=Lvl1ShipBattle(tskqbhvr)
	else unitName=Lvl2AmphBot(tskqbhvr)
	end
	EchoDebug('Naval engineers as factory '..unitName)
	return unitName
end

function TasksHST:EngineerAsFactory(tskqbhvr)
	local unitName = UnitiesHST.DummyUnitName
	if self.side == UnitiesHST.CORESideName then
		unitName = FreakerAsFactory(tskqbhvr)
	else
		unitName = ConsulAsFactory(tskqbhvr)
	end
	return unitName
end



-- mobile construction units:

TasksHST.anyCommander = {
	self.ai.TaskEcoHST:BuildAppropriateFactory,
	self.ai.TaskEcoHST:CommanderEconomy,
	self.ai.TaskBuildHST:BuildLLT,
	self.ai.TaskBuildHST:BuildRadar,
	self.ai.TaskBuildHST:CommanderAA,
	self.ai.TaskBuildHST:BuildPopTorpedo,
}

TasksHST.anyConUnit = {
	self.ai.TaskEcoHST:BuildAppropriateFactory,
	self.ai.TaskEcoHST:Economy1,
	self.ai.TaskBuildHST:BuildLLT,
	self.ai.TaskEcoHST:Economy1,
	self.ai.TaskBuildHST:BuildMediumAA,
	self.ai.TaskBuildHST:BuildRadar,
	self.ai.TaskBuildHST:BuildLvl1Jammer,
	self.ai.TaskEcoHST:BuildGeo,
	self.ai.TaskBuildHST:BuildHLT,
	self.ai.TaskBuildHST:BuildLvl1Plasma,
	self.ai.TaskBuildHST:BuildHeavyishAA,
}

TasksHST.anyConAmphibious = {
	self.ai.TaskEcoHST:BuildAppropriateFactory,
	self.ai.TaskEcoHST:AmphibiousEconomy,
	self.ai.TaskEcoHST:BuildGeo,
	self.ai.TaskEcoHST:Economy1,
	self.ai.TaskBuildHST:BuildMediumAA,
	self.ai.TaskBuildHST:BuildRadar,
	self.ai.TaskBuildHST:BuildLvl1Jammer,
	self.ai.TaskBuildHST:BuildHLT,
	self.ai.TaskBuildHST:BuildLvl1Plasma,
	self.ai.TaskBuildHST:BuildHeavyishAA,
	self.ai.TaskEcoHST:AmphibiousEconomy,
	self.ai.TaskBuildHST:BuildPopTorpedo,
	self.ai.TaskBuildHST:BuildFloatLightAA,
	self.ai.TaskBuildHST:BuildFloatRadar,
	self.ai.TaskBuildHST:BuildFloatHLT,
}

TasksHST.anyConShip = {
	self.ai.TaskEcoHST:BuildAppropriateFactory,
	self.ai.TaskEcoHST:EconomyUnderWater,
	self.ai.TaskBuildHST:BuildFloatLightAA,
	self.ai.TaskBuildHST:BuildLightTorpedo,
	self.ai.TaskBuildHST:BuildFloatRadar,
	self.ai.TaskBuildHST:BuildFloatHLT,
}

TasksHST.anyAdvConUnit = {
	self.ai.TaskEcoHST:BuildAppropriateFactory,
	self.ai.TaskEcoHST:AdvEconomy,
	self.ai.TaskBuildHST:BuildNukeIfNeeded,
	self.ai.TaskBuildHST:BuildAdvancedRadar,
	self.ai.TaskBuildHST:BuildHeavyPlasma,
	self.ai.TaskBuildHST:BuildAntinuke,
	self.ai.TaskBuildHST:BuildLvl2PopUp,
	self.ai.TaskBuildHST:BuildHeavyAA,
	self.ai.TaskBuildHST:BuildLvl2Plasma,
	self.ai.TaskBuildHST:BuildTachyon,
	-- BuildTacticalNuke,
	self.ai.TaskBuildHST:BuildExtraHeavyAA,
	self.ai.TaskBuildHST:BuildLvl2Jammer,
	self.ai.TaskEcoHST:BuildMohoGeo,
}

TasksHST.anyConSeaplane = {
	self.ai.TaskEcoHST:BuildAppropriateFactory,
	self.ai.TaskEcoHST:EconomySeaplane,
	self.ai.TaskBuildHST:BuildFloatHeavyAA,
	self.ai.TaskBuildHST:BuildAdvancedSonar,
	self.ai.TaskBuildHST:BuildHeavyTorpedo,
}

TasksHST.anyAdvConSub = {
	self.ai.TaskEcoHST:BuildAppropriateFactory,
	self.ai.TaskEcoHST:AdvEconomyUnderWater,
	self.ai.TaskBuildHST:BuildFloatHeavyAA,
	self.ai.TaskBuildHST:BuildAdvancedSonar,
	self.ai.TaskBuildHST:BuildHeavyTorpedo,
}

TasksHST.anyNavalEngineer = {
	self.ai.TaskEcoHST:BuildAppropriateFactory,
	self.ai.TaskEcoHST:EconomyNavalEngineer,
	self.ai.TaskBuildHST:BuildFloatHLT,
	self.ai.TaskBuildHST:BuildFloatLightAA,
	self.ai.TaskBuildHST:BuildFloatRadar,
	self.ai.TaskBuildHST:BuildLightTorpedo,
}

TasksHST.anyCombatEngineer = {
	self.ai.TaskEcoHST:BuildAppropriateFactory,
	self.ai.TaskEcoHST:EconomyBattleEngineer,
	self.ai.TaskBuildHST:BuildMediumAA,
	self.ai.TaskBuildHST:BuildAdvancedRadar,
	self.ai.TaskBuildHST:BuildLvl2Jammer,
	self.ai.TaskBuildHST:BuildHeavyAA,
	self.ai.TaskEcoHST:Economy1,
	self.ai.TaskBuildHST:BuildLvl2Plasma,
}


-- factories:

TasksHST.anyLvl1AirPlant = {
	self.ai.TaskAirHST:ScoutAir,
	self.ai.TaskAirHST:Lvl1Bomber,
	self.ai.TaskAirHST:Lvl1AirRaider,
	self.ai.TaskAirHST:ConAir,
	self.ai.TaskAirHST:Lvl1Fighter,
}

TasksHST.anyLvl1VehPlant = {
	self.ai.TaskVehHST:ScoutVeh,
	self.ai.TaskVehHST:ConVehicle,
	self.ai.TaskVehHST:Lvl1VehRaider,
	self.ai.TaskVehHST:Lvl1VehBattle,
	self.ai.TaskVehHST:Lvl1AAVeh,
	self.ai.TaskVehHST:Lvl1VehArty,
	self.ai.TaskVehHST:Lvl1VehBreakthrough,
}

TasksHST.anyLvl1BotLab = {
	self.ai.TaskBotHST:ScoutBot,
	self.ai.TaskBotHST:ConBot,
	self.ai.TaskBotHST:Lvl1BotRaider,
	self.ai.TaskBotHST:Lvl1BotBattle,
	self.ai.TaskBotHST:Lvl1AABot,
	self.ai.TaskBotHST:Lvl1BotBreakthrough,
	self.ai.TaskBotHST:RezBot1,
}

TasksHST.anyLvl1ShipYard = {
	self.ai.TaskShpHST:ScoutShip,
	self.ai.TaskShpHST:ConShip,
	self.ai.TaskShpHST:Lvl1ShipBattle,
	self.ai.TaskShpHST:Lvl1ShipRaider,
}

TasksHST.anyHoverPlatform = {
	self.ai.TaskHovHST:HoverRaider,
	self.ai.TaskHovHST:ConHover,
	self.ai.TaskHovHST:HoverBattle,
	self.ai.TaskHovHST:HoverBreakthrough,
	self.ai.TaskHovHST:HoverMerl,
	self.ai.TaskHovHST:AAHover,
}

TasksHST.anyAmphibiousComplex = {
	self.ai.TaskVehHST:AmphibiousRaider,
	self.ai.TaskVehHST:ConVehicleAmphibious,
	self.ai.TaskVehHST:AmphibiousBattle,
	self.ai.TaskShpHST:Lvl1ShipRaider,
	self.ai.TaskBotHST:Lvl1AABot,
	self.ai.TaskBotHST:Lvl2AABot,
}

TasksHST.anyLvl2VehPlant = {
	self.ai.TaskVehHST:ConAdvVehicle,
	self.ai.TaskVehHST:Lvl2VehRaider,
	self.ai.TaskVehHST:Lvl2VehBattle,
	self.ai.TaskVehHST:Lvl2VehBreakthrough,
	self.ai.TaskVehHST:Lvl2VehArty,
	self.ai.TaskVehHST:Lvl2VehMerl,
	self.ai.TaskVehHST:Lvl2AAVeh,
	self.ai.TaskVehHST:Lvl2VehAssist,
}

TasksHST.anyLvl2BotLab = {
	self.ai.TaskBotHST:Lvl2BotRaider,
	self.ai.TaskBotHST:ConAdvBot,
	self.ai.TaskBotHST:Lvl2BotBattle,
	self.ai.TaskBotHST:Lvl2BotBreakthrough,
	self.ai.TaskBotHST:Lvl2BotArty,
	self.ai.TaskBotHST:Lvl2BotMerl,
	self.ai.TaskBotHST:Lvl2AABot,
	self.ai.TaskBotHST:Lvl2BotAssist,
}

TasksHST.anyLvl2AirPlant = {
	self.ai.TaskAirHST:Lvl2Bomber,
	self.ai.TaskAirHST:Lvl2TorpedoBomber,
	self.ai.TaskAirHST:ConAdvAir,
	self.ai.TaskAirHST:ScoutAdvAir,
	self.ai.TaskAirHST:Lvl2Fighter,
	self.ai.TaskAirHST:Lvl2AirRaider,
	self.ai.TaskAirHST:MegaAircraft,
}

TasksHST.anySeaplanePlatform = {
	self.ai.TaskAirHST:SeaBomber,
	self.ai.TaskAirHST:SeaTorpedoBomber,
	self.ai.TaskAirHST:ConSeaAir,
	self.ai.TaskAirHST:ScoutSeaAir,
	self.ai.TaskAirHST:SeaFighter,
	self.ai.TaskAirHST:SeaAirRaider,
}

TasksHST.anyLvl2ShipYard = {
	self.ai.TaskShpHST:Lvl2ShipRaider,
	self.ai.TaskShpHST:ConAdvSub,
	self.ai.TaskShpHST:Lvl2ShipBattle,
	self.ai.TaskShpHST:Lvl2AAShip,
	self.ai.TaskShpHST:Lvl2ShipBreakthrough,
	self.ai.TaskShpHST:Lvl2ShipMerl,
	self.ai.TaskShpHST:Lvl2ShipAssist,
	self.ai.TaskShpHST:Lvl2SubWar,
	self.ai.TaskShpHST:MegaShip,
}

TasksHST.anyExperimental = {
	self.ai.TaskBotHST:Lvl3Raider,
	self.ai.TaskBotHST:Lvl3Battle,
	self.ai.TaskBotHST:Lvl3Merl,
	self.ai.TaskBotHST:Lvl3Arty,
	self.ai.TaskBotHST:Lvl3Breakthrough,
}

TasksHST.anyOutmodedLvl1BotLab = {
	self.ai.TaskBotHST:ConBot,
	self.ai.TaskBotHST:RezBot1,
	self.ai.TaskBotHST:ScoutBot,
	self.ai.TaskBotHST:Lvl1AABot,
}

TasksHST.anyOutmodedLvl1VehPlant = {
	self.ai.TaskVehHST:Lvl1VehRaiderOutmoded,
	self.ai.TaskVehHST:ConVehicle,
	self.ai.TaskVehHST:ScoutVeh,
	self.ai.TaskVehHST:Lvl1AAVeh,
}

TasksHST.anyOutmodedLvl1AirPlant = {
	self.ai.TaskAirHST:ConAir,
	self.ai.TaskAirHST:ScoutAir,
	self.ai.TaskAirHST:Lvl1Fighter,
}

TasksHST.anyOutmodedLvl1ShipYard = {
	self.ai.TaskShpHST:ConShip,
	self.ai.TaskShpHST:ScoutShip,
}

TasksHST.anyOutmodedLvl2BotLab = {
	-- Lvl2BotRaider,
	self.ai.TaskBotHST:ConAdvBot,
	self.ai.TaskBotHST:Lvl2AABot,
	self.ai.TaskBotHST:Lvl2BotAssist,
}

TasksHST.anyOutmodedLvl2VehPlant = {
	-- Lvl2VehRaider,
	self.ai.TaskVehHST:Lvl2VehAssist,
	self.ai.TaskVehHST:ConAdvVehicle,
	self.ai.TaskVehHST:Lvl2AAVeh,
}

-- fall back to these when a level 2 factory exists
TasksHST.outmodedTaskqueues = {
	corlab = self.anyOutmodedLvl1BotLab,
	armlab = self.anyOutmodedLvl1BotLab,
	corvp = self.anyOutmodedLvl1VehPlant,
	armvp = self.anyOutmodedLvl1VehPlant,
	corap = self.anyOutmodedLvl1AirPlant,
	armap = self.anyOutmodedLvl1AirPlant,
	corsy = self.anyOutmodedLvl1ShipYard,
	armsy = self.anyOutmodedLvl1ShipYard,
	coralab = self.anyOutmodedLvl2BotLab,
	armalab = self.anyOutmodedLvl2BotLab,
	coravp = self.anyOutmodedLvl2VehPlant,
	armavp = self.anyOutmodedLvl2VehPlant,
}

-- finally, the taskqueue definitions
TasksHST.taskqueues = {
	corcom = self.anyCommander,
	armcom = self.anyCommander,
	armdecom = self.anyCommander,
	cordecom = self.anyCommander,
	corcv = self.anyConUnit,
	armcv = self.anyConUnit,
	corck = self.anyConUnit,
	armck = self.anyConUnit,
	cormuskrat = self.anyConAmphibious,
	armbeaver = self.anyConAmphibious,
	corch = self.anyConAmphibious,
	armch = self.anyConAmphibious,
	corca = self.anyConUnit,
	armca = self.anyConUnit,
	corack = self.anyAdvConUnit,
	armack = self.anyAdvConUnit,
	coracv = self.anyAdvConUnit,
	armacv = self.anyAdvConUnit,
	coraca = self.anyAdvConUnit,
	armaca = self.anyAdvConUnit,
	corcsa = self.anyConSeaplane,
	armcsa = self.anyConSeaplane,
	corcs = self.anyConShip,
	armcs = self.anyConShip,
	coracsub = self.anyAdvConSub,
	armacsub = self.anyAdvConSub,
	cormls = self.anyNavalEngineer,
	armmls = self.anyNavalEngineer,
	armconsul = self.anyCombatEngineer,
	corfast = self.anyCombatEngineer,
	corap = self.anyLvl1AirPlant,
	armap = self.anyLvl1AirPlant,
	corlab = self.anyLvl1BotLab,
	armlab = self.anyLvl1BotLab,
	corvp = self.anyLvl1VehPlant,
	armvp = self.anyLvl1VehPlant,
	coralab = self.anyLvl2BotLab,
	coravp = self.anyLvl2VehPlant,
	corhp = self.anyHoverPlatform,
	armhp = self.anyHoverPlatform,
	corfhp = self.anyHoverPlatform,
	armfhp = self.anyHoverPlatform,
	coramsub = self.anyAmphibiousComplex,
	armamsub = self.anyAmphibiousComplex,
	armalab = self.anyLvl2BotLab,
	armavp = self.anyLvl2VehPlant,
	coraap = self.anyLvl2AirPlant,
	armaap = self.anyLvl2AirPlant,
	corplat = self.anySeaplanePlatform,
	armplat = self.anySeaplanePlatform,
	corsy = self.anyLvl1ShipYard,
	armsy = self.anyLvl1ShipYard,
	corasy = self.anyLvl2ShipYard,
	armasy = self.anyLvl2ShipYard,
	corgant = self.anyExperimental,
	armshltx = self.anyExperimental,
	corgantuw = self.anyUWExperimental,
	armshltxuw = self.anyUWExperimental,
	armfark = self.anyfark,
}
