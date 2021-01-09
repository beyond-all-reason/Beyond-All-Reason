TasksHST = class(Module)

function TasksHST:Name()
	return "TasksHST"
end

function TasksHST:internalName()
	return "taskshst"
end

function TasksHST:Init()
	self.DebugEnabled = false
end

function TasksHST:wrap( theTable, theFunction )
	self:EchoDebug(theTable)
	self:EchoDebug(theFunction)
	return function( tb, ai )
	return theTable[theFunction](theTable, tb, ai)
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
	local mtype = self.ai.armyhst.unitTable[unitName].mtype
	local level = self.ai.armyhst.unitTable[unitName].techLevel
	local mtypedLv = mtype .. tostring(level)
	local counter = self.ai.mtypeLvCount[mtypedLv] or 0
	self:EchoDebug('mtypedLvmtype ' .. mtype .. ' '.. level .. ' ' .. counter)
	return counter
end


function TasksHST:BuildAAIfNeeded(unitName)
	if self:IsAANeeded() then
		if not self.ai.armyhst.unitTable[unitName].isBuilding then
			return self:BuildWithLimitedNumber(unitName, self.ai.overviewhst.AAUnitPerTypeLimit)
		else
			return unitName
		end
	else
		return self.ai.armyhst.DummyUnitName
	end
end

function TasksHST:BuildTorpedoIfNeeded(unitName)
	if self:IsTorpedoNeeded() then
		return unitName
	else
		return self.ai.armyhst.DummyUnitName
	end
end

function TasksHST:BuildSiegeIfNeeded(unitName)
	if unitName == self.ai.armyhst.DummyUnitName then return self.ai.armyhst.DummyUnitName end
	if self:IsSiegeEquipmentNeeded() then
		if self.ai.siegeCount < (self.ai.battleCount + self.ai.breakthroughCount) * 0.35 then
			return unitName
		end
	end
	return self.ai.armyhst.DummyUnitName
end

function TasksHST:BuildBreakthroughIfNeeded(unitName)
	if unitName == self.ai.armyhst.DummyUnitName or unitName == nil then return self.ai.armyhst.DummyUnitName end
	if self:IsSiegeEquipmentNeeded() then return unitName end
	local mtype = self.ai.armyhst.unitTable[unitName].mtype
	if mtype == "air" then
		local bomberCounter = self.ai.bomberhst:GetCounter()
		if bomberCounter >= self.ai.armyhst.breakthroughBomberCounter and bomberCounter < self.ai.armyhst.maxBomberCounter then
			return unitName
		else
			return self.ai.armyhst.DummyUnitName
		end
	else
		if self.ai.battleCount <= self.ai.armyhst.minBattleCount then return self.ai.armyhst.DummyUnitName end
		local attackCounter = self.ai.attackhst:GetCounter(mtype)
		if attackCounter < self.ai.armyhst.maxAttackCounter then
			return unitName
		elseif attackCounter >= self.ai.armyhst.breakthroughAttackCounter then
			return unitName
		else
			return self.ai.armyhst.DummyUnitName
		end
	end
end

function TasksHST:BuildRaiderIfNeeded(unitName)
	self:EchoDebug("build raider if needed: " .. unitName)

	if unitName == self.ai.armyhst.DummyUnitName or unitName == nil then return self.ai.armyhst.DummyUnitName end
	self:EchoDebug(unitName,self.ai.armyhst.unitTable[unitName],self.ai.armyhst.unitTable[unitName].mtype)
	local mtype = self.ai.armyhst.unitTable[unitName].mtype
	if self.ai.factoriesAtLevel[3] ~= nil and self.ai.factoriesAtLevel[3] ~= {} then
		-- if we have a level 2 factory, don't build raiders until we have some battle units
		local attackCounter = self.ai.attackhst:GetCounter(mtype)
		if self.ai.battleCount + self.ai.breakthroughCount < attackCounter / 2 then
			return self.ai.armyhst.DummyUnitName
		end
	end
	local counter = self.ai.raidhst:GetCounter(mtype)
	if counter == self.ai.armyhst.minRaidCounter then return self.ai.armyhst.DummyUnitName end
	if self.ai.raiderCount[mtype] == nil then
		-- fine
	elseif self.ai.raiderCount[mtype] >= counter then
		unitName = self.ai.armyhst.DummyUnitName
	end
	return unitName
