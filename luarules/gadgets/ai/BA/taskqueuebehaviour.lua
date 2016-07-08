
local DebugEnabled = false


local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("TaskQueueBehaviour: " .. inStr)
	end
end

local CMD_GUARD = 25

local extraEnergy, extraMetal, energyTooLow, energyOkay, metalTooLow, metalOkay, metalBelowHalf, metalAboveHalf, notEnoughCombats, farTooFewCombats

local function GetEcon()
	extraEnergy = ai.Energy.income - ai.Energy.usage
	extraMetal = ai.Metal.income - ai.Metal.usage
	local enoughMetalReserves = math.min(ai.Metal.income, ai.Metal.capacity * 0.1)
	local lotsMetalReserves = math.min(ai.Metal.income * 10, ai.Metal.capacity * 0.5)
	local enoughEnergyReserves = math.min(ai.Energy.income * 2, ai.Energy.capacity * 0.25)
	-- local lotsEnergyReserves = math.min(ai.Energy.income * 3, ai.Energy.capacity * 0.5)
	energyTooLow = ai.Energy.reserves < enoughEnergyReserves or ai.Energy.income < 40
	energyOkay = ai.Energy.reserves >= enoughEnergyReserves and ai.Energy.income >= 40
	metalTooLow = ai.Metal.reserves < enoughMetalReserves
	metalOkay = ai.Metal.reserves >= enoughMetalReserves
	metalBelowHalf = ai.Metal.reserves < lotsMetalReserves
	metalAboveHalf = ai.Metal.reserves >= lotsMetalReserves
	local attackCounter = ai.attackhandler:GetCounter()
	notEnoughCombats = ai.combatCount < attackCounter * 0.6
	farTooFewCombats = ai.combatCount < attackCounter * 0.2
end

TaskQueueBehaviour = class(Behaviour)

function TaskQueueBehaviour:CategoryEconFilter(value)
	if value == nil then return DummyUnitName end
	if value == DummyUnitName then return DummyUnitName end
	EchoDebug(value .. " (before econ filter)")
	-- EchoDebug("ai.Energy: " .. ai.Energy.reserves .. " " .. ai.Energy.capacity .. " " .. ai.Energy.income .. " " .. ai.Energy.usage)
	-- EchoDebug("ai.Metal: " .. ai.Metal.reserves .. " " .. ai.Metal.capacity .. " " .. ai.Metal.income .. " " .. ai.Metal.usage)
	if Eco1[value] or Eco2[value] then
		return value
	end
	if reclaimerList[value] then
		-- dedicated reclaimer
		EchoDebug(" dedicated reclaimer")
		if metalAboveHalf or energyTooLow or farTooFewCombats then
			value = DummyUnitName
		end
	elseif unitTable[value].isBuilding then
		-- buildings
		EchoDebug(" building")
		if unitTable[value].buildOptions ~= nil then
			-- factory
			EchoDebug("  factory")
			EchoDebug(ai.factories)
			if ai.factories - ai.outmodedFactories <= 0 and metalOkay and energyOkay and ai.Metal.income > 3 and ai.Metal.reserves > unitTable[value].metalCost * 0.7 then
				EchoDebug("   first factory")
				-- build the first factory
			elseif advFactories[value] and ai.needAdvanced and not ai.haveAdvFactory and (ai.couldAttack >= 1 or ai.couldBomb >= 1) then
				EchoDebug('build advanced')
			else
				if ai.Metal.reserves > unitTable[value].metalCost * 0.5 and ai.Energy.reserves > unitTable[value].energyCost *0.3 then
					EchoDebug('build others factories')
				end
			end
					
			
		elseif unitTable[value].isWeapon then
			-- defense
			EchoDebug("  defense")
			if bigPlasmaList[value] or nukeList[value] then
				-- long-range plasma and nukes aren't really defense
				if metalTooLow or energyTooLow or ai.Metal.income < 35 or ai.factories == 0 or notEnoughCombats then
					value = DummyUnitName
				end
			elseif littlePlasmaList[value] then
				-- plasma turrets need units to back them up
				if metalTooLow or energyTooLow or ai.Metal.income < 10 or ai.factories == 0 or notEnoughCombats then
					value = DummyUnitName
				end
			else
				if metalTooLow or ai.Metal.income < (unitTable[value].metalCost / 35) + 2 or energyTooLow or ai.factories == 0 then
					value = DummyUnitName
				end
			end
		elseif unitTable[value].radarRadius > 0 then
			-- radar
			EchoDebug("  radar")
			if metalTooLow or energyTooLow or ai.factories == 0 or ai.Energy.full < 0.5 then
				value = DummyUnitName
			end
		else
			-- other building
			EchoDebug("  other building")
			if notEnoughCombats or metalTooLow or energyTooLow or ai.Energy.income < 200 or ai.Metal.income < 8 or ai.factories == 0 then
				value = DummyUnitName
			end
		end
	else
		-- moving units
		EchoDebug(" moving unit")
		if unitTable[value].buildOptions ~= nil then
			-- construction unit
			EchoDebug("  construction unit")
			if ai.Energy.full > 0.1 and ai.Metal.full > 0.1 then
				return value 
			end
		elseif unitTable[value].isWeapon then
			-- combat unit
			EchoDebug("  combat unit")
			if ai.Energy.full > 0.2 and ai.Metal.full > 0.2 then
				return value 
			end
		elseif value == "armpeep" or value == "corfink" then
			-- scout planes have no weapons
			if ai.Energy.full > 0.3 and ai.Metal.full > 0.3 then
				return value 
			end
		else
			-- other unit
			EchoDebug("  other unit")
			if notEnoughCombats or ai.Energy.full < 0.3 or ai.Metal.full < 0.3 then
				value = DummyUnitName
			end
		end
	end
	return value
