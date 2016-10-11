local DebugEnabled = false


local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("TaskQueueBehaviour: " .. inStr)
	end
end

TaskQueueBehaviour = class(Behaviour)

function TaskQueueBehaviour:Name()
	return "TaskQueueBehaviour"
end

local CMD_GUARD = 25

local maxBuildDists = {}
local maxBuildSpeedDists = {}

-- for non-defensive buildings
local function MaxBuildDist(unitName, speed)
	local dist = maxBuildDists[unitName]
	if not dist then
		local ut = unitTable[unitName]
		if not ut then return 0 end
		dist = math.sqrt(ut.metalCost)
		maxBuildDists[unitName] = dist
	end
	maxBuildSpeedDists[unitName] = maxBuildSpeedDists[unitName] or {}
	local speedDist = maxBuildSpeedDists[unitName][speed]
	if not speedDist then
		speedDist = dist * (speed / 2)
		maxBuildSpeedDists[unitName][speed] = speedDist
	end
	return speedDist
end

function TaskQueueBehaviour:GetAmpOrGroundWeapon()
	if ai.enemyBasePosition then
		if ai.maphandler:MobilityNetworkHere('veh', self.position) ~= ai.maphandler:MobilityNetworkHere('veh', ai.enemyBasePosition) and ai.maphandler:MobilityNetworkHere('amp', self.position) == ai.maphandler:MobilityNetworkHere('amp', ai.enemyBasePosition) then
			EchoDebug('canbuild amphibious because of enemyBasePosition')
			return true
		end
	end
	local mtype = factoryMobilities[self.name][1]
	local network = ai.maphandler:MobilityNetworkHere(mtype, self.position)
	if not network or not ai.factoryBuilded[mtype] or not ai.factoryBuilded[mtype][network] then
		EchoDebug('canbuild amphibious because ' .. mtype .. ' network here is too small or has not enough spots')
		return true
	end
	return false
end

function TaskQueueBehaviour:CategoryEconFilter(value)
	if value == nil then return DummyUnitName end
	if value == DummyUnitName then return DummyUnitName end
	local overview =self.ai.overviewhandler
	EchoDebug(value .. " (before econ filter)")
	-- EchoDebug("ai.Energy: " .. ai.Energy.reserves .. " " .. ai.Energy.capacity .. " " .. ai.Energy.income .. " " .. ai.Energy.usage)
	-- EchoDebug("ai.Metal: " .. ai.Metal.reserves .. " " .. ai.Metal.capacity .. " " .. ai.Metal.income .. " " .. ai.Metal.usage)
	if Eco1[value] or Eco2[value] then
		return value
	end
	if reclaimerList[value] then
		-- dedicated reclaimer
		EchoDebug(" dedicated reclaimer")
		if overview.metalAboveHalf or overview.energyTooLow or overview.farTooFewCombats then
			value = DummyUnitName
		end
	elseif unitTable[value].isBuilding then
		-- buildings
		EchoDebug(" building")
		if unitTable[value].buildOptions ~= nil then
			-- factory
			EchoDebug("  factory")
			return value
		elseif unitTable[value].isWeapon then
			-- defense
			EchoDebug("  defense")
			if bigPlasmaList[value] or nukeList[value] then
				-- long-range plasma and nukes aren't really defense
				if overview.metalTooLow or overview.energyTooLow or ai.Metal.income < 35 or ai.factories == 0 or overview.notEnoughCombats then
					value = DummyUnitName
				end
			elseif littlePlasmaList[value] then
				-- plasma turrets need units to back them up
				if overview.metalTooLow or overview.energyTooLow or ai.Metal.income < 10 or ai.factories == 0 or overview.notEnoughCombats then
					value = DummyUnitName
				end
			else
				if overview.metalTooLow or ai.Metal.income < (unitTable[value].metalCost / 35) + 2 or overview.energyTooLow or ai.factories == 0 then
					value = DummyUnitName
				end
			end
		elseif unitTable[value].radarRadius > 0 then
			-- radar
			EchoDebug("  radar")
			if overview.metalTooLow or overview.energyTooLow or ai.factories == 0 or ai.Energy.full < 0.5 then
				value = DummyUnitName
			end
		else
			-- other building
			EchoDebug("  other building")
			if overview.notEnoughCombats or overview.metalTooLow or overview.energyTooLow or ai.Energy.income < 200 or ai.Metal.income < 8 or ai.factories == 0 then
				value = DummyUnitName
			end
		end
	else
		-- moving units
		EchoDebug(" moving unit")
		if unitTable[value].buildOptions ~= nil then
			-- construction unit
			EchoDebug("  construction unit")
			if ai.Energy.full < 0.05 or ai.Metal.full < 0.05 then
				value = DummyUnitName
			end
		elseif unitTable[value].isWeapon then
			-- combat unit
			EchoDebug("  combat unit")
			if ai.Energy.full < 0.1 or ai.Metal.full < 0.1 then
				value = DummyUnitName 
			end
		elseif value == "armpeep" or value == "corfink" then
			-- scout planes have no weapons
			if ai.Energy.full < 0.3 or ai.Metal.full < 0.3 then
				value = DummyUnitName
			end
		else
			-- other unit
			EchoDebug("  other unit")
			if overview.notEnoughCombats or ai.Energy.full < 0.3 or ai.Metal.full < 0.3 then
				value = DummyUnitName
			end
		end
	end
	return value
