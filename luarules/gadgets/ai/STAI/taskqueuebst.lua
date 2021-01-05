TaskQueueBST = class(Behaviour)

function TaskQueueBST:Name()
	return "TaskQueueBST"
end

local CMD_GUARD = 25

local maxBuildDists = {}
local maxBuildSpeedDists = {}

-- for non-defensive buildings
local function MaxBuildDist(unitName, speed)
	local dist = maxBuildDists[unitName]
	if not dist then
		local ut = self.ai.armyhst.unitTable[unitName]
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




function TaskQueueBST:Init()
	self.DebugEnabled = true
	if self.ai.outmodedFactories == nil then
		self.ai.outmodedFactories = 0
	end

	self.active = false
	self.currentProject = nil
	self.lastWatchdogCheck = self.game:Frame()
	self.watchdogTimeout = 1800
	local u = self.unit:Internal()
	local mtype, network = self.ai.maphst:MobilityOfUnit(u)
	self.mtype = mtype
	self.name = u:Name()
	self.side = self.ai.armyhst.unitTable[self.name].side
	self.speed = self.ai.armyhst.unitTable[self.name].speed
	if self.ai.armyhst.commanderList[self.name] then self.isCommander = true end
	self.id = u:ID()
	self:EchoDebug(self.name .. " " .. self.id .. " initializing...")
	if self:HasQueues() then
		self.queue = self:GetQueue()
	end
end

function TaskQueueBST:CategoryEconFilter(value)
	if value == nil then return self.ai.armyhst.DummyUnitName end
	if value == self.ai.armyhst.DummyUnitName then return self.ai.armyhst.DummyUnitName end
	local overview =self.ai.overviewhst
	self:EchoDebug(value .. " (before econ filter)")
	-- self:EchoDebug("ai.Energy: " .. self.ai.Energy.reserves .. " " .. self.ai.Energy.capacity .. " " .. self.ai.Energy.income .. " " .. self.ai.Energy.usage)
	-- self:EchoDebug("ai.Metal: " .. self.ai.Metal.reserves .. " " .. self.ai.Metal.capacity .. " " .. self.ai.Metal.income .. " " .. self.ai.Metal.usage)

	if self.ai.armyhst.Eco1[value] or self.ai.armyhst.Eco2[value]  then
		return value
	end
	if (value == 'armllt' or value == 'corllt') and self.ai.Energy.income > 40 and self.ai.Metal.income > 4 then
		return value
	end

	if self.ai.armyhst.reclaimerList[value] then
		-- dedicated reclaimer
		self:EchoDebug(" dedicated reclaimer")
		if overview.metalAboveHalf or overview.energyTooLow or overview.farTooFewCombats then
			value = self.ai.armyhst.DummyUnitName
		end
	elseif self.ai.armyhst.unitTable[value].isBuilding then
		-- buildings
		self:EchoDebug(" building")
		if self.ai.armyhst.unitTable[value].buildOptions ~= nil then
			-- factory
			self:EchoDebug("  factory")
			return value
		elseif self.ai.armyhst.unitTable[value].isWeapon then
			-- defense
			self:EchoDebug("  defense")
			if self.ai.armyhst.bigPlasmaList[value] or self.ai.armyhst.nukeList[value] then
				-- long-range plasma and nukes aren't really defense
				if overview.metalTooLow or overview.energyTooLow or self.ai.Metal.income < 35 or self.ai.factories == 0 or overview.notEnoughCombats then
					value = self.ai.armyhst.DummyUnitName
				end
			elseif self.ai.armyhst.littlePlasmaList[value] then
				-- plasma turrets need units to back them up
				if overview.metalTooLow or overview.energyTooLow or self.ai.Metal.income < 10 or self.ai.factories == 0 or overview.notEnoughCombats then
					value = self.ai.armyhst.DummyUnitName
				end
			else
				if overview.metalTooLow or self.ai.Metal.income < (self.ai.armyhst.unitTable[value].metalCost / 35) + 2 or overview.energyTooLow or self.ai.factories == 0 then
					value = self.ai.armyhst.DummyUnitName
				end
			end
		elseif self.ai.armyhst.unitTable[value].radarRadius > 0 then
			-- radar
			self:EchoDebug("  radar")
			if overview.metalTooLow or overview.energyTooLow or self.ai.factories == 0 or self.ai.Energy.full < 0.5 then
				value = self.ai.armyhst.DummyUnitName
			end
		else
			-- other building
			self:EchoDebug("  other building")
			if overview.notEnoughCombats or overview.metalTooLow or overview.energyTooLow or self.ai.Energy.income < 200 or self.ai.Metal.income < 8 or self.ai.factories == 0 then
				value = self.ai.armyhst.DummyUnitName
			end
		end
	else
		-- moving units
		return value
	end
	return self.ai.armyhst.DummyUnitName