end
function TaskQueueBehaviour:Init()
	if not taskqueues then
		shard_include "taskqueues"
	end
	if ai.outmodedFactories == nil then ai.outmodedFactories = 0 end

	GetEcon()
	self.active = false
	self.currentProject = nil
	self.lastWatchdogCheck = game:Frame()
	self.watchdogTimeout = 1800
	local u = self.unit:Internal()
	local mtype, network = ai.maphandler:MobilityOfUnit(u)
	self.mtype = mtype
	self.name = u:Name()
	self.side = unitTable[self.name].side
	if commanderList[self.name] then self.isCommander = true end
	self.id = u:ID()
	EchoDebug(self.name .. " " .. self.id .. " initializing...")

	-- register if factory is going to use outmoded queue
	if factoryMobilities[self.name] ~= nil then
		self.isFactory = true
		local upos = u:GetPosition()
		self.position = upos
		local outmoded = true
		for i, mtype in pairs(factoryMobilities[self.name]) do
			if not ai.maphandler:OutmodedFactoryHere(mtype, upos) then
				-- just one non-outmoded mtype will cause the factory to act normally
				outmoded = false
			end
			if mtype == "air" then self.isAirFactory = true end
		end
		if outmoded then
			EchoDebug("outmoded " .. self.name)
			self.outmodedFactory = true
			ai.outmodedFactoryID[self.id] = true
			ai.outmodedFactories = ai.outmodedFactories + 1
			ai.outmodedFactories = 1
		end
	end

	-- reset attack count
	if self.isFactory and not self.outmodedFactory then
		if self.isAirFactory then
			ai.couldBomb = 0
			ai.hasBombed = 0
		else
			ai.couldAttack = 0
			ai.hasAttacked = 0
		end
	end

	if self:HasQueues() then
		self.queue = self:GetQueue()
	end
end

function TaskQueueBehaviour:HasQueues()
	return (taskqueues[self.name] ~= nil)
end

function TaskQueueBehaviour:OwnerBuilt()
	if self:IsActive() then self.progress = true end
end

function TaskQueueBehaviour:OwnerIdle()
	if not self:IsActive() then
		return
	end
	if self.unit == nil then return end
	self.progress = true
	self.currentProject = nil
	ai.buildsitehandler:ClearMyPlans(self)
	self.unit:ElectBehaviour()
end

function TaskQueueBehaviour:OwnerMoveFailed()
	-- sometimes builders get stuck
	self:OwnerIdle()
end

function TaskQueueBehaviour:OwnerDead()
	if self.unit ~= nil then
		-- game:SendToConsole("taskqueue-er " .. self.name .. " died")
		if self.outmodedFactory then ai.outmodedFactories = ai.outmodedFactories - 1 end
		-- self.unit = nil
		if self.target then ai.targethandler:AddBadPosition(self.target, self.mtype) end
		ai.assisthandler:Release(nil, self.id, true)
		ai.buildsitehandler:ClearMyPlans(self)
		ai.buildsitehandler:ClearMyConstruction(self)
	end
