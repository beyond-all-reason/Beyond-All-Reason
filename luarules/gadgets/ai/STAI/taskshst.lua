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

function TasksHST: MapHasWater()
	return (ai.waterMap or ai.hasUWSpots) or false
end

-- this is initialized in maphst
function TasksHST: MapHasUnderwaterMetal()
	return ai.hasUWSpots or false
end

function TasksHST: IsSiegeEquipmentNeeded()
	return ai.overviewhst.needSiege
end

function TasksHST: IsAANeeded()
	return ai.needAirDefense
end

function TasksHST: IsShieldNeeded()
	return ai.needShields
end

function TasksHST: IsTorpedoNeeded()
	return ai.needSubmergedDefense
end

function TasksHST: IsJammerNeeded()
	return ai.needJammers
end

function TasksHST: IsAntinukeNeeded()
	return ai.needAntinuke
end

function TasksHST: IsNukeNeeded()
	local nuke = ai.needNukes and ai.canNuke
	return nuke
end

function TasksHST: IsLandAttackNeeded()
	return ai.areLandTargets or ai.needGroundDefense
end

function TasksHST: IsWaterAttackNeeded()
	return ai.areWaterTargets or ai.needSubmergedDefense
end

function TasksHST: GetMtypedLv(unitName)
	local mtype = ai.UnitiesHST.unitTable[unitName].mtype
	local level = ai.UnitiesHST.unitTable[unitName].techLevel
	local mtypedLv = mtype .. tostring(level)
	local counter = ai.mtypeLvCount[mtypedLv] or 0
	EchoDebug('mtypedLvmtype ' .. mtype .. ' '.. level .. ' ' .. counter)
	return counter
end


function TasksHST: BuildAAIfNeeded(unitName)
	if IsAANeeded() then
		if not ai.UnitiesHST.unitTable[unitName].isBuilding then
			return BuildWithLimitedNumber(unitName, ai.overviewhst.AAUnitPerTypeLimit)
		else
			return unitName
		end
	else
		return UnitiesHST.DummyUnitName
	end
end

function TasksHST: BuildTorpedoIfNeeded(unitName)
	if IsTorpedoNeeded() then
		return unitName
	else
		return UnitiesHST.DummyUnitName
	end
end

function TasksHST: BuildSiegeIfNeeded(unitName)
	if unitName == UnitiesHST.DummyUnitName then return UnitiesHST.DummyUnitName end
	if IsSiegeEquipmentNeeded() then
		if ai.siegeCount < (ai.battleCount + ai.breakthroughCount) * 0.35 then
			return unitName
		end
	end
	return UnitiesHST.DummyUnitName
end

function TasksHST: BuildBreakthroughIfNeeded(unitName)
	if unitName == UnitiesHST.DummyUnitName or unitName == nil then return UnitiesHST.DummyUnitName end
	if IsSiegeEquipmentNeeded() then return unitName end
	local mtype = ai.UnitiesHST.unitTable[unitName].mtype
	if mtype == "air" then
		local bomberCounter = ai.bomberhst:GetCounter()
		if bomberCounter >= UnitiesHST.breakthroughBomberCounter and bomberCounter < UnitiesHST.maxBomberCounter then
			return unitName
		else
			return UnitiesHST.DummyUnitName
		end
	else
		if ai.battleCount <= UnitiesHST.minBattleCount then return UnitiesHST.DummyUnitName end
		local attackCounter = ai.attackhst:GetCounter(mtype)
		if attackCounter == UnitiesHST.maxAttackCounter then
			return unitName
		elseif attackCounter >= UnitiesHST.breakthroughAttackCounter then
			return unitName
		else
			return UnitiesHST.DummyUnitName
		end
	end
end

