NewPlacementHandler = class(Module)

function NewPlacementHandler:Name()
	return "NewPlacementHandler"
end

function NewPlacementHandler:internalName()
	return "newplacementhandler"
end

function NewPlacementHandler:Init()
	celltoscan = {}
	defidpersizetype = {}
	cells = {}
	self.plans = {}
	self.plansbyunitID = {}
	self.plansbyunitDefID = {}
	mapwidth = math.max(Game.mapSizeX, Game.mapSizeZ)
	for unitDefID, defs in pairs(UnitDefs) do
		if defs.isBuilding or string.find(defs.name, "nanotc") then
			local cellsize = math.max(defs.xsize, defs.zsize) * 8
			local buildtype = (defs.maxWaterDepth >= 0) and "ground" or "water"
			if not cells[cellsize] then
				cells[cellsize] = {}
				defidpersizetype[cellsize] = {}
			end
			if not cells[cellsize][buildtype] then
				defidpersizetype[cellsize][buildtype] = unitDefID
				cells[cellsize][buildtype] = {}
				for x = 0, Game.mapSizeX-1, cellsize do
					for z = 0, Game.mapSizeZ-1, cellsize do
						cells[cellsize][buildtype][self:GetIDFromPos(x, z, cellsize)] = (Spring.TestBuildOrder(unitDefID, x + cellsize/2, Spring.GetGroundHeight(x + cellsize/2, z+cellsize/2), z+cellsize/2, "s") == 2 and Spring.TestBuildOrder(unitDefID, x + cellsize/2, Spring.GetGroundHeight(x + cellsize/2, z+cellsize/2), z+cellsize/2, "e") == 2)
					end
				end
			end
		end
	end		
end

function NewPlacementHandler:Update()
	for id, cell in pairs(celltoscan) do
		if Spring.GetGameFrame()%300 == id%300 then
			for size, metatable in pairs(defidpersizetype) do
				local pos = self:GetPosFromID(id)
				for buildtype, unitDefID in pairs(metatable) do
					cells[size][buildtype][self:GetIDFromPos(pos.x, pos.z, size)] = (Spring.TestBuildOrder(unitDefID, pos.x + size/2, Spring.GetGroundHeight(pos.x + size/2, pos.z+size/2), pos.z+size/2, "s") == 2 and Spring.TestBuildOrder(unitDefID, pos.x + size/2, Spring.GetGroundHeight(pos.x + size/2, pos.z+size/2), pos.z+size/2, "e") == 2)
					celltoscan[id] = nil
				end
			end
		end
	end
end

function NewPlacementHandler:GetPosBuildable(x, z, cellsize, buildtype)
	local id = (x - x%cellsize) * math.floor(mapwidth/cellsize) + z - z%cellsize
	return cells[cellsize][buildtype][id]
end

function NewPlacementHandler:GetClosestBuildPosition(x, z, cellsize, buildtype)
	local ID = self:GetIDFromPos(x, z, cellsize)
	local POS = self:GetPosFromID(ID)
	local x, z = POS.x, POS.z
	local attempt = 0
	local pos
	buildable = cells[cellsize][buildtype][ID]
	if buildable == true then bestID = ID end
	while buildable ~= true and attempt < 50 do
		attempt = attempt + 1
		for v = -attempt, attempt do
			for h = -attempt, attempt do	
				local id = ID + (v*cellsize*mapwidth) + (h*cellsize)
				if cells[cellsize][buildtype][id] == true then
					buildable = true
					bestID = id
					break
				end
			if buildable == true then break end
			end
		if buildable == true then break end
		end
	end
	if bestID then
		pos = NewPlacementHandler:GetPosFromID(bestID, cellsize)
		pos.x = pos.x + cellsize/2
		pos.z = pos.z + cellsize/2
		pos.y = Spring.GetGroundHeight(pos.x, pos.z)
	end
	return pos
end

function NewPlacementHandler:GetPosFromID(id)
	local z = id%mapwidth
	local x = (id - z)/mapwidth
	return {x = x, z = z}
end

function NewPlacementHandler:GetIDFromPos(x, z, cellsize)
	return (x - x%cellsize) * mapwidth + (z - z%cellsize)
end

function NewPlacementHandler:UnitDead(unit)
	local unitDefID = UnitDefNames[unit:Name()].id
	local defs = UnitDefs[unitDefID]
	if defs then
		if defs.isBuilding or string.find(defs.name, "nanotc") then
			local pos = unit:GetPosition()
			local spacing = self:GetMinimalSpacing(unit:Type())
			local cellsize = math.max(defs.xsize, defs.zsize) * 8
			self:FreePosition(pos.x, pos.z, cellsize, spacing)
		elseif defs.canBuild == true then
			local unitID = unit.id
			if self.plansbyunitID[unitID] then
				for planID, plan in pairs(self.plansbyunitID[unitID]) do
					self:ClearPlan(planID)
					local pos = self:GetPosFromID(planID)
					local spacing = self:GetMinimalSpacing(self.game:GetTypeByName(def.name))
					local cellsize = math.max(defs.xsize, defs.zsize) * 8
					self:FreePosition(pos.x, pos.z, cellsize, spacing)
				end
			end
		end
	end
end

