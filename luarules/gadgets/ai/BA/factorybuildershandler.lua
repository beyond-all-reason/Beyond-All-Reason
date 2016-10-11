FactoryBuildersHandler = class(Module)

function FactoryBuildersHandler:Name()
	return "FactoryBuildersHandler"
end

function FactoryBuildersHandler:internalName()
	return "factorybuildershandler"
end 

function FactoryBuildersHandler:Init()
	self.DebugEnabled = false

	self.lastCheckFrameForConName = {}
	self.lastFactoriesForConName = {}
	self.conTypesByName = {}
	self.finishedConIDs = {}
	self.factories = {}
	self:EchoDebug('Initialize')
end

function FactoryBuildersHandler:UnitBuilt(engineUnit)
	local uname = engineUnit:Name()
	local ut = unitTable[uname]
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

function FactoryBuildersHandler:UnitDead(engineUnit)
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

function FactoryBuildersHandler:UpdateFactories()
	self:EchoDebug("update factories")
	local factoriesPreCleaned = self:PrePositionFilter()
	self:AvailableFactories(factoriesPreCleaned)
end

function FactoryBuildersHandler:AvailableFactories(factoriesPreCleaned)
	self.factories = {}
	for order = 1, #factoriesPreCleaned do
		local factoryName = factoriesPreCleaned[order]
		local utype = game:GetTypeByName(factoryName)
		for name, typeAndCount in pairs(self.conTypesByName) do
			if typeAndCount.type:CanBuild(utype) then
				self.factories[#self.factories+1] = factoryName
				break
			end
		end
	end
	if self.DebugEnabled then
		for i, v in pairs(self.factories) do
			self:EchoDebug(i .. ' ' .. v  .. ' is available Factories' )
		end
	end
end	

function FactoryBuildersHandler:PrePositionFilter()
	self:EchoDebug('pre positional filtering...')
	local factoriesPreCleaned = {}
	for rank = 1, #ai.factoriesRanking do
		local factoryName = ai.factoriesRanking[rank]
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
		if buildMe and not ai.needAdvanced and not ai.haveAdvFactory and isAdvanced then
			self:EchoDebug(factoryName .. ' Advanced when i dont need it')
			buildMe = false
		end
		if buildMe and (not ai.needExperimental or ai.haveExpFactory) and expFactories[factoryName] then
			self:EchoDebug(factoryName .. ' Experimental when i dont need it')
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
	if self.DebugEnabled then
		for i, v in pairs(factoriesPreCleaned) do
			self:EchoDebug('rank ' .. i .. ' ' .. v .. ' in factoryPreCleaned')
		end
	end
	return factoriesPreCleaned
end
	
function FactoryBuildersHandler:ConditionsToBuildFactories(builder)
	local factories = {}
	self:EchoDebug('measure conditions to build factories')
	if ai.factoryUnderConstruction then
		self:EchoDebug('other factory under construction')
		return false
	end
	self:EchoDebug('ai.combatCount '..ai.combatCount)
	local canDoFactory = false
	for order = 1, #self.factories do
		local factoryName = self.factories[order]
		local uTn = unitTable[factoryName]
		--if ai.scaledMetal > uTn.metalCost * order and ai.scaledEnergy > uTn.energyCost * order and ai.combatCount >= ai.factories * 20 then
		local factoryCountSq = ai.factories * ai.factories
		local sameFactoryCount = ai.nameCountFinished[factoryName] or 0
		local sameFactoryMetal = sameFactoryCount * 20
		local sameFactoryEnergy = sameFactoryCount * 500
		if (
			ai.Metal.income > (factoryCountSq * 10) + 3 + sameFactoryMetal
			and ai.Energy.income > (factoryCountSq * 100) + 25 + sameFactoryEnergy
			and ai.combatCount >= ai.factories * 20
		) or (
			ai.Metal.income > (factoryCountSq * 20) + (sameFactoryMetal * 2)
			and ai.Energy.income > (factoryCountSq * 200) + (sameFactoryEnergy * 2)
		) then
			self:EchoDebug(factoryName .. ' conditions met')
			local canBuild = builder:CanBuild(game:GetTypeByName(factoryName))
			if canBuild then
				factories[#factories+1] = factoryName
				self:EchoDebug(#factories .. ' ' .. factoryName .. ' can be built by builder ' .. builder:Name())
				canDoFactory = true
			elseif not canDoFactory then
				self:EchoDebug('best factory with conditions met ' .. factoryName .. ' cant be built by builder ' .. builder:Name())
				return false
			end
		end
	end
	if canDoFactory then
		self:EchoDebug('OK Conditions to build something'  )
		self:EchoDebug('4')
		return factories
	else
		self:EchoDebug('5')
		return false
	end
end

function FactoryBuildersHandler:GetBuilderFactory(builder)
	local builderID = builder:ID()
	local builderName = builder:Name()
	local f = game:Frame()
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
		if not self.ai.buildsitehandler:CheckForDuplicates(factoryName) then -- need to check for duplicates right now, not 15 seconds ago
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

function FactoryBuildersHandler:FactoryPosition(factoryName,builder)
	local utype = game:GetTypeByName(factoryName)
	local mtype = factoryMobilities[factoryName][1]
	local builderPos = builder:GetPosition()
	local factoryPos
	local p
	if p == nil then
		self:EchoDebug("looking next to nano turrets for " .. factoryName)
		p = ai.buildsitehandler:BuildNearNano(builder, utype)
	end
	if p == nil then
		self:EchoDebug("looking next to factory for " .. factoryName)
		factoryPos = ai.buildsitehandler:ClosestHighestLevelFactory(builderPos, 10000)
		if factoryPos then
			p = ai.buildsitehandler:ClosestBuildSpot(builder, factoryPos, utype)
		end
	end
	if p == nil then
		self:EchoDebug('builfactory near hotSpot')
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
		p = ai.buildsitehandler:ClosestBuildSpot(builder, builderPos, utype, 10, nil, nil, 1500) -- check at most 1500 elmos away
	end
	if p then
		self:EchoDebug("position found for " .. factoryName)
	end
	return p
end

function FactoryBuildersHandler:PostPositionalFilter(factoryName,p)
	local mobNetOkay = false
	for i, mtype in pairs(factoryMobilities[factoryName]) do
		local network = ai.maphandler:MobilityNetworkHere(mtype, p)
		if ai.factoryBuilded[mtype] and ai.factoryBuilded[mtype][network] then
			mobNetOkay = true
			break
		end
	end
	if not mobNetOkay then
		self:EchoDebug('area to small or not enough spots for ' .. factoryName)
		return false
	end
	local mtype = factoryMobilities[factoryName][1]
	-- below is commented out because sometimes you need a lower level factory to build things the higher level cannot, when the previous low level factory has been destroyed
	-- if unitTable[factoryName].techLevel <= ai.factoryBuilded[mtype][network] then
	-- 	self:EchoDebug('tech level ' .. unitTable[factoryName].techLevel .. ' of ' .. factoryName .. ' is too low for mobility network ' .. ai.factoryBuilded[mtype][network])
	-- 	return false
	-- end
	if mtype == 'bot' then
		local vehNetwork = ai.factoryBuilded['veh'][ai.maphandler:MobilityNetworkHere('veh',p)]
		if (vehNetwork and vehNetwork > 0) and (vehNetwork < 4 or ai.factoryBuilded['air'][1] < 1) then
			self:EchoDebug('dont build bot where are already veh not on top of tech level')
			return false
		end
	elseif mtype == 'veh' then
		local botNetwork = ai.factoryBuilded['bot'][ai.maphandler:MobilityNetworkHere('bot',p)]
		if (botNetwork and botNetwork > 0) and (botNetwork < 9 or ai.factoryBuilded['air'][1] < 1) then
			self:EchoDebug('dont build veh where are already bot not on top of tech level')
			return false
		end
	end
	return true
end