end
function TaskQueueBehaviour:Init()
	self.DebugEnabled = false

	if not taskqueues then
		shard_include "taskqueues"
	end
	if ai.outmodedFactories == nil then ai.outmodedFactories = 0 end

	self.active = false
	self.currentProject = nil
	self.lastWatchdogCheck = game:Frame()
	self.watchdogTimeout = 1800
	local u = self.unit:Internal()
	local mtype, network = ai.maphandler:MobilityOfUnit(u)
	self.mtype = mtype
	self.name = u:Name()
	self.side = unitTable[self.name].side
	self.speed = unitTable[self.name].speed
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

	if self.isFactory then
		-- precalculate amphibious rank
		local ampSpots = ai.maphandler:AccessibleMetalGeoSpotsHere('amp', self.unit:Internal():GetPosition())
		local vehSpots = ai.maphandler:AccessibleMetalGeoSpotsHere('veh', self.unit:Internal():GetPosition())
		local amphRank = 0
		if #ampSpots > 0 and #vehSpots > 0 then
		    amphRank = 1 - (#vehSpots / #ampSpots)
		elseif #vehSpots == 0 and #ampSpots > 0 then
		    amphRank = 1
		end
		self.amphRank = amphRank
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
	if assistList[self.name] and not unitTable[value].isBuilding and not nanoTurretList[value] then 
		return value
	end
	if Eco1[value] then
		if not ai.haveAdvFactory and ai.underReserves then
			ai.assisthandler:TakeUpSlack(builder)
		end
		return value
	end
	if Eco2[value] then
		local hashelp = ai.assisthandler:PersistantSummon(builder, position, math.ceil(unitTable[value].buildTime/10000), 0)
		ai.assisthandler:TakeUpSlack(builder)
		return value
	end
	
	if unitTable[value].isBuilding and unitTable[value].buildOptions then
		if ai.factories - ai.outmodedFactories <= 0 or advFactories[value] then
			EchoDebug("can get help to build factory but don't need it")
			ai.assisthandler:Summon(builder, position)
			ai.assisthandler:Magnetize(builder, position)
			ai.assisthandler:TakeUpSlack(builder)
			return value
		else
			EchoDebug("help for factory that need help")
			local hashelp = ai.assisthandler:Summon(builder, position, unitTable[value].techLevel)
			if hashelp then
				ai.assisthandler:Magnetize(builder, position)
				ai.assisthandler:TakeUpSlack(builder)
				return value
			end
		end
	else
		local number
		if self.isFactory and not unitTable[value].needsWater then
			-- factories have more nano output
			--number = math.floor((unitTable[value].metalCost + 1000) / 1500)
			number = 0 -- dont ask for help, build nano instead
		elseif self.isFactory and unitTable[value].needsWater then
			--number = math.floor((unitTable[value].metalCost + 1000) / 500)
			number = math.floor(unitTable[value].buildTime/5000) --try to use build time instead metal(more sense for me)
		else
			--number = math.floor((unitTable[value].metalCost + 750) / 1000)
			number = math.floor(unitTable[value].buildTime/10000)
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
	elseif assistList[self.name] and not unitTable[value].isBuilding and not nanoTurretList[value] then 
		p = ai.buildsitehandler:BuildNearNano(builder, utype)
		if not p then
			local builderPos = builder:GetPosition()
			p = ai.buildsitehandler:ClosestBuildSpot(builder, builderPos, utype)
		end
		if not p then 
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
		local currentLevel = 0
		local target = nil
		local mtype = unitTable[self.name].mtype
		for level, factories in pairs (ai.factoriesAtLevel)  do
			EchoDebug( ' analysis for level ' .. level)
			for index, factory in pairs(factories) do
				local factoryName = factory.unit:Internal():Name()
				if mtype == factoryMobilities[factoryName][1] and level > currentLevel then
					EchoDebug( self.name .. ' can push up self mtype ' .. factoryName)
					currentLevel = level
					target = factory
				end
			end
		end
		if target then
			EchoDebug(self.name..' search position for nano near ' ..target.unit:Internal():Name())
			local factoryPos = target.unit:Internal():GetPosition()
			p = ai.buildsitehandler:ClosestBuildSpot(builder, factoryPos, utype)
		end
		if not p then
			
			local factoryPos = ai.buildsitehandler:ClosestHighestLevelFactory(builder:GetPosition(), 5000)
			if factoryPos then
				EchoDebug("searching for top level factory")
				p = ai.buildsitehandler:ClosestBuildSpot(builder, factoryPos, utype)
				if p == nil then
					EchoDebug("no spot near factory found")
					utype = nil
				end
			else
				EchoDebug("no factory found")
				utype = nil
			end
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
		if Eco2[value] == 1 then
			p = ai.buildsitehandler:BuildNearNano(builder, utype)
		end
		if not p then
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
			if p and Distance(p, builder:GetPosition()) > MaxBuildDist(value, self.speed) then
				-- HERE BECAUSE DEFENSE PLACEMENT SYSTEM SUCKS
				-- this prevents cons from wasting time building very far away
				p = ai.buildsitehandler:ClosestBuildSpot(builder, builder:GetPosition(), utype)
			end
		end
	end
	-- last ditch placement
	if utype ~= nil and p == nil then
		local builderPos = builder:GetPosition()
		p = ai.buildsitehandler:ClosestBuildSpot(builder, builderPos, utype)
	end
	return utype, value, p
end


function TaskQueueBehaviour:GetQueue()
	self.unit:ElectBehaviour()
	-- fall back to only making enough construction units if a level 2 factory exists
	local q
	if self.isFactory and ai.factoryUnderConstruction and ( ai.Metal.full < 0.5 or ai.Energy.full < 0.5) then
		q = {}
	end
	
	self.outmodedTechLevel = false
	local uT = unitTable
	if outmodedTaskqueues[self.name] ~= nil and not q then 
		local threshold =  1 - (uT[self.name].techLevel / ai.maxFactoryLevel)
		if self.isFactory  and (ai.Metal.full < threshold or ai.Energy.full < threshold) then
			local mtype = factoryMobilities[self.name][1]
			for level, factories in pairs (ai.factoriesAtLevel)  do
				for index, factory in pairs(factories) do
					local factoryName = factory.unit:Internal():Name()
					if mtype == factoryMobilities[factoryName][1] and uT[self.name].techLevel < level then
						EchoDebug( self.name .. ' have major factory ' .. factoryName)
						-- stop buidling lvl1 attackers if we have a lvl2, unless we're with proportioned resources
						q = outmodedTaskqueues[self.name]
						self.outmodedTechLevel = true
						break
					end
				end
				if q then break end
			end
		
		elseif self.outmodedFactory then
			q = outmodedTaskqueues[self.name]
			
		end
	end
	q = q or taskqueues[self.name]
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
	if self.isFactory and f % 311 == 0 and (factoryMobilities[self.name][1] == 'bot' or factoryMobilities[self.name][1] == 'veh') then
		self.AmpOrGroundWeapon = self:GetAmpOrGroundWeapon()
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
			if value == FactoryUnitName then --searching for factory conditions
				value = DummyUnitName
				p, value = self.ai.factorybuildershandler:GetBuilderFactory(builder)
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
					if not self.outmodedTechLevel and not self.ai.underReserves then
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
				if self.queue then limit = #self.queue * 2 end
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