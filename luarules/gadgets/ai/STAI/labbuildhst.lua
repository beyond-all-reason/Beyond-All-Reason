LabBuildHST = class(Module)

function LabBuildHST:Name()
	return "LabBuildHST"
end

function LabBuildHST:internalName()
	return "labbuildhst"
end

function LabBuildHST:Init()
	self.DebugEnabled = false
	self.lastCheckFrameForConName = {}
	self.lastFactoriesForConName = {}
	self.conTypesByName = {}
	self.finishedConIDs = {}
	self.factories = {}
	self.ai.factoriesAtLevel = {}
	self:EchoDebug('Initialize')
end

function LabBuildHST:MyUnitBuilt(engineUnit)
	local uname = engineUnit:Name()
	local ut = self.ai.armyhst.unitTable[uname]
	if ut.isBuilding or not ut.buildOptions then
		-- it's not a construction unit
		return
	end
	self.finishedConIDs[engineUnit:ID()] = true
	if not self.conTypesByName[uname] then
		self:EchoDebug("new con type: " .. uname)
		doUpdate = true
		self.conTypesByName[uname] = { type = engineUnit:Type(), count = 1 }
		self:UpdateFactories()
	else
		self.conTypesByName[uname].count = self.conTypesByName[uname].count + 1
		self:EchoDebug("con type count: " .. uname .. " " .. self.conTypesByName[uname].count)
	end
end

function LabBuildHST:Update()
-- 	local f = self.game:Frame()
-- 	if f % 401 ~= 0 then
-- 		return
-- 	end
	if self.ai.schedulerhst.moduleTeam ~= self.ai.id or self.ai.schedulerhst.moduleUpdate ~= self:Name() then return end

	self:UpdateFactories()
end

function LabBuildHST:UnitDead(engineUnit)
	local uname = engineUnit:Name()
	if not self.finishedConIDs[engineUnit:ID()] or not self.conTypesByName[uname] then
		return
	end
	self.finishedConIDs[engineUnit:ID()] = nil
	self.conTypesByName[uname].count = self.conTypesByName[uname].count - 1
	self:EchoDebug("con type count: " .. uname .. " " .. self.conTypesByName[uname].count)
	if self.conTypesByName[uname].count == 0 then
		self:EchoDebug("none of con type: " .. uname)
		self.conTypesByName[uname] = nil
		self:UpdateFactories()
	end
end

function LabBuildHST:UpdateFactories()
	self:EchoDebug("update factories")
	local factoriesPreCleaned = self:PrePositionFilter()
	self:AvailableFactories(factoriesPreCleaned)
end