function TasksHST: BuildRaiderIfNeeded(unitName)
	EchoDebug("build raider if needed: " .. unitName)
	if unitName == UnitiesHST.DummyUnitName or unitName == nil then return UnitiesHST.DummyUnitName end
	local mtype = ai.UnitiesHST.unitTable[unitName].mtype
	if ai.factoriesAtLevel[3] ~= nil and ai.factoriesAtLevel[3] ~= {} then
		-- if we have a level 2 factory, don't build raiders until we have some battle units
		local attackCounter = ai.attackhst:GetCounter(mtype)
		if ai.battleCount + ai.breakthroughCount < attackCounter / 2 then
			return UnitiesHST.DummyUnitName
		end
	end
	local counter = ai.raidhst:GetCounter(mtype)
	if counter == UnitiesHST.minRaidCounter then return UnitiesHST.DummyUnitName end
	if ai.raiderCount[mtype] == nil then
		-- fine
	elseif ai.raiderCount[mtype] >= counter then
		unitName = UnitiesHST.DummyUnitName
	end
	return unitName
end

function TasksHST: BuildBattleIfNeeded(unitName)
	if unitName == UnitiesHST.DummyUnitName or unitName == nil then return UnitiesHST.DummyUnitName end
	local mtype = ai.UnitiesHST.unitTable[unitName].mtype
	local attackCounter = ai.attackhst:GetCounter(mtype)
	EchoDebug(mtype .. " " .. attackCounter .. " " .. UnitiesHST.maxAttackCounter)
	if attackCounter == UnitiesHST.maxAttackCounter and ai.battleCount > UnitiesHST.minBattleCount then return UnitiesHST.DummyUnitName end
	if mtype == "veh" and self.side == UnitiesHST.CORESideName and (ai.factoriesAtLevel[1] == nil or ai.factoriesAtLevel[1] == {}) then
		-- core only has a lvl1 vehicle raider, so this prevents getting stuck
		return unitName
	end
	if ai.factoriesAtLevel[3] ~= nil and ai.factoriesAtLevel[3] ~= {} then
		-- if we have a level 2 factory, don't wait to build raiders first
		return unitName
	end
	local raidCounter = ai.raidhst:GetCounter(mtype)
	EchoDebug(mtype .. " " .. raidCounter .. " " .. UnitiesHST.maxRaidCounter)
	if raidCounter == UnitiesHST.minRaidCounter then return unitName end
	EchoDebug(ai.raiderCount[mtype])
	if ai.raiderCount[mtype] == nil then
		return unitName
	elseif ai.raiderCount[mtype] < raidCounter / 2 then
		return UnitiesHST.DummyUnitName
	else
		return unitName
	end
end

function TasksHST: CountOwnUnits(tmpUnitName)
	if tmpUnitName == UnitiesHST.DummyUnitName then return 0 end -- don't count no-units
	if ai.nameCount[tmpUnitName] == nil then return 0 end
	return ai.nameCount[tmpUnitName]
end

function TasksHST: BuildWithLimitedNumber(tmpUnitName, minNumber)
	if tmpUnitName == UnitiesHST.DummyUnitName then return UnitiesHST.DummyUnitName end
	if minNumber == 0 then return UnitiesHST.DummyUnitName end
	if ai.nameCount[tmpUnitName] == nil then
		return tmpUnitName
	else
		if ai.nameCount[tmpUnitName] == 0 or ai.nameCount[tmpUnitName] < minNumber then
			return tmpUnitName
		else
			return UnitiesHST.DummyUnitName
		end
	end
end

function TasksHST: GroundDefenseIfNeeded(unitName)
	if not ai.needGroundDefense then
		return UnitiesHST.DummyUnitName
	else
		return unitName
	end
end

function TasksHST: BuildBomberIfNeeded(unitName)
	if not IsLandAttackNeeded() then return UnitiesHST.DummyUnitName end
	if unitName == UnitiesHST.DummyUnitName or unitName == nil then return UnitiesHST.DummyUnitName end
	if ai.bomberhst:GetCounter() == UnitiesHST.maxBomberCounter then
		return UnitiesHST.DummyUnitName
	else
		return unitName
	end
end

function TasksHST: BuildTorpedoBomberIfNeeded(unitName)
	if not IsWaterAttackNeeded() then return UnitiesHST.DummyUnitName end
	if unitName == UnitiesHST.DummyUnitName or unitName == nil then return UnitiesHST.DummyUnitName end
	if ai.bomberhst:GetCounter() == UnitiesHST.maxBomberCounter then
		return UnitiesHST.DummyUnitName
	else
		return unitName
	end
end