end

function TaskQueueBST:GetAmpOrGroundWeapon()
	if self.ai.enemyBasePosition then
		if self.ai.maphst:MobilityNetworkHere('veh', self.position) ~= self.ai.maphst:MobilityNetworkHere('veh', self.ai.enemyBasePosition) and self.ai.maphst:MobilityNetworkHere('amp', self.position) == self.ai.maphst:MobilityNetworkHere('amp', self.ai.enemyBasePosition) then
			self:EchoDebug('canbuild amphibious because of enemyBasePosition')
			return true
		end
	end
	local mtype = self.ai.armyhst.factoryMobilities[self.name][1]
	local network = self.ai.maphst:MobilityNetworkHere(mtype, self.position)
	if not network or not self.ai.factoryBuilded[mtype] or not self.ai.factoryBuilded[mtype][network] then
		self:EchoDebug('canbuild amphibious because ' .. mtype .. ' network here is too small or has not enough spots')
		return true
	end
	return false
end
function TaskQueueBST:HasQueues()
	self:EchoDebug(self.ai.taskshst:taskqueues()[self.name])
	return (self.ai.taskshst:taskqueues()[self.name] ~= nil)
end

function TaskQueueBST:OwnerBuilt()
	if self:IsActive() then self.progress = true end
end

function TaskQueueBST:OwnerIdle()
	if not self:IsActive() then
		return
	end
	if self.unit == nil then return end
	self.progress = true
	self.currentProject = nil
	self.ai.buildsitehst:ClearMyPlans(self)
	self.unit:ElectBehaviour()
end

function TaskQueueBST:OwnerMoveFailed()
	-- sometimes builders get stuck
	self:OwnerIdle()
end

function TaskQueueBST:OwnerDead()
	if self.unit ~= nil then
		-- game:SendToConsole("taskqueue-er " .. self.name .. " died")
		if self.outmodedFactory then
			self.ai.outmodedFactories = self.ai.outmodedFactories - 1
		end
		-- self.unit = nil
		if self.target then
			self.ai.targethst:AddBadPosition(self.target, self.mtype)
		end
		self.ai.assisthst:Release(nil, self.id, true)
		self.ai.buildsitehst:ClearMyPlans(self)
		self.ai.buildsitehst:ClearMyConstruction(self)
	end
end

