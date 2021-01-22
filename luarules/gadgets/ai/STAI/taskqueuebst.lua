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
	self.DebugEnabled = false
	self.role = nil
	self.active = false
	self.currentProject = nil
	self.lastWatchdogCheck = self.game:Frame()
	self.watchdogTimeout = 1800
	local u = self.unit:Internal()

	local mtype, network = self.ai.maphst:MobilityOfUnit(u)
	self.id = u:ID()
	self.mtype = mtype
	self.name = u:Name()
	self.side = self.ai.armyhst.unitTable[self.name].side
	self.speed = self.ai.armyhst.unitTable[self.name].speed
	if self.ai.armyhst.commanderList[self.name] then self.isCommander = true end
	if not self.ai.armyhst.buildersRole.default[self.name] then
		for i,v in pairs(self.ai.armyhst.buildersRole) do
			self.ai.armyhst.buildersRole[i][self.name] = {}
		end
	end
	self.queue = self:GetQueue()
	self:EchoDebug(self.name .. " " .. self.id .. " initializing...")
end

function TaskQueueBST:OwnerBuilt()
	if self:IsActive() then self.progress = true end
end

function TaskQueueBST:OwnerDead()
	if self.unit ~= nil then
		for i, idx in pairs(self.ai.armyhst.buildersRole[self.role][self.name]) do
			if self.id == idx then
				self.ai.armyhst.buildersRole[self.role][self.name][i] = nil
				self.role = nil
			end
		end
		if self.target then
			self.ai.targethst:AddBadPosition(self.target, self.mtype)
		end
		self.ai.buildsitehst:ClearMyPlans(self)
		self.ai.buildsitehst:ClearMyConstruction(self)
	end
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

function TaskQueueBST:ConstructionBegun(unitID, unitName, position)
	self:EchoDebug(self.name .. " " .. self.id .. " began constructing " .. unitName .. " " .. unitID)
	self.constructing = { unitID = unitID, unitName = unitName, position = position }
end

function TaskQueueBST:ConstructionComplete()
	self:EchoDebug(self.name, self.id," completed construction of ", self.constructing.unitName ," ",self.constructing.unitID)
	self.constructing = nil
end

function TaskQueueBST:Activate()
	if self.constructing then
		self:EchoDebug(self.name .. " " .. self.id .. " resuming construction of " .. self.constructing.unitName .. " " .. self.constructing.unitID)
		-- resume construction if we were interrupted
		local floats = api.vectorFloat()
		floats:push_back(self.constructing.unitID)
		self.unit:Internal():ExecuteCustomCommand(CMD_GUARD, floats)
		self.target = self.constructing.position
		self.currentProject = self.constructing.unitName
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
	-- watchdog POS
	if not self.constructing then
		if (self.lastWatchdogCheck + self.watchdogTimeout < f) or (self.currentProject == nil and (self.lastWatchdogCheck + 1 < f)) then
			-- we're probably stuck doing nothing
			local tmpOwnName = self.unit:Internal():Name() or "no-unit"
			local tmpProjectName = self.currentProject or "empty project"
			if self.currentProject ~= nil then
				self:EchoDebug("Watchdog: "..tmpOwnName.." abandoning "..tmpProjectName)
				self:EchoDebug("last watchdog POS: "..self.lastWatchdogCheck .. ", watchdog timeout:"..self.watchdogTimeout)
			end
			self:ProgressQueue()
			return
		end
	end
	if self.progress == true then
		self:ProgressQueue()
	end
end