function TasksHST: LandOrWater(tskqbhvr, landName, waterName)
	local builder = tskqbhvr.unit:Internal()
	local bpos = builder:GetPosition()
	local waterNet = ai.maphst:MobilityNetworkSizeHere("shp", bpos)
	if waterNet ~= nil then
		return waterName
	else
		return landName
	end
end


function TasksHST: TasksHST: ConsulAsFactory(tskqbhvr)
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

function TasksHST: TasksHST: FreakerAsFactory(tskqbhvr)
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

function TasksHST: NavalEngineerAsFactory(tskqbhvr)
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

function TasksHST: EngineerAsFactory(tskqbhvr)
	local unitName = UnitiesHST.DummyUnitName
	if self.side == UnitiesHST.CORESideName then
		unitName = FreakerAsFactory(tskqbhvr)
	else
		unitName = ConsulAsFactory(tskqbhvr)
	end
	return unitName
end

function TasksHST: TasksHST: CommanderEconomy(tskqbhvr)
	local underwater = ai.maphst:IsUnderWater(tskqbhvr.unit:Internal():GetPosition())
	local unitName = UnitiesHST.DummyUnitName
	if not underwater then
		unitName = Economy0()
	else
		unitName = Economy0uw()
	end
	return unitName


end

function TasksHST: TasksHST: AmphibiousEconomy(tskqbhvr)
	local underwater = ai.maphst:IsUnderWater(tskqbhvr.unit:Internal():GetPosition())
	local unitName = UnitiesHST.DummyUnitName
	if underwater then
		unitName = EconomyUnderWater(tskqbhvr)
	else
		unitName = Economy1(tskqbhvr)
	end
	return unitName

end

-- mobile construction units:

TasksHST.anyCommander = {
	BuildAppropriateFactory,
	CommanderEconomy,
	BuildLLT,
	BuildRadar,
	CommanderAA,
	BuildPopTorpedo,
}

TasksHST.anyConUnit = {
	BuildAppropriateFactory,
	Economy1,
	BuildLLT,
	BuildSpecialLT,
	BuildMediumAA,
	BuildRadar,
	BuildLvl1Jammer,
	BuildGeo,
	BuildHLT,
	BuildLvl1Plasma,
	BuildHeavyishAA,
}

TasksHST.anyConAmphibious = {
	BuildAppropriateFactory,
	AmphibiousEconomy,
	BuildGeo,
	BuildSpecialLT,
	BuildMediumAA,
	BuildRadar,
	BuildLvl1Jammer,
	BuildHLT,
	BuildLvl1Plasma,
	BuildHeavyishAA,
	AmphibiousEconomy,
	BuildPopTorpedo,
	BuildFloatLightAA,
	BuildFloatRadar,
	BuildFloatHLT,
}

TasksHST.anyConShip = {
	BuildAppropriateFactory,
	EconomyUnderWater,
	BuildFloatLightAA,
	BuildLightTorpedo,
	BuildFloatRadar,
	BuildFloatHLT,
}

TasksHST.anyAdvConUnit = {
	BuildAppropriateFactory,
	AdvEconomy,
	BuildNukeIfNeeded,
	BuildAdvancedRadar,
	BuildHeavyPlasma,
	BuildAntinuke,
	BuildLvl2PopUp,
	BuildHeavyAA,
	BuildLvl2Plasma,
	BuildTachyon,
	-- BuildTacticalNuke,
	BuildExtraHeavyAA,
	BuildLvl2Jammer,
	BuildMohoGeo,
}

TasksHST.anyConSeaplane = {
	BuildAppropriateFactory,
	EconomySeaplane,
	BuildFloatHeavyAA,
	BuildAdvancedSonar,
	BuildHeavyTorpedo,
}

TasksHST.anyAdvConSub = {
	BuildAppropriateFactory,
	AdvEconomyUnderWater,
	BuildFloatHeavyAA,
	BuildAdvancedSonar,
	BuildHeavyTorpedo,
}

TasksHST.anyNavalEngineer = {
	BuildAppropriateFactory,
	EconomyNavalEngineer,
	BuildFloatHLT,
	BuildFloatLightAA,
	BuildFloatRadar,
	BuildLightTorpedo,
}