function TaskQueueBST:GetHelp(value, position)
	if value == nil then return self.ai.armyhst.DummyUnitName end
	if value == self.ai.armyhst.DummyUnitName then return self.ai.armyhst.DummyUnitName end
	self:EchoDebug(value .. " before getting help")
	local builder = self.unit:Internal()
	if self.ai.armyhst.assistList[self.name] and not self.ai.armyhst.unitTable[value].isBuilding and not self.ai.armyhst.nanoTurretList[value] then
		return value
	end
	if self.ai.armyhst.Eco1[value] then
		if not self.ai.haveAdvFactory and self.ai.underReserves then
			self.ai.assisthst:TakeUpSlack(builder)
		end
		return value
	end
	if self.ai.armyhst.Eco2[value] then
		local hashelp = self.ai.assisthst:PersistantSummon(builder, position, math.ceil(self.ai.armyhst.unitTable[value].buildTime/10000), 0)
		self.ai.assisthst:TakeUpSlack(builder)
		return value
	end

	if self.ai.armyhst.unitTable[value].isBuilding and self.ai.armyhst.unitTable[value].buildOptions then
		if self.ai.factories - self.ai.outmodedFactories <= 0 or self.ai.armyhst.advFactories[value] then
			self:EchoDebug("can get help to build factory but don't need it")
			self.ai.assisthst:Summon(builder, position)
			self.ai.assisthst:Magnetize(builder, position)
			self.ai.assisthst:TakeUpSlack(builder)
			return value
		else
			self:EchoDebug("help for factory that need help")
			local hashelp = self.ai.assisthst:Summon(builder, position, self.ai.armyhst.unitTable[value].techLevel)
			if hashelp then
				self.ai.assisthst:Magnetize(builder, position)
				self.ai.assisthst:TakeUpSlack(builder)
				return value
			end
		end
	else
		local number
		if self.isFactory and not self.ai.armyhst.unitTable[value].needsWater then
			-- factories have more nano output
			--number = math.floor((self.ai.armyhst.unitTable[value].metalCost + 1000) / 1500)
			number = 0 -- dont ask for help, build nano instead
		elseif self.isFactory and self.ai.armyhst.unitTable[value].needsWater then
			--number = math.floor((self.ai.armyhst.unitTable[value].metalCost + 1000) / 500)
			number = math.floor(self.ai.armyhst.unitTable[value].buildTime/5000) --try to use build time instead metal(more sense for me)
		else
			--number = math.floor((self.ai.armyhst.unitTable[value].metalCost + 750) / 1000)
			number = math.floor(self.ai.armyhst.unitTable[value].buildTime/10000)
		end
		if number == 0 then return value end
		local hashelp = self.ai.assisthst:Summon(builder, position, number)
		if hashelp or self.isFactory then return value end
	end
	return self.ai.armyhst.DummyUnitName
end

