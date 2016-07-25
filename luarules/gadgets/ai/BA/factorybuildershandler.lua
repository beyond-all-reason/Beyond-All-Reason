FactoryBuildersHandler = class(Module)

function FactoryBuildersHandler:Name()
	return "FactoryBuildersHandler"
end

function FactoryBuildersHandler:internalName()
	return "factorybuildershandler"
end 

function FactoryBuildersHandler:Init()
	self.DebugEnabled = false

	self.lastCheckFrame = 0
	self.factories = {}
	self:EchoDebug('Initialize')
end

function FactoryBuildersHandler:UpdateFactories()
	self:EchoDebug("update factories")
	local factoriesPreCleaned = self:PrePositionFilter()
	self:AvailableFactories(factoriesPreCleaned)
end

function FactoryBuildersHandler:AvailableFactories(factoriesPreCleaned)
	for index, factoryName in pairs (ai.factoriesRanking) do
		local utype = game:GetTypeByName(factoryName)
		self.factories[factoryName] = {}
		for id, bldr in pairs(ai.conList) do
			local builder = bldr.unit:Internal() 
			if builder:CanBuild(utype) then
				--table.insert(self.factories[factoryName], id)
				self.factories[factoryName][id] = true
			end
		end
		local buildMe = false
		for i,v in pairs(self.factories[factoryName]) do
			buildMe = true
			break
		end
		if not buildMe then
			self.factories[factoryName] = nil
		end
	end
	if self.DebugEnabled then
		for i, v in pairs(self.factories) do
			self:EchoDebug(i  ..' is available Factories' )
		end
	end
end	

function FactoryBuildersHandler:PrePositionFilter()
	self:EchoDebug('pre positional filtering...')
	local factoriesPreCleaned = {}
	for index, factoryName in pairs(ai.factoriesRanking) do
		local buildMe = true
		local utn=unitTable[factoryName]
		local level = utn.techLevel
		local isAdvanced = advFactories[factoryName]
		local isExperimental = expFactories[factoryName] or leadsToExpFactories[factoryName]
		local mtype = factoryMobilities[factoryName][1]
		if ai.needAdvanced and not ai.haveAdvFactory and not isAdvanced then
			self:EchoDebug(factoryName ..' not advanced when i need it')
			buildMe = false 
		end
		if buildMe and ai.needExperimental and not ai.haveExpFactory and not isExperimental then
			self:EchoDebug(factoryName ..' not Experimental when i need it')
			buildMe = false 
		end
		if buildMe and (not ai.needExperimental or ai.haveExpFactory) and expFactories[factoryName] then
			self:EchoDebug('Experimental when i dont need it')
			buildMe = false 
		end
		if buildMe and mtype == 'air' and ai.factoryBuilded['air'][1] >= 1 and utn.needsWater then
			self:EchoDebug(factoryName .. ' dont build seaplane if i have normal planes')
			buildMe = false 
		end
		if not buildMe and mtype == 'air' and ai.haveAdvFactory and ai.factoryBuilded['air'][1] > 0 and ai.factoryBuilded['air'][1] < 3 and isAdvanced then
			self:EchoDebug(factoryName .. ' force build t2 air if you have t1 air and a t2 of another type')
			buildMe = true
		end
		if buildMe and self.ai.factoriesAtLevel[1] and mtype == 'air' and isAdvanced and not ai.haveAdvFactory then
			for index, factory in pairs(self.ai.factoriesAtLevel[1]) do
				if factoryMobilities[factory.unit:Internal():Name()][1] ~= 'air' then
					self:EchoDebug(factoryName .. ' dont build t2 air if we have another t1 type and dont have adv')
					buildMe = false
					break
				end
			end
		end
				
		if buildMe then table.insert(factoriesPreCleaned,factoryName) end
	end
	for i, v in pairs(factoriesPreCleaned) do
		self:EchoDebug('rank ' .. i .. ' factoryPreCleaned '.. v)
	end
	return factoriesPreCleaned
end
	
function FactoryBuildersHandler:ConditionsToBuildFactories()
	local factories = {}
	self:EchoDebug('measure conditions to build factories')
	if ai.factoryUnderConstruction then
		self:EchoDebug('other factory under construction')
		return false
	elseif not self.ai.buildsitehandler:CheckForDuplicates(factoryName) then
		self:EchoDebug('other factory planned')
		return false
	end
	self:EchoDebug('ai.army '..ai.army)
	local idx= 0
	for index , factoryName in pairs(ai.factoriesRanking) do
		if self.factories[factoryName] then
			idx=idx+1
			local uTn = unitTable[factoryName]
			self:EchoDebug('measure conditions to build ' .. factoryName .. ' factory')
			--if ai.scaledMetal > uTn.metalCost * idx and ai.scaledEnergy > uTn.energyCost * idx and ai.army >= ai.factories * 20 then
			if (ai.Metal.income > ((ai.factories ^ 2) * 10) +3 and ai.Energy.income > ((ai.factories ^ 2) * 100) +25 and ai.army >= ai.factories * 20) or (ai.Metal.income > ((ai.factories ^ 2) * 20) and ai.Energy.income > ((ai.factories ^ 2) * 200)) then
				self:EchoDebug(factoryName .. ' can be builded')
				factories[factoryName] = self.factories[factoryName]
			end
		end
	end
	
	local canDoFactory = false
	for factoryName, _ in pairs(factories)do
		canDoFactory = true
		self:EchoDebug('OK Conditions to build something'  )
		break
	end
	if canDoFactory then
		self:EchoDebug('4')
		return factories
	else
		
		self:EchoDebug('5')
		return false
	end
