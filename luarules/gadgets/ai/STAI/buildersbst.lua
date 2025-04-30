BuildersBST = class(Behaviour)

function BuildersBST:Name()
	return "BuildersBST"
end

function BuildersBST:Init()
	self.DebugEnabled = false
	self.active = false
	self.watchdogTimeout = 1800
	local u = self.unit:Internal()
	self.position = u:GetPosition()
	local mtype, network = self.ai.maphst:MobilityOfUnit(u)
	self.id = u:ID()
	self.mtype = mtype
	self.name = u:Name()
	self.idx = 0
	self.fails = 0
	if self.ai.armyhst.commanderList[self.name] then self.isCommander = true end
	self.role = self.ai.buildingshst:SetRole(self.id)
	self.queue = self.ai.taskshst.roles[self.role]
	self:EchoDebug(self.name .. " " .. self.id .. " initializing...")
	self.unit:ElectBehaviour()

end

function BuildersBST:OwnerBuilt()
	self:EngineerhstBuilderBuild()

end

function BuildersBST:EngineerhstBuilderBuild()
	for engineerName,builderName in pairs(self.ai.armyhst.engineers) do
		if self.name == builderName then
			self.ai.engineerhst.Builders[self.id] = {}
			self.ai.engineerhst:EngineersNeeded()
			return
		end
	end
end



function BuildersBST:OwnerDead()
	if self.unit ~= nil then
		self.ai.buildingshst.roles[self.id] = nil
		self.ai.engineerhst.Builders[self.id] = nil
		self.ai.buildingshst:ClearMyProjects(self.id)

	end
end

function BuildersBST:OwnerIdle()
	if not self:IsActive() then
		return
	end
	if self.unit == nil then return end
 	self.ai.buildingshst:ClearMyProjects(self.id)
	self.unit:ElectBehaviour()
end

function BuildersBST:Activate()
	local buildings = self.ai.buildingshst
	if buildings.builders[self.id]then
		self:EchoDebug(self.name, self.id, " resuming construction of ", buildings.builders[self.id].unitName,buildings.builders[self.id].unitID)
		-- resume construction if we were interrupted
		self.unit:Internal():Guard(buildings.builders[self.id].unitID)
	else
		self:UnitIdle(self.unit:Internal())
	end
end

function BuildersBST:Deactivate()
 	self.ai.buildingshst:ClearMyProjects(self.id)
end

function BuildersBST:Priority()
	return 100
end
function BuildersBST:Watchdog()
	if self.watchdogTimeout < game:Frame() then
		self.ai.buildingshst:ClearMyProjects(self.id)
	end
end

function BuildersBST:Evade()
	--[[
	local home = self.ai.labshst:ClosestHighestLevelFactory(self.unit:Internal())
	if home then
		self.unit:Internal():Guard(home.id)
		self.ai.buildingshst:ClearMyProjects(self.id)
		return
-- 		home = home.position
	else
		home = self.ai.tool:UnitPos(self)
		home = self.ai.tool:RandomAway(home,300)
		self.unit:Internal():Move(home)
		self.ai.buildingshst:ClearMyProjects(self.id)
	end
	]]
	self:Assist()

end

function BuildersBST:Update()
	if self.ai.schedulerhst.behaviourTeam ~= self.ai.id or self.ai.schedulerhst.behaviourUpdate ~= 'BuildersBST' then
		return
	end
	local f = self.game:Frame()
	self.position.x,self.position.y,self.position.z = self.unit:Internal():GetRawPos()
	if not self:IsActive() then
		return
	end
	self.builder, self.sketch = self.ai.buildingshst:GetMyProject(self.id)
	local health,maxHealth,paralyzeDamage, captureProgress, buildProgress,relativeHealth = self.unit:Internal():GetHealtsParams()
	if 	relativeHealth < 0.99 and buildProgress == 1 and not self.isCommander then
		self:Evade()
		return
	end
	if not self.sketch and not self.builder and self.failOut then
		self:EchoDebug(self.name,'failout')
		if f > self.failOut + 600 then --wait 360 frame before check again queue
			self:EchoDebug(self.name,'failout reset')
			self.failOut = nil
			self.fails = 0
		end

	elseif self.builder and self.sketch and self.sketch.unitID then
		self:EchoDebug(self.name ,self.role,'build ',self.sketch.unitName,'at', self.sketch.position.x,self.sketch.position.z)
		self:Watchdog()
	elseif self.builder and not self.sketch then
		self:EchoDebug(self.name ,self.role,'move to',self.builder.position.x,self.builder.position.z , 'to build', self.builder.unitName )
		self:Watchdog()

	elseif self.sketch and not self.builder then--WARNING  have a building in build and no builder in construction
		self:Warn(' no builder to execute sketch',self.sketch)

	else
		self:ProgressQueue()
	end
end