function LabBuildHST:AvailableFactories(factoriesPreCleaned)
	self.factories = {}
	for order = 1, #factoriesPreCleaned do
		local factoryName = factoriesPreCleaned[order]
		local utype = self.game:GetTypeByName(factoryName)
		for name, typeAndCount in pairs(self.conTypesByName) do
			if typeAndCount.type:CanBuild(utype) then
				self.factories[#self.factories+1] = factoryName
				break
			end
		end
	end
	for i, v in pairs(self.factories) do
		self:EchoDebug(i .. ' ' .. v  .. ' is available Factories' )
	end
end

function LabBuildHST:PrePositionFilter()
	self:EchoDebug('pre positional filtering...')
	local factoriesPreCleaned = {}
	for rank = 1, #self.ai.factoriesRanking do
		local factoryName = self.ai.factoriesRanking[rank]
		local buildMe = true
		local utn=self.ai.armyhst.unitTable[factoryName]
		local level = utn.techLevel
		local isAdvanced = self.ai.armyhst.advFactories[factoryName]
		local isExperimental = self.ai.armyhst.expFactories[factoryName] or self.ai.armyhst.leadsToExpFactories[factoryName]
		local mtype = self.ai.armyhst.factoryMobilities[factoryName][1]
		local team = self.ai.id
		self:EchoDebug(factoryName,isAdvanced,isExperimental)

		if self.game:GetTeamUnitDefCount(self.ai.id,utn.defId) > 0 then
			self:EchoDebug(factoryName ..' already have ')
			buildMe = false
		end
 		if buildMe and mtype == 'air' and not isAdvanced and self.ai.tool:countMyUnit({'factoryMobilities'}) == 1 then
 			self:EchoDebug(factoryName ..' dont build air before advanced ')
 			buildMe = false
 		end
-- 		if mtype == 'air' then
-- 			local counter = self.game:GetTeamUnitDefCount(self.ai.id,utn.defId)
-- 			if counter > 0 then
-- 				self:EchoDebug(factoryName ..' never build more than 1 air factory per name, units can go anywhare ')
-- 				buildMe = false
-- 			end
-- 		end
		if self.ai.overviewhst.needT2 and not self.ai.overviewhst.T2LAB and not isAdvanced then
			self:EchoDebug(factoryName ..' not advanced when i need it')
			buildMe = false
		end
		if buildMe and self.ai.overviewhst.needT3 and not self.ai.overviewhst.T3LAB and not isExperimental then
			self:EchoDebug(factoryName ..' not Experimental when i need it')
			buildMe = false
		end
		if buildMe and not self.ai.overviewhst.needT2 and not self.ai.overviewhst.T2LAB and isAdvanced then
			self:EchoDebug(factoryName .. ' Advanced when i dont need it')
			buildMe = false
		end
		if buildMe and (not self.ai.overviewhst.needT3 or self.ai.overviewhst.T3LAB) and self.ai.armyhst.expFactories[factoryName] then
			self:EchoDebug(factoryName .. ' Experimental when i dont need it')
			buildMe = false
		end
		if buildMe and mtype == 'air' and self.ai.factoryBuilded['air'][1] >= 1 and utn.needsWater then
			self:EchoDebug(factoryName .. ' dont build seaplane if i have normal planes')
			buildMe = false
		end
		if not buildMe and mtype == 'air' and self.ai.overviewhst.T2LAB and self.ai.factoryBuilded['air'][1] > 0 and self.ai.factoryBuilded['air'][1] < 3 and isAdvanced then
			self:EchoDebug(factoryName .. ' force build t2 air if you have t1 air and a t2 of another type')
			buildMe = true
		end
		if buildMe and self.ai.factoriesAtLevel[1] and mtype == 'air' and isAdvanced and not self.ai.overviewhst.T2LAB then
			for index, factory in pairs(self.ai.factoriesAtLevel[1]) do
				if self.ai.armyhst.factoryMobilities[factory.unit:Internal():Name()][1] ~= 'air' then
					self:EchoDebug(factoryName .. ' dont build t2 air if we have another t1 type and dont have adv')
					buildMe = false
					break
				end
			end
		end
		if buildMe then table.insert(factoriesPreCleaned,factoryName) end
	end
	for i, v in pairs(factoriesPreCleaned) do
		self:EchoDebug('rank ' .. i .. ' ' .. v .. ' in factoryPreCleaned')
	end
	return factoriesPreCleaned
end

function LabBuildHST:ConditionsToBuildFactories(builder)
	local factories = {}
	local factoriesCount = 0
	self:EchoDebug('measure conditions to build factories')
	if self.ai.factoryUnderConstruction then
		self:EchoDebug('other factory under construction')
		return false
	end
	self:EchoDebug('self.ai.tool:countMyUnit({isWeapon}) '..self.ai.tool:countMyUnit({'isWeapon'}))
	local canDoFactory = false
	for order = 1, #self.factories do
		local factoryName = self.factories[order]
		self.factoryCount = self.ai.tool:countMyUnit({'factoryMobilities'})
		local uTn = self.ai.armyhst.unitTable[factoryName]
		local factoryCountSq = self.ai.tool:countMyUnit({'factoryMobilities'}) * self.ai.tool:countMyUnit({'factoryMobilities'})
		local sameFactoryCount = self.ai.tool:countFinished(factoryName)
		local sameFactoryMetal = sameFactoryCount * 20
		local sameFactoryEnergy = sameFactoryCount * 500
		self:EchoDebug('labparams',factoryCountSq,sameFactoryCount,sameFactoryMetal,sameFactoryEnergy)
		if self.ai.Energy.income > self.factoryCount * 800 then
		--[[
		if
			(self.ai.Metal.income > (factoryCountSq * 10) + 3 + sameFactoryMetal
				and self.ai.Energy.income > (factoryCountSq * 100) + 25 + sameFactoryEnergy
				and self.ai.tool:countMyUnit({'isWeapon'}) >= self.ai.tool:countMyUnit({'factoryMobilities'}) * 15)
			or (
				self.ai.Metal.income > (factoryCountSq * 20) + (sameFactoryMetal * 2)
				and self.ai.Energy.income > (factoryCountSq * 200) + (sameFactoryEnergy * 2)
			or  (uTn.metalCost * 1.2 < self.ai.Metal.reserves
					and  uTn.energyCost  < self.ai.Energy.reserves
					and self.ai.tool:countMyUnit({'isWeapon'}) >= 50
					and self.ai.tool:countMyUnit({'factoryMobilities'}) >= 1))then]]
			self:EchoDebug(factoryName .. ' conditions met')
			local canBuild = builder:CanBuild(self.game:GetTypeByName(factoryName))
			if canBuild then
				factoriesCount = factoriesCount + 1
				factories[factoriesCount] = factoryName
				self:EchoDebug(factoriesCount .. ' ' .. factoryName .. ' can be built by builder ' .. builder:Name())
				canDoFactory = true
			elseif not canDoFactory then
				self:EchoDebug('best factory with conditions met ' .. factoryName .. ' cant be built by builder ' .. builder:Name())
				return false
			end
		end
	end
	if canDoFactory then
		self:EchoDebug('OK Conditions to build factories'  )
		return factories
	else
		self:EchoDebug('not enough conditions to build factories')
		return false
	end
end

function LabBuildHST:GetBuilderFactory(builder)
	local builderID = builder:ID()
	local builderName = builder:Name()
	local f = self.game:Frame()
	if self.lastCheckFrameForConName[builderName] and f - self.lastCheckFrameForConName[builderName] < 450 then
		-- update every 15 seconds
		-- between updates return the last factories we got for this builder
		return self.lastFactoriesForConName[builderName]
	end
	local factories = self:ConditionsToBuildFactories(builder)
	self.lastCheckFrameForConName[builderName] = f
	self.lastFactoriesForConName[builderName] = factories
	if not factories then return false end
	for order = 1, #factories do
		local factoryName = factories[order]
		if not self.ai.buildsitehst:CheckForDuplicates(factoryName) then -- need to check for duplicates right now, not 15 seconds ago
			self:EchoDebug(factoryName .. ' not duplicated')
			self:EchoDebug(builder:Name())
			local p = self:FactoryPosition(factoryName,builder)
			if p then
				if self:PostPositionalFilter(factoryName,p) then
					self:EchoDebug(factoryName .. ' position passed filter')
					return p, factoryName
				end
			end
		end
	end
	return false
end

function LabBuildHST:FactoryPosition(factoryName,builder)
	local utype = self.game:GetTypeByName(factoryName)
	local site = self.ai.buildsitehst
	local p
	p = 	site:BuildNearNano(builder, utype) or
			site:searchPosNearCategories(utype, builder,50,nil,{'_nano_'}) or
			site:searchPosNearCategories(utype, builder,50,1000,{'factoryMobilities'}) or
			site:searchPosNearCategories(utype, builder,50,nil,{'_mex_'}) or
			site:searchPosNearCategories(utype, builder,50,nil,{'_llt_'})
	return p
end

function LabBuildHST:PostPositionalFilter(factoryName,p)
	local mobNetOkay = false
	for i, mtype in pairs(self.ai.armyhst.factoryMobilities[factoryName]) do
		local network = self.ai.maphst:MobilityNetworkHere(mtype, p)
		if self.ai.factoryBuilded[mtype] and self.ai.factoryBuilded[mtype][network] then
			self:EchoDebug('mobNetOk')
			mobNetOkay = true
			break
		end
	end
	if not mobNetOkay then
		self:EchoDebug('area to small or not enough spots for ' .. factoryName)
		return false
	end
	local mtype = self.ai.armyhst.factoryMobilities[factoryName][1]
	if mtype ~= 'air' and self.ai.factoryBuilded['air'][1] < 1 and self.ai.overviewhst.T2LAB then
		self:EchoDebug('dont build this if we dont have air')
		return false
	elseif mtype == 'bot' then
		if self.ai.tool:countFinished(factoryName) > 0 and self.ai.armyhst.unitTable[factoryName].techLevel == 1 then
			local sameLabs = self.ai.game.GetTeamUnitsByDefs(self.ai.id, UnitDefNames[factoryName].id)
			for ct, id in pairs(sameLabs) do
				local sameLab = self.game:GetUnitByID(id)
				local sameLabPos = sameLab:GetPosition()
				if self.ai.maphst:MobilityNetworkHere('bot',p) == self.ai.maphst:MobilityNetworkHere('bot',sameLabPos) then
					self:EchoDebug('not duplicate t1 lab')
					return false
				end
			end
		end
		local vehNetwork = self.ai.factoryBuilded['veh'][self.ai.maphst:MobilityNetworkHere('veh',p)]
		if (vehNetwork and vehNetwork > 0) and (vehNetwork < 4 ) then
			self:EchoDebug('dont build bot where are already veh not on top of tech level')
			return false
		end
	elseif mtype == 'veh' then
		if self.ai.tool:countFinished(factoryName) > 0 and self.ai.armyhst.unitTable[factoryName].techLevel == 1 then
			local sameLabs = Spring.GetTeamUnitsByDefs(self.ai.id, UnitDefNames[factoryName].id)
			for ct, id in pairs(sameLabs) do
				local sameLab = self.game:GetUnitByID(id)
				local sameLabPos = sameLab:GetPosition()
				if self.ai.maphst:MobilityNetworkHere('veh',p) == self.ai.maphst:MobilityNetworkHere('veh',sameLabPos) then
					self:EchoDebug('not duplicate t1 lab')
					return false
				end
			end
		end
		local botNetwork = self.ai.factoryBuilded['bot'][self.ai.maphst:MobilityNetworkHere('bot',p)]
		if (botNetwork and botNetwork > 0) and (botNetwork < 9 ) then
			self:EchoDebug('dont build veh where are already bot not on top of tech level')
			return false
		end

	end
	return true
end