TasksHST.anyCombatEngineer = {
	BuildAppropriateFactory,
	EconomyBattleEngineer,
	BuildMediumAA,
	BuildAdvancedRadar,
	BuildLvl2Jammer,
	BuildHeavyAA,
	BuildSpecialLTOnly,
	BuildLvl2Plasma,
}


-- factories:

TasksHST.anyLvl1AirPlant = {
	ScoutAir,
	Lvl1Bomber,
	Lvl1AirRaider,
	ConAir,
	Lvl1Fighter,
}

TasksHST.anyLvl1VehPlant = {
	ScoutVeh,
	ConVehicle,
	Lvl1VehRaider,
	Lvl1VehBattle,
	Lvl1AAVeh,
	Lvl1VehArty,
	Lvl1VehBreakthrough,
}

TasksHST.anyLvl1BotLab = {
	ScoutBot,
	ConBot,
	Lvl1BotRaider,
	Lvl1BotBattle,
	Lvl1AABot,
	Lvl1BotBreakthrough,
	RezBot1,
}

TasksHST.anyLvl1ShipYard = {
	ScoutShip,
	ConShip,
	Lvl1ShipBattle,
	Lvl1ShipRaider,
}

TasksHST.anyHoverPlatform = {
	HoverRaider,
	ConHover,
	HoverBattle,
	HoverBreakthrough,
	HoverMerl,
	AAHover,
}

TasksHST.anyAmphibiousComplex = {
	AmphibiousRaider,
	ConVehicleAmphibious,
	AmphibiousBattle,
	Lvl1ShipRaider,
	Lvl1AABot,
	Lvl2AABot,
}

TasksHST.anyLvl2VehPlant = {
	ConAdvVehicle,
	Lvl2VehRaider,
	Lvl2VehBattle,
	Lvl2VehBreakthrough,
	Lvl2VehArty,
	Lvl2VehMerl,
	Lvl2AAVeh,
	Lvl2VehAssist,
}

TasksHST.anyLvl2BotLab = {
	Lvl2BotRaider,
	ConAdvBot,
	Lvl2BotBattle,
	Lvl2BotBreakthrough,
	Lvl2BotArty,
	Lvl2BotMerl,
	Lvl2AABot,
	Lvl2BotAssist,
}

TasksHST.anyLvl2AirPlant = {
	Lvl2Bomber,
	Lvl2TorpedoBomber,
	ConAdvAir,
	ScoutAdvAir,
	Lvl2Fighter,
	Lvl2AirRaider,
	MegaAircraft,
}

TasksHST.anySeaplanePlatform = {
	SeaBomber,
	SeaTorpedoBomber,
	ConSeaAir,
	ScoutSeaAir,
	SeaFighter,
	SeaAirRaider,
}

TasksHST.anyLvl2ShipYard = {
	Lvl2ShipRaider,
	ConAdvSub,
	Lvl2ShipBattle,
	Lvl2AAShip,
	Lvl2ShipBreakthrough,
	Lvl2ShipMerl,
	Lvl2ShipAssist,
	Lvl2SubWar,
	MegaShip,
}

TasksHST.anyExperimental = {
	Lvl3Raider,
	Lvl3Battle,
	Lvl3Merl,
	Lvl3Arty,
	Lvl3Breakthrough,
}

TasksHST.anyOutmodedLvl1BotLab = {
	ConBot,
	RezBot1,
	ScoutBot,
	Lvl1AABot,
}

TasksHST.anyOutmodedLvl1VehPlant = {
	Lvl1VehRaiderOutmoded,
	ConVehicle,
	ScoutVeh,
	Lvl1AAVeh,
}

TasksHST.anyOutmodedLvl1AirPlant = {
	ConAir,
	ScoutAir,
	Lvl1Fighter,
}

TasksHST.anyOutmodedLvl1ShipYard = {
	ConShip,
	ScoutShip,
}

TasksHST.anyOutmodedLvl2BotLab = {
	-- Lvl2BotRaider,
	ConAdvBot,
	Lvl2AABot,
	Lvl2BotAssist,
}

TasksHST.anyOutmodedLvl2VehPlant = {
	-- Lvl2VehRaider,
	Lvl2VehAssist,
	ConAdvVehicle,
	Lvl2AAVeh,
}

