TaskEcoHST = class(Module)

function TaskEcoHST:Name()
	return "TaskEcoHST"
end

function TaskEcoHST:internalName()
	return "taskecohst"
end

function TaskEcoHST:Init()
	self.DebugEnabled = false
	self.roles = {}
	self.roles.default = {
		--group, eco,duplicate,limitedNumber,location
		{'factoryMobilities',true,true,false},
		{'_wind_',true,false,false},
		{'_tide_',true,false,false},
		{'_solar_',true,false,false},
		{'_advsol_',true,false,false},
		{'_mex_',true,false,false},
		{'_nano_',true,false,false},
		{'_llt_',true,false,false},
		{'_aa1_',true,false,false},
		{'_flak_',true,false,false},
		{'_specialt_',true,false,false},
		{'_fus_',true,true,false},
		{'_popup1_',true,false,false},
		{'_popup2_',true,false,false},
		{'_heavyt_',true,false,false},
		{'_estor_',true,true,1},
		{'_mstor_',true,true,1},
		{'_convs_',true,false,false},
		{'_jam_',true,true,1},
		{'_radar_',true,true,false},
		{'_geo_',true,true,false},
		{'_silo_',true,true,1},
		{'_antinuke_',true,true,1},
		{'_sonar_',true,false,false},
		{'_shield_',true,true,3},
-- 		{'_juno_',true,true,1},
		{'_laser2_',true,true,false},
		{'_lol_',true,true,1},
-- 		{'_coast1_',true,true,2},
-- 		{'_coast2_',true,true,1},
		{'_plasma_',true,true,2},
		{'_torpedo1_',true,false,false},
		{'_torpedo2_',true,false,false},
		{'_torpedoground_',true,false,false},
		{'_aabomb_',true,false,false},
		{'_aaheavy_',true,true,false},
		{'_aa2_',true,true,1},




	}

	self.roles.expand = {
		{'_mex_',true,false,false},
		{'_llt_',true,false,false},
		{'_popup1_',true,false,false},
		{'_popup2_',true,false,false}

	}
	self.roles.eco = {
		{'factoryMobilities',true,true,false},
		{'_wind_',true,false,false},
		{'_tide_',true,false,false},
		{'_solar_',true,false,false},
		{'_advsol_',true,false,false},
		{'_fus_',true,true,false},
		{'_nano_',true,false,false},
		{'_specialt_',true,false,false},
		{'_estor_',true,true,1},
		{'_mstor_',true,true,1},
		{'_convs_',true,false,false},
		{'_jam_',true,true,1},
		{'_antinuke_',true,true,1},


	}
	self.roles.support = {
		{'_aa1_',true,false,false},
		{'_flak_',true,false,false},
		{'_heavyt_',true,false,false},
		{'_radar_',true,true,false},
		{'_laser2_',true,true,false},
		{'_aabomb_',true,false,false},

	}


end


--Factory call
function TaskEcoHST:BuildAppropriateFactory()
	return self.ai.armyhst.FactoryUnitName
end
--nano call
function TaskEcoHST:NanoTurret()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "cornanotc"
	else
		unitName = "armnanotc"
	end
	return unitName
end

function TaskEcoHST:NanoWater()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "cornanotcplat"
	else
		unitName = "armnanotcplat"
	end
	return unitName
end

-- MEX

function TaskEcoHST:BuildMex()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then

		unitName = "cormex"
	else
		unitName = "armmex"
	end
	return unitName
end

function TaskEcoHST:SpecialMex()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corexp"
	else
		unitName = "armamex"
	end
	return unitName
end

function TaskEcoHST:BuildUWMex()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "cormex" --ex coruwmex
	else
		unitName = "armmex"  --ex armuwmex
	end
	return unitName
end

function TaskEcoHST:BuildMohoMex()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "cormoho"
	else
		unitName = "armmoho"
	end
	return unitName
end

function TaskEcoHST:BuildUWMohoMex()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "coruwmme"
	else
		unitName = "armuwmme"
	end
	return unitName
end

--ENERGY
function TaskEcoHST:Solar()
	if  self.ai.side == self.ai.armyhst.CORESideName then
		return "corsolar"
	else
		return "armsolar"
	end
end

function TaskEcoHST:SolarAdv()
	if  self.ai.side == self.ai.armyhst.CORESideName then
		return "coradvsol"
	else
		return "armadvsol"
	end
end

