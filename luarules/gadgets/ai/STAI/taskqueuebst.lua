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
	self.fails = 0
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
	self.unit:ElectBehaviour()
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
	self.progress = false
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
	self:EchoDebug(self.name, self.id," completed construction of ", self.constructing.unitName ,self.constructing.unitID)
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
		return 50
	elseif self.currentProject == nil  or self.role == 'expand' then
		return 50
	elseif self.role == 'eco' then
		return 1000
	else
		return 75
	end
end

function TaskQueueBST:Update()
	local f = self.game:Frame()

-- 	if f % 180 == 0 then
-- 		self:VisualDBG()
-- 	end
	if not self:IsActive() then
		return
	end
	if self.progress == true  and not self.failOut then
		self:EchoDebug('progress update')
		self:ProgressQueue()
		return
	end
	if f % 60 == 0 then
		if self.failOut and f > self.failOut + 360 then
			self:EchoDebug("getting back to work " .. self.name .. " " .. self.id)
			self.failOut = false
			self.fails = 0
			self.progress = true
		elseif not self.constructing and not self.failOut then
			self:EchoDebug('not constructing?')
			if (self.lastWatchdogCheck + self.watchdogTimeout < f) or (self.currentProject == nil and (self.lastWatchdogCheck + 1 < f)) then
				self:EchoDebug('watchdog')
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

	end

end

function TaskQueueBST:CategoryEconFilter(cat,param,name)
	self:EchoDebug(cat ,name,self.role, " (before econ filter)")
	if not name then return end
	local M = self.ai.Metal
	local E = self.ai.Energy
	local check = false
	if cat == 'factoryMobilities' then
		check =  M.income > 3 and E.income > 30
	elseif cat == '_mex_' then
		check =   (M.full < 0.5 or M.income < 6) or self.role == 'expand'
	elseif cat == '_nano_' then
 		check =  (E.full > 0.3  and M.full > 0.3 and M.income > 10 and E.income > 100) or
 				(self.ai.tool:countMyUnit({name}) == 0 and (M.income > 10 and E.income > 100)) or
 				self.ai.tool:countMyUnit({name}) < E.income / 200
	elseif cat == '_wind_' then
		check =   map:AverageWind() > 7 and ((E.full < 0.5 or E.income < E.usage )  or E.income < 30)
	elseif cat == '_tide_' then
		check =  map:TidalStrength() >= 10 and  ((E.full < 0.5 or E.income < E.usage )  or E.income < 30)
	elseif cat == '_solar_' then
		check =   ((E.full < 0.5 or E.income < E.usage * 1.1 )  or E.income < 40 ) and self.ai.Energy.income < 3000
	elseif cat == '_estor_' then
		check =   E.full > 0.8 and E.income > 400  and M.full > 0.1
	elseif cat == '_mstor_' then
		check =   E.full > 0.5  and M.full > 0.75 and M.income > 20 and E.income > 200
	elseif cat == '_convs_' then
		check =   E.income > E.usage * 1.1 and E.full > 0.8
	elseif cat == '_fus_' then
		check =  (E.full < 0.5 or E.income < E.usage) or E.full < 0.3
	elseif cat == '_geo_' then
		check =  E.income > 100 and M.income > 15 and E.full > 0.3 and M.full > 0.2
	elseif cat == '_jam_' then
		check =  M.full > 0.5 and M.income > 50 and E.income > 500
	elseif cat == '_radar_' then
		check =  M.full > 0.1 and M.income > 9 and E.income > 50
	elseif cat == '_sonar_' then
		check =  M.full > 0.3 and M.income > 15 and E.income > 100

	elseif cat == '_llt_' then
		check =   (E.income > 5 and M.income > 1)
	elseif cat == '_popup1_' then
		check =   (E.income > 200 and M.income > 25  )
	elseif cat == '_specialt_' then
		check =   E.income > 40 and M.income > 4 and M.full > 0.1
	elseif cat == '_heavyt_' then
		check =   E.income > 100 and M.income > 15 and M.full > 0.3
	elseif cat == '_popup2_' then
		check =  M.full > 0.1
	elseif cat == '_laser2_' then
		check =   E.income > 2000 and M.income > 50 and E.full > 0.5 and M.full > 0.3
	elseif cat == '_coast1_' then
		check =  false
	elseif cat == '_coast2_' then
		check =  false
	elseif cat == '_plasma_' then
		check =  E.income > 5000 and M.income > 120 and E.full > 0.8 and M.full > 0.5
	elseif cat == '_lol_' then
		check =  E.income > 15000 and M.income > 200 and E.full > 0.8 and M.full > 0.5

	elseif cat == '_torpedo1_' then
		check =  (E.income > 20 and M.income > 2 and M.full < 0.5)
	elseif cat == '_torpedo2_' then
		check =  E.income > 100 and M.income > 15 and M.full > 0.2
	elseif cat == '_torpedoground_' then
		check =  false

	elseif cat == '_aa1_' then
		check =  E.full > 0.1 and E.full < 0.5 and M.income > 25 and E.income > 100
	elseif cat == '_aabomb_' then
		check =  E.full > 0.5 and M.full > 0.5
	elseif cat == '_flak_' then
		check =  E.full > 0.1 and E.full < 0.5 and E.income > 2000

	elseif cat == '_aaheavy_' then
		check =  E.income > 500 and M.income > 25 and E.full > 0.3 and M.full > 0.3
	elseif cat == '_aa2_' then
		check =  E.income > 7000 and M.income > 100 and E.full > 0.3 and M.full > 0.3
	elseif cat == '_silo_' then
		check =  E.income > 10000 and M.income > 100 and E.full > 0.8 and M.full > 0.5
	elseif cat == '_antinuke_' then
		check =  E.income > 4000 and M.income > 75 and E.full > 0.6 and M.full > 0.3
	elseif cat == '_shield_' then
		check =  E.income > 8000 and M.income > 100 and E.full > 0.6 and M.full > 0.5
	elseif cat == '_juno_' then
		check =  false
	else
		self:EchoDebug('economi category not handled')
	end
	if check then
		self:EchoDebug('ecofilter',name)
		return name
	else
		self:EchoDebug('ecofilter stop')
	end
