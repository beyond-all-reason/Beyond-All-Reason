BuildingsHST = class(Module)

function BuildingsHST:Name()
	return "BuildingsHST"
end

function BuildingsHST:internalName()
	return "buildingshst"
end

function BuildingsHST:Init()
	self.DebugEnabled = false
	self.dontBuildRects = {}
	self.sketch = {}
	self.builders = {}
	self.roles = {}
	self.allyMex = {}
	self:DontBuildOnMetalOrGeoSpots()

	-- Shared rectangle helper so we can test pure logic without spinning up AI.
	self.factoryRect = VFS.Include('common/stai_factory_rect.lua')
end

function BuildingsHST:GetFacing(p)
	local x = p.x
	local z = p.z
	local facing = 3
	local NSEW = 'north'
	if math.abs(Game.mapSizeX - 2 * x) > math.abs(Game.mapSizeZ - 2 * z) then
		if (2 * x > Game.mapSizeX) then
			facing = 3 --east
			NSEW = 'est'
		else
			facing = 1 --weast
			NSEW = 'west'
		end
	else
		if ( 2 * z > Game.mapSizeZ) then
			facing = 2 --south
			NSEW = 'south'
		else
			facing = 0 -- north
			NSEW = 'north'
		end
	end
	return facing , NSEW
end

function BuildingsHST:PlansOverlap(position, unitName)
	local rect = { position = position, unitName = unitName }
	self:CalculateRect(rect)
	for i, plan in pairs(self.builders) do
		if self.ai.tool:RectsOverlap(rect, plan) then
			return true
		end
	end
	return false
end
-- keeps amphibious/hover cons from zigzagging from the water to the land too far
function BuildingsHST:LandWaterFilter(pos, unitTypeToBuild, builder)
	local builderName = builder:Name()
	local mtype = self.ai.armyhst.unitTable[builderName].mtype
	if mtype ~= "amp" and  mtype ~= "hov" and not self.ai.armyhst.commanderList[builderName] then
		-- don't bother with units that aren't amphibious
		return true
	end
	local unitName = unitTypeToBuild:Name()
	if self.ai.armyhst.unitTable[unitName].extractsMetal > 0 or self.ai.armyhst.unitTable[unitName].buildOptions then
		-- leave mexes and factories alone
		return true
	end
	-- where is the con?
	local builderPos = builder:GetPosition()
	local water = self.ai.maphst:MobilityNetworkHere("shp", builderPos)
	-- is this a land or a water unit we're building?
	local waterBuildOrder = self.ai.armyhst.unitTable[unitName].needsWater
	-- if this is a movement from land to water or water to land, check the self.ai.tool:distance
	if water then self:EchoDebug(builderName .. " is in water") else self:EchoDebug(builderName .. " is on land") end
	if waterBuildOrder then 
		self:EchoDebug(unitName .. " would be in water") 
	else self:EchoDebug(unitName .. " would be on land") 
		
	end
	if (water and not waterBuildOrder) or (not water and waterBuildOrder) then
		self:EchoDebug("builder would traverse the shore to build " .. unitName)
		local dist = self.ai.tool:distance(pos, builderPos)
		if dist > 250 then
			self:EchoDebug("build too far away from shore to build " .. unitName)
			return false
		else
			return true
		end
	else
		return true
	end
end

function BuildingsHST:GetBuildSpacing(unitTypeToBuild)
	local army = self.ai.armyhst
	local spacing = 100
	local un = unitTypeToBuild:Name()
	if army.factoryMobilities[un] then
		spacing = 100
	elseif army._mex_[un] then
		spacing = 50
	end
	return spacing
end

function BuildingsHST:DontBuildRectangle(x1, z1, x2, z2, unitID)
	x1 = math.ceil(x1)
	z1 = math.ceil(z1)
	x2 = math.ceil(x2)
	z2 = math.ceil(z2)
	table.insert(self.dontBuildRects, {x1 = x1, z1 = z1, x2 = x2, z2 = z2, unitID = unitID})
end

function BuildingsHST:DoBuildRectangleByUnitID(unitID)
	for i,rect in pairs(self.dontBuildRects) do
		if rect.unitID == unitID then
			table.remove(self.dontBuildRects, i)
		end
	end