function TaskEcoHST:Tidal()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "cortide"
	else
		unitName = "armtide"
	end
	return unitName
end

function TaskEcoHST:Wind()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corwin"
	else
		unitName = "armwin"
	end
	return unitName
end

function TaskEcoHST:TidalIfTidal()
	local unitName = self.ai.armyhst.DummyUnitName
	local tidalPower = map:TidalStrength()
	self:EchoDebug("tidal power is " .. tidalPower)
	if tidalPower >= 10 then
		unitName = self:Tidal()
	end
	return unitName
end

function TaskEcoHST:windLimit()
	if map:AverageWind() >= 10 then
		local minWind = map:MinimumWindSpeed()
		if minWind >= 8 then
			self:EchoDebug("minimum wind high enough to build only wind")
			return true
		else
			return math.random() < math.max(0.5, minWind / 8)
		end
	else
		return false
	end
end

function TaskEcoHST:WindSolar()
	if self:windLimit() then
		return self:Wind()
	else
		return self:Solar()
	end
end

function TaskEcoHST:Energy1()

	if self.ai.Energy.income > math.max(map:AverageWind() * 20, 150) and self.ai.Metal.full > 0.1 then
		return self:SolarAdv()
	else
		return self:WindSolar()
	end
end

function TaskEcoHST:BuildGeo()
	-- don't attempt if there are no spots on the map
	self:EchoDebug("BuildGeo " .. tostring(self.ai.mapHasGeothermal))
	if not self.ai.mapHasGeothermal or self.ai.Energy.income < 150 or self.ai.Metal.income < 10 then
		return self.ai.armyhst.DummyUnitName
	end
	if  self.ai.side == self.ai.armyhst.CORESideName then
		return "corgeo"
	else
		return "armgeo"
	end
end

function TaskEcoHST:BuildMohoGeo()
	self:EchoDebug("BuildMohoGeo " .. tostring(self.ai.mapHasGeothermal))
	-- don't attempt if there are no spots on the map
	if not self.ai.mapHasGeothermal or self.ai.Energy.income < 900 or self.ai.Metal.income < 24 then
		return self.ai.armyhst.DummyUnitName
	end
	if  self.ai.side == self.ai.armyhst.CORESideName then
		return "corageo"
	else
		return "armageo"
	end
	-- will turn into a safe geothermal or a geothermal plasma battery if too close to a factory
end

function TaskEcoHST:BuildSpecialGeo()
	-- don't attempt if there are no spots on the map
	if not self.ai.mapHasGeothermal then
		return self.ai.armyhst.DummyUnitName
	end
	if  self.ai.side == self.ai.armyhst.CORESideName then
		return "corbhmt"
	else
		return "armgmm"
	end
end

function TaskEcoHST:BuildFusion()
	if  self.ai.side == self.ai.armyhst.CORESideName then
		return "corfus"
	else
		return "armfus"
	end
	-- will become corafus and armafus in CategoryEconFilter in TaskQueueBST if energy income is higher than 4000
end

function TaskEcoHST:BuildAdvFusion()
	if  self.ai.side == self.ai.armyhst.CORESideName then
		return "corafus"
	else
		return "armafus"
	end
	-- will become corafus and armafus in CategoryEconFilter in TaskQueueBST if energy income is higher than 4000
end

function TaskEcoHST:BuildAdvEnergy(tqb)
	self:EchoDebug(tostring('advname '..tqb.name))
	local unitName = self.ai.armyhst.DummyUnitName
	unitName = self:BuildFusion()
	if self.ai.Energy.income > 4000 and (tqb.name == 'armacv' or tqb.name == 'coracv') then
		unitName = self:BuildAdvFusion()
	end
	return unitName
end


function TaskEcoHST:BuildUWFusion()
	if  self.ai.side == self.ai.armyhst.CORESideName then
		return "coruwfus"
	else
		return "armuwfus"
	end
end

function TaskEcoHST:buildEstore1()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corestor"
	else
		unitName = "armestor"
	end
	return unitName
end

function TaskEcoHST:buildEstore2()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "coruwadves"
	else
		unitName = "armuwadves"
	end
	return unitName
end

function TaskEcoHST:buildMstore1()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
			unitName = "cormstor"
	else
			unitName = "armmstor"
	end
	return unitName
end

function TaskEcoHST:buildMstore2()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "coruwadvms"
	else
		unitName = "armuwadvms"
	end
	return unitName
end

function TaskEcoHST:buildMconv1()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "cormakr"
	else
		unitName = "armmakr"
	end
	return unitName