end

function TaskQueueBehaviour:GetHelp(value, position)
	if value == nil then return DummyUnitName end
	if value == DummyUnitName then return DummyUnitName end
	EchoDebug(value .. " before getting help")
	local builder = self.unit:Internal()
	if Eco1[value] then
		return value
	end
	if Eco2[value] then
		local hashelp = ai.assisthandler:PersistantSummon(builder, position, math.ceil(unitTable[value].buildTime/10000), 0)
		return value
	end
	
	if unitTable[value].isBuilding and unitTable[value].buildOptions then
		if ai.factories - ai.outmodedFactories <= 0 or advFactories[value] then
			EchoDebug("can get help to build factory but don't need it")
			ai.assisthandler:Summon(builder, position)
			ai.assisthandler:Magnetize(builder, position)
			return value
		else
			EchoDebug("help for factory that need help")
			local hashelp = ai.assisthandler:Summon(builder, position, unitTable[value].techLevel)
			if hashelp then
				ai.assisthandler:Magnetize(builder, position)
				return value
			end
		end
	else
		local number
		if self.isFactory and not unitTable[value].needsWater then
			-- factories have more nano output
			number = math.floor((unitTable[value].metalCost + 1000) / 1500)
		elseif self.isFactory and unitTable[value].needsWater then
			number = math.floor((unitTable[value].metalCost + 1000) / 500)
		else
			number = math.floor((unitTable[value].metalCost + 750) / 1000)
		end
		if number == 0 then return value end
		local hashelp = ai.assisthandler:Summon(builder, position, number)
		if hashelp or self.isFactory then return value end
	end
	return DummyUnitName
end

