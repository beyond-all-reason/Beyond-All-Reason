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

		{ 	category = 'factoryMobilities' ,
			economy = {},--economicParameters
			duplicate = true , --duplicateFilter
			numeric = false , --numericalParameter
			location = true ,},

		{ 	category = '_wind_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'selfCat','_nano_','factoryMobilities'},himself = true} ,},

		{ 	category = '_tide_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'selfCat','_nano_','factoryMobilities'},himself = true} ,},

		{ 	category = '_solar_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'selfCat','_nano_','factoryMobilities'},himself = true} ,
			special = true } , --specialFilter

		{ 	category = '_mstor_' ,
			economy = true,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = 1 , --numericalParameter
			location = {categories = {'selfCat','_nano_','factoryMobilities'},himself = true} ,
	        },

		{ 	category = '_estor_' ,
			economy = true,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = 1 , --numericalParameter
			location = {categories = {'selfCat','_nano_','factoryMobilities'},himself = true} ,
	        },

		{ 	category = '_convs_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'selfCat','_nano_','factoryMobilities'},himself = true} ,
	        },

		{ 	category = '_mex_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = true , --positional category to search near
	        },

		{ 	category = '_nano_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = true ,
	        },

		{ 	category = '_aa1_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_mex_'},min = 50,neighbours = {'_aa1_'}} ,
	        },

		{ 	category = '_flak_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_mex_'},min = 50,neighbours = {'_flak_'}} ,
			special = true } , --specialFilter

		{ 	category = '_specialt_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_mex_'},min = 50,neighbours = {'_specialt_'}} ,
	        },

		{ 	category = '_fus_' ,
			economy = true,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_nano_','factoryMobilities'}} ,
			special = true } , --specialFilter

		{ 	category = '_popup1_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_mex_'},min = 50,neighbours = {'_llt_','_popup2_','_popup1_'}} ,
	        },

		{ 	category = '_popup2_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_mex_'},min = 50,neighbours = {'_popup2_'}} ,
	        },

		{ 	category = '_heavyt_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {list = self.ai.hotSpot, min = 50 , neighbours = {'_heavyt_','_laser2_'}} ,
	        },

		{ 	category = '_jam_' ,
			economy = true,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = 1 , --numericalParameter
			location = {categories = {'factoryMobilities'},min = 100,neighbours = {'_jam_'}} ,
	        },

		{ 	category = '_radar_' ,
			economy = true,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_mex_'},min = 50,neighbours = {'_radar_'}} ,
	        },

		{ 	category = '_geo_' ,
			economy = true,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = false , --numericalParameter
			location = true , --positional category to search near
	        },

		{ 	category = '_silo_' ,
			economy = true,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = 1 , --numericalParameter
			location = {categories = {'_nano_'},min = 50} ,
	        },

		{ 	category = '_antinuke_' ,
			economy = true,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = 1 , --numericalParameter
			location = {categories = {'_nano_'},min = 50} ,
	        },

		{ 	category = '_sonar_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_mex_'},min = 50,neighbours = {'_sonar_'}} ,
	        },

		{ 	category = '_shield_' ,
			economy = true,true,3,--numericalParameter
			location = {categories = {'_nano_'},min = 50,neighbours = {'_shield_'}} ,
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
	        },