function TaskQueueBST:CategoryEconFilter(cat,param,name)
	self:EchoDebug(cat ,value,self.role, " (before econ filter)")
	if not name then return end
	local M = self.ai.Metal
	local E = self.ai.Energy
	local eco = false
	if cat == 'factoryMobilities' then
		eco =  M.income > 3 and E.income > 30
	elseif cat == '_mex_' then
		eco =   (M.full < 0.5 or M.income < 6) or self.role == 'expand'
	elseif cat == '_nano_' then
		eco =  (E.full > 0.5  and M.full > 0.3 and M.income > 10 and E.income > 100)
	elseif cat == '_wind_' then
		eco =   map:AverageWind() > 7 and ((E.full < 0.5 or E.income < E.usage )  or E.income < 30)
	elseif cat == '_tide_' then
		eco =  map:TidalStrength() >= 10 and  ((E.full < 0.5 or E.income < E.usage )  or E.income < 30)
	elseif cat == '_advsol_' then
		eco =   ((E.full < 0.5 or E.income < E.usage )  and M.income > 12 and M.reserves > 100 )
	elseif cat == '_solar_' then
		eco =   (E.full < 0.5 or E.income < E.usage )  or E.income < 30
	elseif cat == '_estor_' then
		eco =   E.full > 0.9 and E.income > 400  and M.reserves > 100 and E.capacity < 7000
	elseif cat == '_mstor_' then
		eco =   E.full > 0.5  and M.full > 0.3 and M.income > 10 and E.income > 100
	elseif cat == '_convs_' then
		eco =   E.income > E.usage * 1.1 and E.full > 0.9 and E.income > 200 and E.income  and M.full < 0.3
	elseif cat == '_llt_' then
		eco =   (E.income > 30 and M.income > 1 and M.full < 0.5)
	elseif cat == '_popup1_' then
		eco =   (E.income > 100 and M.income > 12 and M.full > 0.5)
	elseif cat == '_specialt_' then
		eco =   E.income > 40 and M.income > 4 and M.full > 0.1
	elseif cat == '_heavyt_' then
		eco =   E.income > 100 and M.income > 15 and M.full > 0.3
	elseif cat == '_aa1_' then
		eco =  E.full > 0.1 and E.full < 0.5 and M.income > 25 and E.income > 100
	elseif cat == '_flak_' then
		eco =  E.full > 0.1 and E.full < 0.5 and E.income > 2000
	elseif cat == '_fus_' then
		eco =  (E.full < 0.6 or E.income < E.usage) or E.full < 0.3
	elseif cat == '_popup2_' then
		eco =  M.full > 0.2
	elseif cat == '_jam_' then
		eco =  M.full > 0.5 and M.income > 25 and E.income > 100
	elseif cat == '_radar_' then
		eco =  M.full > 0.5 and M.income > 6 and E.income > 50
	elseif cat == '_geo_' then
		eco =  E.income > 100 and M.income > 15 and E.full > 0.3 and M.full > 0.3
	elseif cat == '_silo_' then
		eco =  E.income > 10000 and M.income > 100 and E.full > 0.8 and M.full > 0.5
	elseif cat == '_antinuke_' then
		eco =  E.income > 5000 and M.income > 75 and E.full > 0.6 and M.full > 0.3
	elseif cat == '_sonar_' then
		eco =  true
	elseif cat == '_shield_' then
		eco =  E.income > 8000 and M.income > 100 and E.full > 0.6 and M.full > 0.5
	elseif cat == '_juno_' then
		eco =  false
	elseif cat == '_laser2_' then
		eco =   E.income > 2000 and M.income > 50 and E.full > 0.5 and M.full > 0.3
	elseif cat == '_lol_' then
		eco =  E.income > 20000 and M.income > 200 and E.full > 0.8 and M.full > 0.8
	elseif cat == '_coast1_' then
		eco =  false
	elseif cat == '_coast2_' then
		eco =  false
	elseif cat == '_plasma_' then
		eco =  E.income > 6000 and M.income > 120 and E.full > 0.8 and M.full > 0.5
	elseif cat == '_torpedo1_' then
		eco =  true
	elseif cat == '_torpedo2_' then
		eco =  true
	elseif cat == '_torpedoground_' then
		eco =  true
	elseif cat == '_aabomb_' then
		eco =  E.full > 0.5 and M.full > 0.5
	elseif cat == '_aaheavy_' then
		eco =  E.income > 500 and M.income > 25 and E.full > 0.3 and M.full > 0.3
	elseif cat == '_aa2_' then
		eco =  E.income > 7000 and M.income > 100 and E.full > 0.3 and M.full > 0.3
	else
		self:EchoDebug('economi category not handled')
	end
	if eco then return name end
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