function TaskQueueBehaviour:LocationFilter(utype, value)
	if self.isFactory then return utype, value end -- factories don't need to look for build locations
	local p
	local builder = self.unit:Internal()
	if unitTable[value].extractsMetal > 0 then
		-- metal extractor
		local uw
		p, uw, reclaimEnemyMex = ai.maphandler:ClosestFreeSpot(utype, builder)
		if p ~= nil then
			if reclaimEnemyMex then
				value = {"ReclaimEnemyMex", reclaimEnemyMex}
			else
				EchoDebug("extractor spot: " .. p.x .. ", " .. p.z)
				if uw then
					EchoDebug("underwater extractor " .. uw:Name())
					utype = uw
					value = uw:Name()
				end
			end
		else
			utype = nil
		end
	elseif geothermalPlant[value] then
		-- geothermal
		p = self.ai.maphandler:ClosestFreeGeo(utype, builder)
		if p then
			EchoDebug("geo spot", p.x, p.y, p.z)
			if value == "cmgeo" or value == "amgeo" then
				-- don't build moho geos next to factories
				if ai.buildsitehandler:ClosestHighestLevelFactory(p, 500) ~= nil then
					if value == "cmgeo" then
						if ai.targethandler:IsBombardPosition(p, "corbhmth") then
							-- instead build geothermal plasma battery if it's a good spot for it
							value = "corbhmth"
							utype = game:GetTypeByName(value)
						end
					else
						-- instead build a safe geothermal
						value = "armgmm"
						utype = game:GetTypeByName(value)
					end
				end
			end
		else
			utype = nil
		end
	elseif nanoTurretList[value] then
		-- build nano turrets next to a factory near you
		EchoDebug("looking for factory for nano")
		local factoryPos = ai.buildsitehandler:ClosestHighestLevelFactory(builder:GetPosition(), 5000)
		if factoryPos then
			EchoDebug("found factory")
			p = ai.buildsitehandler:ClosestBuildSpot(builder, factoryPos, utype)
			if p == nil then
				EchoDebug("no spot near factory found")
				utype = nil
			end
		else
			EchoDebug("no factory found")
			utype = nil
		end
	elseif (unitTable[value].isWeapon and unitTable[value].isBuilding and not nukeList[value] and not bigPlasmaList[value] and not littlePlasmaList[value]) then
		EchoDebug("looking for least turtled positions")
		local turtlePosList = ai.turtlehandler:LeastTurtled(builder, value)
		if turtlePosList then
			if #turtlePosList ~= 0 then
				EchoDebug("found turtle positions")
				for i, turtlePos in ipairs(turtlePosList) do
					p = ai.buildsitehandler:ClosestBuildSpot(builder, turtlePos, utype)
					if p ~= nil then break end
				end
			end
		end
		if p and Distance(p, builder:GetPosition()) > 300 then
			-- HERE BECAUSE DEFENSE PLACEMENT SYSTEM SUCKS
			-- this prevents cons from wasting time building defenses very far away
			utype = nil
			-- p = ai.buildsitehandler:ClosestBuildSpot(builder, builder:GetPosition(), utype)
		end
		-- if p then
		-- 	for id,position in pairs(ai.groundDefense) do
		-- 		if Distance(p, position) < unitTable[self.name].groundRange then
		-- 			utype = nil 
		-- 			break
		-- 		end
		-- 	end
		-- end
		
		if p == nil then
			EchoDebug("did NOT find build spot near turtle position")
			utype = nil
		end

		
	elseif nukeList[value] or bigPlasmaList[value] or littlePlasmaList[value] then
		-- bombarders
		EchoDebug("seeking bombard build spot")
		local turtlePosList = ai.turtlehandler:MostTurtled(builder, value, value)
		if turtlePosList then
			EchoDebug("got sorted turtle list")
			if #turtlePosList ~= 0 then
				EchoDebug("turtle list has turtles")
				for i, turtlePos in ipairs(turtlePosList) do
					p = ai.buildsitehandler:ClosestBuildSpot(builder, turtlePos, utype)
					if p ~= nil then break end
				end
			end
		end
		if p == nil then
			utype = nil
			EchoDebug("could not find bombard build spot")
		else
			EchoDebug("found bombard build spot")
		end
	elseif shieldList[value] or antinukeList[value] or unitTable[value].jammerRadius ~= 0 or unitTable[value].radarRadius ~= 0 or unitTable[value].sonarRadius ~= 0 or (unitTable[value].isWeapon and unitTable[value].isBuilding and not nukeList[value] and not bigPlasmaList[value] and not littlePlasmaList[value]) then
		-- shields, defense, antinukes, jammer towers, radar, and sonar
		EchoDebug("looking for least turtled positions")
		local turtlePosList = ai.turtlehandler:LeastTurtled(builder, value)
		if turtlePosList then
			if #turtlePosList ~= 0 then
				EchoDebug("found turtle positions")
				for i, turtlePos in ipairs(turtlePosList) do
					p = ai.buildsitehandler:ClosestBuildSpot(builder, turtlePos, utype)
					if p ~= nil then break end
				end
			end
		end
		if p and Distance(p, builder:GetPosition()) > 300 then
			-- HERE BECAUSE DEFENSE PLACEMENT SYSTEM SUCKS
			-- this prevents cons from wasting time building defenses very far away
			utype = nil
			-- p = ai.buildsitehandler:ClosestBuildSpot(builder, builder:GetPosition(), utype)
		end
		if p == nil then
			EchoDebug("did NOT find build spot near turtle position")
			utype = nil
		end
	elseif unitTable[value].isBuilding then
		-- buildings in defended positions
		local turtlePosList = ai.turtlehandler:MostTurtled(builder, value)
		if turtlePosList then
			if #turtlePosList ~= 0 then
				for i, turtlePos in ipairs(turtlePosList) do
					p = ai.buildsitehandler:ClosestBuildSpot(builder, turtlePos, utype)
					if p ~= nil then break end
				end
			end
		end
		if p and Distance(p, builder:GetPosition()) > 300 then
			-- HERE BECAUSE DEFENSE PLACEMENT SYSTEM SUCKS
			-- this prevents cons from wasting time building very far away
			p = ai.buildsitehandler:ClosestBuildSpot(builder, builder:GetPosition(), utype)
		end
	end
	-- last ditch placement
	if utype ~= nil and p == nil then
		local builderPos = builder:GetPosition()
		p = ai.buildsitehandler:ClosestBuildSpot(builder, builderPos, utype)
		if p == nil then
			p = map:FindClosestBuildSite(utype, builderPos, 500, 15)
		end
	end
	return utype, value, p
end

