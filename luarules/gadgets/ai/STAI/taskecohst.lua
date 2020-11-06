TaskEcoHST = class(Module)

function TaskEcoHST:Name()
	return "TaskEcoHST"
end

function TaskEcoHST:internalName()
	return "taskecohst"
end

function TaskEcoHST:Init()
	self.DebugEnabled = false

end

--Factory call
function TaskEcoHST:BuildAppropriateFactory( taskQueueBehaviour, ai, builder )
	return self.ai.armyhst.FactoryUnitName
end
--nano call
function TaskEcoHST:NanoTurret( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "cornanotc"
	else
		unitName = "armnanotc"
	end
	return unitName
end

function TaskEcoHST:NanoWater( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "cornanotcplat"
	else
		unitName = "armnanotcplat"
	end
	return unitName
end

-- MEX

function TaskEcoHST:BuildMex( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then

		unitName = "cormex"
	else
		unitName = "armmex"
	end
	return unitName
end

function TaskEcoHST:SpecialMex( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corexp"
	else
		unitName = "armamex"
	end
	return unitName
end

function TaskEcoHST:BuildUWMex( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "cormex" --ex coruwmex
	else
		unitName = "armmex"  --ex armuwmex
	end
	return unitName
end

function TaskEcoHST:BuildMohoMex( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "cormoho"
	else
		unitName = "armmoho"
	end
	return unitName
end

function TaskEcoHST:BuildUWMohoMex( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "coruwmme"
	else
		unitName = "armuwmme"
	end
	return unitName
end

--ENERGY
function TaskEcoHST:Solar( taskQueueBehaviour, ai, builder )
	if  self.ai.side == self.ai.armyhst.CORESideName then
		return "corsolar"
	else
		return "armsolar"
	end
end

function TaskEcoHST:SolarAdv( taskQueueBehaviour, ai, builder )
	if  self.ai.side == self.ai.armyhst.CORESideName then
		return "coradvsol"
	else
		return "armadvsol"
	end
end

function TaskEcoHST:Tidal( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "cortide"
	else
		unitName = "armtide"
	end
	return unitName
end

function TaskEcoHST:Wind( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corwin"
	else
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
	if  self.ai.side == self.ai.armyhst.CORESideName then
		return "corgeo"
	else
		return "armgeo"
	end
end

function TaskEcoHST:BuildMohoGeo( taskQueueBehaviour, ai, builder )
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

function TaskEcoHST:BuildSpecialGeo( taskQueueBehaviour, ai, builder )
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

function TaskEcoHST:BuildFusion( taskQueueBehaviour, ai, builder )
	if  self.ai.side == self.ai.armyhst.CORESideName then
		return "corfus"
	else
		return "armfus"
	end
	-- will become corafus and armafus in CategoryEconFilter in TaskQueueBST if energy income is higher than 4000
end

function TaskEcoHST:BuildAdvFusion( taskQueueBehaviour, ai, builder )
	if  self.ai.side == self.ai.armyhst.CORESideName then
		return "corafus"
	else
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
	if  self.ai.side == self.ai.armyhst.CORESideName then
		return "coruwfus"
	else
		return "armuwfus"
	end
end

function TaskEcoHST:buildEstore1( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corestor"
	else
		unitName = "armestor"
	end
	return unitName
end

function TaskEcoHST:buildEstore2( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "coruwadves"
	else
		unitName = "armuwadves"
	end
	return unitName
end

function TaskEcoHST:buildMstore1( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
			unitName = "cormstor"
	else
			unitName = "armmstor"
	end
	return unitName
end

function TaskEcoHST:buildMstore2( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "coruwadvms"
	else
		unitName = "armuwadvms"
	end
	return unitName
end

function TaskEcoHST:buildMconv1( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "cormakr"
	else
		unitName = "armmakr"
	end
	return unitName
end

function TaskEcoHST:buildMconv2( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
			unitName ='cormmkr'
	else
			unitName ='armmmkr'
	end
	return unitName
end

function TaskEcoHST:buildMconv2UW( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
			unitName ='corfmmm'
	else
			unitName ='armfmmm'
	end
	return unitName
end

function TaskEcoHST:buildWEstore1( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "coruwes"
	else
		unitName = "armuwes"
	end
	return unitName
end

function TaskEcoHST:buildWMstore1( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "coruwms"
	else
		unitName = "armuwms"
	end
	return unitName
end

function TaskEcoHST:buildWMconv1( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corfmkr"
	else
		unitName = "armfmkr"
	end
	return unitName
end

function TaskEcoHST:CommanderEconomy( taskQueueBehaviour, ai, builder )
	self:EchoDebug('commander economy ',self,type(self),taskQueueBehaviour)
	local underwater = self.ai.maphst:IsUnderWater( builder:Internal():GetPosition() )
	local unitName = self.ai.armyhst.DummyUnitName
	if not underwater then
		unitName = self:Economy0()
	else
		unitName = self:Economy0uw()
	end
	return unitName
end


function TaskEcoHST:AmphibiousEconomy( taskQueueBehaviour, ai, builder )
	local underwater = self.ai.maphst:IsUnderWater( builder:Internal():GetPosition())
	local unitName = self.ai.armyhst.DummyUnitName
	if underwater then
		unitName = self:EconomyUnderWater( taskQueueBehaviour, ai, builder )
	else
		unitName = self:Economy1( taskQueueBehaviour, ai, builder )
	end
	return unitName
end

function TaskEcoHST:Economy0( taskQueueBehaviour, ai, builder )
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

function TaskEcoHST:Economy0uw( taskQueueBehaviour, ai, builder )
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

function TaskEcoHST:Economy1( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if self.ai.Energy.full > 0.5 and self.ai.Metal.full > 0.3 and self.ai.Metal.full < 0.7 and self.ai.Metal.income > 30 then
		unitName = self:SpecialMex()
	elseif (self.ai.Energy.full > 0.5  and self.ai.Metal.full > 0.3 and self.ai.Metal.income > 10 and self.ai.Energy.income > 100) then
		unitName = self:NanoTurret()
	elseif 	self.ai.Energy.full > 0.8 and self.ai.Energy.income > 600 and self.ai.Metal.reserves > 200 and self.ai.Energy.capacity < 7000 then
		unitName = self:buildEstore1()
	elseif self.ai.Metal.full > 0.8 and self.ai.Metal.income > 40 and self.ai.Metal.capacity < 4000  and self.ai.Energy.reserves > 300 then
		unitName = self:buildMstore1()
	elseif self.ai.Energy.income > self.ai.Energy.usage and self.ai.Energy.full > 0.8 and self.ai.Energy.income > 100 and self.ai.Energy.income < 2000 and self.ai.Metal.full < 0.5 then
		unitName = self:buildMconv1()
	elseif (self.ai.Energy.full < 0.3 or self.ai.Energy.income < self.ai.Energy.usage * 1.25) and self.ai.Metal.full > 0.1 then
		unitName = self:Energy1()
	else
		unitName = self:BuildMex()
	end
	self:EchoDebug('Economy level 1 '..unitName)
	return unitName
end

function TaskEcoHST:EconomyUnderWater( taskQueueBehaviour, ai, builder )
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

function TaskEcoHST:AdvEconomy( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if self.ai.Energy.full > 0.9 and self.ai.Energy.income > 3000 and self.ai.Metal.reserves > 1000 and self.ai.Energy.capacity < 40000 then
		unitName = self:buildEstore2( taskQueueBehaviour, ai, builder )
	elseif self.ai.Metal.full > 0.8 and self.ai.Metal.income > 100 and self.ai.Metal.capacity < 20000 and self.ai.Energy.full > 0.3 then
		unitName = self:buildMstore2( taskQueueBehaviour, ai, builder )
	elseif self.ai.Energy.income > self.ai.Energy.usage and self.ai.Energy.full > 0.7 and self.ai.Energy.income > 2000 and self.ai.Metal.full < 0.5 then
		unitName = self:buildMconv2( taskQueueBehaviour, ai, builder )
	elseif (self.ai.Energy.full < 0.3 or self.ai.Energy.income < self.ai.Energy.usage * 1.25) and self.ai.Metal.full > 0.1 and self.ai.Metal.income > 18 then
		unitName = self:BuildAdvEnergy( taskQueueBehaviour, ai, builder )
	else--if self.ai.Metal.full < 0.2 and self.ai.Energy.full > 0.1 then
		unitName = self:BuildMohoMex( taskQueueBehaviour, ai, builder )
	end
	self:EchoDebug('Economy level 3 '..unitName)
	return unitName
end

function TaskEcoHST:AdvEconomyUnderWater( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if self.ai.Energy.full>0.8 and self.ai.Energy.income > 2500 and self.ai.Metal.reserves > 800 and self.ai.Energy.capacity < 50000  then
		unitName = self:buildEstore2( taskQueueBehaviour, ai, builder )
	elseif self.ai.Metal.full>0.7 and self.ai.Metal.income>30 and self.ai.Metal.capacity < 20000 and self.ai.Energy.full > 0.4 then
		unitName = self:buildMstore2( taskQueueBehaviour, ai, builder )
	elseif self.ai.Energy.income > self.ai.Energy.usage and self.ai.Energy.full > 0.9 and self.ai.Energy.income > 2000 and self.ai.Metal.full < 0.3 then
		unitName = self:buildMconv2UW( taskQueueBehaviour, ai, builder )
	elseif (self.ai.Energy.full<0.3 or self.ai.Energy.income < self.ai.Energy.usage * 1.5) and self.ai.Metal.full>0.1 then
		unitName = self:BuildUWFusion( taskQueueBehaviour, ai, builder )
	else
		unitName = self:BuildUWMohoMex( taskQueueBehaviour, ai, builder )
	end
	self:EchoDebug('Economy under water level 2 '..unitName)
	return unitName
end

function TaskEcoHST:EconomySeaplane( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if self.ai.Energy.full>0.7 and self.ai.Energy.income > 2000 and self.ai.Metal.income>self.ai.Metal.usage and self.ai.Energy.capacity < 60000  then
		unitName = self:buildEstore2( taskQueueBehaviour, ai, builder )
	elseif self.ai.Metal.full>0.9 and self.ai.Metal.income>30 and self.ai.Metal.capacity < 30000 and self.ai.Energy.full > 0.3 then
		unitName = self:buildMstore2( taskQueueBehaviour, ai, builder )
	elseif self.ai.Energy.full>0.8  then
		unitName = self:buildMconv2UW( taskQueueBehaviour, ai, builder )
	elseif self.ai.Energy.full>0.5 and self.ai.Metal.full>0.5 then
		unitName = self:Lvl2ShipAssist( taskQueueBehaviour, ai, builder )
	end
	self:EchoDebug('Economy Seaplane '..unitName)
	return unitName
end

function TaskEcoHST:EconomyBattleEngineer( taskQueueBehaviour, ai, builder )
        local unitName = self.ai.armyhst.DummyUnitName
	if self.ai.realEnergy > 1.25 and self.ai.realMetal > 1.1 then
		unitName =  self:NanoTurret()
	elseif self.ai.Energy.full < 0.1 and self.ai.Metal.full > 0.1 then
		unitName = self:Solar()
	elseif self.ai.Metal.full < 0.2 then
		unitName = self:BuildMex()
	else
		unitName = self.ai.taskshst:EngineerAsFactory( taskQueueBehaviour, ai, builder )
	end
	self:EchoDebug('Economy battle engineer  '..unitName)
	return unitName
end

function TaskEcoHST:EconomyNavalEngineer( taskQueueBehaviour, ai, builder )
        local unitName = self.ai.armyhst.DummyUnitName
	if self.ai.Energy.full < 0.2 and realMetal > 1 then
		unitName = self:TidalIfTidal( taskQueueBehaviour, ai, builder )
	elseif self.ai.Metal.full < 0.2 and self.ai.Energy.income > self.ai.Metal.usage then
		unitName = self:BuildUWMex( taskQueueBehaviour, ai, builder )
	else
		unitName = self:NavalEngineerAsFactory( taskQueueBehaviour, ai, builder )
	end
	self:EchoDebug('Economy Naval Engineer '..unitName)
	return unitName
end

function TaskEcoHST:EconomyFark( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if (self.ai.Energy.full < 0.3 or self.ai.realEnergy < 1.1)   then
		unitName = self:WindSolar( taskQueueBehaviour, ai, builder )
	elseif self.ai.Energy.full > 0.9 and self.ai.Metal.capacity < 4000 then
		unitName = self:buildEstore1( taskQueueBehaviour, ai, builder )
	else
		unitName = self:BuildMex( taskQueueBehaviour, ai, builder )
	end
	return unitName
end