end

function TaskQueueBST:specialFilter(cat,param,name)
	self:EchoDebug(cat ,name, self.role, " (before special filter)")
	if not name then return end
	local tasks = self.ai.taskshst
	local check = false
	if cat == 'factoryMobilities' then
		check =  true
	elseif cat == '_mex_' then
		check =  true
	elseif cat == '_nano_' then
		check =  true
	elseif cat == '_wind_' then
		check =   true
	elseif cat == '_tide_' then
		check =  true
	elseif cat == '_solar_' then
		local newName = self.ai.armyhst[cat][name]
		self:EchoDebug('newName',newName)
		if self.unit:Internal():CanBuild(self.game:GetTypeByName(newName)) then
			if self.ai.Metal.reserves > 100 and self.ai.Energy.income > 200 and self.role == 'eco' then
				name = newName
			end
		end
		check =  true
	elseif cat == '_estor_' then
		check = true
	elseif cat == '_mstor_' then
		check = true
	elseif cat == '_convs_' then
		check = true
	elseif cat == '_llt_' then
		check = true
	elseif cat == '_popup1_' then
		check = true
	elseif cat == '_specialt_' then
		check = true
	elseif cat == '_heavyt_' then
		check =  true
	elseif cat == '_fus_' then
		local newName = self.ai.armyhst[cat][name]
		self:EchoDebug('newName',newName)
		if self.unit:Internal():CanBuild(game:GetTypeByName(newName)) then
			if self.ai.Metal.reserves > 1000 and self.ai.Energy.income > 4000 and self.role == 'eco' then
				name = newName
			end
		end
		check =  true
	elseif cat == '_popup2_' then
		check =  true
	elseif cat == '_jam_' then
		check = true
	elseif cat == '_radar_' then
		check = true
	elseif cat == '_geo_' then
		check = true
	elseif cat == '_silo_' then
		check = true
	elseif cat == '_antinuke_' then
		check = true
	elseif cat == '_sonar_' then
		check =  true
	elseif cat == '_shield_' then
		check = tasks.needShields
	elseif cat == '_juno_' then
		check =  false
	elseif cat == '_laser2_' then
		check = true
	elseif cat == '_lol_' then
		check = true
	elseif cat == '_coast1_' then
		check =  false
	elseif cat == '_coast2_' then
		check =  false
	elseif cat == '_plasma_' then
		check =  true
	elseif cat == '_torpedo1_' then
		check =  true
	elseif cat == '_torpedo2_' then
		check =  true
	elseif cat == '_torpedoground_' then
		check =  true
	elseif cat == '_aa1_' then
		check =  self.ai.needAirDefense
	elseif cat == '_flak_' then
		check = self.ai.needAirDefense
	elseif cat == '_aabomb_' then
		check = self.ai.needAirDefense
	elseif cat == '_aaheavy_' then
		check = true
	elseif cat == '_aa2_' then
		check = true
	else
		self:EchoDebug('special filter not handled')
	end
	if check then
		self:EchoDebug('special filter pass',cat,name)
		return  name
	else
		self:EchoDebug('special filter block',cat,name)
	end
