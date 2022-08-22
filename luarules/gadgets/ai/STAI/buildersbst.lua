BuildersBST = class(Behaviour)

function BuildersBST:Name()
	return "BuildersBST"
end

function BuildersBST:Init()
	self.DebugEnabled = true
	self.active = false
	self.watchdogTimeout = 1800
	local u = self.unit:Internal()
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
	--if self:IsActive() then self.progress = true end
end

function BuildersBST:OwnerDead()
	if self.unit ~= nil then
-- 		for i, idx in pairs(self.ai.armyhst.buildersRole[self.role][self.name]) do
-- 			if self.id == idx then
-- 				table.remove(self.ai.armyhst.buildersRole[self.role][self.name],i)
-- 				self.role = nil
-- 			end
-- 		end
		self.ai.buildingshst.roles[self.id] = nil
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

function BuildersBST:OwnerMoveFailed()
	-- sometimes builders get stuck
	self:Warn('builder stuck',self.id)
	self:OwnerIdle()
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
	return 100--[[
	if self.failOut then
		return 50
	elseif not self.ai.buildingshst.builders[self.id]  or self.role == 'expand' then
		return 50
	elseif self.role == 'eco' then
		return 1000
	else
		return 75
	end]]
end
function BuildersBST:Watchdog()
	if self.watchdogTimeout < game:Frame() then
		self.ai.buildingshst:ClearMyProjects(self.id)
	end
end


function BuildersBST:Update()
	if self.ai.schedulerhst.behaviourTeam ~= self.ai.id or self.ai.schedulerhst.behaviourUpdate ~= 'BuildersBST' then return end
	local f = self.game:Frame()
	self.ai.buildingshst:VisualDBG()
	if not self:IsActive() then
		return
	end
	self.builder, self.sketch = self.ai.buildingshst:GetMyProject(self.id)
	if not self.sketch and not self.builder and self.failOut then
		self:EchoDebug(self.name,'failout')
		if f > self.failOut + 360 then --wait 360 frame before check again queue
			self:EchoDebug(self.name,'failout reset')
			self.failOut = nil
		end

	elseif self.builder and self.sketch and self.sketch.unitID then
		self:EchoDebug(self.name ,self.role,'build ',self.sketch.unitName,'at', self.sketch.position.x,self.sketch.position.z)
		self:Watchdog()
	elseif self.builder and not self.sketch then
		self:EchoDebug(self.name ,self.role,'move to',self.builder.position.x,self.builder.position.z , 'to build', self.builder.unitName )
		self:Watchdog()

	elseif self.sketch and not self.builder then
		self:Warn(' no builder to execute sketch',self.sketch)
		--ERROR impossible have a building in build and no builder in construction
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

function BuildersBST:findPlace(utype, value,cat,loc)
	if not value or not cat or not utype then return end
	local POS = nil
	local builder = self.unit:Internal()
	local builderPos = builder:GetPosition()
	local army = self.ai.armyhst
	local site = self.ai.buildingshst
	local closestFactory = self.ai.buildingshst:ClosestHighestLevelFactory(builderPos)
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
		POS, uw, reclaimEnemyMex = self.ai.maphst:ClosestFreeMex(utype, builder)
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
					if not self.ai.buildingshst:unitsNearCheck(factory.unit:Internal():GetPosition(),390,10+(5*level),{'_nano_'}) then
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

function BuildersBST:GetAmpOrGroundWeapon()
	if self.ai.enemyBasePosition then
		if self.ai.maphst:MobilityNetworkHere('veh', self.position) ~= self.ai.maphst:MobilityNetworkHere('veh', self.ai.enemyBasePosition) and self.ai.maphst:MobilityNetworkHere('amp', self.position) == self.ai.maphst:MobilityNetworkHere('amp', self.ai.enemyBasePosition) then
			self:EchoDebug('canbuild amphibious because of enemyBasePosition')
			return true
		end
	end
	local mtype = self.ai.armyhst.factoryMobilities[self.name][1]
	local network = self.ai.maphst:MobilityNetworkHere(mtype, self.position)
	if not network or not self.ai.labbuildhst.factoryBuilded[mtype] or not self.ai.labbuildhst.factoryBuilded[mtype][network] then
		self:EchoDebug('canbuild amphibious because ' .. mtype .. ' network here is too small or has not enough spots')
		return true
	end
	return false
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




function BuildersBST:ProgressQueue()
	self:EchoDebug(self.name," progress queue",self.role,self.idx,#self.queue)
	if self.isCommander then
		self.role = self.ai.buildingshst:SetRole(self.id)
		self.queue = self.ai.taskshst.roles[self.role]
	end
	local builder = self.unit:Internal()
	if self.idx > #self.queue then
		self.idx = 0
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
		if JOB then
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
				self.watchdogTimeout = math.huge--game:Frame() + math.max(self.ai.tool:Distance(self.unit:Internal():GetPosition(), p) * 1.5, 460)

				self.fails = 0
				self.failOut = nil
				self.assistant = false
				self:EchoDebug(self.name , " successful build command for ", utype:Name())
				return true
			else
				self.fails = self.fails + 1
				if self.fails >  #self.queue +1 then
					self.failOut = self.game:Frame()
					self:assist()
				end
			end
		end
	end
end

function BuildersBST:assist()
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
		elseif self.ai.armyhst.techs[unitName] and self.unit:Internal():GetUnitIsBuilding() then
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

--[[
function BuildersBST:removeOldBuildersRole()
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
]]