end

function BuildingsHST:DontBuildOnMetalOrGeoSpots()
	for i, p in pairs(self.ai.maphst.allSpots) do
		self:DontBuildRectangle(p.x-40, p.z-40, p.x+40, p.z+40)
	end
end

function BuildingsHST:FindClosestBuildSite(unittype, bx,by,bz, minDist, maxDist,builder,recycledPos) -- returns Position

	--local ch = 2
	--map:EraseAll(ch)

	maxDist = maxDist or 390
	minDist = minDist or 1
	minDist = math.max(minDist,1)

	local twicePi = math.pi * 2
	local angleIncMult = twicePi / minDist

	local maxX, maxZ = Game.mapSizeX, Game.mapSizeZ
	---map:DrawPoint({x=bx,y=by,z=bz}, {1,0,0,1},'origin',  ch)
	local attempt = 1
	self:EchoDebug('maxDist',maxDist)
	local maxtest = math.max(10,(maxDist - minDist) / 100)
	local checkpos = recycledPos or {}
	--self:EchoDebug('FindClosestBuildSite',unittype,bx,bz,minDist,maxDist,maxtest)
	for radius = minDist, maxDist, maxtest do
		self:EchoDebug('radius = minDist, maxDist, maxtest',radius , maxDist, maxtest)
		local angleInc = radius * twicePi * angleIncMult
		local initAngle = math.random() * twicePi
		for angle = initAngle, initAngle+twicePi, angleInc do
			self:EchoDebug('intAAngle initAngle+twicePi, angleinc',initAngle, initAngle+twicePi, angleInc)
			attempt = attempt + 1

			local realAngle = angle+0
			local dx,dz
			if realAngle > twicePi then realAngle = realAngle - twicePi end
			local s = math.sin(realAngle)
			local c = math.cos(realAngle)
			if c > 0 then
				dx = radius*c
			else
				dx  = (radius * -c) * -1
			end
			if s > 0 then
				dz = radius * s
			else
				dz = (radius * -s) * -1
			end

			local x, z = bx+dx, bz+dz
			if x < 0 then x = 0 elseif x > maxX then x = maxX end
			if z < 0 then z = 0 elseif z > maxZ then z = maxZ end
			self:EchoDebug('attempt',attempt,radius, maxDist, angle,realAngle,maxtest,dx,dz)
			local y = map:GetGroundHeight(x,z)
			checkpos.x = x
			checkpos.y = y
			checkpos.z = z
			--map:DrawPoint({x=x, y=y, z=z}, {1,1,1,1},attempt,  ch)
			local check = self:CheckBuildPos(checkpos, unittype, builder)
			if check then
				local buildable, px,py,pz = self:CanBuildHere(unittype, x,y,z)
				if buildable then
					checkpos.x =px
					checkpos.y =py
					checkpos.z = pz
					return checkpos
				else
					self:EchoDebug('not buildable here',unittype:Name(),x,y,z,px,py,pz)
				end
			end
		end
	end
end

function BuildingsHST:CanBuildHere(unittype,x,y,z) -- returns boolean
	local newX, newY, newZ = Spring.Pos2BuildPos(unittype:ID(), x, y, z)
	local buildable = Spring.TestBuildOrder(unittype:ID(), newX, newY, newZ, 1) --TODO check if it really necessary

	self:EchoDebug('canbuildhere',unittype:Name(), newX, newY, newZ, buildable)
	if buildable == 0 then buildable = false end
	return buildable , newX, newY, newZ
end