function TaskQueueBST:findPlace(utype, value,cat)
	if not value or not cat or not utype then return end
	local POS = nil
	local builder = self.unit:Internal()
	local builderPos = builder:GetPosition()
	local army = self.ai.armyhst
	local site = self.ai.buildsitehst

	if cat == 'factoryMobilities' then
		POS =  site:BuildNearLastNano(builder, utype) or
				site:searchPosNearThing(utype, builder,'isNano',400, nil,100) or
				site:searchPosNearThing(utype, builder,'isFactory',1000, nil,100) or
				site:searchPosNearThing(utype, builder,'extractsMetal',nil, 'radarRadius',20)
	elseif cat == '_mex_' then
		local uw
		POS, uw, reclaimEnemyMex = self.ai.maphst:ClosestFreeSpot(utype, builder,site:ClosestHighestLevelFactory(builder:GetPosition(), 999999999))
		if POS  then
			if reclaimEnemyMex then
				value = {"ReclaimEnemyMex", reclaimEnemyMex}
			else
				self:EchoDebug("extractor spot: " .. POS.x .. ", " .. POS.z)
				if uw then
					self:EchoDebug("underwater extractor " .. uw:Name())
					utype = uw
					value = uw:Name()
				end
			end
		end
	elseif cat == '_nano_' then
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
			POS = self.ai.buildsitehst:ClosestBuildSpot(builder, factoryPos, utype)
		end
		if not POS then
			local factoryPos = self.ai.buildsitehst:ClosestHighestLevelFactory(builder:GetPosition(), 5000)
			if factoryPos then
				self:EchoDebug("searching for top level factory")
				POS = self.ai.buildsitehst:ClosestBuildSpot(builder, factoryPos, utype)
			end
		end
	elseif cat == '_wind_' then
		POS = 	site:searchPosNearThing(utype, builder,'isNano',500, nil,50) or
				site:searchPosNearThing(utype, builder,'isFactory',1000, nil,100) or
				site:ClosestBuildSpot(builder, builderPos, utype)
	elseif cat == '_tide_' then
		POS =  	site:searchPosNearThing(utype, builder,'isNano',500, nil,50) or
				site:searchPosNearThing(utype, builder,'isFactory',1000, nil,100) or
				site:ClosestBuildSpot(builder, builderPos, utype)
	elseif cat == '_advsol_' then
		POS = 	site:searchPosNearThing(utype, builder,'isNano',500, nil,50) or
				site:searchPosNearThing(utype, builder,'isFactory',1000, nil,100) or
				site:ClosestBuildSpot(builder, builderPos, utype)
	elseif cat == '_solar_' then
		POS = 	site:searchPosNearThing(utype, builder,'isNano',500, nil,50) or
				site:searchPosNearThing(utype, builder,'isFactory',1000, nil,100) or
				site:ClosestBuildSpot(builder, builderPos, utype)
	elseif cat == '_fus_' then
		POS = site:searchPosNearThing(utype, builder,'isNano',500, nil,50) or
				site:searchPosNearThing(utype, builder,'isFactory',1000, nil,100) or
				site:ClosestBuildSpot(builder, builderPos, utype) or
				site:BuildNearLastNano(builder, utype)
	elseif cat == '_estor_' then
		POS = site:searchPosNearThing(utype, builder,'isNano',500, nil,300) or
				site:searchPosNearThing(utype, builder,'isFactory',1000, nil,300) or
				site:ClosestBuildSpot(builder, builderPos, utype)
	elseif cat == '_mstor_' then
		POS = site:searchPosNearThing(utype, builder,'isNano',500, nil,300) or
				site:searchPosNearThing(utype, builder,'isFactory',1000, nil,300) or
				site:ClosestBuildSpot(builder, builderPos, utype)
	elseif cat == '_convs_' then
		POS = site:searchPosNearThing(utype, builder,'isNano',500, nil,200) or
				site:searchPosNearThing(utype, builder,'isFactory',1000, nil,200) or
				site:ClosestBuildSpot(builder, builderPos, utype)
	elseif cat == '_llt_' then
		POS = site:searchPosNearThing(utype, builder,'extractsMetal',nil, 'losRadius',20)
	elseif cat == '_popup1_' then
		POS = site:searchPosNearThing(utype, builder,'extractsMetal',nil, 'losRadius',20)
	elseif cat == '_specialt_' then
		POS = site:searchPosNearThing(utype, builder,'isFactory',500, 300,300)
	elseif cat == '_heavyt_' then
		POS = site:searchPosInList(self.ai.hotSpot,utype, builder, 'losRadius',0)
	elseif cat == '_aa1_' then
		POS = site:searchPosNearThing(utype, builder,'extractsMetal',nil, 'losRadius',20)
	elseif cat == '_flak_' then
		POS = site:searchPosNearThing(utype, builder,'extractsMetal',nil, 'losRadius',20)
	elseif cat == '_popup2_' then
		POS = site:searchPosNearThing(utype, builder,'extractsMetal',nil, 'losRadius',20)
	elseif cat == '_jam_' then
		POS =  site:searchPosNearThing(utype, builder,'isFactory',nil, 200,200)
	elseif cat == '_radar_' then
		POS = site:searchPosNearThing(utype, builder,'extractsMetal',nil, 'losRadius',20)
	elseif cat == '_geo_' then
		POS =  self.ai.maphst:ClosestFreeGeo(utype, builder)
	elseif cat == '_silo_' then
		POS =  site:searchPosNearThing(utype, builder,'isFactory',nil, 500,500)
	elseif cat == '_antinuke_' then
		POS =  site:searchPosNearThing(utype, builder,'isFactory',nil, 500,500)
	elseif cat == '_sonar_' then
		POS = site:searchPosNearThing(utype, builder,'extractsMetal',nil, 'losRadius',20)
	elseif cat == '_shield_' then
		POS =  site:searchPosNearThing(utype, builder,'isFactory',nil, 500,500)
	elseif cat == '_juno_' then
		POS =  site:searchPosNearThing(utype, builder,'isFactory',nil, 500,500)
	elseif cat == '_laser2_' then
		POS =   site:searchPosNearThing(utype, builder,'isFactory',nil, 1000,500) or
				site:searchPosInList(self.ai.hotSpot,utype, builder, 'losRadius',0)
	elseif cat == '_lol_' then
		POS =  site:searchPosNearThing(utype, builder,'isFactory',nil, 1000,1000)
	elseif cat == '_coast1_' then
		POS = site:searchPosInList(self.ai.turtlehst:LeastTurtled(builder, value),utype, builder, 'losRadius',0)
	elseif cat == '_coast2_' then
		POS = site:searchPosInList(self.ai.turtlehst:LeastTurtled(builder, value),utype, builder, 'losRadius',0)
	elseif cat == '_plasma_' then
		POS =  site:searchPosNearThing(utype, builder,'isFactory',nil, 500,500)
	elseif cat == '_torpedo1_' then
		POS = site:searchPosNearThing(utype, builder,'extractsMetal',nil, 'losRadius',20)
	elseif cat == '_torpedo2_' then
		POS = site:searchPosNearThing(utype, builder,'extractsMetal',nil, 'losRadius',20)
	elseif cat == '_torpedoground_' then
		POS = site:searchPosNearThing(utype, builder,'extractsMetal',nil, 'losRadius',20)
	elseif cat == '_aabomb_' then
		POS =  site:searchPosNearThing(utype, builder,nil,nil, 'losRadius',20,'_heavyt_') or
				site:searchPosNearThing(utype, builder,nil,nil, 'losRadius',20,'_laser2_')
	elseif cat == '_aaheavy_' then
		POS = site:searchPosNearThing(utype, builder,'isFactory',nil, 400,400)
	elseif cat == '_aa2_' then
		POS =  site:searchPosNearThing(utype, builder,'isFactory',nil, 500,500)
	else
		self:EchoDebug(' cant find a place for ',value,cat)
	end
	if POS then
		self:EchoDebug('found pos for .. ' ,value)
		return utype, value, POS
	else
		self:EchoDebug('pos not found for .. ' ,value)
	end