function TaskQueueBehaviour:BestFactoryPrePositionFilter(factoryName)
	local buildMe = true
	local utn=unitTable[factoryName]
	local level = utn.techLevel
	local isAdvanced = advFactories[factoryName]
	local isExperimental = expFactories[factoryName] or leadsToExpFactories[factoryName]
	local mtype = factoryMobilities[factoryName][1]

	if ai.needAdvanced and not ai.haveAdvFactory then
		if not isAdvanced then
			EchoDebug('not advanced when i need it')
			buildMe = false 
		end
	end
	if ai.needExperimental and not ai.haveExpFactory then
		if not isExperimental then
			EchoDebug('not Experimental when i need it')
			buildMe = false 
		end
	end
	if not ai.needExperimental then
		if expFactories[factoryName] then 
			EchoDebug('Experimental when i dont need it')
			buildMe = false 
		end
	end
	if isExperimental and ai.Energy.income > 5000 and ai.Metal.income > 100 and ai.Metal.reserves > utn.metalCost / 2 and ai.factoryBuilded['air'][1] > 2 and ai.combatCount > 40 then
		EchoDebug('i dont need it but economic situation permitted')
		buildMe = true
	end
	if mtype == 'air' and ai.factoryBuilded['air'][1] >= 1 then
		if utn.needsWater then 
			EchoDebug('dont build seaplane if i have normal planes')
			buildMe = false 
		end
	elseif mtype ~= 'air' and ai.haveAdvFactory and 
			ai.factoryBuilded['air'][1] > 0 and ai.factoryBuilded['air'][1] < 3 then
		EchoDebug('force build t2 air if you have t1 air and a t2 of another type')
		buildMe = false
	end
	return buildMe
end

function TaskQueueBehaviour:BestFactoryPosition(factoryName,utype,builder,builderPos,mtype)
	local p
	if p == nil then
		EchoDebug("looking next to factory for " .. factoryName)
		local factoryPos = ai.buildsitehandler:ClosestHighestLevelFactory(builderPos, 10000)
		if factoryPos then
			p = ai.buildsitehandler:ClosestBuildSpot(builder, factoryPos, utype)
		end
	end
	if p == nil then
		EchoDebug('builfactory near hotSpot')
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
		EchoDebug("looking for most turtled position for " .. factoryName)
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
		EchoDebug("trying near builder for " .. factoryName)
		p = ai.buildsitehandler:ClosestBuildSpot(builder, builderPos, utype)
	end
	return p
end

function TaskQueueBehaviour:BestFactoryPostPositionFilter(factoryName,p , mtype, network)
	local buildMe = true
	if ai.factoryBuilded[mtype] == nil or ai.factoryBuilded[mtype][network] == nil then
		EchoDebug('area to small for ' .. factoryName)
		return false
	end
	if unitTable[factoryName].techLevel <= ai.factoryBuilded[mtype][network] then
		EchoDebug('Not enough tech level for '..factoryName)
		buildMe = false
	end
	if mtype == 'bot' then
		local vehNetwork = ai.factoryBuilded['veh'][ai.maphandler:MobilityNetworkHere('veh',p)]
		if (vehNetwork and vehNetwork > 0) and (vehNetwork < 4 or ai.factoryBuilded['air'][1] < 1) then
			EchoDebug('dont build bot where are already veh not on top of tech level')
			buildMe = false
		end
	elseif mtype == 'veh' then
		local botNetwork = ai.factoryBuilded['bot'][ai.maphandler:MobilityNetworkHere('bot',p)]
		if (botNetwork and botNetwork > 0) and (botNetwork < 9 or ai.factoryBuilded['air'][1] < 1) then
			EchoDebug('dont build veh where are already bot not on top of tech level')
			buildMe = false
		end
	end
	return buildMe
end

function TaskQueueBehaviour:BestFactory()
	if ai.factoryUnderConstruction then return end
	EchoDebug('no factory under construction')
	local builder = self.unit:Internal()
	local factoryNames = unitTable[self.name].factoriesCanBuild
	if factoryNames ~= nil then
		for index, Name in pairs(ai.factoriesRanking) do
			for i, factoryName in pairs(factoryNames) do
				if Name == factoryName then
					EchoDebug('try to build factory '..factoryName)
					local prePositionFilter = self:BestFactoryPrePositionFilter(factoryName)
					if prePositionFilter then
						EchoDebug('buildMe')
						local mtype = factoryMobilities[factoryName][1]
						local builderPos = builder:GetPosition()
						local utype = game:GetTypeByName(factoryName)
						local p = self:BestFactoryPosition(factoryName,utype,builder,builderPos,mtype)
						if p ~= nil then
							local network = ai.maphandler:MobilityNetworkHere(mtype,p)
							EchoDebug("found spot for " .. factoryName)
							local postPositionFilter = self:BestFactoryPostPositionFilter(factoryName, p, mtype, network)
							if postPositionFilter then
								EchoDebug('place: ' ..factoryName .. ' on ' ..mtype ..'-' ..network )
								return p, factoryName
							end
						end
					end
				end
			end
		end
	end