-- fall back to these when a level 2 factory exists
TasksHST.outmodedTaskqueues = {
	corlab = TasksHST.anyOutmodedLvl1BotLab,
	armlab = TasksHST.anyOutmodedLvl1BotLab,
	corvp = TasksHST.anyOutmodedLvl1VehPlant,
	armvp = TasksHST.anyOutmodedLvl1VehPlant,
	corap = TasksHST.anyOutmodedLvl1AirPlant,
	armap = TasksHST.anyOutmodedLvl1AirPlant,
	corsy = TasksHST.anyOutmodedLvl1ShipYard,
	armsy = TasksHST.anyOutmodedLvl1ShipYard,
	coralab = TasksHST.anyOutmodedLvl2BotLab,
	armalab = TasksHST.anyOutmodedLvl2BotLab,
	coravp = TasksHST.anyOutmodedLvl2VehPlant,
	armavp = TasksHST.anyOutmodedLvl2VehPlant,
}

-- finally, the taskqueue definitions
TasksHST.taskqueues = {
	corcom = TasksHST.anyCommander,
	armcom = TasksHST.anyCommander,
	armdecom = TasksHST.anyCommander,
	cordecom = TasksHST.anyCommander,
	corcv = TasksHST.anyConUnit,
	armcv = TasksHST.anyConUnit,
	corck = TasksHST.anyConUnit,
	armck = TasksHST.anyConUnit,
	cormuskrat = TasksHST.anyConAmphibious,
	armbeaver = TasksHST.anyConAmphibious,
	corch = TasksHST.anyConAmphibious,
	armch = TasksHST.anyConAmphibious,
	corca = TasksHST.anyConUnit,
	armca = TasksHST.anyConUnit,
	corack = TasksHST.anyAdvConUnit,
	armack = TasksHST.anyAdvConUnit,
	coracv = TasksHST.anyAdvConUnit,
	armacv = TasksHST.anyAdvConUnit,
	coraca = TasksHST.anyAdvConUnit,
	armaca = TasksHST.anyAdvConUnit,
	corcsa = TasksHST.anyConSeaplane,
	armcsa = TasksHST.anyConSeaplane,
	corcs = TasksHST.anyConShip,
	armcs = TasksHST.anyConShip,
	coracsub = TasksHST.anyAdvConSub,
	armacsub = TasksHST.anyAdvConSub,
	cormls = TasksHST.anyNavalEngineer,
	armmls = TasksHST.anyNavalEngineer,
	armconsul = TasksHST.anyCombatEngineer,
	corfast = TasksHST.anyCombatEngineer,
	corap = TasksHST.anyLvl1AirPlant,
	armap = TasksHST.anyLvl1AirPlant,
	corlab = TasksHST.anyLvl1BotLab,
	armlab = TasksHST.anyLvl1BotLab,
	corvp = TasksHST.anyLvl1VehPlant,
	armvp = TasksHST.anyLvl1VehPlant,
	coralab = TasksHST.anyLvl2BotLab,
	coravp = TasksHST.anyLvl2VehPlant,
	corhp = TasksHST.anyHoverPlatform,
	armhp = TasksHST.anyHoverPlatform,
	corfhp = TasksHST.anyHoverPlatform,
	armfhp = TasksHST.anyHoverPlatform,
	coramsub = TasksHST.anyAmphibiousComplex,
	armamsub = TasksHST.anyAmphibiousComplex,
	armalab = TasksHST.anyLvl2BotLab,
	armavp = TasksHST.anyLvl2VehPlant,
	coraap = TasksHST.anyLvl2AirPlant,
	armaap = TasksHST.anyLvl2AirPlant,
	corplat = TasksHST.anySeaplanePlatform,
	armplat = TasksHST.anySeaplanePlatform,
	corsy = TasksHST.anyLvl1ShipYard,
	armsy = TasksHST.anyLvl1ShipYard,
	corasy = TasksHST.anyLvl2ShipYard,
	armasy = TasksHST.anyLvl2ShipYard,
	corgant = TasksHST.anyExperimental,
	armshltx = TasksHST.anyExperimental,
	corgantuw = TasksHST.anyUWExperimental,
	armshltxuw = TasksHST.anyUWExperimental,
	armfark = TasksHST.anyfark,
}