function TaskQueueBST:LocationFilter(utype, value)
	local p
	--if self.isFactory then return utype, value end -- factories don't need to look for build locations
	local builder = self.unit:Internal()
	local builderPos = builder:GetPosition()
	if self.ai.armyhst.unitTable[value].extractsMetal > 0 then
		-- metal extractor
		local uw
		p, uw, reclaimEnemyMex = self.ai.maphst:ClosestFreeSpot(utype, builder)
		if p ~= nil then
			if reclaimEnemyMex then
				value = {"ReclaimEnemyMex", reclaimEnemyMex}
			else
				self:EchoDebug("extractor spot: " .. p.x .. ", " .. p.z)
				if uw then
					self:EchoDebug("underwater extractor " .. uw:Name())
					utype = uw
					value = uw:Name()
				end
			end
		else
			utype = nil
		end

	elseif self.ai.armyhst.geothermalPlant[value] then
		-- geothermal
		p = self.ai.maphst:ClosestFreeGeo(utype, builder)
		if p then
			self:EchoDebug("geo spot", p.x, p.y, p.z)
			if value == "corageo" or value == "armageo" then
				-- don't build moho geos next to factories
				if self.ai.buildsitehst:ClosestHighestLevelFactory(p, 500) ~= nil then
					if value == "corageo" then
						if self.ai.targethst:IsBombardPosition(p, "corbhmth") then
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
			utype = nil
		end
	elseif self.ai.armyhst.nanoTurretList[value] then
		-- build nano turrets next to a factory near you
		self:EchoDebug("looking for factory for nano")
		local currentLevel = 0
		local target = nil
		local mtype = self.ai.armyhst.unitTable[self.name].mtype
		for level, factories in pairs (self.ai.factoriesAtLevel)  do
			self:EchoDebug( ' analysis for level ' .. level)
			for index, factory in pairs(factories) do
				local factoryName = factory.unit:Internal():Name()
				if mtype == self.ai.armyhst.factoryMobilities[factoryName][1] and level > currentLevel then
					self:EchoDebug( self.name .. ' can push up self mtype ' .. factoryName)
					currentLevel = level
					target = factory
				end
			end
		end
		if target then
			self:EchoDebug(self.name..' search position for nano near ' ..target.unit:Internal():Name())
			local factoryPos = target.unit:Internal():GetPosition()
			p = self.ai.buildsitehst:ClosestBuildSpot(builder, factoryPos, utype)
		end
		if not p then
			local factoryPos = self.ai.buildsitehst:ClosestHighestLevelFactory(builder:GetPosition(), 5000)
			if factoryPos then
				self:EchoDebug("searching for top level factory")
				p = self.ai.buildsitehst:ClosestBuildSpot(builder, factoryPos, utype)
				if p == nil then
					self:EchoDebug("no spot near factory found")
					utype = nil
				end
			else
				self:EchoDebug("no factory found")
				utype = nil
			end
		end
	elseif not self.ai.armyhst.unitTable[value].isBuilding then
		if self.ai.armyhst.assistList[self.name] and not self.ai.armyhst.nanoTurretList[value] then
		p = self.ai.buildsitehst:BuildNearNano(builder, utype)
		end
	else
		if self.ai.armyhst.unitTable[value].isWeapon  then
			if 	utype:Name() == self.ai.taskbuildhst:BuildLLT(self) or
				utype:Name() == self.ai.taskbuildhst:BuildLightAA(self) or
				utype:Name() == self.ai.taskbuildhst:BuildLvl2PopUp(self) then
					p = self.ai.buildsitehst:searchPosNearThing(utype, builder,'extractsMetal',nil, 'losRadius',20) or
					self.ai.buildsitehst:searchPosInList(self.map:GetMetalSpots(),utype, builder, 'losRadius',20)
			elseif 	utype:Name() == self.ai.taskbuildhst:BuildSpecialLT(self) or
					utype:Name() == self.ai.taskbuildhst:BuildSpecialLTOnly(self) or
					utype:Name() == self.ai.taskbuildhst:BuildMediumAA(self) or
					utype:Name() == self.ai.taskbuildhst:BuildHeavyAA(self)then
						p =  self.ai.buildsitehst:searchPosInList(self.ai.hotSpot,utype, builder, 'losRadius',0)
			elseif 	utype:Name() == self.ai.taskbuildhst:BuildHLT(self) or
					utype:Name() == self.ai.taskbuildhst:BuildHeavyishAA(self) or
					utype:Name() == self.ai.taskbuildhst:BuildExtraHeavyAA(self) or
					utype:Name() == self.ai.taskbuildhst:BuildTachyon(self) then
				p =  self.ai.buildsitehst:searchPosNearThing(utype, builder,'isFactory',nil, 'losRadius',100)  or self.ai.buildsitehst:searchPosInList(self.ai.turtlehst:LeastTurtled(builder, utype:Name()),utype, builder, 'losRadius',0)
			elseif 	self.ai.armyhst.unitTable[value].isPlasmaCannon then
				if self.ai.armyhst.unitTable[value].isPlasmaCannon < 4 then
					local turtlePosList = self.ai.turtlehst:MostTurtled(builder, value, value)
					p =  self.ai.buildsitehst:searchPosInList(turtlePosList,utype, builder, 'losRadius',0) or
							self.ai.buildsitehst:searchPosNearThing(utype, builder,'extractsMetal',nil, 'losRadius',20)
				elseif self.ai.armyhst.unitTable[value].isPlasmaCannon > 4 then
					p =  self.ai.buildsitehst:searchPosNearThing(utype, builder,'isNano',nil, 'losRadius',100) or
					self.ai.buildsitehst:searchPosInList(self.ai.hotSpot,utype, builder, 'losRadius',0)
				end
			elseif 	self.ai.armyhst.nukeList[value] or
					self.ai.armyhst.antinukeList[value] then
				p = self.ai.buildsitehst:searchPosNearThing(utype, builder,'isNano',nil,'losRadius',100)
			else
				self:EchoDebug('turret value not handled ' .. value)
			end
		elseif self.ai.armyhst.shieldList[value] or self.ai.armyhst.unitTable[value].jammerRadius ~= 0 then
			self:EchoDebug("looking for least turtled positions")
			local turtlePosList = self.ai.turtlehst:LeastTurtled(builder, value)
			p =  self.ai.buildsitehst:searchPosInList(turtlePosList,utype, builder, 'losRadius',0)
		elseif self.ai.armyhst.unitTable[value].sonarRadius ~= 0  then
			--local turtlePosList = self.ai.turtlehst:MostTurtled(builder, value)
			p = self.ai.buildsitehst:searchPosNearThing(utype, builder,'extractsMetal',nil, 'sonarRadius',20)
		elseif self.ai.armyhst.unitTable[value].radarRadius ~= 0   then
			p =  self.ai.buildsitehst:searchPosNearThing(utype, builder,'extractsMetal',nil, 'radarRadius',20)
		elseif self.ai.armyhst.Eco2[value] == 1 then
					p = self.ai.buildsitehst:searchPosNearThing(utype, builder,'isNano',1000, nil,100) or
					self.ai.buildsitehst:searchPosNearThing(utype, builder,'isFactory',5000, nil,100) or
					self.ai.buildsitehst:BuildNearLastNano(builder, utype)
		elseif self.ai.armyhst.Eco1[value] == 1 then
			self:EchoDebug('searching pos for ',value)
			p = self.ai.buildsitehst:searchPosNearThing(utype, builder,'isNano',1000, nil,50) or
					self.ai.buildsitehst:searchPosNearThing(utype, builder,'isFactory',500, nil,50) or
					self.ai.buildsitehst:ClosestBuildSpot(builder, builderPos, utype)
		else
			self.game:SendToConsole('value not handled '.. value)
			p = self.ai.buildsitehst:ClosestBuildSpot(builder, builderPos, utype)
		end
	end
	if not p then
		self:EchoDebug('pos not found for .. ' .. value)
	else
		self:EchoDebug('found for .. ' .. tostring(value))
	end
	-- last ditch placement