function BuildingsHST:CheckBuildPos(pos, unitTypeToBuild, builder--[[, originalPosition]]) --TODO clean this
	if not pos then return end
	if not self.ai.maphst:isInMap(pos) then return end
	-- sanity check: is it REALLY possible to build here?
 	local range = self:GetBuildSpacing(unitTypeToBuild)
  	local neighbours = game:getUnitsInCylinder(pos, range) --security distance between buildings prevent units stuck --TODO refine and TEST
	for idx, unitID in pairs (neighbours) do
		local unitName = self.game:GetUnitByID(unitID):Name()
		local mobile = self.ai.armyhst.unitTable[unitName].speed > 0
		if not mobile  and unitTypeToBuild:Name() ~= unitName then
			self:EchoDebug('blocked by a building')
			return nil
		end
	end
	
	local rect
	if pos ~= nil then
		rect = {position = pos, unitName = unitTypeToBuild:Name()}
		self:CalculateRect(rect)
	end

	-- don't build where you shouldn't (metal spots, geo spots, factory lanes)
	if pos ~= nil then
		for i, dont in pairs(self.dontBuildRects) do
			if self.ai.tool:RectsOverlap(rect, dont) then
				pos = nil
				self:EchoDebug('blocked by a dontBuildRect')
				return nil
			end
		end
	end
	-- don't build on top of current build orders
	if pos ~= nil then
		for i, plan in pairs(self.builders) do
			if self.ai.tool:RectsOverlap(rect, plan) then
				self:EchoDebug('blocked by a plan')
				return nil
			end
		end
	end
	-- is it too far away from an amphibious constructor?
	if pos ~= nil then
		local lw = self:LandWaterFilter(pos, unitTypeToBuild, builder)
		if not lw then
			self:EchoDebug('blocked by a land/water filter')
			return nil
		end
	end
	-- don't build where the builder can't go
	if pos ~= nil then
		if not self.ai.maphst:UnitCanGoHere(builder,pos) then
			self:EchoDebug('blocked by unitCanGoHere')
			return nil
		end
	end
	return true
end

function BuildingsHST:searchPosNearCategories(utype,builder,minDist,maxDist,categories,neighbours,number)
	if not categories then return end
	self:EchoDebug(categories,'search pos near categories')
	local army = self.ai.armyhst
	local builderName = builder:Name()
	local p = {}
	maxDist = maxDist or 390
	if type(maxDist) == 'string' then
		maxDist = army.unitTable[builderName][maxDist]
	end
	local Units = {}

	for i,cat in pairs(categories) do
		for name, _ in pairs(army[cat]) do
			local defId = army.unitTable[name].defId
			local units = self.game:GetTeamUnitsByDefs(self.ai.id,defId)
			for index,uID in pairs(units) do
				self:EchoDebug('unit', index,uID)
				local dist = self.game:GetUnitSeparation(uID,builder:ID())
				self:EchoDebug('dist = ', dist)
				table.insert(Units,dist,uID)
			end
			local k,sortedUnits = self.ai.tool:tableSorting(Units)
			for index, uID in pairs(sortedUnits) do
				local unitID = table.remove(sortedUnits,index)--self.game:GetUnitByID(uID)
				local unit = self.game:GetUnitByID(unitID)
				local unitName = unit:Name()
				local  bx,by,bz = unit:GetRawPos()
				if not neighbours or not self:unitsNearCheck(bx,by,bz, maxDist,number,neighbours) then
					p = self:FindClosestBuildSite(utype, bx,by,bz, minDist, maxDist,builder,p)
					if p and p.x then
						return p
					end
				end
			end
		end
	end

end

function BuildingsHST:searchPosInList(utype, builder,minDist,maxDist,list,neighbours,number)
	
	self:EchoDebug('search pos in list for',utype:Name())
	local maxDist = maxDist or 390
	local d = math.huge
	local p
	local tmpDist
	local tmpPos = {}
	if not list then 		return	end
	for  index, pos in pairs(self.ai.tool:sortByDistance(builder:GetPosition(),list)) do
		if not neighbours or not self:unitsNearCheck(pos.x,pos.y,pos.z, maxDist,number,neighbours)then
			tmpPos = self:FindClosestBuildSite(utype, pos.x,pos.y,pos.z, minDist, maxDist,builder,tmpPos)
			if tmpPos and tmpPos.x then
				self:EchoDebug('found Position in list at: ' , tmpPos.x ,tmpPos.z,'for',utype:Name())
				return tmpPos
				
			end
		end
	end
end



function BuildingsHST:BuildNearNano(builder, utype,minDist,maxDist)
	minDist = minDist or 50
	maxDist = maxDist or 390
	local nanoCount,nanos = self.ai.tool:countFinished( {'_nano_'})
	for i,id in pairs (nanos) do
		local nanoUnit = game:GetUnitByID(id)
-- 		local nanoPos = nanoUnit:GetPosition()
		local bx,by,bz = nanoUnit:GetRawPos()