end

function TasksHST:BuildBattleIfNeeded(unitName)
	if unitName == self.ai.armyhst.DummyUnitName or unitName == nil then return self.ai.armyhst.DummyUnitName end
	local mtype = self.ai.armyhst.unitTable[unitName].mtype
	local attackCounter = self.ai.attackhst:GetCounter(mtype)
	self:EchoDebug(mtype .. " " .. attackCounter .. " " .. self.ai.armyhst.maxAttackCounter)
	if attackCounter == self.ai.armyhst.maxAttackCounter and self.ai.battleCount > self.ai.armyhst.minBattleCount then return self.ai.armyhst.DummyUnitName end
	if mtype == "veh" and  self.ai.side == self.ai.armyhst.CORESideName and (self.ai.factoriesAtLevel[1] == nil or self.ai.factoriesAtLevel[1] == {}) then
		-- core only has a lvl1 vehicle raider, so this prevents getting stuck
		return unitName
	end
	if self.ai.factoriesAtLevel[3] ~= nil and self.ai.factoriesAtLevel[3] ~= {} then
		-- if we have a level 2 factory, don't wait to build raiders first
		return unitName
	end
	local raidCounter = self.ai.raidhst:GetCounter(mtype)
	self:EchoDebug(mtype .. " " .. raidCounter .. " " .. self.ai.armyhst.maxRaidCounter)
	if raidCounter == self.ai.armyhst.minRaidCounter then return unitName end
	self:EchoDebug(self.ai.raiderCount[mtype])
	if self.ai.raiderCount[mtype] == nil then
		return unitName
	elseif self.ai.raiderCount[mtype] < raidCounter / 2 then
		return self.ai.armyhst.DummyUnitName
	else
		return unitName
	end
end

function TasksHST:CountOwnUnits(tmpUnitName)
	if tmpUnitName == self.ai.armyhst.DummyUnitName then return 0 end -- don't count no-units
	if self.ai.nameCount[tmpUnitName] == nil then return 0 end
	return self.ai.nameCount[tmpUnitName]
end

function TasksHST:BuildWithLimitedNumber(tmpUnitName, minNumber)
	if tmpUnitName == self.ai.armyhst.DummyUnitName then return self.ai.armyhst.DummyUnitName end
	if minNumber == 0 then return self.ai.armyhst.DummyUnitName end
	if self.ai.nameCount[tmpUnitName] == nil then
		return tmpUnitName
	else
		if self.ai.nameCount[tmpUnitName] == 0 or self.ai.nameCount[tmpUnitName] < minNumber then
			return tmpUnitName
		else
			return self.ai.armyhst.DummyUnitName
		end
	end
end

function TasksHST:GroundDefenseIfNeeded(unitName)
	if not self.ai.needGroundDefense then
		return self.ai.armyhst.DummyUnitName
	else
		return unitName
	end
end

function TasksHST:BuildBomberIfNeeded(unitName)
	if not self:IsLandAttackNeeded() then return self.ai.armyhst.DummyUnitName end
	if unitName == self.ai.armyhst.DummyUnitName or unitName == nil then return self.ai.armyhst.DummyUnitName end
	if self.ai.bomberhst:GetCounter() == self.ai.armyhst.maxBomberCounter then
		return self.ai.armyhst.DummyUnitName
	else
		return unitName
	end
end