-- 	if utype ~= nil and p == nil then
-- 		local builderPos = builder:GetPosition()
-- 		p = self.ai.buildsitehst:ClosestBuildSpot(builder, builderPos, utype)
-- 	end
	return utype, value, p
end


function TaskQueueBST:GetQueue()
	self.unit:ElectBehaviour()
	-- fall back to only making enough construction units if a level 2 factory exists
	local q
	local uT = self.ai.armyhst.unitTable
	q = q or self.ai.taskshst:taskqueues()[self.name]
	if type(q) == "function" then
		self:EchoDebug("function table found!",q)
		q = q(self)
	end
	return q
end

function TaskQueueBST:ConstructionBegun(unitID, unitName, position)
	self:EchoDebug(self.name .. " " .. self.id .. " began constructing " .. unitName .. " " .. unitID)
	self.constructing = { unitID = unitID, unitName = unitName, position = position }
end

function TaskQueueBST:ConstructionComplete()
	self:EchoDebug(self.name .. " " .. self.id .. " completed construction of " .. self.constructing.unitName .. " " .. self.constructing.unitID)
	self.constructing = nil
end

function TaskQueueBST:Update()
	if self.failOut then
		local f = self.game:Frame()
		if f > self.failOut + 300 then
			-- game:SendToConsole("getting back to work " .. self.name .. " " .. self.id)
			self.failOut = nil
			self.failures = 0
		end
	end
	if not self:IsActive() then
		return
	end
	local f = self.game:Frame()
	-- watchdog check
	if not self.constructing and not self.isFactory then
		if (self.lastWatchdogCheck + self.watchdogTimeout < f) or (self.currentProject == nil and (self.lastWatchdogCheck + 1 < f)) then
			-- we're probably stuck doing nothing
			local tmpOwnName = self.unit:Internal():Name() or "no-unit"
			local tmpProjectName = self.currentProject or "empty project"
			if self.currentProject ~= nil then
				self:EchoDebug("Watchdog: "..tmpOwnName.." abandoning "..tmpProjectName)
				self:EchoDebug("last watchdog check: "..self.lastWatchdogCheck .. ", watchdog timeout:"..self.watchdogTimeout)
			end
			self:ProgressQueue()
			return
		end
	end
	if self.progress == true then
		self:ProgressQueue()
	end
end

