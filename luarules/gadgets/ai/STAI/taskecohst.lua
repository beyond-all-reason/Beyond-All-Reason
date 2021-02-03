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
function TaskEcoHST:BuildAppropriateFactory( taskQueueBehaviour, ai, builder )
	return self.ai.armyhst.FactoryUnitName
	--return self.ai.labbuildhst:GetBuilderFactory( taskQueueBehaviour, ai, builder )
end

--nano call
function TaskEcoHST:NanoTurret( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "cornanotc" ) then
		unitName = "cornanotc"
	elseif builder:CanBuild( "armnanotc" ) then
		unitName = "armnanotc"
	end
	return unitName
end

function TaskEcoHST:NanoWater( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "cornanotcplat" ) then
		unitName = "cornanotcplat"
	elseif builder:CanBuild( "armnanotcplat" ) then
		unitName = "armnanotcplat"
	end
	return unitName
end

-- MEX

function TaskEcoHST:BuildMex( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "cormex" ) then
		unitName = "cormex"
	elseif builder:CanBuild( "armmex" ) then
		unitName = "armmex"
	end
	return unitName
end

function TaskEcoHST:SpecialMex( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corexp" ) then
		unitName = "corexp"
	elseif builder:CanBuild( "armamex" ) then
		unitName = "armamex"
	end
	return unitName
end

function TaskEcoHST:BuildUWMex( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "cormex" ) then
		unitName = "cormex" --ex coruwmex
	elseif builder:CanBuild( "armmex" ) then
		unitName = "armmex"  --ex armuwmex
	end
	return unitName
end

function TaskEcoHST:BuildMohoMex( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "cormoho" ) then
		unitName = "cormoho"
	elseif builder:CanBuild( "armmoho" ) then
		unitName = "armmoho"
	end
	return unitName
end

function TaskEcoHST:BuildUWMohoMex( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "coruwmme" ) then
		unitName = "coruwmme"
	elseif builder:CanBuild( "armuwmme" ) then
		unitName = "armuwmme"
	end
	return unitName
end

--ENERGY
function TaskEcoHST:Solar( taskQueueBehaviour, ai, builder )
	if builder:CanBuild( "corsolar" ) then
		return "corsolar"
	elseif builder:CanBuild( "armsolar" ) then
		return "armsolar"
	end
end

function TaskEcoHST:SolarAdv( taskQueueBehaviour, ai, builder )
	if builder:CanBuild( "coradvsol" ) then
		return "coradvsol"
	elseif builder:CanBuild( "armadvsol" ) then
		return "armadvsol"
	end
end

function TaskEcoHST:Tidal( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "cortide" ) then
		unitName = "cortide"
	elseif builder:CanBuild( "armtide" ) then
		unitName = "armtide"
	end
	return unitName
end

function TaskEcoHST:Wind( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corwin" ) then
		unitName = "corwin"
	elseif builder:CanBuild( "armwin" ) then
		unitName = "armwin"
	end
	return unitName
end

function TaskEcoHST:TidalIfTidal( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	local tidalPower = map:TidalStrength()
	self:EchoDebug("tidal power is " .. tidalPower)
	if tidalPower >= 10 then
		unitName = self:Tidal()
	end
	return unitName
end

function TaskEcoHST:windLimit()
	if self.ai.map:AverageWind() >= 10 then
		local minWind = self.ai.map:MinimumWindSpeed()
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

function TaskEcoHST:WindSolar( taskQueueBehaviour, ai, builder )
	if self:windLimit() then
		return self:Wind( taskQueueBehaviour, ai, builder )
	else
		return self:Solar( taskQueueBehaviour, ai, builder )
	end
end

function TaskEcoHST:Energy1( taskQueueBehaviour, ai, builder )

	if self.ai.Energy.income > math.max(map:AverageWind() * 20, 150) and self.ai.Metal.full > 0.1 then
		return self:SolarAdv( taskQueueBehaviour, ai, builder )
	else
		return self:WindSolar( taskQueueBehaviour, ai, builder )
	end
end

function TaskEcoHST:BuildGeo( taskQueueBehaviour, ai, builder )
	-- don't attempt if there are no spots on the map
	self:EchoDebug("BuildGeo " .. tostring(self.ai.mapHasGeothermal))
	if not self.ai.mapHasGeothermal or self.ai.Energy.income < 150 or self.ai.Metal.income < 10 then
		return self.ai.armyhst.DummyUnitName
	end
	if builder:CanBuild( "corgeo" ) then
		return "corgeo"
	elseif builder:CanBuild( "armgeo" ) then
		return "armgeo"
	end
	return ""
end

function TaskEcoHST:BuildMohoGeo( taskQueueBehaviour, ai, builder )
	self:EchoDebug("BuildMohoGeo " .. tostring(self.ai.mapHasGeothermal))
	-- don't attempt if there are no spots on the map
	if not self.ai.mapHasGeothermal or self.ai.Energy.income < 900 or self.ai.Metal.income < 24 then
		return self.ai.armyhst.DummyUnitName
	end
	if builder:CanBuild( "corageo" ) then
		return "corageo"
	elseif builder:CanBuild( "armageo" ) then
		return "armageo"
	end
	return ""
	-- will turn into a safe geothermal or a geothermal plasma battery if too close to a factory
end

function TaskEcoHST:BuildSpecialGeo( taskQueueBehaviour, ai, builder )
	-- don't attempt if there are no spots on the map
	if not self.ai.mapHasGeothermal then
		return self.ai.armyhst.DummyUnitName
	end
	if builder:CanBuild( "corbhmt" ) then
		return "corbhmt"
	elseif builder:CanBuild( "armgmm" ) then
		return "armgmm"
	end
end

function TaskEcoHST:BuildFusion( taskQueueBehaviour, ai, builder )
	if builder:CanBuild( "corfus" ) then
		return "corfus"
	elseif builder:CanBuild( "armfus" ) then
		return "armfus"
	end
	-- will become corafus and armafus in CategoryEconFilter in TaskQueueBST if energy income is higher than 4000
end

function TaskEcoHST:BuildAdvFusion( taskQueueBehaviour, ai, builder )
	if builder:CanBuild( "corafus" ) then
		return "corafus"
	elseif builder:CanBuild( "armafus" ) then
		return "armafus"
	end
	-- will become corafus and armafus in CategoryEconFilter in TaskQueueBST if energy income is higher than 4000
end

function TaskEcoHST:BuildAdvEnergy( taskQueueBehaviour, ai, builder )
	self:EchoDebug(tostring('advname '..taskQueueBehaviour.name))
	local unitName = self.ai.armyhst.DummyUnitName
	unitName = self:BuildFusion( taskQueueBehaviour, ai, builder )
	if self.ai.Energy.income > 4000 and (taskQueueBehaviour.name == 'armacv' or taskQueueBehaviour.name == 'coracv') then
		unitName = self:BuildAdvFusion( taskQueueBehaviour, ai, builder )
	end
	return unitName
end


function TaskEcoHST:BuildUWFusion( taskQueueBehaviour, ai, builder )
	if builder:CanBuild( "coruwfus" ) then
		return "coruwfus"
	elseif builder:CanBuild( "armuwfus" ) then
		return "armuwfus"
	end
end

function TaskEcoHST:buildEstore1( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corestor" ) then
		unitName = "corestor"
	elseif builder:CanBuild( "armestor" ) then
		unitName = "armestor"
	end
	return unitName
end

function TaskEcoHST:buildEstore2( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "coruwadves" ) then
		unitName = "coruwadves"
	elseif builder:CanBuild( "armuwadves" ) then
		unitName = "armuwadves"
	end
	return unitName
end

function TaskEcoHST:buildMstore1( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "cormstor" ) then
		unitName = "cormstor"
	elseif builder:CanBuild( "armmstor" ) then
		unitName = "armmstor"
	end
	return unitName
end

function TaskEcoHST:buildMstore2( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "coruwadvms" ) then
		unitName = "coruwadvms"
	elseif builder:CanBuild( "armuwadvms" ) then
		unitName = "armuwadvms"
	end
	return unitName
end

function TaskEcoHST:buildMconv1( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "cormakr" ) then
		unitName = "cormakr"
	elseif builder:CanBuild( "armmakr" ) then
		unitName = "armmakr"
	end
	return unitName
end

function TaskEcoHST:buildMconv2( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "cormmkr" ) then
		unitName ='cormmkr'
	elseif builder:CanBuild( "armmmkr" ) then
		unitName ='armmmkr'
	end
	return unitName
end

function TaskEcoHST:buildMconv2UW( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corfmmm" ) then
		unitName ='corfmmm'
	elseif builder:CanBuild( "armfmmm" ) then
		unitName ='armfmmm'
	end
	return unitName
end

function TaskEcoHST:buildWEstore1( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "coruwes" ) then
		unitName = "coruwes"
	elseif builder:CanBuild( "armuwes" ) then
		unitName = "armuwes"
	end
	return unitName
end

function TaskEcoHST:buildWMstore1( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "coruwms" ) then
		unitName = "coruwms"
	elseif builder:CanBuild( "armuwms" ) then
		unitName = "armuwms"
	end
	return unitName
end

function TaskEcoHST:buildWMconv1( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corfmkr" ) then
		unitName = "corfmkr"
	elseif builder:CanBuild( "armfmkr" ) then
		unitName = "armfmkr"
	end
	return unitName
end

function TaskEcoHST:CommanderEconomy( taskQueueBehaviour, ai, builder )
	self:EchoDebug('commander economy ',self,type(self),taskQueueBehaviour)
	local underwater = self.ai.maphst:IsUnderWater( builder:GetPosition() )
	local unitName = self.ai.armyhst.DummyUnitName
	if not underwater then
		unitName = self:Economy0( taskQueueBehaviour, ai, builder )
	else
		unitName = self:Economy0uw( taskQueueBehaviour, ai, builder )
	end
	return unitName
end


function TaskEcoHST:AmphibiousEconomy( taskQueueBehaviour, ai, builder )
	local underwater = self.ai.maphst:IsUnderWater( builder:GetPosition())
	local unitName = self.ai.armyhst.DummyUnitName
	if underwater then
		unitName = self:EconomyUnderWater( taskQueueBehaviour, ai, builder )
	else
		unitName = self:Economy1( taskQueueBehaviour, ai, builder )
	end
	return unitName
end