function TasksHST:BuildTorpedoBomberIfNeeded(unitName)
	if not IsWaterAttackNeeded() then return self.ai.armyhst.DummyUnitName end
	if unitName == self.ai.armyhst.DummyUnitName or unitName == nil then return self.ai.armyhst.DummyUnitName end
	if self.ai.bomberhst:GetCounter() == self.ai.armyhst.maxBomberCounter then
		return self.ai.armyhst.DummyUnitName
	else
		return unitName
	end
end


function TasksHST:LandOrWater(tqb, landName, waterName)
	local builder = tqb.unit:Internal()
	local bpos = builder:GetPosition()
	local waterNet = self.ai.maphst:MobilityNetworkSizeHere("shp", bpos)
	if waterNet ~= nil then
		return waterName
	else
		return landName
	end
end


-- function TasksHST:ConsulAsFactory(tqb)
-- 	local unitName = self.ai.armyhst.DummyUnitName
-- 	local rnd = math.random(1,8)
-- 	if 	rnd == 1 then unitName = self.ai.taskvehhst:ConVehicle(tqb)
-- 	elseif 	rnd == 2 then unitName = self.ai.taskshphst:ConShip(tqb)
-- 	elseif 	rnd == 3 then unitName = self.ai.taskbothst:Lvl1BotRaider(tqb)
-- 	elseif 	rnd == 4 then unitName = self.ai.taskbothst:Lvl1AABot(tqb)
-- 	elseif 	rnd == 5 then unitName = self.ai.taskbothst:Lvl2BotArty(tqb)
-- 	elseif 	rnd == 6 then unitName = self.ai.taskbothst:Lvl2BotAllTerrain(tqb)
-- 	elseif 	rnd == 7 then unitName = self.ai.taskbothst:Lvl2BotMedium(tqb)
-- 	else unitName = self.ai.taskshphst:Lvl1ShipDestroyerOnly(tqb)
-- 	end
-- 	if unitName == nil then unitName = self.ai.armyhst.DummyUnitName end
-- 	self:EchoDebug('Consul as factory '..unitName)
-- 	return unitName
-- end
--
-- function TasksHST:FreakerAsFactory(tqb)
-- 	local unitName = self.ai.armyhst.DummyUnitName
-- 	local rnd = math.random(1,7)
-- 	if 	rnd == 1 then unitName = self.ai.taskbothst:ConBot(tqb)
-- 	elseif 	rnd == 2 then unitName = self.ai.taskshphst:ConShip(tqb)
-- 	elseif 	rnd == 3 then unitName = self.ai.taskbothst:Lvl1BotRaider(tqb)
-- 	elseif 	rnd == 4 then unitName = self.ai.taskbothst:Lvl1AABot(tqb)
-- 	elseif 	rnd == 5 then unitName = self.ai.taskbothst:Lvl2BotRaider(tqb)
-- 	elseif 	rnd == 6 then unitName = self.ai.taskbothst:Lvl2AmphBot(tqb)
-- 	else unitName = self.ai.taskshphst:Lvl1ShipDestroyerOnly(tqb)
-- 	end
-- 	if unitName == nil then unitName = self.ai.armyhst.DummyUnitName end
-- 	self:EchoDebug('Freaker as factory '..unitName)
-- 	return unitName
-- end
--
-- function TasksHST:NavalEngineerAsFactory(tqb)
-- 	local unitName = self.ai.armyhst.DummyUnitName
-- 	local rnd= math.random(1,6)
-- 	if 	rnd == 1 then unitName = self.ai.taskshphst:ConShip(tqb)
-- 	elseif 	rnd == 2 then unitName = self.ai.taskshphst:ScoutShip(tqb)
-- 	elseif 	rnd == 3 then unitName = self.ai.taskshphst:Lvl1ShipDestroyerOnly(tqb)
-- 	elseif 	rnd == 4 then unitName = self.ai.taskshphst:Lvl1ShipRaider(tqb)
-- 	elseif 	rnd == 5 then unitName = self.ai.taskshphst:Lvl1ShipBattle(tqb)
-- 	else unitName = self.ai.taskbothst:Lvl2AmphBot(tqb)
-- 	end
-- 	self:EchoDebug('Naval engineers as factory '..unitName)
-- 	return unitName
-- end
--
-- function TasksHST:EngineerAsFactory(tqb)
-- 	local unitName = self.ai.armyhst.DummyUnitName
-- 	if  self.ai.side == self.ai.armyhst.CORESideName then
-- 		unitName = self:FreakerAsFactory(tqb)
-- 	else
-- 		unitName = self:ConsulAsFactory(tqb)
-- 	end
-- 	return unitName
-- end



