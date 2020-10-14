TasksHST = class(Module)

function TasksHST:Name()
	return "TasksHST"
end

function TasksHST:internalName()
	return "TasksHST"
end

function TasksHST:Init()
	self.DebugEnabled = false
end

function TasksHST:wrap( theTable, theFunction )
	return function( tb, ai )
		return theTable[theFunction](theTable)
	end
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
		return self.ai.UnitiesHST.DummyUnitName
	end
end

function TasksHST:BuildTorpedoIfNeeded(unitName)
	if IsTorpedoNeeded() then
		return unitName
	else
		return self.ai.UnitiesHST.DummyUnitName
	end
end

function TasksHST:BuildSiegeIfNeeded(unitName)
	if unitName == self.ai.UnitiesHST.DummyUnitName then return self.ai.UnitiesHST.DummyUnitName end
	if IsSiegeEquipmentNeeded() then
		if self.ai.siegeCount < (self.ai.battleCount + self.ai.breakthroughCount) * 0.35 then
			return unitName
		end
	end
	return self.ai.UnitiesHST.DummyUnitName
end

function TasksHST:BuildBreakthroughIfNeeded(unitName)
	if unitName == self.ai.UnitiesHST.DummyUnitName or unitName == nil then return self.ai.UnitiesHST.DummyUnitName end
	if IsSiegeEquipmentNeeded() then return unitName end
	local mtype = self.ai.UnitiesHST.unitTable[unitName].mtype
	if mtype == "air" then
		local bomberCounter = self.ai.bomberhst:GetCounter()
		if bomberCounter >= self.ai.UnitiesHST.breakthroughBomberCounter and bomberCounter < self.ai.UnitiesHST.maxBomberCounter then
			return unitName
		else
			return self.ai.UnitiesHST.DummyUnitName
		end
	else
		if self.ai.battleCount <= self.ai.UnitiesHST.minBattleCount then return self.ai.UnitiesHST.DummyUnitName end
		local attackCounter = self.ai.attackhst:GetCounter(mtype)
		if attackCounter == self.ai.UnitiesHST.maxAttackCounter then
			return unitName
		elseif attackCounter >= self.ai.UnitiesHST.breakthroughAttackCounter then
			return unitName
		else
			return self.ai.UnitiesHST.DummyUnitName
		end
	end
end

function TasksHST:BuildRaiderIfNeeded(unitName)
	EchoDebug("build raider if needed: " .. unitName)
	if unitName == self.ai.UnitiesHST.DummyUnitName or unitName == nil then return self.ai.UnitiesHST.DummyUnitName end
	local mtype = self.ai.UnitiesHST.unitTable[unitName].mtype
	if self.ai.factoriesAtLevel[3] ~= nil and self.ai.factoriesAtLevel[3] ~= {} then
		-- if we have a level 2 factory, don't build raiders until we have some battle units
		local attackCounter = self.ai.attackhst:GetCounter(mtype)
		if self.ai.battleCount + self.ai.breakthroughCount < attackCounter / 2 then
			return self.ai.UnitiesHST.DummyUnitName
		end
	end
	local counter = self.ai.raidhst:GetCounter(mtype)
	if counter == self.ai.UnitiesHST.minRaidCounter then return self.ai.UnitiesHST.DummyUnitName end
	if self.ai.raiderCount[mtype] == nil then
		-- fine
	elseif self.ai.raiderCount[mtype] >= counter then
		unitName = self.ai.UnitiesHST.DummyUnitName
	end
	return unitName
end