function TaskQueueBST:ProgressQueue()
	self:EchoDebug(self.name .. " " .. self.id .. " progress queue")
	self.lastWatchdogCheck = self.game:Frame()
	self.constructing = false
	self.progress = false
	local builder = self.unit:Internal()
	if not self.released then
		self.ai.assisthst:Release(builder)
		self.ai.buildsitehst:ClearMyPlans(self)
		if not self.isCommander and not self.isFactory then
			if self.ai.IDByName[self.id] ~= nil then
				if self.ai.IDByName[self.id] > self.ai.dontAssist[self.name]then
					self.ai.nonAssistant[self.id] = nil
				end
			end
		end
		self.released = true
	end
	if self.queue ~= nil then
		local idx, val = next(self.queue,self.idx)
		self:EchoDebug(idx , val)
		self.idx = idx
		if idx == nil then
			self.queue = self:GetQueue(name)
			self.progress = true
			return
		end

		local utype = nil
		local value = val

		-- evaluate any functions here, they may return tables
		while type(value) == "function" do
			self:EchoDebug('function queue', value)
			value = value(self,self.ai)
		end

		if type(value) == "table" then
			self:EchoDebug('table queue', value)
			-- not using this
		else
			local p
			if value == self.ai.armyhst.FactoryUnitName then --searching for factory conditions
				value = self.ai.armyhst.DummyUnitName
				p, value = self.ai.labbuildhst:GetBuilderFactory(builder)
			end

			local success = false
			if value ~= self.ai.armyhst.DummyUnitName and value ~= nil then
				self:EchoDebug(self.name .. " filtering...")
				value = self:CategoryEconFilter(value)
				if value ~= self.ai.armyhst.DummyUnitName then
					self:EchoDebug("before duplicate filter " .. value)
					local duplicate = self.ai.buildsitehst:CheckForDuplicates(value)
					if duplicate then value = self.ai.armyhst.DummyUnitName end
				end
				self:EchoDebug(value .. " after filters")
			else
				value = self.ai.armyhst.DummyUnitName
			end
			if value ~= self.ai.armyhst.DummyUnitName then
				if value ~= nil then
					utype = game:GetTypeByName(value)
				else
					utype = nil
					value = "nil"
				end
				if utype ~= nil then
					if self.unit:Internal():CanBuild(utype) then
						if p == nil then utype, value, p = self:LocationFilter(utype, value) end
						if utype ~= nil and p ~= nil then
							if type(value) == "table" and value[1] == "ReclaimEnemyMex" then
								self:EchoDebug("reclaiming enemy mex...")
								--  success = self.unit:Internal():Reclaim(value[2])
								success = self.ai.tool:CustomCommand(self.unit:Internal(), CMD_RECLAIM, {value[2].unitID})
								value = value[1]
							else
								--local helpValue = self:GetHelp(value, p) --uncommenttohelp--
								local helpValue = value
								if helpValue ~= nil and helpValue ~= self.ai.armyhst.DummyUnitName then
									self:EchoDebug(utype:Name() .. " has help")
									self.ai.buildsitehst:NewPlan(value, p, self)
									local facing = self.ai.buildsitehst:GetFacing(p)
									success = self.unit:Internal():Build(utype, p, facing)
								end
							end
						end
-- 						end
					else
						game:SendToConsole("WARNING: bad taskque: "..self.name.." cannot build "..value)
					end
				else
					game:SendToConsole(self.name .. " cannot build:"..value..", couldnt grab the unit type from the engine")
				end
			end
			if success then
				self:EchoDebug(self.name .. " " .. self.id .. " successful build command for " .. utype:Name())
				self.target = p
				self.watchdogTimeout = math.max(self.ai.tool:Distance(self.unit:Internal():GetPosition(), p) * 1.5, 360)
				self.currentProject = value
				if value == "ReclaimEnemyMex" then
					self.watchdogTimeout = self.watchdogTimeout + 450 -- give it 15 more seconds to reclaim it
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
					self.failOut = self.game:Frame()
					self.unit:ElectBehaviour()
				end
			end
		end
	end
end

function TaskQueueBST:Activate()
	if self.constructing then
		self:EchoDebug(self.name .. " " .. self.id .. " resuming construction of " .. self.constructing.unitName .. " " .. self.constructing.unitID)
		-- resume construction if we were interrupted
		local floats = api.vectorFloat()
		floats:push_back(self.constructing.unitID)
		self.unit:Internal():ExecuteCustomCommand(CMD_GUARD, floats)
		--self:GetHelp(self.constructing.unitName, self.constructing.position) --uncommenttohelp--
		-- self.target = self.constructing.position
		-- self.currentProject = self.constructing.unitName
		self.released = false
		self.progress = false
	else
		self:UnitIdle(self.unit:Internal())
	end
end

function TaskQueueBST:Deactivate()
	self.ai.buildsitehst:ClearMyPlans(self)
end

function TaskQueueBST:Priority()
	if self.failOut then
		return 0
	elseif self.currentProject == nil then
		return 50
	else
		return 75
	end
end