end

function TaskQueueBST:findPlace(utype, value,cat)
	if not value or not cat or not utype then return end
	local POS = nil
	local builder = self.unit:Internal()
	local builderPos = builder:GetPosition()
	local army = self.ai.armyhst
	local site = self.ai.buildsitehst
	local closestFactory = self.ai.buildsitehst:ClosestHighestLevelFactory(builderPos)
	--factory will get position in labbuildhst
	if cat == '_mex_' then
		local uw
		local reclaimEnemyMex
		POS, uw, reclaimEnemyMex = self.ai.maphst:ClosestFreeSpot(utype, builder)
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

   			POS = site:ClosestBuildSpot(builder, factoryPos, utype,nil,nil,nil,390)

		end
		if not POS then
			local factoryPos = site:ClosestHighestLevelFactory(builder:GetPosition(), 5000)
			if factoryPos then
				self:EchoDebug("searching for top level factory")
				POS = site:ClosestBuildSpot(builder, factoryPos, utype,nil,nil,nil,390)
			end
		end
	elseif cat == '_wind_' then
		POS = 	site:searchPosNearCategories(utype, builder,nil, nil,{'_wind_'}) or
				site:searchPosNearCategories(utype, builder,nil, nil,{'_nano_'}) or
				site:searchPosNearCategories(utype, builder,nil, nil,{'factoryMobilities'}) or
				site:ClosestBuildSpot(builder, builderPos, utype)
	elseif cat == '_tide_' then
		POS = 	site:searchPosNearCategories(utype, builder,nil, nil,{'_tide_'}) or
				site:searchPosNearCategories(utype, builder,nil, nil,{'_nano_'}) or
				site:searchPosNearCategories(utype, builder,nil, nil,{'factoryMobilities'}) or
				site:ClosestBuildSpot(builder, builderPos, utype)
	elseif cat == '_solar_' then
		POS = 	site:searchPosNearCategories(utype, builder,nil, nil,{'_solar_'}) or
				site:searchPosNearCategories(utype, builder,nil, nil,{'_nano_'}) or
				site:searchPosNearCategories(utype, builder,nil, nil,{'factoryMobilities'}) or
				site:ClosestBuildSpot(builder, builderPos, utype)
	elseif cat == '_fus_' then
		POS = 	site:searchPosNearCategories(utype, builder,nil, nil,{'_nano_'}) or
				site:searchPosNearCategories(utype, builder,nil, nil,{'factoryMobilities'})
	elseif cat == '_estor_' then
		POS = 	site:searchPosNearCategories(utype, builder,nil, nil,{'_estor_'}) or
				site:searchPosNearCategories(utype, builder,nil, nil,{'_nano_'}) or
				site:searchPosNearCategories(utype, builder,nil, nil,{'factoryMobilities'}) or
				site:ClosestBuildSpot(builder, builderPos, utype)
	elseif cat == '_mstor_' then
		POS = 	site:searchPosNearCategories(utype, builder,nil, nil,{'_mstor_'}) or
				site:searchPosNearCategories(utype, builder,nil, nil,{'_nano_'}) or
				site:searchPosNearCategories(utype, builder,nil, nil,{'factoryMobilities'}) or
				site:ClosestBuildSpot(builder, builderPos, utype)
	elseif cat == '_convs_' then
		POS = 	site:searchPosNearCategories(utype, builder,nil, nil,{'_convs_'}) or
				site:searchPosNearCategories(utype, builder,nil, nil,{'_nano_'}) or
				site:searchPosNearCategories(utype, builder,nil, nil,{'factoryMobilities'}) or
				site:ClosestBuildSpot(builder, builderPos, utype)
	elseif cat == '_llt_' then
		POS = 	site:searchPosNearCategories(utype, builder, 50, nil,{'_mex_'},{'_llt_','_popup2_','_popup1_'}) or
				site:searchPosInList(utype, builder, 50,nil,self.map:GetMetalSpots(),{'_llt_','_popup2_','_popup1_'})


	elseif cat == '_popup1_' then
 		POS = site:searchPosNearCategories(utype, builder, 50, nil,{'_mex_'},{'_llt_','_popup2_','_popup1_'})
