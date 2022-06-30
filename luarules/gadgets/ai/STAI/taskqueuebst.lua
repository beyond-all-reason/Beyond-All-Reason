TaskQueueBST = class(Behaviour)

function TaskQueueBST:Name()
	return "TaskQueueBST"
end

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
	self.visualdbg = true
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
	self.idx = 1
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
				table.remove(self.ai.armyhst.buildersRole[self.role][self.name],i)
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

function TaskQueueBST:removeOldBuildersRole()
	for role,roleTable in pairs(self.ai.armyhst.buildersRole) do
		for name,nameTable in pairs (roleTable) do
			for index,unitID in pairs(nameTable) do
				if self.id == unitID then
					table.remove(self.ai.armyhst.buildersRole[role][name],index)
				end
			end
		end
	end
	self.role = nil
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
		self.unit:Internal():Guard(self.constructing.unitID)
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

	if self.ai.schedulerhst.behaviourTeam ~= self.ai.id or self.ai.schedulerhst.behaviourUpdate ~= 'TaskQueueBST' then return end
	--print('schedulertaskq',f,self.ai.id)
	self:VisualDBG()
	if not self:IsActive() then
		return
	end
	if self.progress == true  and not self.failOut then
		self:EchoDebug('progress update')
		self:ProgressQueue()
		return
	end

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

function TaskQueueBST:CategoryEconFilter(cat,param,name)
	self:EchoDebug(cat ,name,self.role,self.ai.taskshst.roles[self.role][self.idx]:economy(), " (before econ filter)")
	if not name  or not param then
		self:EchoDebug('ecofilter stop',name,cat, param)
		return
	end
	local ecoCheck = self.ai.taskshst.roles[self.role][self.idx]:economy(param,name)
	self:EchoDebug('eco filter',name,cat,ecoCheck)
	if ecoCheck then
		return name
	end
end

function TaskQueueBST:specialFilter(cat,param,name)
	self:EchoDebug(cat ,name, self.role, " (before special filter)")
	if not name then return end
	local tasks = self.ai.taskshst
	local check = false
	if cat == '_solar_' then
		local newName = self.ai.armyhst[cat][name]
		self:EchoDebug('newName',newName)
		if self.unit:Internal():CanBuild(self.game:GetTypeByName(newName)) then
			if self.ai.Metal.reserves > 100 and self.ai.Energy.income > 200 and self.role == 'eco' then
				name = newName
			end
		end
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
 	elseif (cat == '_convs_' ) then
 		if self.ai.tool:countMyUnit( {'_fus_'}  ) < 2 and self.ai.armyhst.unitTable[name].techLevel == 1 then
 			check= true
		elseif  self.ai.armyhst.unitTable[name].techLevel > 1 then
			check= true
 		end
				--local factoryPos = factory.unit:Internal():GetPosition()
				--local nanoNear = buildSiteHST:unitsNearCheck(factoryPos,400,level * 10,'_nano_')
	elseif cat == '_wind_' then
		check = map:AverageWind() > 7
	elseif cat == '_tide_' then
		check = map:TidalStrength() >= 10
	elseif cat == '_aa1_' then
		check =  self.ai.needAntiAir
	elseif cat == '_flak_' then
		check = self.ai.needAntiAir
	elseif cat == '_aabomb_' then
		check = self.ai.needAntiAir
	end
	if check then
		self:EchoDebug('special filter pass',cat,name)
		return  name
	else
		self:EchoDebug('special filter block',cat,name)
	end
end

function TaskQueueBST:findPlace(utype, value,cat,loc)
	if not value or not cat or not utype then return end
	local POS = nil
	local builder = self.unit:Internal()
	local builderPos = builder:GetPosition()
	local army = self.ai.armyhst
	local site = self.ai.buildsitehst
	local closestFactory = self.ai.buildsitehst:ClosestHighestLevelFactory(builderPos)
	if loc and type(loc) == 'table' then
		if loc.categories then
			for index, category in pairs(loc.categories) do
				if category == 'selfCat' then
					category = cat
				end
				POS = site:searchPosNearCategories(utype, builder,loc.min, loc.max,{category},loc.neighbours, loc.number)
				if POS then
					break
				end
			end
		end
		if not POS and loc.list then
			POS = site:searchPosInList(utype, builder, loc.min,loc.max,loc.list,loc.neighbours)
		end
		if not POS and loc.himself then
			POS = site:ClosestBuildSpot(builder, builderPos, utype)
		end
	end
	--factory will get position in labbuildhst
	if cat == '_mex_' then
		local uw
		local reclaimEnemyMex
		POS, uw, reclaimEnemyMex = self.ai.maphst:ClosestFreeSpot(utype, builder)
		self:EchoDebug(POS, uw, reclaimEnemyMex)
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
					if not self.ai.buildsitehst:unitsNearCheck(factory.unit:Internal():GetPosition(),390,10+(5*level),{'_nano_'}) then
						self:EchoDebug( self.name .. ' can push up self mtype ' .. factoryName)
						currentLevel = level
						target = factory
					end
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
	end
	if POS then
		self:EchoDebug('found pos for .. ' ,value)
		return utype, value, POS
	else
		self:EchoDebug('pos not found for .. ' ,value)
	end
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
	if params.category == 'factoryMobilities' then
		if params.economy then
			local p = nil
			local  value = nil
			p, value = self.ai.labbuildhst:GetBuilderFactory(builder)
			if p and value then
				self:EchoDebug('factory', value, 'is returned from labbuildhst')
				return  value, p
			end
		end
	else
		self:EchoDebug(params.category)
		local army = self.ai.armyhst
		for index, uName in pairs (army.unitTable[self.name].buildingsCanBuild) do
			if army[params.category][uName] then
				return uName
			end
		end
	end