-- mobile construction units:

function TasksHST:anyCommander()
	return {
		self:wrap( self.ai.taskecohst,'BuildAppropriateFactory' ) ,
		self:wrap( self.ai.taskecohst,'CommanderEconomy' ) ,
		self:wrap( self.ai.taskbuildhst,'BuildLLT' ) ,
		self:wrap( self.ai.taskbuildhst,'BuildRadar' ) ,
		self:wrap( self.ai.taskbuildhst,'CommanderAA' ) ,
		self:wrap( self.ai.taskbuildhst,'BuildPopTorpedo' ) ,
	}
end
function TasksHST:anyConUnit()  return  {
	self:wrap( self.ai.taskecohst,'BuildAppropriateFactory' ) ,
	self:wrap( self.ai.taskecohst,'Economy1' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildLLT' ) ,
	self:wrap( self.ai.taskecohst,'Economy1' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildMediumAA' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildRadar' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildLvl1Jammer' ) ,
	self:wrap( self.ai.taskecohst,'BuildGeo' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildHLT' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildLvl1Plasma' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildHeavyishAA' ) ,
} end

function TasksHST:anyConAmphibious()  return  {
	self:wrap( self.ai.taskecohst,'BuildAppropriateFactory' ) ,
	self:wrap( self.ai.taskecohst,'AmphibiousEconomy' ) ,
	self:wrap( self.ai.taskecohst,'BuildGeo' ) ,
	self:wrap( self.ai.taskecohst,'Economy1' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildMediumAA' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildRadar' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildLvl1Jammer' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildHLT' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildLvl1Plasma' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildHeavyishAA' ) ,
	self:wrap( self.ai.taskecohst,'AmphibiousEconomy' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildPopTorpedo' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildFloatLightAA' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildFloatRadar' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildFloatHLT' ) ,
} end

function TasksHST:anyConShip()  return  {
	self:wrap( self.ai.taskecohst,'BuildAppropriateFactory' ) ,
	self:wrap( self.ai.taskecohst,'EconomyUnderWater' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildFloatLightAA' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildLightTorpedo' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildFloatRadar' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildFloatHLT' ) ,
} end

function TasksHST:anyAdvConUnit()  return  {
	self:wrap( self.ai.taskecohst,'BuildAppropriateFactory' ) ,
	self:wrap( self.ai.taskecohst,'AdvEconomy' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildNukeIfNeeded' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildAdvancedRadar' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildHeavyPlasma' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildAntinuke' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildLvl2PopUp' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildHeavyAA' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildLvl2Plasma' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildTachyon' ) ,
	-- BuildTacticalNuke' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildExtraHeavyAA' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildLvl2Jammer' ) ,
	self:wrap( self.ai.taskecohst,'BuildMohoGeo' ) ,
} end

function TasksHST:anyConSeaplane()  return  {
	self:wrap( self.ai.taskecohst,'BuildAppropriateFactory' ) ,
	self:wrap( self.ai.taskecohst,'EconomySeaplane' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildFloatHeavyAA' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildAdvancedSonar' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildHeavyTorpedo' ) ,
} end

function TasksHST:anyAdvConSub()  return  {
	self:wrap( self.ai.taskecohst,'BuildAppropriateFactory' ) ,
	self:wrap( self.ai.taskecohst,'AdvEconomyUnderWater' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildFloatHeavyAA' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildAdvancedSonar' ) ,
	self:wrap( self.ai.taskbuildhst,'BuildHeavyTorpedo' ) ,
} end

-- function TasksHST:anyNavalEngineer()  return  {
-- 	self:wrap( self.ai.taskecohst,'BuildAppropriateFactory' ) ,
-- 	self:wrap( self.ai.taskecohst,'EconomyNavalEngineer' ) ,
-- 	self:wrap( self.ai.taskbuildhst,'BuildFloatHLT' ) ,
-- 	self:wrap( self.ai.taskbuildhst,'BuildFloatLightAA' ) ,
-- 	self:wrap( self.ai.taskbuildhst,'BuildFloatRadar' ) ,
-- 	self:wrap( self.ai.taskbuildhst,'BuildLightTorpedo' ) ,
-- } end

-- function TasksHST:anyCombatEngineer()  return  {
-- 	self:wrap( self.ai.taskecohst,'BuildAppropriateFactory' ) ,
-- 	self:wrap( self.ai.taskecohst,'EconomyBattleEngineer' ) ,
-- 	self:wrap( self.ai.taskbuildhst,'BuildMediumAA' ) ,
-- 	self:wrap( self.ai.taskbuildhst,'BuildAdvancedRadar' ) ,
-- 	self:wrap( self.ai.taskbuildhst,'BuildLvl2Jammer' ) ,
-- 	self:wrap( self.ai.taskbuildhst,'BuildHeavyAA' ) ,
-- 	self:wrap( self.ai.taskecohst,'EconomyBattleEngineer' ) ,
-- 	self:wrap( self.ai.taskbuildhst,'BuildLvl2Plasma' ) ,
-- } end

-- function TasksHST:anyFark() return{
-- 	self:wrap( self.ai.taskecohst,'EconomyFark' ) ,
-- }end

-- finally' ) , the taskqueue definitions
function TasksHST:taskqueues()  return  {

	armaca = self:wrap( self  ,  'anyAdvConUnit' ) ,
	armack = self:wrap( self  ,  'anyAdvConUnit' ) ,
	armacsub = self:wrap( self  ,  'anyAdvConSub' ) ,
	armacv = self:wrap( self  ,  'anyAdvConUnit' ) ,
	armbeaver = self:wrap( self  ,  'anyConAmphibious' ) ,
	armca = self:wrap( self  ,  'anyConUnit' ) ,
	armch = self:wrap( self  ,  'anyConAmphibious' ) ,
	armck = self:wrap( self  ,  'anyConUnit' ) ,
	armcom = self:wrap( self  ,  'anyCommander' ) ,
	armconsul = self:wrap( self  ,  'anyCombatEngineer' ) ,
	armcs = self:wrap( self  ,  'anyConShip' ) ,
	armcsa = self:wrap( self  ,  'anyConSeaplane' ) ,
	armcv = self:wrap( self  ,  'anyConUnit' ) ,
	armdecom = self:wrap( self  ,  'anyCommander' ) ,
	coraca = self:wrap( self  ,  'anyAdvConUnit' ) ,
	corack = self:wrap( self  ,  'anyAdvConUnit' ) ,
	coracsub = self:wrap( self  ,  'anyAdvConSub' ) ,
	coracv = self:wrap( self  ,  'anyAdvConUnit' ) ,
	corca = self:wrap( self  ,  'anyConUnit' ) ,
	corch = self:wrap( self  ,  'anyConAmphibious' ) ,
	corck = self:wrap( self  ,  'anyConUnit' ) ,
	corcom = self:wrap( self  ,  'anyCommander' ) ,
	corcs = self:wrap( self  ,  'anyConShip' ) ,
	corcsa = self:wrap( self  ,  'anyConSeaplane' ) ,
	corcv = self:wrap( self  ,  'anyConUnit' ) ,
	cordecom = self:wrap( self  ,  'anyCommander' ) ,
	cormuskrat = self:wrap( self  ,  'anyConAmphibious' ) ,
} end