end

function FactoryBuildersHandler:GetBuilderFactory(builder)
	local builderID = builder:ID()
	local f = game:Frame()
	if f - self.lastCheckFrame < 1000 then
		return false
	end
	self.lastCheckFrame = f
	local factories = self:ConditionsToBuildFactories()
	if not factories then return false end
	for rank, factoryName in pairs(ai.factoriesRanking ) do
		if factories[factoryName] then
			if factories[factoryName][builderID] then
				self:EchoDebug(builder:Name())
				local p = self:FactoryPosition(factoryName,builder)
				if p then
					if self.ai.factorybuildershandler:PostPositionalFilter(factoryName,p) then
						return p, factoryName
					end
				end
			end
		end
	end
	return false
end

function FactoryBuildersHandler:FactoryPosition(factoryName,builder)
	local utype = game:GetTypeByName(factoryName)
	local mtype = factoryMobilities[factoryName][1]
	local builderPos = builder:GetPosition()
	local p
	if p == nil then
		self:EchoDebug("looking next to last nano turrets for " .. factoryName)
		p = ai.buildsitehandler:BuildNearNano(builder, utype)
	end
	if p == nil then
		self:EchoDebug("looking next to factory for " .. factoryName)
		local factoryPos = ai.buildsitehandler:ClosestHighestLevelFactory(builderPos, 10000)
		if factoryPos then
			p = ai.buildsitehandler:ClosestBuildSpot(builder, factoryPos, utype)
		end
	end
	if p == nil then
		self:EchoDebug('builfactory near hotSpot')
		local factoryPos = ai.buildsitehandler:ClosestHighestLevelFactory(builderPos, 10000)
		local place = false
		local distance = 99999
		if factoryPos then
			for index, hotSpot in pairs(ai.hotSpot) do
				if ai.maphandler:MobilityNetworkHere(mtype,hotSpot) then
					
					dist = math.min(distance, Distance(hotSpot,factoryPos))
					if dist < distance then 
						place = hotSpot
						distance  = dist
					end
				end
			end
		end
		if place then
			p = ai.buildsitehandler:ClosestBuildSpot(builder, place, utype)
		end
	end
	if p == nil then
		self:EchoDebug("looking for most turtled position for " .. factoryName)
		local turtlePosList = ai.turtlehandler:MostTurtled(builder, factoryName)
		if turtlePosList then
			if #turtlePosList ~= 0 then
				for i, turtlePos in ipairs(turtlePosList) do
					p = ai.buildsitehandler:ClosestBuildSpot(builder, turtlePos, utype)
					if p ~= nil then break end
				end
			end
		end
	end
	if p == nil then
		self:EchoDebug("trying near builder for " .. factoryName)
		p = ai.buildsitehandler:ClosestBuildSpot(builder, builderPos, utype)
	end
	if p then
		self:EchoDebug("position found for " .. factoryName)
	end
	return p
end

function FactoryBuildersHandler:PostPositionalFilter(factoryName,p)
	local buildMe = true
	
	local mtype = factoryMobilities[factoryName][1]
	local network = ai.maphandler:MobilityNetworkHere(mtype ,p)
	if ai.factoryBuilded[mtype] == nil or ai.factoryBuilded[mtype][network] == nil then
		self:EchoDebug('area to small for ' .. factoryName)
		return false
	end
	if unitTable[factoryName].techLevel <= ai.factoryBuilded[mtype][network] then
		self:EchoDebug('Not enough tech level for '..factoryName)
		buildMe = false
	end
	if mtype == 'bot' then
		local vehNetwork = ai.factoryBuilded['veh'][ai.maphandler:MobilityNetworkHere('veh',p)]
		if (vehNetwork and vehNetwork > 0) and (vehNetwork < 4 or ai.factoryBuilded['air'][1] < 1) then
			self:EchoDebug('dont build bot where are already veh not on top of tech level')
			buildMe = false
		end
	elseif mtype == 'veh' then
		local botNetwork = ai.factoryBuilded['bot'][ai.maphandler:MobilityNetworkHere('bot',p)]
		if (botNetwork and botNetwork > 0) and (botNetwork < 9 or ai.factoryBuilded['air'][1] < 1) then
			self:EchoDebug('dont build veh where are already bot not on top of tech level')
			buildMe = false
		end
	end
	return buildMe
end