end



function TaskQueueBST:limitedNumber(name,number)
	self:EchoDebug(number,'limited for ',name)
	if not name then return end
	local team = game:GetTeamID()
	local id = self.ai.armyhst.unitTable[name].defId
	local counter = game:GetTeamUnitDefCount(team,id)
	if counter < number then
		return name
	end
	self:EchoDebug('limited stop',name)
end

function TaskQueueBST:getOrder(builder,params)
	if params[1] == 'factoryMobilities' then
		if params[2] then
			local p = nil
			local  value = nil
			p, value = self.ai.labbuildhst:GetBuilderFactory(builder)
			if p and value then
				self:EchoDebug('factory', value, 'is returned from labbuildhst')
				return  value, p
			end
		end
	else
		self:EchoDebug(params[1])
		local army = self.ai.armyhst
		for index, uName in pairs (army.unitTable[self.name].buildingsCanBuild) do
			if army[params[1]][uName] then
				return uName
			end
		end
	end

end

function TaskQueueBST:GetQueue()
	self.unit:ElectBehaviour()
	local buildersRole = self.ai.armyhst.buildersRole
	local team = game:GetTeamID()
	local id = self.ai.armyhst.unitTable[self.name].defId
	local counter = game:GetTeamUnitDefCount(team,id)
	if self.role then
		return self.ai.taskshst.roles[self.role]
	elseif self.name == 'corcom' or self.name == 'armcom' then
		table.insert(buildersRole.default[self.name], self.id)
		self.role = 'default'
	elseif #buildersRole.eco[self.name] < 1 then
		table.insert(buildersRole.eco[self.name], self.id)
		self.role = 'eco'
	elseif #buildersRole.expand[self.name] < 2 then
		self.role = 'expand'
		table.insert(buildersRole.expand[self.name], self.id)
	elseif #buildersRole.default[self.name] < 1 then
		table.insert(buildersRole.default[self.name], self.id)
		self.role = 'default'
	elseif #buildersRole.support[self.name] < 1 then
		table.insert(buildersRole.support[self.name], self.id)
		self.role = 'support'
	else
		table.insert(buildersRole.expand[self.name], self.id)
		self.role ='expand'
	end
	self:EchoDebug(self.name, 'added to role', self.role,#buildersRole.default[self.name] )
	return self.ai.taskshst.roles[self.role]
end

function TaskQueueBST:ProgressQueue()
	self:EchoDebug(self.name .. " " .. self.id .. " progress queue")
	self.lastWatchdogCheck = self.game:Frame()
	self.constructing = false
	self.progress = false
	local builder = self.unit:Internal()
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
	self:EchoDebug('here start with queue')
	local utype = nil
	local p
	local value = self:getOrder(builder,val)
	self:EchoDebug('value',value)
	if type(value) == "table" then
		self:EchoDebug('table queue ', value,value[1],'think about mex upgrade')
		-- not using this except for upgrading things
	else
		self:EchoDebug(self.name .. " filtering...")
		local success = false
		if val[4] then
			value = self:limitedNumber(value, val[4])
		end
		if val[3] then
			self:EchoDebug("before duplicate filter ", value)
			if self.ai.buildsitehst:CheckForDuplicates(value) then
				value = nil
			end
		end
		if val[2] and value then
			self:EchoDebug("before eco filter ", value)
			value = self:CategoryEconFilter(val[1],val[2],value)
		end
		self:EchoDebug(value, " after filters")
		if value  then
			utype = game:GetTypeByName(value)
		end
		if value and not utype   then
			self:EchoDebug('warning' , self.name , " cannot build:",value,", couldnt grab the unit type from the engine")
			self.progress = true
			return
		end
		if not self.unit:Internal():CanBuild(utype) then
			self:EchoDebug("WARNING: bad taskque: ",self.name," cannot build ",value)
			self.progress = true
			return
		end
		if value and utype and not p then
			self:EchoDebug('p',p)
			utype, value, p = self:findPlace(utype, value,val[1])
			self:EchoDebug('p',p)
		end
		if utype ~= nil and p ~= nil then
			if type(value) == "table" and value[1] == "ReclaimEnemyMex" then
				self:EchoDebug("reclaiming enemy mex...")
				success = self.ai.tool:CustomCommand(self.unit:Internal(), CMD_RECLAIM, {value[2].unitID}) --TODO redo with shardify one
				value = value[1]
			else
				self.ai.buildsitehst:NewPlan(value, p, self)
				local facing = self.ai.buildsitehst:GetFacing(p)
				success = self.unit:Internal():Build(utype, p, facing)
			end
		end
		if success then
			self:EchoDebug(self.name .. " " .. self.id .. " successful build command for " .. utype:Name())
			self.target = p
			self.watchdogTimeout = math.max(self.ai.tool:Distance(self.unit:Internal():GetPosition(), p) * 1.5, 360)
			self.currentProject = value
			self.progress = false
			self.failures = 0
			if value == "ReclaimEnemyMex" then
				self.watchdogTimeout = self.watchdogTimeout + 450 -- give it 15 more seconds to reclaim it
			end
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