end

function TaskEcoHST:buildMconv2()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
			unitName ='cormmkr'
	else
			unitName ='armmmkr'
	end
	return unitName
end

function TaskEcoHST:buildMconv2UW()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
			unitName ='corfmmm'
	else
			unitName ='armfmmm'
	end
	return unitName
end

function TaskEcoHST:buildWEstore1()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "coruwes"
	else
		unitName = "armuwes"
	end
	return unitName
end

function TaskEcoHST:buildWMstore1()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "coruwms"
	else
		unitName = "armuwms"
	end
	return unitName
end

function TaskEcoHST:buildWMconv1()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corfmkr"
	else
		unitName = "armfmkr"
	end
	return unitName
end

function TaskEcoHST:CommanderEconomy(tqb)
	self:EchoDebug('commander economy ',self,type(self),tqb)
	local underwater = self.ai.maphst:IsUnderWater(tqb.unit:Internal():GetPosition())
	local unitName = self.ai.armyhst.DummyUnitName
	if not underwater then
		unitName = self:Economy0()
	else
		unitName = self:Economy0uw()
	end
	return unitName
end


function TaskEcoHST:AmphibiousEconomy(tqb)
	local underwater = self.ai.maphst:IsUnderWater(tqb.unit:Internal():GetPosition())
	local unitName = self.ai.armyhst.DummyUnitName
	if underwater then
		unitName = self:EconomyUnderWater(tqb)
	else
		unitName = self:Economy1(tqb)
	end
	return unitName
end

function TaskEcoHST:Economy0()
	self:EchoDebug(self.ai.Energy.income,self.ai.Metal.income,self.ai.Energy.full,self.ai.Metal.full)
	local unitName = self.ai.armyhst.DummyUnitName
	if self.ai.Energy.full > 0.1 and (self.ai.Metal.income < 1 or self.ai.Metal.full < 0.3) then
		unitName = self:BuildMex()
	elseif self.ai.Energy.full > 0.9 and self.ai.Energy.income > 400  and self.ai.Metal.reserves > 100 and self.ai.Energy.capacity < 7000 then
		unitName = self:buildEstore1()
	elseif self.ai.Metal.full > 0.7 and self.ai.Metal.income > 50 and self.ai.Metal.capacity < 4000 and self.ai.Energy.reserves > 500  then
		unitName = self:buildMstore1()
	elseif self.ai.Energy.income > self.ai.Energy.usage * 1.1 and self.ai.Energy.full > 0.9 and self.ai.Energy.income > 200 and self.ai.Energy.income < 2000 and self.ai.Metal.full < 0.3 then
		unitName = self:buildMconv1()
	elseif (self.ai.Energy.full < 0.5 or self.ai.Energy.income < self.ai.Energy.usage )  or self.ai.Energy.income < 30 then
		unitName = self:WindSolar()
	else
		unitName = self:BuildMex()
	end
	self:EchoDebug('Economy commander '..unitName)
	return unitName
end

function TaskEcoHST:Economy0uw()
	local unitName = self.ai.armyhst.DummyUnitName
	if self.ai.Energy.full > 0.9 and self.ai.Energy.income > 500  and self.ai.Metal.reserves > 300 and self.ai.Energy.capacity < 7000 then
		unitName = self:buildWEstore1()
	elseif self.ai.Metal.full > 0.7 and self.ai.Metal.income > 30 and self.ai.Metal.capacity < 4000 and self.ai.Energy.reserves > 600 then
		unitName = self:buildWMstore1()
	elseif self.ai.Energy.income > self.ai.Energy.usage and self.ai.Energy.full > 0.9 and self.ai.Energy.income > 200 and self.ai.Energy.income < 2000 and self.ai.Metal.full < 0.3 then
		unitName = self:buildWMconv1()
	elseif self.ai.Energy.full > 0.1 and (self.ai.Metal.income < 1 or self.ai.Metal.full < 0.6) then
		unitName = self:BuildUWMex()
	elseif (self.ai.Energy.full < 0.3 or self.ai.Energy.income < self.ai.Energy.usage * 1.25) and self.ai.Metal.income > 3 and self.ai.Metal.full > 0.1 then
		unitName = self:TidalIfTidal()--this can get problems
	else
		unitName = self:BuildUWMex()
	end
	self:EchoDebug('Under water Economy level 1 '..unitName)
	return unitName
end