function TasksHST:BuildBattleIfNeeded(unitName)
	if unitName == self.ai.UnitiesHST.DummyUnitName or unitName == nil then return self.ai.UnitiesHST.DummyUnitName end
	local mtype = self.ai.UnitiesHST.unitTable[unitName].mtype
	local attackCounter = self.ai.attackhst:GetCounter(mtype)
	EchoDebug(mtype .. " " .. attackCounter .. " " .. self.ai.UnitiesHST.maxAttackCounter)
	if attackCounter == self.ai.UnitiesHST.maxAttackCounter and self.ai.battleCount > self.ai.UnitiesHST.minBattleCount then return self.ai.UnitiesHST.DummyUnitName end
	if mtype == "veh" and self.side == self.ai.UnitiesHST.CORESideName and (self.ai.factoriesAtLevel[1] == nil or self.ai.factoriesAtLevel[1] == {}) then
		-- core only has a lvl1 vehicle raider, so this prevents getting stuck
		return unitName
	end
	if self.ai.factoriesAtLevel[3] ~= nil and self.ai.factoriesAtLevel[3] ~= {} then
		-- if we have a level 2 factory, don't wait to build raiders first
		return unitName
	end
	local raidCounter = self.ai.raidhst:GetCounter(mtype)
	EchoDebug(mtype .. " " .. raidCounter .. " " .. self.ai.UnitiesHST.maxRaidCounter)
	if raidCounter == self.ai.UnitiesHST.minRaidCounter then return unitName end
	EchoDebug(self.ai.raiderCount[mtype])
	if self.ai.raiderCount[mtype] == nil then
		return unitName
	elseif self.ai.raiderCount[mtype] < raidCounter / 2 then
		return self.ai.UnitiesHST.DummyUnitName
	else
		return unitName
	end
end

function TasksHST:CountOwnUnits(tmpUnitName)
	if tmpUnitName == self.ai.UnitiesHST.DummyUnitName then return 0 end -- don't count no-units
	if self.ai.nameCount[tmpUnitName] == nil then return 0 end
	return self.ai.nameCount[tmpUnitName]
end

function TasksHST:BuildWithLimitedNumber(tmpUnitName, minNumber)
	if tmpUnitName == self.ai.UnitiesHST.DummyUnitName then return self.ai.UnitiesHST.DummyUnitName end
	if minNumber == 0 then return self.ai.UnitiesHST.DummyUnitName end
	if self.ai.nameCount[tmpUnitName] == nil then
		return tmpUnitName
	else
		if self.ai.nameCount[tmpUnitName] == 0 or self.ai.nameCount[tmpUnitName] < minNumber then
			return tmpUnitName
		else
			return self.ai.UnitiesHST.DummyUnitName
		end
	end
end

function TasksHST:GroundDefenseIfNeeded(unitName)
	if not self.ai.needGroundDefense then
		return self.ai.UnitiesHST.DummyUnitName
	else
		return unitName
	end
end

function TasksHST:BuildBomberIfNeeded(unitName)
	if not IsLandAttackNeeded() then return self.ai.UnitiesHST.DummyUnitName end
	if unitName == self.ai.UnitiesHST.DummyUnitName or unitName == nil then return self.ai.UnitiesHST.DummyUnitName end
	if self.ai.bomberhst:GetCounter() == self.ai.UnitiesHST.maxBomberCounter then
		return self.ai.UnitiesHST.DummyUnitName
	else
		return unitName
	end
end

function TasksHST:BuildTorpedoBomberIfNeeded(unitName)
	if not IsWaterAttackNeeded() then return self.ai.UnitiesHST.DummyUnitName end
	if unitName == self.ai.UnitiesHST.DummyUnitName or unitName == nil then return self.ai.UnitiesHST.DummyUnitName end
	if self.ai.bomberhst:GetCounter() == self.ai.UnitiesHST.maxBomberCounter then
		return self.ai.UnitiesHST.DummyUnitName
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
	local unitName = self.ai.UnitiesHST.DummyUnitName
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
	if unitName == nil then unitName = self.ai.UnitiesHST.DummyUnitName end
	EchoDebug('Consul as factory '..unitName)
	return unitName
end

function TasksHST:FreakerAsFactory(tskqbhvr)
	local unitName = self.ai.UnitiesHST.DummyUnitName
	local rnd = math.random(1,7)
	if 	rnd == 1 then unitName=ConBot(tskqbhvr)
elseif 	rnd == 2 then unitName=ConShip(tskqbhvr)
	elseif 	rnd == 3 then unitName=Lvl1BotRaider(tskqbhvr)
	elseif 	rnd == 4 then unitName=Lvl1AABot(tskqbhvr)
	elseif 	rnd == 5 then unitName=Lvl2BotRaider(tskqbhvr)
	elseif 	rnd == 6 then unitName=Lvl2AmphBot(tskqbhvr)
	else unitName = Lvl1ShipDestroyerOnly(tskqbhvr)
	end
	if unitName == nil then unitName = self.ai.UnitiesHST.DummyUnitName end
	EchoDebug('Freaker as factory '..unitName)
	return unitName
