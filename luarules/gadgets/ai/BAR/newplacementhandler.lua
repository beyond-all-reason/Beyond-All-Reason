NewPlacementHandler = class(Module)

function NewPlacementHandler:Name()
	return "NewPlacementHandler"
end

function NewPlacementHandler:internalName()
	return "newplacementhandler"
end

function NewPlacementHandler:GetIDBuildable(id, cellsize, buildtype)
	return GG.AiHelpers.NewPlacementHandler.GetIDBuildable(id,cellsize,buildtype)
end

function NewPlacementHandler:GetPosFromID(id)
	return GG.AiHelpers.NewPlacementHandler.GetPosFromID(id)
end

function NewPlacementHandler:GetIDFromPos(x, z, cellsize)
	return GG.AiHelpers.NewPlacementHandler.GetIDFromPos(x,z,cellsize)
end

function NewPlacementHandler:ClosePosition(x,z, cellsize,spacing)
	GG.AiHelpers.NewPlacementHandler.ClosePosition(x,z, cellsize, spacing)
end

function NewPlacementHandler:FreePosition(x,z,cellsize,spacing)
	GG.AiHelpers.NewPlacementHandler.FreePosition(x,z,cellsize,spacing)
end

function generateSpiral()
	local retTable = {}
	local attempt = 0
	local ct = 0
	while attempt < 50 do
		attempt = attempt + 1
		for v = -attempt, attempt do
			for h = -attempt, attempt do	
				if math.abs(v) == attempt or math.abs(h) == attempt then
					ct = ct + 1
					retTable[ct] = {v, h}
				end
			end
		end
	end
	return retTable
end
		
	

function NewPlacementHandler:UnitIdle(engineunit)
	if not Spring.GetGameFrame() == 0 then
		local unitDefID = UnitDefNames[unit:Name()].id
		local defs = UnitDefs[unitDefID]
		if defs then
			if defs.canBuild == true then
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
end

function NewPlacementHandler:Init()
	self.plans = {}
	self.plansbyunitID = {}
	self.plansbyunitDefID = {}	
	mapwidth = math.max(Game.mapSizeX, Game.mapSizeZ)
	if not spiral then
		spiral = generateSpiral()
	end
	for i, spot in pairs(self.ai.metalspothandler.spots) do
		self:ClosePosition(spot.x, spot.z, 32, 80) -- close mex positions (they might get freed during a scan though)
	end
end

function NewPlacementHandler:GetClosestBuildPosition(x, z, cellsize, buildtype)
	local ID = self:GetIDFromPos(x, z, cellsize)
	local POS = self:GetPosFromID(ID)
	local x, z = POS.x, POS.z
	local attempt = 0
	local pos
	buildable = self:GetIDBuildable(ID, cellsize, buildtype)
	if buildable == true then bestID = ID end
	while buildable ~= true and attempt <= 10200 do
		attempt = attempt + 1
		v = spiral[attempt][1]
		h = spiral[attempt][2]
		local id = ID + (v*cellsize*mapwidth) + (h*cellsize)
		if self:GetIDBuildable(id, cellsize, buildtype) == true then
			buildable = true
			bestID = id
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

function NewPlacementHandler:CreateNewPlan(unit, utype, p)
	local defs = UnitDefs[utype.id]
	local Building = (defs.isBuilding == true or string.find(defs.name, "nanotc"))
	local cellsize = math.max(defs.xsize, defs.zsize) * 8
	local buildtype = "ground"
	p = self:GetClosestBuildPosition(p.x, p.z, cellsize, buildtype)
	if p and p.x and p.y and p.z then
		local facing = self:GetFacing(p)
		if facing == 0 or facing == 2 then
			p.x = p.x - (p.x%16) + (defs.xsize*4 % 16)
			p.z = p.z - (p.z%16) + (defs.zsize*4 % 16)
		else
			p.x = p.x - (p.x%16) + (defs.zsize*4 % 16)
			p.z = p.z - (p.z%16) + (defs.xsize*4 % 16)
		end
		if Spring.TestBuildOrder(utype.id, p.x,p.y,p.z, "s") == 0 then
			return
		end
		if Building then -- filter out mobile units built from mobile engineers, these will only need a buildposition, no planning
			self:ClosePosition(p.x, p.z, cellsize, self:GetMinimalSpacing(utype))
			local newplan = {unitID = unit.id, unitDefID = utype.id, p = { x= p.x, y = p.y, z = p.z}}
			local planID = self:GetIDFromPos(p.x, p.z, cellsize)
			newplan["planID"] = planID
			self.plans[planID] = newplan
			self.plansbyunitID[unit.id] = self.plansbyunitID[unit.id] or {}
			self.plansbyunitID[unit.id][planID] = newplan
			self.plansbyunitDefID[utype.id] = self.plansbyunitDefID[utype.id] or {}
			self.plansbyunitDefID[utype.id][planID] = newplan
		end
		return p, facing
	end
	return
end

function NewPlacementHandler:CreateNewPlanNoSearch(unit, utype, p)
	local defs = UnitDefs[utype.id]
	local cellsize = math.max(defs.xsize, defs.zsize) * 8
	local buildtype = "ground"
	if p and p.x and p.y and p.z then
		local facing = self:GetFacing(p)
		if facing == 0 or facing == 2 then
			p.x = p.x - (p.x%16) + (defs.xsize*4 % 16)
			p.z = p.z - (p.z%16) + (defs.zsize*4 % 16)
		else
			p.x = p.x - (p.x%16) + (defs.zsize*4 % 16)
			p.z = p.z - (p.z%16) + (defs.xsize*4 % 16)
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
		return p, facing
	end
	return
end

function NewPlacementHandler:GetFacing(p)
	local x = p.x
	local z = p.z
    if math.abs(Game.mapSizeX - 2*x) > math.abs(Game.mapSizeZ - 2*z) then
      if (2*x>Game.mapSizeX) then
        facing=3
      else
        facing=1
      end
    else
      if (2*z>Game.mapSizeZ) then
        facing=2
      else
        facing=0
      end
    end
	return facing
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
	local r = math.random(0,5)
	if string.find(UnitDefs[utype.id].name, "nanotc") then
		if r <= 1 then
			return 0
		elseif r == 2 then
			return 60
		else
			return 20
		end
	elseif string.find(UnitDefs[utype.id].name, "solar") then
		if r <= 1 then
			return 0
		elseif r == 2 then
			return 60
		else
			return 20
		end
	elseif string.find(UnitDefs[utype.id].name, "win") then
		if r <= 1 then
			return 0
		elseif r == 2 then
			return 60
		else
			return 20
		end
	elseif string.find(UnitDefs[utype.id].name, "makr") then
		if r <= 1 then
			return 0
		elseif r == 2 then
			return 60
		else
			return 20
		end
	elseif not (UnitDefs[utype.id].extractsMetal>0) then
		return (math.max(UnitDefs[utype.id].xsize, UnitDefs[utype.id].zsize) * 8)
	else
		return math.random(50,100)
	end
end