function NewPlacementHandler:UnitCreated(unit) -- Clear plan but leave position closed, unitDead will clear it
	local unitDefID = UnitDefNames[unit:Name()].id
	local defs = UnitDefs[unitDefID]
	if defs then
		if defs.isBuilding or string.find(defs.name, "nanotc") then
			local pos = unit:GetPosition()
			local spacing = self:GetMinimalSpacing(unit:Type())
			local cellsize = math.max(defs.xsize, defs.zsize) * 8
			local planID = self:GetIDFromPos(pos.x, pos.z, cellsize)
			self:ClearPlan(planID)
		end
	end
end

function NewPlacementHandler:ClearPlan(planID)
	if self.plans[planID] then
		local unitID = self.plans[planID].unitID
		local unitDefID = self.plans[planID].unitDefID
		self.plans[planID] = nil
		self.plansbyunitDefID[unitDefID][planID] = nil
		self.plansbyunitID[unitID][planID] = nil
	end
end


function NewPlacementHandler:ClosePosition(x,z, cellsize,spacing)
	local id1 = self:GetIDFromPos(x,z,cellsize)
	local pos = self:GetPosFromID(id1)
	local x, z = pos.x, pos.z
	for v = x-spacing, x+spacing+cellsize-1, 8 do
		for h = z-spacing, z+spacing+cellsize-1, 8 do
			for size, cell in pairs(cells) do
				local id = self:GetIDFromPos(v,h,size)
				cells[size]["ground"][id] = false
			end
		end
	end
end

function NewPlacementHandler:FreePosition(x,z,cellsize,spacing)
	local id1 = self:GetIDFromPos(x,z,cellsize)
	local pos = self:GetPosFromID(id1)
	local x, z = pos.x, pos.z
	for v = x - spacing, x + spacing + cellsize-1, 8 do
		for h = z - spacing, z + spacing + cellsize - 1 ,8 do
			celltoscan[self:GetIDFromPos(x,z,8)] = true
		end
	end
end


function NewPlacementHandler:CreateNewPlan(unit, utype, p)
	local defs = UnitDefs[utype.id]
	local cellsize = math.max(defs.xsize, defs.zsize) * 8
	local buildtype = "ground"
	p = self:GetClosestBuildPosition(p.x, p.z, cellsize, buildtype)
	if p and p.x and p.y and p.z then
		if Spring.TestBuildOrder(utype.id, x,y,z, "s") == 0 then
			return
		end
		self:ClosePosition(p.x, p.z, cellsize, self:GetMinimalSpacing(utype))
		local newplan = {unitID = unit.id, unitDefID = utype.id, p = { x= p.x, y = p.y, z = p.z}}
		local planID = self:GetIDFromPos(p.x, p.z, cellsize)
		newplan["planID"] = planID
		self.plans[planID] = newplan
		self.plansbyunitID[unit.id] = self.plansbyunitID[unit.id] or {}
		self.plansbyunitID[unit.id][planID] = newplan
		self.plansbyunitDefID[utype.id] = self.plansbyunitDefID[utype.id] or {}
		self.plansbyunitDefID[utype.id][planID] = newplan
		return p
	end
	return
end

function NewPlacementHandler:CreateNewPlanNoSearch(unit, utype, p)
	local defs = UnitDefs[utype.id]
	local cellsize = math.max(defs.xsize, defs.zsize) * 8
	local buildtype = "ground"
	if p and p.x and p.y and p.z then
		self:ClosePosition(p.x, p.z, cellsize, self:GetMinimalSpacing(utype))
		local newplan = {unitID = unit.id, unitDefID = utype.id, p = { x= p.x, y = p.y, z = p.z}}
		local planID = self:GetIDFromPos(p.x, p.z, cellsize)
		newplan["planID"] = planID
		self.plans[planID] = newplan
		self.plansbyunitID[unit.id] = self.plansbyunitID[unit.id] or {}
		self.plansbyunitID[unit.id][planID] = newplan
		self.plansbyunitDefID[utype.id] = self.plansbyunitDefID[utype.id] or {}
		self.plansbyunitDefID[utype.id][planID] = newplan
		return p
	end
	return
end

function NewPlacementHandler:GetExistingPlansByUType(utype)
	local planned = {}
	if self.plansbyunitDefID[utype.id] then
		local planned = {}
		for planID, plan in pairs(self.plansbyunitDefID[utype.id]) do
			planned[planID] = plan
		end
	end
	return planned
end

function NewPlacementHandler:GetExistingPlansByUnitDefID(unitDefID)
	local planned = {}
	if self.plansbyunitDefID[unitDefID] then
		for planID, plan in pairs(self.plansbyunitDefID[unitDefID]) do
			planned[planID] = plan
		end
	end
	return planned
end

function NewPlacementHandler:GetExistingPlansByUnit(unit)
	local planned = {}
	if self.plansbyunitID[unit.id] then
		local planned = {}
		for planID, plan in pairs(self.plansbyunitDefID[unit.id]) do
			planned[planID] = plan
		end
	end
	return planned
end

function NewPlacementHandler:GetMinimalSpacing(utype)
	if not (UnitDefs[utype.id].extractsMetal>0) then
		return (math.max(UnitDefs[utype.id].xsize, UnitDefs[utype.id].zsize) * 8)
	else
		return 80
	end
end