function BuildersBST:CategoryEconFilter(cat,param,name)
	self:EchoDebug(cat ,name,self.role,self.ai.taskshst.roles[self.role][self.idx]:economy(), " (before econ filter)")
	if not name  or not param then
		self:EchoDebug('ecofilter stop',name,cat, param)
		return
	end
	local ecoCheck = self.ai.taskshst.roles[self.role][self.idx]:economy(param,name)
	self:EchoDebug('eco filter',name,cat,ecoCheck,self.idx)
	if ecoCheck then
		return name
	end
end

function BuildersBST:specialFilter(cat,param,name)
	self:EchoDebug(cat ,name, self.role, " (before special filter)")
	if not name then return end
	local tasks = self.ai.taskshst
	local check = false
	if cat == '_solar_' then
		local newName = self.ai.armyhst[cat][name]
		self:EchoDebug('newName',newName)
		if self.unit:Internal():CanBuild(self.game:GetTypeByName(newName)) then
			if self.ai.ecohst.Metal.reserves > 100 and self.ai.ecohst.Energy.income > 200 and self.role == 'eco' then
				name = newName
			end
		end
		check =  true
	elseif cat == '_fus_' then
		local newName = self.ai.armyhst[cat][name]
		self:EchoDebug('newName',newName)
		if self.unit:Internal():CanBuild(game:GetTypeByName(newName)) then
			if   self.ai.ecohst.Energy.income > 4000 and self.role == 'eco' then
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

function BuildersBST:findPlace(utype, value,cat,loc)
	if not value or not cat or not utype then return end
	local POS = nil
	local builder = self.unit:Internal()
	local builderPos =  self.position
	local army = self.ai.armyhst
	local site = self.ai.buildingshst
	if loc and type(loc) == 'table' then
		if loc.categories then
			for index, category in pairs(loc.categories) do
				if category == 'selfCat' then
					category = cat
				end
				self:EchoDebug('category',category)

				POS = site:searchPosNearCategories(utype, builder,loc.min, loc.max,{category},loc.neighbours, loc.number)
				self:EchoDebug('POS',POS)
				if POS then
					break
				end
			end
		end
		if not POS and loc.list then
			self:EchoDebug('loc.max',loc.max)
			POS = site:searchPosInList(utype, builder, loc.min,loc.max,loc.list,loc.neighbours)
			self:EchoDebug('POS2',POS)
		end
		if not POS and loc.himself then
			POS = site:FindClosestBuildSite(utype, builderPos.x,builderPos.y,builderPos.z, loc.min, loc.max,builder)
			self:EchoDebug('POS3',POS)
		end
		if not POS and loc.friendlyGrid then
			POS = site:FindClosestBuildSite(utype, builderPos.x,builderPos.y,builderPos.z, loc.min, loc.max,builder)
			self:EchoDebug('POS3',POS)
		end
	end
	--factory will get position in labshst
	if cat == '_mex_' then
		local uw
		local reclaimEnemyMex
		POS, uw, reclaimEnemyMex = self.ai.maphst:ClosestFreeMex(utype, builder)
		if not POS then
			self:EchoDebug('no pos for mex found')
		end
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
	local minDist = nil
	elseif cat == '_nano_' then
		self:EchoDebug("looking for factory for nano")
		local currentLevel = 0
		local target = nil
		local mtype = self.ai.armyhst.unitTable[self.name].mtype
		for id,lab in pairs(self.ai.labshst.labs) do
			self:EchoDebug(mtype,lab.level,self.ai.armyhst.factoryMobilities[lab.name][1],currentLevel)
			if mtype == self.ai.armyhst.factoryMobilities[lab.name][1] and lab.level >= currentLevel then
				local lp = lab.position
				if not self.ai.buildingshst:unitsNearCheck(lp.x,lp.y,lp.z,390,10+(5*lab.level),{'_nano_'}) then
					self:EchoDebug( self.name, ' can push up self mtype ', lab.name)
					currentLevel = lab.level
					target = lab
					minDist = 0
				end
			end
		end
		
		if target then
			self:EchoDebug(self.name,' search position for nano near ',target.name )
-- 			POS = site:ClosestBuildSpot(builder, target.position, utype,nil,nil,nil,390)
			POS = site:FindClosestBuildSite(utype, target.position.x,target.position.y,target.position.z, minDist, maxDist,builder)

		end
		if not POS then
			local lab = self.ai.labshst:ClosestHighestLevelFactory(builder,5000)
			if lab then
				self:EchoDebug("searching for top level factory")
-- 				POS = site:ClosestBuildSpot(builder, lab.position, utype,nil,nil,nil,390)
				POS = site:FindClosestBuildSite(utype, lab.position.x,lab.position.y,lab.position.z, minDist, maxDist,builder)

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

function BuildersBST:limitedNumber(name,number)
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