-- 		POS = site:buildOnCircle(self.ai.buildsitehst:ClosestHighestLevelFactory(builderPos),500,8,value)
	elseif cat == '_specialt_' then
		POS = site:searchPosNearCategories(utype, builder,100,nil,{'factoryMobilities'},{'_specialt_'})
	elseif cat == '_heavyt_' then
		POS = site:searchPosInList(utype, builder, nil,nil,self.ai.hotSpot,{'_heavyt_','_laser2_'})
	elseif cat == '_popup2_' then
		POS = site:searchPosNearCategories(utype, builder,50,nil,{'_mex_'},{'_popup2_'})
	elseif cat == '_jam_' then
		POS =  site:searchPosNearCategories(utype, builder,100,nil,{'factoryMobilities'},{'_jam_'})
	elseif cat == '_radar_' then
		POS = site:searchPosNearCategories(utype, builder,50,'radarRadius',{'_mex_'},{'_radar_'})
	elseif cat == '_sonar_' then
		POS = site:searchPosNearCategories(utype, builder,50,nil,{'_mex_'},{'_sonar_'})
	elseif cat == '_geo_' then
		POS =  self.ai.maphst:ClosestFreeGeo(utype, builder)
	elseif cat == '_silo_' then
		POS =  site:searchPosNearCategories(utype, builder,100,nil,{'_nano_'})
	elseif cat == '_antinuke_' then
		POS =  site:searchPosNearCategories(utype, builder,100,nil,{'_nano_'})
	elseif cat == '_shield_' then
		POS =  site:searchPosNearCategories(utype, builder,50,nil,{'_nano_'},{'_shield_'})
	elseif cat == '_juno_' then
		POS =  site:searchPosNearCategories(utype, builder,50,nil,{'_nano_'})
	elseif cat == '_laser2_' then
		POS =   site:searchPosNearCategories(utype, builder,50,nil,{'_nano_'},{'_laser2_'}) or
				site:searchPosInList(utype, builder, nil,nil,self.ai.hotSpot,{'_laser2_'})
	elseif cat == '_lol_' then
		POS =  site:searchPosNearCategories(utype, builder,50,nil,{'_nano_'})
 	elseif cat == '_coast1_' then
 		POS = site:searchPosInList(utype, builder, nil,nil,self.ai.turtlehst:LeastTurtled(builder, value),{'_coast1_','_coast2_'})
 	elseif cat == '_coast2_' then
 		POS = site:searchPosInList(utype, builder, nil,nil,self.ai.turtlehst:LeastTurtled(builder, value),{'_coast2_'})
	elseif cat == '_plasma_' then
		POS =  site:searchPosNearCategories(utype, builder,50,nil,{'_nano_'})
	elseif cat == '_torpedo1_' then
		POS = site:searchPosNearCategories(utype, builder,50,nil,{'_mex_'})
	elseif cat == '_torpedo2_' then
		POS = site:searchPosNearCategories(utype, builder,50,nil,{'_mex_'},{'_torpedo2_'})
	elseif cat == '_torpedoground_' then
		POS = site:searchPosNearCategories(utype, builder,50,nil,{'_mex_'},{'_torpedoground_'})
	elseif cat == '_aabomb_' then
		POS =  site:searchPosNearCategories(utype, builder,50,nil,{'_heavyt_'},{'_aabomb_'}) or
			site:searchPosNearCategories(utype, builder,50,nil,{'_laser2_'},{'_aabomb_'})
	elseif cat == '_aaheavy_' then
		POS = site:searchPosNearCategories(utype, builder,50,nil,{'factoryMobilities'},{'_aaheavy_'})
	elseif cat == '_aa2_' then
		POS =  site:searchPosNearCategories(utype, builder,50,nil,{'factoryMobilities'},{'_aa2_'})
	elseif cat == '_aa1_' then
		POS = site:searchPosNearCategories(utype, builder,20,nil,{'_mex_'},{'_aa1_'})
	elseif cat == '_flak_' then
		POS = site:searchPosNearCategories(utype, builder,20,nil,{'_mex_'},{'_flak_'})
	else
		self:EchoDebug(' cant manage POS for ',value,cat)
	end
	if POS then
		self:EchoDebug('found pos for .. ' ,value)
		return utype, value, POS
	else
		self:EchoDebug('pos not found for .. ' ,value)
	end