-- 		local p = self:ClosestBuildSpot(builder, nanoPos, utype, 10, nil, nil, maxDist)
		local p = self:FindClosestBuildSite(utype, bx,by,bz, nil, maxDist,builder)
		if p then
			self:EchoDebug('found Position for near nano hotspot at: ' .. p.x ..' ' ..p.z)
		end
	end
end

function BuildingsHST:unitsNearCheck(x,y,z,range,number,targets)
	if not range or not x then return end
	number = number or 1
	local counter = 0
	for i,target in pairs(targets) do
		for builder,project in pairs(self.builders) do
			if not project.unitID and project.unitName == target or (self.ai.armyhst[target] and self.ai.armyhst[target][project.unitName]) then
				if self.ai.tool:RawDistance(project.position.x,project.position.y,project.position.z, x,y,z) < range then
					counter = counter + 1
					if counter >= number then
						self:EchoDebug(' block by a project',counter ,project.unitName)
						return true
					end
				end
			end
		end
	end
	local neighbours = self.game:getUnitsInCylinder({x=x,z=z}, range)
	if not neighbours then return false end
	for idx, unitID in pairs(neighbours) do
		local unitName = self.game:GetUnitByID(unitID):Name()
		for i,target in pairs(targets) do
			if unitName ==  target or (self.ai.armyhst[target] and self.ai.armyhst[target][unitName]) then
				counter = counter +1
				if counter >= number then
					self:EchoDebug(' block by a building',counter ,unitName)
					return true
				end
			end
		end
	end
	return
end

function BuildingsHST:CheckForDuplicates(unitName)
	if unitName == nil then return true end
	local utable = self.ai.armyhst.unitTable[unitName]
	local isFactory = self.ai.armyhst.factoryMobilities[unitName]
	self:EchoDebug("looking for duplicate plan for ", unitName)
	for i, plan in pairs(self.builders) do
		local factoryPlanned = self.ai.armyhst.factoryMobilities[plan.unitName]
		if isFactory and factoryPlanned then return true end
		if plan.unitName == unitName then return true end
	end
	self:EchoDebug("looking for duplicate construction for ", unitName)
	for unitID, construct in pairs(self.sketch) do
		if construct.unitName == unitName then
			self:EchoDebug('there is already one of this')
			return true
		end
	end
	return false
end

function BuildingsHST:UnitCreated(unit, unitDefId, teamId, builderID)
	local unitName = unit:Name()
	local position = unit:GetPosition()
	local unitID = unit:ID()
	local planned = false
	local project = self.builders[builderID]
	if project and project.unitName == unitName and self.ai.tool:PositionWithinRect(position, project) then
		self:EchoDebug(project.builderName," began constructing ",unitName)
		if self.ai.armyhst.unitTable[unitName].speed == 0 then
			self:DontBuildRectangle(project.x1, project.z1, project.x2, project.z2, unitID)
		end
		project.frame = self.game:Frame()
		project.unitID = unitID
		self.sketch[unitID] = project
 		self.builders[builderID] = project
		planned = true
	end
	if not planned and self.ai.armyhst.unitTable[unitName].speed == 0 then
		-- for when we're restarting the AI, or other contingency
		local rect = { position = position, unitName = unitName }
		self:CalculateRect(rect)
		self:DontBuildRectangle(rect.x1, rect.z1, rect.x2, rect.z2, unitID)
	end
end

function BuildingsHST:MyUnitBuilt(unit)
	local unitID = unit:ID()
	local done = self.sketch[unitID]
	if done then
		self:EchoDebug(done.builderName , done.builderID,  " completed ", done.unitName, unitID)
		self:ClearMyProjects(done.builderID)
	end
end


function BuildingsHST:UnitDead(unit)
	local unitID = unit:ID()
	local sketch = self.sketch[unitID]
	if sketch then
		self:ClearMyProjects(self.sketch[unitID].builderID)
	end
	self:DoBuildRectangleByUnitID(unitID)
end

function BuildingsHST:ClearMyProjects(builderID)
	self.sketch[builderID] = nil
 	for id,sketch in pairs(self.sketch) do
 		if sketch.builderID == builderID then
 			self.sketch[id] = nil
 			break
 		end
 	end
	self.builders[builderID] = nil
