
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

function CheckMySide(self)
	if self.unit ~= nil then
		local tmpName = self.unit:Internal():Name()
		if tmpName == "corcom" then
			ai.mySide = CORESideName
			return DummyUnitName
		end
		if tmpName == "armcom" then
			ai.mySide = ARMSideName
			return DummyUnitName
		end
		game:SendToConsole("Unexpected start unit: "..tmpName..", cannot determine it's race. Assuming CORE")
		ai.mySide = CORESideName
	else
		game:SendToConsole("Unexpected start unit: nil, cannot determine it's race. Assuming CORE")
		ai.mySide = CORESideName
	end
	return DummyUnitName
end

-- this is initialized in maphandler
function MapHasUnderwaterMetal()
	return ai.hasUWSpots or false
end

function IsSiegeEquipmentNeeded()
	return ai.situation.needSiege
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
			return BuildWithLimitedNumber(unitName, ai.situation.AAUnitPerTypeLimit)
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
	if mtype == "veh" and ai.mySide == CORESideName and (ai.factoriesAtLevel[1] == nil or ai.factoriesAtLevel[1] == {}) then
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

function GroundDefenseIfNeeded(unitName, builder)
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

function CheckMySideIfNeeded()
	if ai.mySide == nil then
		EchoDebug("commander: checkmyside")
		return CheckMySide
	else
		return DummyUnitName
	end
end


function LandOrWater(self, landName, waterName)
	local builder = self.unit:Internal()
	local bpos = builder:GetPosition()
	local waterNet = ai.maphandler:MobilityNetworkSizeHere("shp", bpos)
	if waterNet ~= nil then
		return waterName
	else
		return landName
	end
end


local function ConsulAsFactory(self)
	local unitName=DummyUnitName
	local rnd= math.random(1,9)
	if 	rnd==1 then unitName=ConVehicle(self) 
	elseif 	rnd==2 then unitName=ConShip(self) 
	elseif 	rnd==3 then unitName=Lvl1BotRaider(self) 
	elseif 	rnd==4 then unitName=Lvl1AABot(self) 
	elseif 	rnd==5 then unitName=Lvl2BotArty(self)
	-- elseif 	rnd==6 then unitName=spiders(self)
	elseif 	rnd==7 then unitName=Lvl2BotMedium(self)
	elseif 	rnd==8 then unitName=Lvl1ShipDestroyerOnly(self)
	else unitName=DummyUnitName
	end
	if unitName==nil then unitName = DummyUnitName end
	EchoDebug('Consul as factory '..unitName)
	return unitName
end

local function FreakerAsFactory(self)
	local unitName=DummyUnitName
	local rnd = math.random(1,9)
	if 	rnd==1 then unitName=ConBot(self)
	elseif 	rnd==2 then unitName=ConShip(self)
	elseif 	rnd==3 then unitName=Lvl1BotRaider(self)
	elseif 	rnd==4 then unitName=Lvl1AABot(self)
	elseif 	rnd==5 then unitName=Lvl2BotRaider(self)
	elseif 	rnd==6 then unitName=Lvl2AmphBot(self)
	elseif 	rnd==7 then unitName=Lvl1ShipDestroyerOnly(self)
	-- elseif 	rnd==8 then unitName=Decoy(self)
	else unitName = DummyUnitName
	end
	if unitName==nil then unitName = DummyUnitName end
	EchoDebug('Freaker as factory '..unitName)
	return unitName
end

function NavalEngineerAsFactory(self)
	local unitName=DummyUnitName
	local rnd= math.random(1,9)
	EchoDebug(rnd)
	if 	rnd==1 then unitName=ConShip(self)
	elseif 	rnd==2 then unitName=ScoutShip(self)
	elseif 	rnd==3 then unitName=Lvl1ShipDestroyerOnly(self)
	elseif 	rnd==4 then unitName=Lvl1ShipRaider(self)
	elseif 	rnd==5 then unitName=Lvl1ShipBattle(self)
	elseif 	rnd==6 then unitName=Lvl2AmphBot(self)
	else 
		unitName=DummyUnitName
	end
	EchoDebug('Naval engineers as factory '..unitName)
	return unitName
end

function EngineerAsFactory(self)
	local unitName=DummyUnitName
	if ai.Energy.full>0.3 and ai.Energy.full<0.7 and ai.Metal.full>0.3 and ai.Metal.full<0.7 then
		if ai.mySide == CORESideName then
			unitName=FreakerAsFactory(self)
		else
			unitName=ConsulAsFactory(self)
		end
	end
	return unitName
end	

local function CommanderEconomy(self)
	local underwater = ai.maphandler:IsUnderWater(self.unit:Internal():GetPosition())
	local unitName = DummyUnitName
	if not underwater then 
		unitName = Economy0()
	else
		unitName = EconomyUnderWater()
	end
	return unitName
	
	
end

local function AmphibiousEconomy(self)
	local underwater = ai.maphandler:IsUnderWater(self.unit:Internal():GetPosition())
	local unitName = DummyUnitName
	if here then 
		unitName = Economy1(self)
	else
		unitName = EconomyUnderWater(self)
	end
	return unitName
	
end

-- mobile construction units:

local anyCommander = {
	CheckMySideIfNeeded,
	CommanderEconomy,
	BuildAppropriateFactory,
	BuildLLT,
	BuildRadar,
	BuildLightAA,
	BuildPopTorpedo,
	BuildSonar,
}

local anyConUnit = {
	Economy1,
	BuildAppropriateFactory,
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
	EconomyUnderWater,
	BuildFloatLightAA,
	BuildSonar,
	BuildLightTorpedo,
	BuildFloatRadar,
	BuildAppropriateFactory,
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
	-- DoSomethingAdvancedForTheEconomy,
}

local anyConSeaplane = {
	EconomySeaplane,
	BuildFloatHeavyAA,
	BuildAdvancedSonar,
	BuildHeavyTorpedo,
	BuildAppropriateFactory,
}

local anyAdvConSub = {
	AdvEconomyUnderWater,
	BuildFloatHeavyAA,
	BuildAdvancedSonar,
	BuildHeavyTorpedo,
}

local anyNavalEngineer = {
	EconomyNavalEngineer,
	BuildFloatHLT,
	BuildFloatLightAA,
	BuildAppropriateFactory,
	Lvl1ShipBattle,
	BuildFloatRadar,
	BuildSonar,
	Lvl1ShipRaider,
	Conship,
	ScoutShip,
	BuildLightTorpedo,
}

local anyCombatEngineer = {
	EconomyBattleEngineer,
	BuildAppropriateFactory,
	BuildMediumAA,
	BuildAdvancedRadar,
	BuildLvl2Jammer,
	BuildHeavyAA,
	BuildSpecialLTOnly,
	BuildLvl2Plasma,
	ConCoreBotArmVehicle,
	Lvl2BotCorRaiderArmArty,
	Lvl1AABot,
	ConShip,
	Lvl1ShipDestroyerOnly,
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
	Lvl2VehRaider,
	ConAdvVehicle,
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

local anyLvl1VehPlantForWater = {
	ScoutVeh,
	AmphibiousRaider,
	ConVehicleAmphibious,
	Lvl1AAVeh,
}

-- use these if it's a watery map
wateryTaskqueues = {
	armvp = anyLvl1VehPlantForWater,
	corvp = anyLvl1VehPlantForWater,
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