function BuildersBST:getOrder(builder,params)
	if params.category == 'factoryMobilities' then
		if params.economy then
			local p = nil
			local  value = nil
			p, value = self.ai.labshst:GetBuilderFactory(builder)
			if p and value then
				self:EchoDebug('factory', value, 'is returned from labshst')
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

function BuildersBST:ProgressQueue()
	self:EchoDebug(self.name," progress queue",self.role,self.idx,#self.queue)
	if self.isCommander then
		self.role = self.ai.buildingshst:SetRole(self.id)
		self.queue = self.ai.taskshst.roles[self.role]
	end
	local builder = self.unit:Internal()
	if self.idx > #self.queue then
		self.idx = 0
		self.queue = self.ai.taskshst.roles[self.role]
	end
	self.idx = self.idx + 1
	for index = self.idx, #self.queue do

		self.idx = index
		self:EchoDebug(self.name,self.role,'queue idx',self.idx ,'JOB', JOB)
		JOB = self.queue[index]
		local utype = nil
		local p
		local jobName, p = self:getOrder(builder,JOB)

		self:EchoDebug('jobName',jobName)
		if JOB and jobName then
			self:EchoDebug(self.name .. " filtering...",jobName)
			local success = false
			if JOB.special and jobName then
				jobName = self:specialFilter(JOB.category,JOB.special,jobName)
			end
			if JOB.numeric and jobName then
				jobName = self:limitedNumber(jobName, JOB.numeric)
			end
			if JOB.duplicate and jobName then
				if self.ai.buildingshst:CheckForDuplicates(jobName) then
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
				return
			end
			if not self.unit:Internal():CanBuild(utype) then
				self:EchoDebug("WARNING: bad taskque: ",self.name," cannot build ",jobName)
				return
			end
			if utype  and p then
				self.ai.buildingshst:NewPlan(jobName, p, self.id,self.name)
				local facing = self.ai.buildingshst:GetFacing(p)
				local command = self.unit:Internal():Build(jobName, p, facing)
				self.watchdogTimeout = math.huge
				self.fails = 0
				self.failOut = nil
				self.assistant = false
				self:EchoDebug(self.name , " successful build command for ", utype:Name())
				--
				return true
			else
				self.fails = self.fails + 1
				if self.fails >  #self.queue  then
					self.failOut = self.game:Frame()
					if self.ai.buildingshst.roles[self.id].role == 'expand' then
						self.ai.buildingshst.roles[self.id].role = 'support'
					elseif self.ai.buildingshst.roles[self.id].role == 'support' then
						self.ai.buildingshst.roles[self.id].role = 'default'
					elseif self.ai.buildingshst.roles[self.id].role == 'default' then
						self.ai.buildingshst.roles[self.id].role = 'expand'
					end
					self:Assist()
					return
				end
			end
		end
	end
end

function BuildersBST:Assist()
	if self.assistant then return end
	local builderPos = self.ai.tool:UnitPos(self)
	if self.role ~= 'eco' then
		local bossDist = math.huge
		local bossTarget
		for bossID,project in pairs(self.ai.buildingshst.sketch) do
			if project.position then
				if self.ai.maphst:UnitCanGoHere(self.unit:Internal(), project.position) then
					local dist = self.ai.tool:distance( builderPos,project.position)
					if dist < bossDist then
						bossDist = dist
						bossTarget = bossID
					end
				end
			end
		end
		if bossTarget then
			self.unit:Internal():Guard(bossTarget)
			self.assistant = true
		end
	else
		local bossDist = math.huge
		local bossTarget
		for bossID,project in pairs(self.ai.buildingshst.sketch) do
			if project.position and self.ai.armyhst.unitTable[project.builderName].techLevel >= self.ai.armyhst.unitTable[self.name].techLevel then
				if self.ai.maphst:UnitCanGoHere(self.unit:Internal(), project.position) then
					local dist = self.ai.tool:distance( builderPos,project.position)
					if dist < bossDist then
						bossDist = dist
						bossTarget = bossID
					end
				end
			end
		end
		if bossTarget then
			self.unit:Internal():Guard(bossTarget)
			self.assistant = true
		else

			local unitsNear = self.game:getUnitsInCylinder(builderPos, 2500)
			for index, unitID in pairs(unitsNear) do
				local unitName = self.game:GetUnitByID(unitID):Name()
				if self.ai.armyhst.factoryMobilities[unitName] then
					self.unit:Internal():Guard(unitID)
					self.assistant = true
					return
				end
			end
		end
	end
	for i = 1, 3 do
		local r = 2000 * i
		local doing = self.unit:Internal():AreaResurrect( builderPos, r) or
				self.unit:Internal():AreaReclaim(builderPos, r ) or
				self.unit:Internal():AreaRepair( builderPos, r)
		if doing  then
			self:EchoDebug('assistant reclaim or repair')
			self.assitant = true
		else
			self:EchoDebug('assistant not work')
		end

	end
end