-- 		{ 	category = '_juno_' ,			economy = true,true,1},
		{ 	category = '_laser2_' ,
			economy = true,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_nano_'},min = 50,neighbours = {'_laser2_'},list = self.ai.hotSpot}
	        } ,


		{ 	category = '_lol_' ,
			economy = true,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = 1 , --numericalParameter
			location = {categories = {'_nano_'},min = 50}
			},

		{ 	category = '_plasma_' ,
			economy = true,true,2,--numericalParameter
			duplicate = true , --duplicateFilter
			numeric = 2 , --numericalParameter
			location = {categories = {'_nano_'},min = 50} ,
	        },

		{ 	category = '_torpedo1_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_mex_'},min = 50}
			},

		{ 	category = '_torpedo2_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_mex_'},min = 50}
			},

	--	{ 	category = '_torpedoground_' ,economy = true,false,false},
		{ 	category = '_aabomb_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_heavyt_'},min = 50,neighbours = {'_aabomb_'}} ,
			special = true } , --specialFilter

		{ 	category = '_aaheavy_' ,
			economy = true,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'factoryMobilities'},min = 50,neighbours = {'_aaheavy_'}} ,
			special = true } , --specialFilter

		{ 	category = '_aa2_' ,
			economy = true,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = 1 , --numericalParameter
			location = {categories = {'factoryMobilities'},min = 50,neighbours = {'_aa2_'}} ,
			special = true } , --specialFilter

	}
----------------------------------------------------------------------------------------------------------------------------------
	self.roles.expand = {
		{ 	category = '_mex_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = true ,
	        },

		{ 	category = '_llt_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_mex_'},min = 50,neighbours = {'_llt_','_popup2_','_popup1_'},list = {self.map:GetMetalSpots()}} ,
			},

		{ 	category = '_popup2_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_mex_'},min = 50,neighbours = {'_popup2_'}} ,
	        },

		{ 	category = '_solar_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_mex_','_llt_',},himself = true} ,
			special = true } , --specialFilter

	}
--------------------------------------------------------------------------------------------------------------------------------
	self.roles.eco = {
		{ 	category = 'factoryMobilities' ,
			economy = true,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = false , --numericalParameter
			location = true , --positional category to search near
	        },

--[[		{ 	category = '_specialt_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {} , --positional category to search near
]]

		{ 	category = '_wind_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'selfCat','_nano_','factoryMobilities'},himself = true} ,
	        },

		{ 	category = '_tide_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'selfCat','_nano_','factoryMobilities'},himself = true} ,
	        },

		{ 	category = '_solar_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'selfCat','_nano_','factoryMobilities'},himself = true} ,
			special = true } , --specialFilter

		{ 	category = '_fus_' ,
			economy = true,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = false , --numericalParameter
			llocation = {categories = {'_nano_','factoryMobilities'},himself = true} ,
			special = true } , --specialFilter

		{ 	category = '_nano_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = true , --positional category to search near
	        },

		{ 	category = '_estor_' ,
			economy = true,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = 1 , --numericalParameter
			location = {categories = {'selfCat','_nano_','factoryMobilities'},himself = true} ,
	        },

		{ 	category = '_mstor_' ,
			economy = true,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = 1 , --numericalParameter
			location = {categories = {'selfCat','_nano_','factoryMobilities'},himself = true} ,
	        },

		{ 	category = '_convs_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'selfCat','_nano_','factoryMobilities'},himself = true} ,
	        },

		{ 	category = '_jam_' ,
			economy = true,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = 1 , --numericalParameter
			location = {categories = {'factoryMobilities'},min = 100,neighbours = {'_jam_'}} ,
	        },

		{ 	category = '_antinuke_' ,
			economy = true,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = 1 , --numericalParameter
			location = {categories = {'_nano_'},min = 50} ,
	        },

	}
------------------------------------------------------------------------------------------------------------------------------------
	self.roles.support = {
		{ 	category = '_radar_' ,
			economy = true,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_mex_'},min = 50,neighbours = {'_radar_'}} ,
	        },

		{ 	category = '_specialt_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_mex_'},min = 50,neighbours = {'_specialt_'}} ,
	        },

		{ 	category = '_popup1_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_mex_'},min = 50,neighbours = {'_llt_','_popup2_','_popup1_'}} ,
	        },

		{ 	category = '_popup2_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_mex_'},min = 50,neighbours = {'_popup2_'}} ,
	        },

		{ 	category = '_heavyt_' ,
			economy = true,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = false , --numericalParameter
			location = {list = self.ai.hotSpot, min = 50 , neighbours = {'_heavyt_','_laser2_'}} ,
	        },

		{ 	category = '_laser2_' ,
			economy = true,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_nano_'},min = 50,neighbours = {'_laser2_'},list = self.ai.hotSpot} ,
	        },

		{ 	category = '_aa1_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_mex_'},min = 50,neighbours = {'_aa1_'}} ,
	        },

		{ 	category = '_aabomb_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_heavyt_'},min = 50,neighbours = {'_aabomb_'}} ,
			special = true } , --specialFilter

		{ 	category = '_flak_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_mex_'},min = 50,neighbours = {'_flak_'}} ,
			special = true } , --specialFilter
	}
