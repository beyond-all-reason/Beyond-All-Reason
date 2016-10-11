--[[
 Task Queues!
]]--

shard_include("taskAir")
shard_include("taskBot")
shard_include("taskVeh")
shard_include("taskShp")
shard_include("taskHov")
shard_include("taskExp")
shard_include("taskBuild")
shard_include("taskEco")

local DebugEnabled = false

local function EchoDebug(inStr)
	if DebugEnabled then
		if not inStr then return end
		game:SendToConsole("Taskqueues: " .. inStr)
	end
end
random = math.random
math.randomseed( os.time() + game:GetTeamID() )
random(); random(); random()

function MapHasWater()
	return (ai.waterMap or ai.hasUWSpots) or false
end

-- this is initialized in maphandler
function MapHasUnderwaterMetal()
	return ai.hasUWSpots or false
end

function IsSiegeEquipmentNeeded()
	return ai.overviewhandler.needSiege
end

function IsAANeeded()
	return ai.needAirDefense
end

function IsShieldNeeded()
	return ai.needShields
end

function IsTorpedoNeeded()
	return ai.needSubmergedDefense
end

function IsJammerNeeded()
	return ai.needJammers
end

function IsAntinukeNeeded()
	return ai.needAntinuke
end

function IsNukeNeeded()
	local nuke = ai.needNukes and ai.canNuke
	return nuke
end

function IsLandAttackNeeded()
	return ai.areLandTargets or ai.needGroundDefense
end

function IsWaterAttackNeeded()
	return ai.areWaterTargets or ai.needSubmergedDefense
end

function GetMtypedLv(unitName)
	local mtype = unitTable[unitName].mtype
	local level = unitTable[unitName].techLevel
	local mtypedLv = mtype .. tostring(level)
	local counter = ai.mtypeLvCount[mtypedLv] or 0
	EchoDebug('mtypedLvmtype ' .. mtype .. ' '.. level .. ' ' .. counter)
	return counter
end


function BuildAAIfNeeded(unitName)
	if IsAANeeded() then
		if not unitTable[unitName].isBuilding then
			return BuildWithLimitedNumber(unitName, ai.overviewhandler.AAUnitPerTypeLimit)
		else
			return unitName
		end
	else
		return DummyUnitName
	end
end

function BuildTorpedoIfNeeded(unitName)
	if IsTorpedoNeeded() then
		return unitName
	else
		return DummyUnitName
	end
end

function BuildSiegeIfNeeded(unitName)
	if unitName == DummyUnitName then return DummyUnitName end
	if IsSiegeEquipmentNeeded() then
		if ai.siegeCount < (ai.battleCount + ai.breakthroughCount) * 0.35 then
			return unitName
		end
	end
	return DummyUnitName
end

function BuildBreakthroughIfNeeded(unitName)
	if unitName == DummyUnitName or unitName == nil then return DummyUnitName end
	if IsSiegeEquipmentNeeded() then return unitName end
	local mtype = unitTable[unitName].mtype
	if mtype == "air" then
		local bomberCounter = ai.bomberhandler:GetCounter()
		if bomberCounter >= breakthroughBomberCounter and bomberCounter < maxBomberCounter then
			return unitName
		else
			return DummyUnitName
		end
	else
		if ai.battleCount <= minBattleCount then return DummyUnitName end
		local attackCounter = ai.attackhandler:GetCounter(mtype)
		if attackCounter == maxAttackCounter then
			return unitName
		elseif attackCounter >= breakthroughAttackCounter then
			return unitName
		else
			return DummyUnitName
		end
	end
end

function BuildRaiderIfNeeded(unitName)
	EchoDebug("build raider if needed: " .. unitName)
	if unitName == DummyUnitName or unitName == nil then return DummyUnitName end
	local mtype = unitTable[unitName].mtype
	if ai.factoriesAtLevel[3] ~= nil and ai.factoriesAtLevel[3] ~= {} then
		-- if we have a level 2 factory, don't build raiders until we have some battle units
		local attackCounter = ai.attackhandler:GetCounter(mtype)
		if ai.battleCount + ai.breakthroughCount < attackCounter / 2 then
			return DummyUnitName
		end
	end
	local counter = ai.raidhandler:GetCounter(mtype)
	if counter == minRaidCounter then return DummyUnitName end
	if ai.raiderCount[mtype] == nil then
		-- fine
	elseif ai.raiderCount[mtype] >= counter then
		unitName = DummyUnitName
	end
	return unitName