end

function BuildingsHST:GetMyProject(builderID)
	local builder = self.builders[builderID]
	local sketch = nil
	if builder then
		sketch = self.sketch[builder.unitID]
	end
	return builder, sketch
end

function BuildingsHST:NewPlan(unitName, position, builderID, builderName)
	self:EchoDebug(builderName, " plans to build ", unitName .. " at ", position.x , position.z)
	local plan = {unitName = unitName, position = position, builderID = builderID, builderName = builderName}
	self:CalculateRect(plan)
	self.builders[builderID] = plan
end

function BuildingsHST:CalculateFactoryLane(rect)
	local unitName = rect.unitName
	local position = rect.position
	local outX = self.ai.armyhst.unitTable[unitName].xsize * 6
	local outZ = self.ai.armyhst.unitTable[unitName].zsize * 6
	local tall = outZ * 10
	local facing = self:GetFacing(position)
	if facing == 0 then
		rect.x1 = position.x - outX
		rect.x2 = position.x + outX
		rect.z1 = position.z - outZ
		rect.z2 = position.z + tall
	elseif facing == 2 then
		rect.x1 = position.x - outX
		rect.x2 = position.x + outX
		rect.z1 = position.z - tall
		rect.z2 = position.z + outZ
	elseif facing == 1 then
		rect.x1 = position.x - outX
		rect.x2 = position.x + tall
		rect.z1 = position.z - outZ
		rect.z2 = position.z + outZ
	elseif facing == 3 then
		rect.x1 = position.x - tall
		rect.x2 = position.x + outX
		rect.z1 = position.z - outZ
		rect.z2 = position.z + outZ
	end
end

function BuildingsHST:CalculateRect(rect)
	local unitName = rect.unitName
	local unitTable = self.ai.armyhst.unitTable
	local outsets = self.factoryRect.getOutsets(unitName, unitTable, self.ai.armyhst.factoryExitSides)

	-- Known exit side -> factory lane handling
	if outsets == nil and self.ai.armyhst.factoryExitSides[unitName] ~= nil and self.ai.armyhst.factoryExitSides[unitName] ~= 0 then
		self:CalculateFactoryLane(rect)
		return
	end

	-- Default / factory apron path.
	local position = rect.position
	local outX = outsets.outX
	local outZ = outsets.outZ
	rect.x1 = position.x - outX
	rect.z1 = position.z - outZ
	rect.x2 = position.x + outX
	rect.z2 = position.z + outZ
end

function BuildingsHST:RoleCounter(builderName,targetRole)
	local counter = 0
	local globalCount = 0
	local roleCount = 0
	local nameCount = 0
	for id,role in pairs(self.roles) do
		globalCount = globalCount + 1
		if role.builderName == builderName and role.role == targetRole then
			counter = counter + 1
		end
		if role.builderName == builderName then
			nameCount = nameCount + 1
		end
		if role.role == targetRole then
			roleCount = roleCount + 1
		end

	end
	return counter,nameCount, roleCount,globalCount
end

function BuildingsHST:SetRole(builderID)
	local builder = game:GetUnitByID(builderID)
	local name = builder:Name()
	local role = nil
	if self.ai.armyhst.commanderList[name] then
		local _,_, roleCount,_ = self:RoleCounter(nil,'eco')
		local _,_, expandCount,_ = self:RoleCounter(nil,'expand')
		--if roleCount < 1 then
		if self.ai.tool:countFinished( {'_nano_'},self.ai.teamID) == 0 and self.ai.tool:countMyUnit( {'_nano_'}) == 1 then
			role = 'assist'
		elseif self.ai.tool:countFinished( {'_nano_'},self.ai.teamID) == 0 then
			role = 'starter'
		elseif roleCount >= 1 and expandCount >= 3	then
			role = 'assist'
		elseif roleCount >= 1	then
			role = 'expand'
		else
			role = 'default'
		end
	elseif self.ai.armyhst.unitTable[name].techLevel == 4 then
		if self.roles[builderID] then
			role = self.roles[builderID].role
		elseif self:RoleCounter(name,'expand') < 1 then
			role = 'expand'
		elseif self:RoleCounter(name,'eco') < 1 then
			role = 'eco'
		elseif self:RoleCounter(name,'expand') < 2 then
			role = 'expand'
		elseif self:RoleCounter(name,'support') < 1 then
			role = 'support'
		elseif self:RoleCounter(name,'metalMaker') < 1 then
			role = 'metalMaker'
		elseif self:RoleCounter(name,'default') < 1 then
			role = 'default'
		else
			if math.random() <0.6 then
				role ='expand'
			else
				role = 'support'
			end
		end
	else
		if self.roles[builderID] then
			role = self.roles[builderID].role
		elseif self:RoleCounter(name,'eco') < 1 then
			role = 'eco'
		elseif self:RoleCounter(name,'expand') < 3 then
			role = 'expand'
		elseif self:RoleCounter(name,'nano') < 1 then
			role = 'nano'
		elseif self:RoleCounter(name,'support') < 1 then
			role = 'support'
		elseif self:RoleCounter(name,'default') < 1 then
			role = 'default'

		else
			if math.random() <0.6 then
				role ='expand'
			else
				role = 'support'
			end
		end
	end
	self.roles[builderID] = {
		role = role,
		builderName = builder:Name()
	}
	return role