end

function TasksHST:NavalEngineerAsFactory(tskqbhvr)
	local unitName = self.ai.UnitiesHST.DummyUnitName
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
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = FreakerAsFactory(tskqbhvr)
	else
		unitName = ConsulAsFactory(tskqbhvr)
	end
	return unitName
end



-- mobile construction units:

function TasksHST:anyCommander()
	return {
		self:wrap( self.ai.TaskEcoHST,'BuildAppropriateFactory' ) ,
		self:wrap( self.ai.TaskEcoHST,'CommanderEconomy' ) ,
		self:wrap(  self.ai.TaskBuildHST,'BuildLLT' ) ,
		self:wrap( self.ai.TaskBuildHST,'BuildRadar' ) ,
		self:wrap( self.ai.TaskBuildHST,'CommanderAA' ) ,
		self:wrap( self.ai.TaskBuildHST,'BuildPopTorpedo' ) ,
	}
end
function TasksHST:anyConUnit()  return  {
	self:wrap( self.ai.TaskEcoHST,'BuildAppropriateFactory' ) ,
	self:wrap( self.ai.TaskEcoHST,'Economy1' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildLLT' ) ,
	self:wrap( self.ai.TaskEcoHST,'Economy1' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildMediumAA' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildRadar' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildLvl1Jammer' ) ,
	self:wrap( self.ai.TaskEcoHST,'BuildGeo' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildHLT' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildLvl1Plasma' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildHeavyishAA' ) ,
} end

function TasksHST:anyConAmphibious()  return  {
	self:wrap( self.ai.TaskEcoHST,'BuildAppropriateFactory' ) ,
	self:wrap( self.ai.TaskEcoHST,'AmphibiousEconomy' ) ,
	self:wrap( self.ai.TaskEcoHST,'BuildGeo' ) ,
	self:wrap( self.ai.TaskEcoHST,'Economy1' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildMediumAA' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildRadar' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildLvl1Jammer' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildHLT' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildLvl1Plasma' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildHeavyishAA' ) ,
	self:wrap( self.ai.TaskEcoHST,'AmphibiousEconomy' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildPopTorpedo' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildFloatLightAA' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildFloatRadar' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildFloatHLT' ) ,
} end

function TasksHST:anyConShip()  return  {
	self:wrap( self.ai.TaskEcoHST,'BuildAppropriateFactory' ) ,
	self:wrap( self.ai.TaskEcoHST,'EconomyUnderWater' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildFloatLightAA' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildLightTorpedo' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildFloatRadar' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildFloatHLT' ) ,
} end

function TasksHST:anyAdvConUnit()  return  {
	self:wrap( self.ai.TaskEcoHST,'BuildAppropriateFactory' ) ,
	self:wrap( self.ai.TaskEcoHST,'AdvEconomy' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildNukeIfNeeded' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildAdvancedRadar' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildHeavyPlasma' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildAntinuke' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildLvl2PopUp' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildHeavyAA' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildLvl2Plasma' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildTachyon' ) ,
	-- BuildTacticalNuke' ) ,
			self:wrap( self.ai.TaskBuildHST,'BuildExtraHeavyAA' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildLvl2Jammer' ) ,
	self:wrap( self.ai.TaskEcoHST,'BuildMohoGeo' ) ,
} end

function TasksHST:anyConSeaplane()  return  {
	self:wrap( self.ai.TaskEcoHST,'BuildAppropriateFactory' ) ,
	self:wrap( self.ai.TaskEcoHST,'EconomySeaplane' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildFloatHeavyAA' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildAdvancedSonar' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildHeavyTorpedo' ) ,
} end

function TasksHST:anyAdvConSub()  return  {
	self:wrap( self.ai.TaskEcoHST,'BuildAppropriateFactory' ) ,
	self:wrap( self.ai.TaskEcoHST,'AdvEconomyUnderWater' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildFloatHeavyAA' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildAdvancedSonar' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildHeavyTorpedo' ) ,
} end

function TasksHST:anyNavalEngineer()  return  {
	self:wrap( self.ai.TaskEcoHST,'BuildAppropriateFactory' ) ,
	self:wrap( self.ai.TaskEcoHST,'EconomyNavalEngineer' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildFloatHLT' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildFloatLightAA' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildFloatRadar' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildLightTorpedo' ) ,
} end

function TasksHST:anyCombatEngineer()  return  {
	self:wrap( self.ai.TaskEcoHST,'BuildAppropriateFactory' ) ,
	self:wrap( self.ai.TaskEcoHST,'EconomyBattleEngineer' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildMediumAA' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildAdvancedRadar' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildLvl2Jammer' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildHeavyAA' ) ,
	self:wrap( self.ai.TaskEcoHST,'Economy1' ) ,
	self:wrap( self.ai.TaskBuildHST,'BuildLvl2Plasma' ) ,
} end


-- factories.

		function TasksHST:anyLvl1AirPlant()  return  {
	self:wrap( self.ai.TaskAirHST,'ScoutAir' ) ,
	self:wrap( self.ai.TaskAirHST,'Lvl1Bomber' ) ,
	self:wrap( self.ai.TaskAirHST,'Lvl1AirRaider' ) ,
	self:wrap( self.ai.TaskAirHST,'ConAir' ) ,
	self:wrap( self.ai.TaskAirHST,'Lvl1Fighter' ) ,
} end

function TasksHST:anyLvl1VehPlant()  return  {
	self:wrap( self.ai.TaskVehHST,'ScoutVeh' ) ,
	self:wrap( self.ai.TaskVehHST,'ConVehicle' ) ,
	self:wrap( self.ai.TaskVehHST,'Lvl1VehRaider' ) ,
	self:wrap( self.ai.TaskVehHST,'Lvl1VehBattle' ) ,
	self:wrap( self.ai.TaskVehHST,'Lvl1AAVeh' ) ,
	self:wrap( self.ai.TaskVehHST,'Lvl1VehArty' ) ,
	self:wrap( self.ai.TaskVehHST,'Lvl1VehBreakthrough' ) ,
} end

function TasksHST:anyLvl1BotLab()  return  {
	self:wrap( self.ai.TaskBotHST,'ScoutBot' ) ,
	self:wrap( self.ai.TaskBotHST,'ConBot' ) ,
	self:wrap( self.ai.TaskBotHST,'Lvl1BotRaider' ) ,
	self:wrap( self.ai.TaskBotHST,'Lvl1BotBattle' ) ,
	self:wrap( self.ai.TaskBotHST,'Lvl1AABot' ) ,
	self:wrap( self.ai.TaskBotHST,'Lvl1BotBreakthrough' ) ,
	self:wrap( self.ai.TaskBotHST,'RezBot1' ) ,
} end

function TasksHST:anyLvl1ShipYard()  return  {
	self:wrap( self.ai.TaskShpHST,'ScoutShip' ) ,
	self:wrap( self.ai.TaskShpHST,'ConShip' ) ,
	self:wrap( self.ai.TaskShpHST,'Lvl1ShipBattle' ) ,
	self:wrap( self.ai.TaskShpHST,'Lvl1ShipRaider' ) ,
} end

function TasksHST:anyHoverPlatform()  return  {
	self:wrap( self.ai.TaskHovHST,'HoverRaider' ) ,
	self:wrap( self.ai.TaskHovHST,'ConHover' ) ,
	self:wrap( self.ai.TaskHovHST,'HoverBattle' ) ,
	self:wrap( self.ai.TaskHovHST,'HoverBreakthrough' ) ,
	self:wrap( self.ai.TaskHovHST,'HoverMerl' ) ,
	self:wrap( self.ai.TaskHovHST,'AAHover' ) ,
} end

function TasksHST:anyAmphibiousComplex()  return  {
	self:wrap( self.ai.TaskVehHST,'AmphibiousRaider' ) ,
	self:wrap( self.ai.TaskVehHST,'ConVehicleAmphibious' ) ,
	self:wrap( self.ai.TaskVehHST,'AmphibiousBattle' ) ,
	self:wrap( self.ai.TaskShpHST,'Lvl1ShipRaider' ) ,
	self:wrap( self.ai.TaskBotHST,'Lvl1AABot' ) ,
	self:wrap( self.ai.TaskBotHST,'Lvl2AABot' ) ,
} end

function TasksHST:anyLvl2VehPlant()  return  {
	self:wrap( self.ai.TaskVehHST,'ConAdvVehicle' ) ,
	self:wrap( self.ai.TaskVehHST,'Lvl2VehRaider' ) ,
	self:wrap( self.ai.TaskVehHST,'Lvl2VehBattle' ) ,
	self:wrap( self.ai.TaskVehHST,'Lvl2VehBreakthrough' ) ,
	self:wrap( self.ai.TaskVehHST,'Lvl2VehArty' ) ,
	self:wrap( self.ai.TaskVehHST,'Lvl2VehMerl' ) ,
	self:wrap( self.ai.TaskVehHST,'Lvl2AAVeh' ) ,
	self:wrap( self.ai.TaskVehHST,'Lvl2VehAssist' ) ,
} end

function TasksHST:anyLvl2BotLab()  return  {
	self:wrap( self.ai.TaskBotHST,'Lvl2BotRaider' ) ,
	self:wrap( self.ai.TaskBotHST,'ConAdvBot' ) ,
	self:wrap( self.ai.TaskBotHST,'Lvl2BotBattle' ) ,
	self:wrap( self.ai.TaskBotHST,'Lvl2BotBreakthrough' ) ,
	self:wrap( self.ai.TaskBotHST,'Lvl2BotArty' ) ,
	self:wrap( self.ai.TaskBotHST,'Lvl2BotMerl' ) ,
	self:wrap( self.ai.TaskBotHST,'Lvl2AABot' ) ,
	self:wrap( self.ai.TaskBotHST,'Lvl2BotAssist' ) ,
} end

function TasksHST:anyLvl2AirPlant()  return  {
	self:wrap( self.ai.TaskAirHST,'Lvl2Bomber' ) ,
	self:wrap( self.ai.TaskAirHST,'Lvl2TorpedoBomber' ) ,
	self:wrap( self.ai.TaskAirHST,'ConAdvAir' ) ,
	self:wrap( self.ai.TaskAirHST,'ScoutAdvAir' ) ,
	self:wrap( self.ai.TaskAirHST,'Lvl2Fighter' ) ,
	self:wrap( self.ai.TaskAirHST,'Lvl2AirRaider' ) ,
	self:wrap( self.ai.TaskAirHST,'MegaAircraft' ) ,
} end

function TasksHST:anySeaplanePlatform()  return  {
	self:wrap( self.ai.TaskAirHST,'SeaBomber' ) ,
	self:wrap( self.ai.TaskAirHST,'SeaTorpedoBomber' ) ,
	self:wrap( self.ai.TaskAirHST,'ConSeaAir' ) ,
	self:wrap( self.ai.TaskAirHST,'ScoutSeaAir' ) ,
	self:wrap( self.ai.TaskAirHST,'SeaFighter' ) ,
	self:wrap( self.ai.TaskAirHST,'SeaAirRaider' ) ,
} end

function TasksHST:anyLvl2ShipYard()  return  {
	self:wrap( self.ai.TaskShpHST,'Lvl2ShipRaider' ) ,
	self:wrap( self.ai.TaskShpHST,'ConAdvSub' ) ,
	self:wrap( self.ai.TaskShpHST,'Lvl2ShipBattle' ) ,
	self:wrap( self.ai.TaskShpHST,'Lvl2AAShip' ) ,
	self:wrap( self.ai.TaskShpHST,'Lvl2ShipBreakthrough' ) ,
	self:wrap( self.ai.TaskShpHST,'Lvl2ShipMerl' ) ,
	self:wrap( self.ai.TaskShpHST,'Lvl2ShipAssist' ) ,
	self:wrap( self.ai.TaskShpHST,'Lvl2SubWar' ) ,
	self:wrap( self.ai.TaskShpHST,'MegaShip' ) ,
} end

function TasksHST:anyExperimental()  return  {
	self:wrap( self.ai.TaskBotHST,'Lvl3Raider' ) ,
	self:wrap( self.ai.TaskBotHST,'Lvl3Battle' ) ,
	self:wrap( self.ai.TaskBotHST,'Lvl3Merl' ) ,
	self:wrap( self.ai.TaskBotHST,'Lvl3Arty' ) ,
	self:wrap( self.ai.TaskBotHST,'Lvl3Breakthrough' ) ,
} end

function TasksHST:anyOutmodedLvl1BotLab()  return  {
	self:wrap( self.ai.TaskBotHST,'ConBot' ) ,
	self:wrap( self.ai.TaskBotHST,'RezBot1' ) ,
	self:wrap( self.ai.TaskBotHST,'ScoutBot' ) ,
	self:wrap( self.ai.TaskBotHST,'Lvl1AABot' ) ,
} end

function TasksHST:anyOutmodedLvl1VehPlant()  return  {
	self:wrap( self.ai.TaskVehHST,'Lvl1VehRaiderOutmoded' ) ,
	self:wrap( self.ai.TaskVehHST,'ConVehicle' ) ,
	self:wrap( self.ai.TaskVehHST,'ScoutVeh' ) ,
	self:wrap( self.ai.TaskVehHST,'Lvl1AAVeh' ) ,
} end

function TasksHST:anyOutmodedLvl1AirPlant()  return  {
	self:wrap( self.ai.TaskAirHST,'ConAir' ) ,
	self:wrap( self.ai.TaskAirHST,'ScoutAir' ) ,
	self:wrap( self.ai.TaskAirHST,'Lvl1Fighter' ) ,
} end

function TasksHST:anyOutmodedLvl1ShipYard()  return  {
	self:wrap( self.ai.TaskShpHST,'ConShip' ) ,
	self:wrap( self.ai.TaskShpHST,'ScoutShip' ) ,
} end

function TasksHST:anyOutmodedLvl2BotLab()  return  {
	-- Lvl2BotRaider' ) ,
			self:wrap( self.ai.TaskBotHST,'ConAdvBot' ) ,
	self:wrap( self.ai.TaskBotHST,'Lvl2AABot' ) ,
	self:wrap( self.ai.TaskBotHST,'Lvl2BotAssist' ) ,
} end

function TasksHST:anyOutmodedLvl2VehPlant()  return  {
	-- Lvl2VehRaider' ) ,
			self:wrap( self.ai.TaskVehHST,'Lvl2VehAssist' ) ,
	self:wrap( self.ai.TaskVehHST,'ConAdvVehicle' ) ,
	self:recall( self.ai.TaskVehHST,'Lvl2AAVeh' ) ,
} end

-- fall back to these when a level 2 factory exists
function TasksHST:outmodedTaskqueues()  return  {
	corlab = self:wrap( self  ,  'anyOutmodedLvl1BotLab' ) ,
	armlab = self:wrap( self  ,  'anyOutmodedLvl1BotLab' ) ,
	corvp = self:wrap( self  ,  'anyOutmodedLvl1VehPlant' ) ,
	armvp = self:wrap( self  ,  'anyOutmodedLvl1VehPlant' ) ,
	corap = self:wrap( self  ,  'anyOutmodedLvl1AirPlant' ) ,
	armap = self:wrap( self  ,  'anyOutmodedLvl1AirPlant' ) ,
	corsy = self:wrap( self  ,  'anyOutmodedLvl1ShipYard' ) ,
	armsy = self:wrap( self  ,  'anyOutmodedLvl1ShipYard' ) ,
	coralab = self:wrap( self  ,  'anyOutmodedLvl2BotLab' ) ,
	armalab = self:wrap( self  ,  'anyOutmodedLvl2BotLab' ) ,
	coravp = self:wrap( self  ,  'anyOutmodedLvl2VehPlant' ) ,
	armavp = self:wrap( self  ,  'anyOutmodedLvl2VehPlant' ) ,
} end

-- finally' ) , the taskqueue definitions
function TasksHST:taskqueues()  return  {
	corcom = self:wrap( self  ,  'anyCommander' ) ,
	armcom = self:wrap( self  ,  'anyCommander' ) ,
	armdecom = self:wrap( self  ,  'anyCommander' ) ,
	cordecom = self:wrap( self  ,  'anyCommander' ) ,
	corcv = self:wrap( self  ,  'anyConUnit' ) ,
	armcv = self:wrap( self  ,  'anyConUnit' ) ,
	corck = self:wrap( self  ,  'anyConUnit' ) ,
	armck = self:wrap( self  ,  'anyConUnit' ) ,
	cormuskrat = self:wrap( self  ,  'anyConAmphibious' ) ,
	armbeaver = self:wrap( self  ,  'anyConAmphibious' ) ,
	corch = self:wrap( self  ,  'anyConAmphibious' ) ,
	armch = self:wrap( self  ,  'anyConAmphibious' ) ,
	corca = self:wrap( self  ,  'anyConUnit' ) ,
	armca = self:wrap( self  ,  'anyConUnit' ) ,
	corack = self:wrap( self  ,  'anyAdvConUnit' ) ,
	armack = self:wrap( self  ,  'anyAdvConUnit' ) ,
	coracv = self:wrap( self  ,  'anyAdvConUnit' ) ,
	armacv = self:wrap( self  ,  'anyAdvConUnit' ) ,
	coraca = self:wrap( self  ,  'anyAdvConUnit' ) ,
	armaca = self:wrap( self  ,  'anyAdvConUnit' ) ,
	corcsa = self:wrap( self  ,  'anyConSeaplane' ) ,
	armcsa = self:wrap( self  ,  'anyConSeaplane' ) ,
	corcs = self:wrap( self  ,  'anyConShip' ) ,
	armcs = self:wrap( self  ,  'anyConShip' ) ,
	coracsub = self:wrap( self  ,  'anyAdvConSub' ) ,
	armacsub = self:wrap( self  ,  'anyAdvConSub' ) ,
	cormls = self:wrap( self  ,  'anyNavalEngineer' ) ,
	armmls = self:wrap( self  ,  'anyNavalEngineer' ) ,
	armconsul = self:wrap( self  ,  'anyCombatEngineer' ) ,
	corfast = self:wrap( self  ,  'anyCombatEngineer' ) ,
	corap = self:wrap( self  ,  'anyLvl1AirPlant' ) ,
	armap = self:wrap( self  ,  'anyLvl1AirPlant' ) ,
	corlab = self:wrap( self  ,  'anyLvl1BotLab' ) ,
	armlab = self:wrap( self  ,  'anyLvl1BotLab' ) ,
	corvp = self:wrap( self  ,  'anyLvl1VehPlant' ) ,
	armvp = self:wrap( self  ,  'anyLvl1VehPlant' ) ,
	coralab = self:wrap( self  ,  'anyLvl2BotLab' ) ,
	coravp = self:wrap( self  ,  'anyLvl2VehPlant' ) ,
	corhp = self:wrap( self  ,  'anyHoverPlatform' ) ,
	armhp = self:wrap( self  ,  'anyHoverPlatform' ) ,
	corfhp = self:wrap( self  ,  'anyHoverPlatform' ) ,
	armfhp = self:wrap( self  ,  'anyHoverPlatform' ) ,
	coramsub = self:wrap( self  ,  'anyAmphibiousComplex' ) ,
	armamsub = self:wrap( self  ,  'anyAmphibiousComplex' ) ,
	armalab = self:wrap( self  ,  'anyLvl2BotLab' ) ,
	armavp = self:wrap( self  ,  'anyLvl2VehPlant' ) ,
	coraap = self:wrap( self  ,  'anyLvl2AirPlant' ) ,
	armaap = self:wrap( self  ,  'anyLvl2AirPlant' ) ,
	corplat = self:wrap( self  ,  'anySeaplanePlatform' ) ,
	armplat = self:wrap( self  ,  'anySeaplanePlatform' ) ,
	corsy = self:wrap( self  ,  'anyLvl1ShipYard' ) ,
	armsy = self:wrap( self  ,  'anyLvl1ShipYard' ) ,
	corasy = self:wrap( self  ,  'anyLvl2ShipYard' ) ,
	armasy = self:wrap( self  ,  'anyLvl2ShipYard' ) ,
	corgant = self:wrap( self  ,  'anyExperimental' ) ,
	armshltx = self:wrap( self  ,  'anyExperimental' ) ,
	corgantuw = self:wrap( self  ,  'anyUWExperimental' ) ,
	armshltxuw = self:wrap( self  ,  'anyUWExperimental' ) ,
	armfark = self:wrap( self  ,  'anyfark' ) ,
} end