function TaskEcoHST:Economy1()
	local unitName = self.ai.armyhst.DummyUnitName
	if (self.ai.Energy.full  < 0.1  ) and self.ai.Energy.income < 8000 then
		unitName = self:Energy1()
	elseif self.ai.Metal.income > self.ai.Metal.usage * 1.5 and self.ai.Energy.income > self.ai.Energy.usage * 2  and math.random() < 0.33 then
		unitName = self:NanoTurret()
	elseif self.ai.Energy.full > 0.5 and self.ai.Metal.full > 0.3 and self.ai.Metal.full < 0.7 and self.ai.Metal.income > 30 then
		unitName = self:SpecialMex()
	elseif (self.ai.Energy.full > 0.5  and self.ai.Metal.full > 0.3 and self.ai.Metal.income > 10 and self.ai.Energy.income > 100)  then
		unitName = self:NanoTurret()
	elseif 	self.ai.Energy.full > 0.8 and self.ai.Energy.income > 600 and self.ai.Metal.reserves > 200 and self.ai.Energy.capacity < 7000 then
		unitName = self:buildEstore1()
	elseif self.ai.Metal.full > 0.8 and self.ai.Metal.income > 40 and self.ai.Metal.capacity < 4000  and self.ai.Energy.reserves > 300 then
		unitName = self:buildMstore1()
	elseif self.ai.Energy.income > self.ai.Energy.usage and self.ai.Energy.full > 0.8 and self.ai.Energy.income > 100 and self.ai.Energy.income < 2000 and self.ai.Metal.full < 0.5 then
		unitName = self:buildMconv1()
	elseif (self.ai.Energy.full < 0.3 or self.ai.Energy.income < self.ai.Energy.usage * 1.25) and self.ai.Metal.full > 0.1  and self.ai.Energy.income < 4000 then
		unitName = self:Energy1()
	else
		unitName = self:BuildMex()
	end
	self:EchoDebug('Economy level 1 '..unitName)
	return unitName
end

function TaskEcoHST:EconomyUnderWater()
	local unitName = self.ai.armyhst.DummyUnitName
	if (self.ai.Energy.full > 0.5  and self.ai.Metal.full > 0.3 and self.ai.Metal.income > 10 and self.ai.Energy.income > 100) then
		unitName = self:NanoWater()
	elseif self.ai.Energy.full > 0.9 and self.ai.Energy.income > 500  and self.ai.Metal.reserves > 300 and self.ai.Energy.capacity < 7000 then
		unitName = self:buildWEstore1()
	elseif self.ai.Metal.full > 0.7 and self.ai.Metal.income > 30 and self.ai.Metal.capacity < 4000 and self.ai.Energy.reserves > 600 then
		unitName = self:buildWMstore1()
	elseif self.ai.Energy.income > self.ai.Energy.usage and self.ai.Energy.full > 0.9 and self.ai.Energy.income > 200 and self.ai.Energy.income < 2000 and self.ai.Metal.full < 0.3 then
		unitName = self:buildWMconv1()
	elseif self.ai.Energy.full > 0.1 and (self.ai.Metal.income < 1 or self.ai.Metal.full < 0.6) then
		unitName = self:BuildUWMex()
	elseif (self.ai.Energy.full < 0.3 or self.ai.Energy.income < self.ai.Energy.usage * 1.25) and self.ai.Metal.income > 3 and self.ai.Metal.full > 0.1 then
		unitName = self:TidalIfTidal()--this can get problems
	else
		unitName = self:BuildUWMex()
	end
	self:EchoDebug('Under water Economy level 1 '..unitName)
	return unitName
end

function TaskEcoHST:AdvEconomy(tqb)
	local unitName = self.ai.armyhst.DummyUnitName
-- 	if self.ai.cleanhst.bigEnergyCount == 0 then
-- 		unitName = self:BuildAdvEnergy(tqb)
	if self.ai.Energy.full > 0.9 and self.ai.Energy.income > 3000 and self.ai.Metal.reserves > 1000 and self.ai.Energy.capacity < 40000 then
		unitName = self:buildEstore2()
	elseif self.ai.Metal.full > 0.8 and self.ai.Metal.income > 100 and self.ai.Metal.capacity < 20000 and self.ai.Energy.full > 0.3 then
		unitName = self:buildMstore2()
	elseif self.ai.Energy.income > self.ai.Energy.usage and self.ai.Energy.full > 0.7 and self.ai.Energy.income > 2000 and self.ai.Metal.full < 0.5 then
		unitName = self:buildMconv2()
	elseif (self.ai.Energy.full < 0.3 or self.ai.Energy.income < self.ai.Energy.usage * 1.25) and self.ai.Metal.full > 0.1 and self.ai.Metal.income > 18 then
		unitName = self:BuildAdvEnergy(tqb)
	else--if self.ai.Metal.full < 0.2 and self.ai.Energy.full > 0.1 then
		unitName = self:BuildMohoMex()
	end
	self:EchoDebug('Economy level 3 '..unitName)
	return unitName