end

function BuildingsHST:NearestBuilderRole(unit, targetRole)
	local unitPos = unit:GetPosition()
	local bestDist = math.huge
	local bestBuilder
	for id,role in pairs ( self.ai.buildingshst.roles) do
		local targetUnit = game:GetUnitByID(id)
		local targetPos = targetUnit:GetPosition()
		if not targetRole or targetRole == role.role  then
			if self.ai.maphst:UnitCanGoHere(unit,targetPos) then
				local d = self.ai.tool:DISTANCE(unitPos,targetPos)
				if d < bestDist then
					bestDist = d
					bestBuilder = id
				end
			end
		end
	end
	return bestBuilder
end

function BuildingsHST:VisualDBG()
	
	if not self.ai.drawDebug then
		return
	end
	local ch = 8
	map:EraseAll(ch)
	local colours = {
		starter = {1,1,0,1},
		default = {1,0,0,1},
		eco = {0,1,0,1},
		support = {0,0,1,1},
		expand = {0,1,1,1},
		}

	for id,role in pairs(self.roles) do
		local builder = game:GetUnitByID(id)

		builder:EraseHighlight(nil, nil, ch )
		builder:DrawHighlight(colours[role.role] , role.role, ch )
	end
	for i,sketch in pairs(self.sketch) do
		map:DrawRectangle({x=sketch.x1,y=0,z=sketch.z1}, {x=sketch.x2,y=0,z=sketch.z2}, {1,0,1,1}, nil, true, ch)
	end
	for i,rect in pairs(self.dontBuildRects) do
		map:DrawRectangle({x=rect.x1,y=0,z=rect.z1}, {x=rect.x2,y=0,z=rect.z2}, {1,0,0,1}, nil, true, ch)
	end
end

--[[
function BuildingsHST:BuildNearNano(builder, utype)
-- 	self:EchoDebug("looking for spot near nano hotspots")
-- 	local nanoHots = self.ai.nanohst:GetHotSpots()
-- 	if nanoHots then
-- 		self:EchoDebug("got " .. #nanoHots .. " nano hotspots")
-- 		local hotRadius = self.ai.nanohst:HotBuildRadius()
-- 		for i = 1, #nanoHots do
-- 			local hotPos = nanoHots[i]
-- 			-- find somewhere within hotspot
-- 			local p = self:ClosestBuildSpot(builder, hotPos, utype, 10, nil, nil, hotRadius)
-- 			if p then
-- 				self:EchoDebug('found Position for near nano hotspot at: ' .. hotPos.x ..' ' ..hotPos.z)
-- 				return p
-- 			end
-- 		end
-- 	end
	return self:BuildNearLastNano(builder, utype)
end

function BuildingsHST:BuildNearLastNano(builder, utype)
	self:EchoDebug("looking for spot near last nano")
	local p = nil
	if self.ai.lastNanoBuild then
		self:EchoDebug('found position near last nano')
		-- find somewhere at most 400 away
		p = self:ClosestBuildSpot(builder, self.ai.lastNanoBuild, utype, 30, nil, nil, 400)
	end
	return p
end
]]