---------------------------------------------------------------------------------------------------------------------
	self.roles.starter = {
		{ 	category = 'factoryMobilities' ,
			economy = true,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = false , --numericalParameter
			location = true ,
	        },

		{ 	category = '_wind_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'selfCat','_nano_','factoryMobilities'},himself = true} ,
	        },

		{ 	category = '_tide_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'selfCat','_nano_','factoryMobilities'},himself = true} ,
	        },

		{ 	category = '_solar_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'selfCat','_nano_','factoryMobilities'},himself = true} ,
			special = true } , --specialFilter

		{ 	category = '_llt_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'factoryMobilities'},min = 50,neighbours = {'_llt_','_popup2_','_popup1_'}}
	        } ,
		{ 	category = '_mex_' ,
			economy = true,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = true ,
	        },
		}
	self.roles.assistant = {}
end




-- function TasksHST:wrap( theTable, theFunction )
-- 	self:EchoDebug(theTable)
-- 	self:EchoDebug(theFunction)
-- 	return function( tb, ai ,bd)
-- 		return theTable[theFunction](theTable, tb, ai, bd)
-- 	end
-- end
--
-- function map(func, array)
-- 	local new_array = {}
-- 	for i,v in ipairs(array) do
-- 		new_array[i] = func(v)
-- 	end
-- 	return new_array
-- end
--
-- function TasksHST:multiwrap( tables )
-- 	local wrapped = {}
-- 	for i,v in ipairs( table ) do
-- 		wrapped[i] = self:wrap( v[1], v[2] )
-- 	end
-- 	return wrapped
-- end
--
-- random = math.random
-- math.randomseed( os.time() + game:GetTeamID() )
-- random(); random(); random()
--
-- function TasksHST:MapHasWater()
-- 	return (self.ai.waterMap or self.ai.hasUWSpots) or false
-- end
--
-- -- this is initialized in maphst
-- function TasksHST:MapHasUnderwaterMetal()
-- 	return self.ai.hasUWSpots or false
-- end
--
-- function TasksHST:IsSiegeEquipmentNeeded()
-- 	return self.ai.overviewhst.needSiege
-- end
--
-- function TasksHST:IsAANeeded()
-- 	return self.ai.needAirDefense
-- end
--
-- function TasksHST:IsShieldNeeded()
-- 	return self.ai.needShields
-- end
--
-- function TasksHST:IsTorpedoNeeded()
-- 	return self.ai.needSubmergedDefense
-- end
--
-- function TasksHST:IsJammerNeeded()
-- 	return self.ai.needJammers
-- end
--
-- function TasksHST:IsAntinukeNeeded()
-- 	return self.ai.needAntinuke
-- end
--
-- function TasksHST:IsNukeNeeded()
-- 	local nuke = self.ai.needNukes and self.ai.canNuke
-- 	return nuke
-- end
--
-- function TasksHST:IsLandAttackNeeded()
-- 	return self.ai.areLandTargets or self.ai.needGroundDefense
-- end
--
-- function TasksHST:IsWaterAttackNeeded()
-- 	return self.ai.areWaterTargets or self.ai.needSubmergedDefense
-- end


--[[

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
end]]