end

function BuildBattleIfNeeded(unitName)
	if unitName == DummyUnitName or unitName == nil then return DummyUnitName end
	local mtype = unitTable[unitName].mtype
	local attackCounter = ai.attackhandler:GetCounter(mtype)
	EchoDebug(mtype .. " " .. attackCounter .. " " .. maxAttackCounter)
	if attackCounter == maxAttackCounter and ai.battleCount > minBattleCount then return DummyUnitName end
	if mtype == "veh" and MyTB.side == CORESideName and (ai.factoriesAtLevel[1] == nil or ai.factoriesAtLevel[1] == {}) then
		-- core only has a lvl1 vehicle raider, so this prevents getting stuck
		return unitName
	end
	if ai.factoriesAtLevel[3] ~= nil and ai.factoriesAtLevel[3] ~= {} then
		-- if we have a level 2 factory, don't wait to build raiders first
		return unitName
	end
	local raidCounter = ai.raidhandler:GetCounter(mtype)
	EchoDebug(mtype .. " " .. raidCounter .. " " .. maxRaidCounter)
	if raidCounter == minRaidCounter then return unitName end
	EchoDebug(ai.raiderCount[mtype])
	if ai.raiderCount[mtype] == nil then
		return unitName
	elseif ai.raiderCount[mtype] < raidCounter / 2 then
		return DummyUnitName
	else
		return unitName
	end
end

function CountOwnUnits(tmpUnitName)
	if tmpUnitName == DummyUnitName then return 0 end -- don't count no-units
	if ai.nameCount[tmpUnitName] == nil then return 0 end
	return ai.nameCount[tmpUnitName]
end

function BuildWithLimitedNumber(tmpUnitName, minNumber)
	if tmpUnitName == DummyUnitName then return DummyUnitName end
	if minNumber == 0 then return DummyUnitName end
	if ai.nameCount[tmpUnitName] == nil then
		return tmpUnitName
	else
		if ai.nameCount[tmpUnitName] == 0 or ai.nameCount[tmpUnitName] < minNumber then
			return tmpUnitName
		else
			return DummyUnitName
		end
	end
end

function GroundDefenseIfNeeded(unitName)
	if not ai.needGroundDefense then
		return DummyUnitName
	else
		return unitName
	end
end

function BuildBomberIfNeeded(unitName)
	if not IsLandAttackNeeded() then return DummyUnitName end
	if unitName == DummyUnitName or unitName == nil then return DummyUnitName end
	if ai.bomberhandler:GetCounter() == maxBomberCounter then
		return DummyUnitName
	else
		return unitName
	end
end

function BuildTorpedoBomberIfNeeded(unitName)
	if not IsWaterAttackNeeded() then return DummyUnitName end
	if unitName == DummyUnitName or unitName == nil then return DummyUnitName end
	if ai.bomberhandler:GetCounter() == maxBomberCounter then
		return DummyUnitName
	else
		return unitName
	end
end


function LandOrWater(tskqbhvr, landName, waterName)
	local builder = tskqbhvr.unit:Internal()
	local bpos = builder:GetPosition()
	local waterNet = ai.maphandler:MobilityNetworkSizeHere("shp", bpos)
	if waterNet ~= nil then
		return waterName
	else
		return landName
	end
end


local function ConsulAsFactory(tskqbhvr)
	local unitName = DummyUnitName
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
	if unitName == nil then unitName = DummyUnitName end
	EchoDebug('Consul as factory '..unitName)
	return unitName
end

local function FreakerAsFactory(tskqbhvr)
	local unitName = DummyUnitName
	local rnd = math.random(1,7)
	if 	rnd == 1 then unitName=ConBot(tskqbhvr)
	elseif 	rnd == 2 then unitName=ConShip(tskqbhvr)
	elseif 	rnd == 3 then unitName=Lvl1BotRaider(tskqbhvr)
	elseif 	rnd == 4 then unitName=Lvl1AABot(tskqbhvr)
	elseif 	rnd == 5 then unitName=Lvl2BotRaider(tskqbhvr)
	elseif 	rnd == 6 then unitName=Lvl2AmphBot(tskqbhvr)
	else unitName = Lvl1ShipDestroyerOnly(tskqbhvr)
	end
	if unitName == nil then unitName = DummyUnitName end
	EchoDebug('Freaker as factory '..unitName)
	return unitName
end

function NavalEngineerAsFactory(tskqbhvr)
	local unitName = DummyUnitName
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

