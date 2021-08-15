TasksHST = class(Module)

function TasksHST:Name()
	return "TasksHST"
end

function TasksHST:internalName()
	return "taskshst"
end

function TasksHST:Init()
	self.DebugEnabled = false
	self.roles = {}
	self.roles.default = {
		--category, eco,duplicate,limitedNumber,location,special
		{'factoryMobilities',true,true,false,true,true},
		{'_wind_',true,false,false,true,true},
		{'_tide_',true,false,false,true,true},
		{'_solar_',true,false,false,true,true},
		{'_mex_',true,false,false,true,true},
		{'_llt_',true,false,false,true,true},
		{'_nano_',true,false,false,true,true},
		{'_aa1_',true,false,false,true,true},
		{'_flak_',true,false,false,true,true},
		{'_specialt_',true,false,false,true,true},--limited number % Energy
		{'_fus_',true,true,false,true,true},
		{'_popup1_',true,false,false,true,true},
		{'_popup2_',true,false,false,true,true},
		{'_heavyt_',true,false,false,true,true},
		{'_estor_',true,true,1,true,true},
		{'_mstor_',true,true,1,true,true},
		{'_convs_',true,false,false,true,true},
		{'_specialt_',true,false,false,true,true},
		{'_jam_',true,true,1,true,true},
		{'_radar_',true,true,false,true,true},
		{'_geo_',true,true,false,true,true},
		{'_silo_',true,true,1,true,true},
		{'_antinuke_',true,true,1,true,true},
		{'_sonar_',true,false,false,true,true},
		{'_shield_',true,true,3,true,true},
-- 		{'_juno_',true,true,1},
		{'_laser2_',true,true,false,true,true},
		{'_lol_',true,true,1,true,true},
-- 		{'_coast1_',true,true,2},
-- 		{'_coast2_',true,true,1},
		{'_plasma_',true,true,2,true,true},
		{'_torpedo1_',true,false,false,true,true},
		{'_torpedo2_',true,false,false,true,true},
	--	{'_torpedoground_',true,false,false},
		{'_aabomb_',true,false,false,true,true},
		{'_aaheavy_',true,true,false,true,true},
		{'_aa2_',true,true,1,true,true},
	}

	self.roles.expand = {
		{'_mex_',true,false,false,true,true},
		{'_llt_',true,false,false,true,true},
		{'_popup2_',true,false,false,true,true},
	}

	self.roles.eco = {
		{'factoryMobilities',true,true,false,true,true},
-- 		{'_specialt_',true,false,false,true,true},
		{'_wind_',true,false,false,true,true},
		{'_tide_',true,false,false,true,true},
		{'_solar_',true,false,false,true,true},
		{'_fus_',true,true,false,true,true},
		{'_nano_',true,false,false,true,true},
		{'_estor_',true,true,1,true,true},
		{'_mstor_',true,true,1,true,true},
		{'_convs_',true,false,false,true,true},
		{'_jam_',true,true,1,true,true},
		{'_antinuke_',true,true,1,true,true},
	}
	self.roles.support = {
		{'_radar_',true,true,false,true,true},
		{'_specialt_',true,false,false,true,true},
		{'_popup1_',true,false,false,true,true},
		{'_popup2_',true,false,false,true,true},
		{'_heavyt_',true,true,false,true,true},
		{'_laser2_',true,true,false,true,true},
		{'_aa1_',true,false,false,true,true},
		{'_aabomb_',true,false,false,true,true},
		{'_flak_',true,false,false,true,true},
	}
end

function TasksHST:wrap( theTable, theFunction )
	self:EchoDebug(theTable)
	self:EchoDebug(theFunction)
	return function( tb, ai ,bd)
		return theTable[theFunction](theTable, tb, ai, bd)
	end
end

function map(func, array)
	local new_array = {}
	for i,v in ipairs(array) do
		new_array[i] = func(v)
	end
	return new_array
end

function TasksHST:multiwrap( tables )
	local wrapped = {}
	for i,v in ipairs( table ) do
		wrapped[i] = self:wrap( v[1], v[2] )
	end
	return wrapped
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
-- 	local mtype = self.ai.armyhst.unitTable[unitName].mtype
-- 	local level = self.ai.armyhst.unitTable[unitName].techLevel
-- 	local mtypedLv = mtype .. tostring(level)
--
-- 	local counter = self.ai.mtypeLvCount[mtypedLv] or 0
	local counter = self.ai.tool:mtypedLvCount(self.ai.armyhst.unitTable[unitName].mtypedLv)
	self:EchoDebug('mtypedLvmtype ' , counter)
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
		if self.ai.tool:countMyUnit({'artillerys'}) < (self.ai.tool:countMyUnit({'battles'}) + self.ai.tool:countMyUnit({'breaks'})) * 0.35 then
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
		if self.ai.tool:countMyUnit({'battles'}) <= self.ai.armyhst.minBattleCount then return self.ai.armyhst.DummyUnitName end
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
		if self.ai.tool:countMyUnit({'battles'}) + self.ai.breakthroughCount < attackCounter / 2 then
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
	if attackCounter == self.ai.armyhst.maxAttackCounter and self.ai.tool:countMyUnit({'battles'}) > self.ai.armyhst.minBattleCount then return self.ai.armyhst.DummyUnitName end
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

-- function TasksHST:CountOwnUnits(tmpUnitName)
-- 	if tmpUnitName == self.ai.armyhst.DummyUnitName then return 0 end -- don't count no-units
-- 	if self.ai.nameCount[tmpUnitName] == nil then return 0 end
-- 	return self.ai.nameCount[tmpUnitName]
-- end

function TasksHST:BuildWithLimitedNumber(tmpUnitName, minNumber)
	if tmpUnitName == self.ai.armyhst.DummyUnitName then return self.ai.armyhst.DummyUnitName end
	if minNumber == 0 then return self.ai.armyhst.DummyUnitName end
-- 	if self.ai.nameCount[tmpUnitName] == nil then
-- 		return tmpUnitName
-- 	else
-- 		if self.ai.nameCount[tmpUnitName] == 0 or self.ai.nameCount[tmpUnitName] < minNumber then
-- 			return tmpUnitName
-- 		else
-- 			return self.ai.armyhst.DummyUnitName
-- 		end
-- 	end
	return self.ai.tool:countMyUnit({tmpUnitName})
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