end

function TaskEcoHST:AdvEconomyUnderWater()
	local unitName = self.ai.armyhst.DummyUnitName
	if self.ai.Energy.full>0.8 and self.ai.Energy.income > 2500 and self.ai.Metal.reserves > 800 and self.ai.Energy.capacity < 50000  then
		unitName = self:buildEstore2()
	elseif self.ai.Metal.full>0.7 and self.ai.Metal.income>30 and self.ai.Metal.capacity < 20000 and self.ai.Energy.full > 0.4 then
		unitName = self:buildMstore2()
	elseif self.ai.Energy.income > self.ai.Energy.usage and self.ai.Energy.full > 0.9 and self.ai.Energy.income > 2000 and self.ai.Metal.full < 0.3 then
		unitName = self:buildMconv2UW()
	elseif (self.ai.Energy.full<0.3 or self.ai.Energy.income < self.ai.Energy.usage * 1.5) and self.ai.Metal.full>0.1 then
		unitName = self:BuildUWFusion()
	else
		unitName = self:BuildUWMohoMex()
	end
	self:EchoDebug('Economy under water level 2 '..unitName)
	return unitName
end

function TaskEcoHST:EconomySeaplane()
	local unitName = self.ai.armyhst.DummyUnitName
	if self.ai.Energy.full>0.7 and self.ai.Energy.income > 2000 and self.ai.Metal.income>self.ai.Metal.usage and self.ai.Energy.capacity < 60000  then
		unitName = self:buildEstore2()
	elseif self.ai.Metal.full>0.9 and self.ai.Metal.income>30 and self.ai.Metal.capacity < 30000 and self.ai.Energy.full > 0.3 then
		unitName = self:buildMstore2()
	elseif self.ai.Energy.full>0.8  then
		unitName = self:buildMconv2UW()
	elseif self.ai.Energy.full>0.5 and self.ai.Metal.full>0.5 then
		unitName = self:Lvl2ShipAssist()
	end
	self:EchoDebug('Economy Seaplane '..unitName)
	return unitName
end
--[[
function TaskEcoHST:EconomyBattleEngineer(tqb)
        local unitName = self.ai.armyhst.DummyUnitName
	if self.ai.realEnergy > 1.25 and self.ai.realMetal > 1.1 then
		unitName =  self:NanoTurret()
	elseif self.ai.Energy.full < 0.1 and self.ai.Metal.full > 0.1 then
		unitName = self:Solar()
	elseif self.ai.Metal.full < 0.2 then
		unitName = self:BuildMex()
	else
		unitName = self.ai.taskshst:EngineerAsFactory(tqb)
	end
	self:EchoDebug('Economy battle engineer  '..unitName)
	return unitName
end]]

-- function TaskEcoHST:EconomyNavalEngineer(tqb)
--         local unitName = self.ai.armyhst.DummyUnitName
-- 	if self.ai.Energy.full < 0.2 and realMetal > 1 then
-- 		unitName = self:TidalIfTidal()
-- 	elseif self.ai.Metal.full < 0.2 and self.ai.Energy.income > self.ai.Metal.usage then
-- 		unitName = self:BuildUWMex()
-- 	else
-- 		unitName = self:NavalEngineerAsFactory(tqb)
-- 	end
-- 	self:EchoDebug('Economy Naval Engineer '..unitName)
-- 	return unitName
-- end

-- function TaskEcoHST:EconomyFark()
-- 	local unitName = self.ai.armyhst.DummyUnitName
-- 	if (self.ai.Energy.full < 0.3 or self.ai.realEnergy < 1.1)   then
-- 		unitName = self:WindSolar()
-- 	elseif self.ai.Energy.full > 0.9 and self.ai.Metal.capacity < 4000 then
-- 		unitName = self:buildEstore1()
-- 	else
-- 		unitName = self:BuildMex()
-- 	end
-- 	return unitName
-- end