function EngineerAsFactory(tskqbhvr)
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = FreakerAsFactory(tskqbhvr)
	else
		unitName = ConsulAsFactory(tskqbhvr)
	end
	return unitName
end	

local function CommanderEconomy(tskqbhvr)
	local underwater = ai.maphandler:IsUnderWater(tskqbhvr.unit:Internal():GetPosition())
	local unitName = DummyUnitName
	if not underwater then 
		unitName = Economy0()
	else
		unitName = EconomyUnderWater()
	end
	return unitName
	
	
end

local function AmphibiousEconomy(tskqbhvr)
	local underwater = ai.maphandler:IsUnderWater(tskqbhvr.unit:Internal():GetPosition())
	local unitName = DummyUnitName
	if underwater then 
		unitName = EconomyUnderWater(tskqbhvr)
	else
		unitName = Economy1(tskqbhvr)
	end
	return unitName
	
end

-- mobile construction units:

local anyCommander = {
	BuildAppropriateFactory,
	CommanderEconomy,
	BuildLLT,
	BuildRadar,
	CommanderAA,
	BuildPopTorpedo,
	BuildSonar,
}

local anyConUnit = {
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

local anyConAmphibious = {
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
	BuildSonar,
	BuildFloatRadar,
	BuildFloatHLT,
}

local anyConShip = {
	BuildAppropriateFactory,
	EconomyUnderWater,
	BuildFloatLightAA,
	BuildSonar,
	BuildLightTorpedo,
	BuildFloatRadar,
	BuildFloatHLT,
}

local anyAdvConUnit = {
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

local anyConSeaplane = {
	BuildAppropriateFactory,
	EconomySeaplane,
	BuildFloatHeavyAA,
	BuildAdvancedSonar,
	BuildHeavyTorpedo,
}

local anyAdvConSub = {
	BuildAppropriateFactory,
	AdvEconomyUnderWater,
	BuildFloatHeavyAA,
	BuildAdvancedSonar,
	BuildHeavyTorpedo,
}

local anyNavalEngineer = {
	BuildAppropriateFactory,
	EconomyNavalEngineer,
	BuildFloatHLT,
	BuildFloatLightAA,
	BuildFloatRadar,
	BuildSonar,
	BuildLightTorpedo,
}

local anyCombatEngineer = {
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

local anyLvl1AirPlant = {
	ScoutAir,
	Lvl1Bomber,
	Lvl1AirRaider,
	ConAir,
	Lvl1Fighter,
}

local anyLvl1VehPlant = {
	ScoutVeh,
	ConVehicle,
	Lvl1VehRaider,
	Lvl1VehBattle,
	Lvl1AAVeh,
	Lvl1VehArty,
	Lvl1VehBreakthrough,
}

local anyLvl1BotLab = {
	ScoutBot,
	ConBot,
	Lvl1BotRaider,
	Lvl1BotBattle,
	Lvl1AABot,
	Lvl1BotBreakthrough,
	RezBot1,
}

local anyLvl1ShipYard = {
	ScoutShip,
	ConShip,
	Lvl1ShipBattle,
	Lvl1ShipRaider,
}

local anyHoverPlatform = {
	HoverRaider,
	ConHover,
	HoverBattle,
	HoverBreakthrough,
	HoverMerl,
	AAHover,
}

local anyAmphibiousComplex = {
	AmphibiousRaider,
	ConVehicleAmphibious,
	AmphibiousBattle,
	Lvl1ShipRaider,
	Lvl1AABot,
	Lvl2AABot,
}

local anyLvl2VehPlant = {
	ConAdvVehicle,
	Lvl2VehRaider,
	Lvl2VehBattle,
	Lvl2VehBreakthrough,
	Lvl2VehArty,
	Lvl2VehMerl,
	Lvl2AAVeh,
	Lvl2VehAssist,
}

local anyLvl2BotLab = {
	Lvl2BotRaider,
	ConAdvBot,
	Lvl2BotBattle,
	Lvl2BotBreakthrough,
	Lvl2BotArty,
	Lvl2BotMerl,
	Lvl2AABot,
	Lvl2BotAssist,
}

local anyLvl2AirPlant = {
	Lvl2Bomber,
	Lvl2TorpedoBomber,
	ConAdvAir,
	ScoutAdvAir,
	Lvl2Fighter,
	Lvl2AirRaider,
	MegaAircraft,
}

local anySeaplanePlatform = {
	SeaBomber,
	SeaTorpedoBomber,
	ConSeaAir,
	ScoutSeaAir,
	SeaFighter,
	SeaAirRaider,
}

local anyLvl2ShipYard = {
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

local anyExperimental = {
	Lvl3Raider,
	Lvl3Battle,
	Lvl3Merl,
	Lvl3Arty,
	Lvl3Breakthrough,
}

local anyOutmodedLvl1BotLab = {
	ConBot,
	RezBot1,
	ScoutBot,
	Lvl1AABot,
}

local anyOutmodedLvl1VehPlant = {
	Lvl1VehRaiderOutmoded,
	ConVehicle,
	ScoutVeh,
	Lvl1AAVeh,
}

local anyOutmodedLvl1AirPlant = {
	ConAir,
	ScoutAir,
	Lvl1Fighter,
}

local anyOutmodedLvl1ShipYard = {
	ConShip,
	ScoutShip,
}

local anyOutmodedLvl2BotLab = {
	-- Lvl2BotRaider,
	ConAdvBot,
	Lvl2AABot,
	Lvl2BotAssist,
}

local anyOutmodedLvl2VehPlant = {
	-- Lvl2VehRaider,
	Lvl2VehAssist,
	ConAdvVehicle,
	Lvl2AAVeh,
}

-- fall back to these when a level 2 factory exists
outmodedTaskqueues = {
	corlab = anyOutmodedLvl1BotLab,
	armlab = anyOutmodedLvl1BotLab,
	corvp = anyOutmodedLvl1VehPlant,
	armvp = anyOutmodedLvl1VehPlant,
	corap = anyOutmodedLvl1AirPlant,
	armap = anyOutmodedLvl1AirPlant,
	corsy = anyOutmodedLvl1ShipYard,
	armsy = anyOutmodedLvl1ShipYard,
	coralab = anyOutmodedLvl2BotLab,
	armalab = anyOutmodedLvl2BotLab,
	coravp = anyOutmodedLvl2VehPlant,
	armavp = anyOutmodedLvl2VehPlant,
}

-- finally, the taskqueue definitions
taskqueues = {
	corcom = anyCommander,
	armcom = anyCommander,
	armdecom = anyCommander,
	cordecom = anyCommander,
	corcv = anyConUnit,
	armcv = anyConUnit,
	corck = anyConUnit,
	armck = anyConUnit,
	cormuskrat = anyConAmphibious,
	armbeaver = anyConAmphibious,
	corch = anyConAmphibious,
	armch = anyConAmphibious,
	corca = anyConUnit,
	armca = anyConUnit,
	corack = anyAdvConUnit,
	armack = anyAdvConUnit,
	coracv = anyAdvConUnit,
	armacv = anyAdvConUnit,
	coraca = anyAdvConUnit,
	armaca = anyAdvConUnit,
	corcsa = anyConSeaplane,
	armcsa = anyConSeaplane,
	corcs = anyConShip,
	armcs = anyConShip,
	coracsub = anyAdvConSub,
	armacsub = anyAdvConSub,
	cormls = anyNavalEngineer,
	armmls = anyNavalEngineer,
	consul = anyCombatEngineer,
	corfast = anyCombatEngineer,
	corap = anyLvl1AirPlant,
	armap = anyLvl1AirPlant,
	corlab = anyLvl1BotLab,
	armlab = anyLvl1BotLab,
	corvp = anyLvl1VehPlant,
	armvp = anyLvl1VehPlant,
	coralab = anyLvl2BotLab,
	coravp = anyLvl2VehPlant,
	corhp = anyHoverPlatform,
	armhp = anyHoverPlatform,
	corfhp = anyHoverPlatform,
	armfhp = anyHoverPlatform,
	csubpen = anyAmphibiousComplex,
	asubpen = anyAmphibiousComplex,
	armalab = anyLvl2BotLab,
	armavp = anyLvl2VehPlant,
	coraap = anyLvl2AirPlant,
	armaap = anyLvl2AirPlant,
	corplat = anySeaplanePlatform,
	armplat = anySeaplanePlatform,
	corsy = anyLvl1ShipYard,
	armsy = anyLvl1ShipYard,
	corasy = anyLvl2ShipYard,
	armasy = anyLvl2ShipYard,
	corgant = anyExperimental,
	armshltx = anyExperimental,
	corgantuw = anyUWExperimental,
	armshltxuw = anyUWExperimental,
	armfark = anyfark,
}