end

function TaskQueueBehaviour:GetQueue()
	self.unit:ElectBehaviour()
	-- fall back to only making enough construction units if a level 2 factory exists
	local got = false
	if wateryTaskqueues[self.name] ~= nil then
		if ai.mobRating["shp"] * 0.5 > ai.mobRating["veh"] then
			q = wateryTaskqueues[self.name]
			got = true
		end
	end
	self.outmodedTechLevel = false
	if outmodedTaskqueues[self.name] ~= nil and not got then
		if self.isFactory and unitTable[self.name].techLevel < ai.maxFactoryLevel and ai.Metal.reserves < ai.Metal.capacity * 0.95 then
			-- stop buidling lvl1 attackers if we have a lvl2, unless we're about to waste metal, in which case use it up
			q = outmodedTaskqueues[self.name]
			got = true
			self.outmodedTechLevel = true
		elseif self.outmodedFactory then
			q = outmodedTaskqueues[self.name]
			got = true
		end
	end
	if not got then
		q = taskqueues[self.name]
	end
	if type(q) == "function" then
		-- game:SendToConsole("function table found!")
		q = q(self)
	end
	return q
end

function TaskQueueBehaviour:ConstructionBegun(unitID, unitName, position)
	EchoDebug(self.name .. " " .. self.id .. " began constructing " .. unitName .. " " .. unitID)
	self.constructing = { unitID = unitID, unitName = unitName, position = position }
end

function TaskQueueBehaviour:ConstructionComplete()
	EchoDebug(self.name .. " " .. self.id .. " completed construction of " .. self.constructing.unitName .. " " .. self.constructing.unitID)
	self.constructing = nil
end

function TaskQueueBehaviour:Update()
	if self.failOut then
		local f = game:Frame()
		if f > self.failOut + 300 then
			-- game:SendToConsole("getting back to work " .. self.name .. " " .. self.id)
			self.failOut = nil
			self.failures = 0
		end
	end
	if not self:IsActive() then
		return
	end
	local f = game:Frame()
	-- econ check
	if f % 22 == 0 then
		GetEcon()
	end
	-- watchdog check
	if not self.constructing and not self.isFactory then
		if (self.lastWatchdogCheck + self.watchdogTimeout < f) or (self.currentProject == nil and (self.lastWatchdogCheck + 1 < f)) then
			-- we're probably stuck doing nothing
			local tmpOwnName = self.unit:Internal():Name() or "no-unit"
			local tmpProjectName = self.currentProject or "empty project"
			if self.currentProject ~= nil then
				EchoDebug("Watchdog: "..tmpOwnName.." abandoning "..tmpProjectName)
				EchoDebug("last watchdog check: "..self.lastWatchdogCheck .. ", watchdog timeout:"..self.watchdogTimeout)
			end
			self:ProgressQueue()
			return
		end
	end
	if self.progress == true then
		self:ProgressQueue()
	end
end