end

function TaskQueueBST:roleCounter(role)
	if not self.ai.armyhst.buildersRole[role] then
		return 0
	end
	local counter = 0
	for name, units in pairs(self.ai.armyhst.buildersRole[role]) do
		counter = counter + #units
	end
	return counter
end

function TaskQueueBST:GetQueue()
	local buildersRole = self.ai.armyhst.buildersRole
	local team = self.game:GetTeamID()
	local id = self.ai.armyhst.unitTable[self.name].defId
	local counter = self.game:GetTeamUnitDefCount(team,id)
	if self.isCommander then
		if  self.ai.tool:countMyUnit({'_llt_'}) < 1 then --self.ai.tool:countMyUnit({'techs'}) < 1 and
			self:removeOldBuildersRole(self.name,self.id)
			table.insert(buildersRole.starter[self.name], self.id)
			self.role = 'starter'
		elseif self.ai.Energy.full < 0.3  then
			self:removeOldBuildersRole(self.name,self.id)
			table.insert(buildersRole.eco[self.name], self.id)
			self.role = 'eco'
		elseif self.ai.Energy.full > 0.3 and self.ai.Metal.full < 0.3 then
			self:removeOldBuildersRole(self.name,self.id)
			table.insert(buildersRole.expand[self.name], self.id)
			self.role = 'expand'
		else
			self:removeOldBuildersRole(self.name,self.id)
			table.insert(buildersRole.default[self.name], self.id)
			self.role = 'default'
		end
	end
	if self.role then
		return self.ai.taskshst.roles[self.role]
	elseif #buildersRole.eco[self.name] < 1 then
		table.insert(buildersRole.eco[self.name], self.id)
		self.role = 'eco'
	elseif #buildersRole.expand[self.name] < 2 then
		table.insert(buildersRole.expand[self.name], self.id)
		self.role = 'expand'
	elseif #buildersRole.support[self.name] < 1 then
		table.insert(buildersRole.support[self.name], self.id)
		self.role = 'support'
	elseif #buildersRole.default[self.name] < 1 then
		table.insert(buildersRole.default[self.name], self.id)
		self.role = 'default'
	else
		table.insert(buildersRole.expand[self.name], self.id)
		self.role ='expand'
	end
	self:EchoDebug(self.name, 'added to role', self.role,#buildersRole.default[self.name] )
	return self.ai.taskshst.roles[self.role]
end

function TaskQueueBST:ProgressQueue()

	self:EchoDebug(self.name," progress queue",self.role,self.idx,#self.queue)
	self.lastWatchdogCheck = self.game:Frame()
	self.constructing = false
	self.progress = true
	self.ai.buildsitehst:ClearMyPlans(self)
	self.queue = self:GetQueue()
	local builder = self.unit:Internal()
	if self.idx > #self.queue then
		self.idx = 1
	end
	for index = self.idx, #self.queue + 1 do
		if  not self.progress then
			self.idx = index
			return
		end
		self:EchoDebug('role',self.role,'self.idx',self.idx ,'JOB', JOB)
		JOB = self.queue[index]
		if JOB == nil then
			self.progress = true
			self.idx = 1
			return
		end
		self.idx = index
		local utype = nil
		local p
		local jobName, p = self:getOrder(builder,JOB)
		self:EchoDebug('jobName',jobName)
		if type(jobName) == "table" then
			self:EchoDebug('table queue ', jobName,jobName[1],'think about mex upgrade')
			-- not using this except for upgrading things
		else
			self:EchoDebug(self.name .. " filtering...")
			local success = false
			if JOB.special and jobName then
				jobName = self:specialFilter(JOB.category,JOB.special,jobName)
			end
			if JOB.numeric and jobName then
				jobName = self:limitedNumber(jobName, JOB.numeric)
			end
			if JOB.duplicate and jobName then
				if self.ai.buildsitehst:CheckForDuplicates(jobName) then
					jobName = nil
				end
			end
			if JOB.economy and jobName then
				jobName = self:CategoryEconFilter(JOB.category,JOB.economy,jobName)
			end
			if jobName  then
				utype = self.game:GetTypeByName(jobName)
			end
			if jobName and utype and not p then
				utype, jobName, p = self:findPlace(utype, jobName,JOB.category,JOB.location)
				self:EchoDebug('p',p)
			end
			if jobName and not utype   then
				self:Warn('warning' , self.name , " cannot build:",jobName,", couldnt grab the unit type from the engine")
				self.progress = true
				return
			end
			if not self.unit:Internal():CanBuild(utype) then
				self:EchoDebug("WARNING: bad taskque: ",self.name," cannot build ",jobName)
				self.progress = true
				return
			end
			if utype ~= nil and p ~= nil then
				if type(jobName) == "table" and jobName[1] == "ReclaimEnemyMex" then
					jobName = jobName[1]
				else
					self.ai.buildsitehst:NewPlan(jobName, p, self)
					local facing = self.ai.buildsitehst:GetFacing(p)
					local command = self.unit:Internal():Build(jobName, p, facing)
				end

				success = true
			end
			if success then
				self:EchoDebug(self.name , " successful build command for ", utype:Name())
				self.target = p
				self.watchdogTimeout = math.max(self.ai.tool:Distance(self.unit:Internal():GetPosition(), p) * 1.5, 460)
				self.currentProject = jobName
				self.fails = 0
				self.failOut = nil
				self.progress = false
				self.assistant = false
-- 				if jobName == "ReclaimEnemyMex" then
-- 					self.watchdogTimeout = self.watchdogTimeout + 450 -- give it 15 more seconds to reclaim it
-- 				end
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
end

function TaskQueueBST:assist()
	if self.assistant then return end
	local builderPos = self.unit:Internal():GetPosition()
	local unitsNear = self.game:getUnitsInCylinder(builderPos, 2500)
	for index, unitID in pairs(unitsNear) do
		local unitName = self.game:GetUnitByID(unitID):Name()
		if self.role == 'eco' then
			if self.ai.armyhst.factoryMobilities[unitName] then
				self.unit:Internal():Guard(unitID)
				self.assistant = true
				return
			end
		elseif self.ai.armyhst.techs[unitName] and Spring.GetUnitIsBuilding(unitID) then
			self.unit:Internal():Guard(unitID)
			self.assistant = true
			return
		end
	end
	for i = 1, 3 do
		local r = 2000 * i
		local doing = self.unit:Internal():AreaResurrect( builderPos, r) or
				self.unit:Internal():AreaReclaim(builderPos, r ) or
				self.unit:Internal():AreaRepair( builderPos, r)
		if doing  then
			self:EchoDebug('assistant')
			self.assitant = true
		else
			self:EchoDebug('assistant not work')
		end

	end
end
-- function TasksHST:repair(id)
-- 	local builder = id:GetUintByID()
-- 	local builderPos = builder:GetPosition()
-- 	local bestDistance = math.huge
-- 	for i,v in pairs(self.game:GetUnits()) do
-- 		if id ~= v then
-- 			local target = v:GetUintByID()
-- 			local health, maxHealth, paralyzeDamage, captureProgress, buildProgress = target:GetHealtsParams()
-- 			if health < maxHealth then
-- 				local targetPos = target:GetPosition()
-- 				local dist = self.ai.tool:Distance(builderPos,targetPos)
-- 				if dist < bestDistance then
-- 					bestTarget = v
-- 					bestDistance = dist
-- 				end
-- 			end
-- 		end
-- 	end
-- 	return bestTarget
-- end
--
-- function TasksHST:reclaim(id)
-- 	local builder = id:GetUintByID()
-- 	local builderPos = builder:GetPosition()
-- 	local bestDistance = math.huge
-- 	for i,v in pairs(self.game:GetUnits()) do
-- 		if id ~= v then
-- 			local target = v:GetUintByID()
-- 			local health, maxHealth, paralyzeDamage, captureProgress, buildProgress = target:GetHealtsParams()
-- 			if health < maxHealth then
-- 				local targetPos = target:GetPosition()
-- 				local dist = self.ai.tool:Distance(builderPos,targetPos)
-- 				if dist < bestDistance then
-- 					bestTarget = v
-- 					bestDistance = dist
-- 				end
-- 			end
-- 		end
-- 	end
-- 	return bestTarget
-- end

function TaskQueueBST:VisualDBG()
	if not self.visualdbg then
		return
	end
	local colours = {
		starter = {1,1,0,1},
		default = {1,0,0,1},
		eco = {0,1,0,1},
		support = {0,0,1,1},
		expand = {0,1,1,1},
		}
	self.unit:Internal():EraseHighlight(nil, nil, 8 )
	self.unit:Internal():DrawHighlight(colours[self.role] , self.role, 8 )

end