end



function TaskQueueBST:limitedNumber(name,number)
	if not name then return end
	self:EchoDebug(number,'limited for ',name)
	local team = self.game:GetTeamID()
	local id = self.ai.armyhst.unitTable[name].defId
	local counter = self.game:GetTeamUnitDefCount(team,id)
	if counter < number then
		self:EchoDebug('limited OK',name)
		return name
	end
	self:EchoDebug('limited stop',name)
end

function TaskQueueBST:getOrder(builder,params)
	if params[1] == 'factoryMobilities' then
		--self.game:StartTimer('getOrder1')
		if params[2] then
			local p = nil
			local  value = nil
			p, value = self.ai.labbuildhst:GetBuilderFactory(builder)
			if p and value then
				self:EchoDebug('factory', value, 'is returned from labbuildhst')
				return  value, p
			end
		end
		--self.game:StopTimer('getOrder1')
	else
		--self.game:StartTimer('getOrder2')
		self:EchoDebug(params[1])
		local army = self.ai.armyhst
		for index, uName in pairs (army.unitTable[self.name].buildingsCanBuild) do
			if army[params[1]][uName] then
				return uName
			end
		end
		----self.game:StopTimer('getOrder2')
	end

end

function TaskQueueBST:GetQueue()
-- 	self.unit:ElectBehaviour()
	local buildersRole = self.ai.armyhst.buildersRole
	local team = self.game:GetTeamID()
	local id = self.ai.armyhst.unitTable[self.name].defId
	local counter = self.game:GetTeamUnitDefCount(team,id)
	if self.role then
		return self.ai.taskshst.roles[self.role]
	elseif self.isCommander then
		table.insert(buildersRole.default[self.name], self.id)
		self.role = 'default'
	elseif #buildersRole.eco[self.name] < 1 then
		table.insert(buildersRole.eco[self.name], self.id)
		self.role = 'eco'
	elseif #buildersRole.expand[self.name] < 1 then
		self.role = 'expand'
		table.insert(buildersRole.expand[self.name], self.id)
	elseif #buildersRole.default[self.name] < 1 then
		table.insert(buildersRole.default[self.name], self.id)
		self.role = 'default'
	elseif #buildersRole.support[self.name] < 1 then
		table.insert(buildersRole.support[self.name], self.id)
		self.role = 'support'

	elseif #buildersRole.expand[self.name] < 2 then
		self.role = 'expand'
		table.insert(buildersRole.expand[self.name], self.id)
	elseif #buildersRole.eco[self.name] < 3 then
		table.insert(buildersRole.eco[self.name], self.id)
		self.role = 'eco'
	elseif #buildersRole.support[self.name] < 2 then
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
	--self.game:StartTimer('tqb1')
	self:EchoDebug(self.name," progress queue")
	self.lastWatchdogCheck = self.game:Frame()
	self.constructing = false
	self.progress = false
	self.ai.buildsitehst:ClearMyPlans(self)
	--self.game:StartTimer('tqb7')
	local builder = self.unit:Internal()
	local idx, val = next(self.queue,self.idx)
	self:EchoDebug(idx , val)
	self.idx = idx
	if idx == nil then
		self.queue = self:GetQueue(name)--TODO ?????????????????????self.name?
		self.progress = true

		return
	end
	local utype = nil
	local value = val
	local utype = nil
	local p
	local value, p = self:getOrder(builder,val)
	self:EchoDebug('value',value)
	--self.game:StartTimer('tqb3')
	--self.game:StopTimer('tqb7')
	if type(value) == "table" then
		self:EchoDebug('table queue ', value,value[1],'think about mex upgrade')
		-- not using this except for upgrading things
	else
		--self.game:StartTimer('tqb4')
		self:EchoDebug(self.name .. " filtering...")

		local success = false
		if val[6] and value then
			value = self:specialFilter(val[1],val[6],value)
		end
		if val[4] and value then
			value = self:limitedNumber(value, val[4])
		end
		if val[3] and value then
			if self.ai.buildsitehst:CheckForDuplicates(value) then
				value = nil
			end
		end
		if val[2] and value then
			value = self:CategoryEconFilter(val[1],val[2],value)
		end
		if value  then
			utype = self.game:GetTypeByName(value)
		end
		--self.game:StopTimer('tqb4')
		--self.game:StartTimer('tqbPOS')
		if value and utype and not p then
			utype, value, p = self:findPlace(utype, value,val[1])
			self:EchoDebug('p',p)

		end
		--self.game:StopTimer('tqbPOS')
		--self.game:StartTimer('tqb5')
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
			self:EchoDebug(self.name , " successful build command for ", utype:Name())
			self.target = p
			self.watchdogTimeout = math.max(self.ai.tool:Distance(self.unit:Internal():GetPosition(), p) * 1.5, 460)
			self.currentProject = value
			self.fails = 0
			self.failOut = nil
			self.progress = false
			self.assistant = false
			if value == "ReclaimEnemyMex" then
				self.watchdogTimeout = self.watchdogTimeout + 450 -- give it 15 more seconds to reclaim it
			end
		else
			self.progress = true
			self.target = nil
			self.currentProject = nil
			self.fails = self.fails + 1


			if self.fails >  #self.queue +1 then
				self.failOut = self.game:Frame()
				self.progress = false
				self:assist()
			end
		end
	end
end

function TaskQueueBST:assist()
	if self.assistant then return end
	local unitsNear = self.game:getUnitsInCylinder(self.unit:Internal():GetPosition(), 2500)
	for index, unitID in pairs(unitsNear) do
		local unitName = self.game:GetUnitByID(unitID):Name()
		if self.role == 'eco' then
-- 			if self.ai.armyhst.factoryMobilities[unitName] then
-- 				self.unit:Internal():Guard(unitID)
-- 				self.assistant = true
				return
-- 			end
		elseif self.ai.armyhst.techs[unitName] and Spring.GetUnitIsBuilding(unitID) then
			self.unit:Internal():Guard(unitID)
			self.assistant = true
			return
		end
	end
end


function TaskQueueBST:VisualDBG()
	local colours = {
	default = {255,0,0,255},
	eco = {0,255,0,255},
	support = {0,0,255,255},
	expand = {255,255,255,255},
	}
	self.unit:Internal():EraseHighlight(nil, self.id, 8 )
	self.unit:Internal():DrawHighlight(colours[self.role] , self.id, 8 )

end