function TaskQueueBehaviour:ProgressQueue()
	EchoDebug(self.name .. " " .. self.id .. " progress queue")
	self.lastWatchdogCheck = game:Frame()
	self.constructing = false
	self.progress = false
	local builder = self.unit:Internal()
	if not self.released then
		ai.assisthandler:Release(builder)
		ai.buildsitehandler:ClearMyPlans(self)
		if not self.isCommander and not self.isFactory then
			if ai.IDByName[self.id] ~= nil then
				if ai.IDByName[self.id] > ai.nonAssistantsPerName then
					ai.nonAssistant[self.id] = nil
				end
			end
		end
		self.released = true
	end
	if self.queue ~= nil then
		local idx, val = next(self.queue,self.idx)
		self.idx = idx
		if idx == nil then
			self.queue = self:GetQueue(name)
			self.progress = true
			return
		end
		
		local utype = nil
		local value = val

		-- evaluate any functions here, they may return tables
		MyTB = self
		while type(value) == "function" do
			value = value(self)
		end

		if type(value) == "table" then
			-- not using this
		else
			-- if bigPlasmaList[value] or littlePlasmaList[value] then DebugEnabled = true end -- debugging plasma
			local p
			if value == FactoryUnitName then
				-- build the best factory this builder can build
				p, value = self:BestFactory()
			end
			local success = false
			if value ~= DummyUnitName and value ~= nil then
				EchoDebug(self.name .. " filtering...")
				value = self:CategoryEconFilter(value)
				if value ~= DummyUnitName then
					EchoDebug("before duplicate filter " .. value)
					local duplicate = ai.buildsitehandler:CheckForDuplicates(value)
					if duplicate then value = DummyUnitName end
				end
				EchoDebug(value .. " after filters")
			else
				value = DummyUnitName
			end
			if value ~= DummyUnitName then
				if value ~= nil then
					utype = game:GetTypeByName(value)
				else
					utype = nil
					value = "nil"
				end
				if utype ~= nil then
					if self.unit:Internal():CanBuild(utype) then
						if self.isFactory then
							local helpValue = self:GetHelp(value, self.position)
							if helpValue ~= nil and helpValue ~= DummyUnitName then
								success = self.unit:Internal():Build(utype)
							end
						else
							if p == nil then utype, value, p = self:LocationFilter(utype, value) end
							if utype ~= nil and p ~= nil then
								if type(value) == "table" and value[1] == "ReclaimEnemyMex" then
									EchoDebug("reclaiming enemy mex...")
									--  success = self.unit:Internal():Reclaim(value[2])
									success = CustomCommand(self.unit:Internal(), CMD_RECLAIM, {value[2].unitID})
									value = value[1]
								else
									local helpValue = self:GetHelp(value, p)
									if helpValue ~= nil and helpValue ~= DummyUnitName then
										EchoDebug(utype:Name() .. " has help")
										ai.buildsitehandler:NewPlan(value, p, self)
										success = self.unit:Internal():Build(utype, p)
									end
								end
							end
						end
					else
						game:SendToConsole("WARNING: bad taskque: "..self.name.." cannot build "..value)
					end
				else
					game:SendToConsole(self.name .. " cannot build:"..value..", couldnt grab the unit type from the engine")
				end
			end
			-- DebugEnabled = false -- debugging plasma
			if success then
				EchoDebug(self.name .. " " .. self.id .. " successful build command for " .. utype:Name())
				if self.isFactory then
					if not self.outmodedTechLevel then
						-- factories take up idle assistants
						ai.assisthandler:TakeUpSlack(builder)
					end
				else
					self.target = p
					self.watchdogTimeout = math.max(Distance(self.unit:Internal():GetPosition(), p) * 1.5, 360)
					self.currentProject = value
					if value == "ReclaimEnemyMex" then
						self.watchdogTimeout = self.watchdogTimeout + 450 -- give it 15 more seconds to reclaim it
					end
				end
				self.released = false
				self.progress = false
				self.failures = 0
			else
				self.target = nil
				self.currentProject = nil
				self.progress = true
				self.failures = (self.failures or 0) + 1
				local limit = 20
				if self.queue then limit = #self.queue end
				if self.failures > limit then
					-- game:SendToConsole("taking a break after " .. limit .. " tries. " .. self.name .. " " .. self.id)
					self.failOut = game:Frame()
					self.unit:ElectBehaviour()
				end
			end
		end
	end
end

function TaskQueueBehaviour:Activate()
	self.active = true
	if self.constructing then
		EchoDebug(self.name .. " " .. self.id .. " resuming construction of " .. self.constructing.unitName .. " " .. self.constructing.unitID)
		-- resume construction if we were interrupted
		local floats = api.vectorFloat()
		floats:push_back(self.constructing.unitID)
		self.unit:Internal():ExecuteCustomCommand(CMD_GUARD, floats)
		self:GetHelp(self.constructing.unitName, self.constructing.position)
		-- self.target = self.constructing.position
		-- self.currentProject = self.constructing.unitName
		self.released = false
		self.progress = false
	else
		self:UnitIdle(self.unit:Internal())
	end
end

function TaskQueueBehaviour:Deactivate()
	self.active = false
	ai.buildsitehandler:ClearMyPlans(self)
end

function TaskQueueBehaviour:Priority()
	if self.failOut then
		return 0
	elseif self.currentProject == nil then
		return 50
	else
		return 75
	end
end