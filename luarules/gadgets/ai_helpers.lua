function gadget:GetInfo()
	return {
		name 	= "Ai Helpers",
		desc	= "Used for AI scripts",
		author	= "Doo",
		date	= "August 2018",
		license	= "GNU GPL, v2 or later",
		layer	= 0,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then

GG.AiHelpers = {}

--------------------------------
-- NewPlacementHandler Helper --
--------------------------------
GG.AiHelpers.NewPlacementHandler = {}

GG.AiHelpers.Start = function()
	enabled = true
	gadget:Initialize()
end

local mapwidth = math.max(Game.mapSizeX, Game.mapSizeZ)
local celltoscan = celltoscan or {}
local defidpersizetype = defidpersizetype or {}
local cells = cells or {}

GG.AiHelpers.NewPlacementHandler.GetPosFromID = function(id)
	local z = id%mapwidth
	local x = (id - z)/mapwidth
	return {x = x, z = z}
end

GG.AiHelpers.NewPlacementHandler.GetIDFromPos = function(x, z, cellsize)
	return (x - x%cellsize) * mapwidth + (z - z%cellsize)
end

GG.AiHelpers.NewPlacementHandler.GetIDBuildable = function(id, cellsize, buildtype)
	return cells[cellsize][buildtype][id]
end

GG.AiHelpers.NewPlacementHandler.ClosePosition = function(x,z, cellsize,spacing)
	local id1 = GG.AiHelpers.NewPlacementHandler.GetIDFromPos(x,z,cellsize)
	local pos = GG.AiHelpers.NewPlacementHandler.GetPosFromID(id1)
	local x, z = pos.x, pos.z
	for v = x-spacing, x+spacing+cellsize-1, 8 do
		for h = z-spacing, z+spacing+cellsize-1, 8 do
			for size, cell in pairs(cells) do
				local id = GG.AiHelpers.NewPlacementHandler.GetIDFromPos(v,h,size)
				gadget:SetCellValue(id, size, "ground", false)
			end
		end
	end
end

GG.AiHelpers.NewPlacementHandler.FreePosition = function(x,z,cellsize,spacing)
	local id1 = GG.AiHelpers.NewPlacementHandler.GetIDFromPos(x,z,cellsize)
	local pos = GG.AiHelpers.NewPlacementHandler.GetPosFromID(id1)
	local x, z = pos.x, pos.z
	for v = x - spacing, x + spacing + cellsize-1, 8 do
		for h = z - spacing, z + spacing + cellsize - 1 ,8 do
			gadget:ScanCell(GG.AiHelpers.NewPlacementHandler.GetIDFromPos(x,z,8))
		end
	end
end

----------------------------
--Retreat Positions Helper--
----------------------------
GG.AiHelpers.NanoTC = {}
local isNanoTC = {}
local NanoTC = {}
local ClosestNanoTC = {}

for unitDefID, defs in pairs(UnitDefs) do
	if string.find(defs.name, "nanotc") then
		isNanoTC[unitDefID] = true
	end
end

GG.AiHelpers.NanoTC.GetClosestNanoTC = function (unitID)
	local bestx, besty, bestz
	local teamID = Spring.GetUnitTeam(unitID)
	local ux, uy, uz = Spring.GetUnitPosition(unitID)
	local bestID
	local mindis = math.huge
	local x, y, z = math.floor(ux/256), math.floor(uy/256), math.floor(uz/256)
	if ClosestNanoTC and ClosestNanoTC[teamID] and ClosestNanoTC[teamID][x] and ClosestNanoTC[teamID][x][z] and Spring.ValidUnitID(ClosestNanoTC[teamID][x][z]) then
		bestID = ClosestNanoTC[teamID][x][z]
	elseif NanoTC and NanoTC[teamID] then
		for uid, pos in pairs (NanoTC[teamID]) do
			local gx, gy, gz = pos[1], pos[2], pos[3]
			local dis = gadget:Distance(ux, uz, gx, gz)
			if dis< mindis then
				mindis = dis
				bestID = uid
				if not ClosestNanoTC then ClosestNanoTC = {} end
				if not ClosestNanoTC[teamID] then ClosestNanoTC[teamID] = {} end		
				if not ClosestNanoTC[teamID][x] then ClosestNanoTC[teamID][x] = {} end						
				ClosestNanoTC[teamID][x][z] = uid
			end
		end
	end
	if bestID then
	bestx, besty, bestz = Spring.GetUnitPosition(bestID)
	end
	return bestx, besty, bestz
end
-------------
--Unit Info--
-------------

GG.AiHelpers.UnitInfo = {}
local info = {}

GG.AiHelpers.UnitInfo = function(teamID, unitDefID)
	return info[teamID] and info[teamID][unitDefID] or nil
end

--------------------------
--Unit Visibility Checks--
-------------------------
GG.AiHelpers.VisibilityCheck = {}
local SeenBuildings = {}

GG.AiHelpers.VisibilityCheck.IsUnitVisible = function(unitID, teamID)
	local _,_,_,_,_,allyTeamID = Spring.GetTeamInfo(teamID)
	if SeenBuildings[teamID] and SeenBuildings[teamID][unitID] then
		return true
	elseif Spring.IsUnitInLos(unitID, allyTeamID) or Spring.IsUnitInRadar(unitID, allyTeamID) then
		return true
	end
	return false
end


-------------------------
--Gadget Core Functions--
-------------------------

	function gadget:Distance(x1,z1, x2,z2)
		local vectx = x2 - x1
		local vectz = z2 - z1
		local dis = math.sqrt(vectx^2+vectz^2)
		return dis
	end
	
	function gadget:Initialize()
		if enabled ~= true then return end
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
							gadget:SetCellValue(GG.AiHelpers.NewPlacementHandler.GetIDFromPos(x, z, cellsize), cellsize, buildtype, (Spring.TestBuildOrder(unitDefID, x + cellsize/2, Spring.GetGroundHeight(x + cellsize/2, z+cellsize/2), z+cellsize/2, "s") >= 1 and Spring.TestBuildOrder(unitDefID, x + cellsize/2, Spring.GetGroundHeight(x + cellsize/2, z+cellsize/2), z+cellsize/2, "e") >= 1))
						end
					end
				end
			end
		end
		
		for ct, unitID in pairs(Spring.GetAllUnits()) do
			local unitDefID = Spring.GetUnitDefID(unitID)
			local unitTeam = Spring.GetUnitTeam(unitID)
			gadget:UnitFinished(unitID, unitDefID, unitTeam)
		end
	end

	function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
		if enabled ~= true then return end
		info[teamID] = info[teamID] or {}
		info[teamID][unitDefID] = info[teamID][unitDefID] or {killed_cost=0,n=0, avgkilled_cost=0}
		info[teamID][unitDefID].n = info[teamID][unitDefID].n + 1
		if info[teamID][unitDefID].n > 80 then 
			info[teamID][unitDefID].n = info[teamID][unitDefID].n - 1
			info[teamID][unitDefID].killed_cost = info[teamID][unitDefID].killed_cost - info[teamID][unitDefID].avgkilled_cost
			if info[teamID][unitDefID].killed_cost <= 0 then info[teamID][unitDefID].killed_cost = 0 end
			info[teamID][unitDefID].avgkilled_cost = info[teamID][unitDefID].killed_cost / info[teamID][unitDefID].n
		end
	end
	
	function gadget:UnitEnteredRadar(unitID, unitTeam, allyTeam, unitDefID)
		if enabled ~= true then return end
		local defs = UnitDefs[unitDefID]
		if defs.isBuilding or string.find(defs.name, "nanotc") then
			for ct, id in pairs (Spring.GetTeamList(allyTeam)) do
				SeenBuildings[id] = SeenBuildings[id] or {}
				SeenBuildings[id][unitID] = true
			end
		end				
	end
	
	function gadget:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)
		if enabled ~= true then return end
		local defs = UnitDefs[unitDefID]
		if defs.isBuilding or string.find(defs.name, "nanotc") then
			for ct, id in pairs (Spring.GetTeamList(allyTeam)) do
				SeenBuildings[id] = SeenBuildings[id] or {}
				SeenBuildings[id][unitID] = true
			end
		end				
	end
	
	function gadget:UnitFinished(unitID, unitDefID, unitTeam)
		if enabled ~= true then return end
		if isNanoTC[unitDefID] then
			if not NanoTC[unitTeam] then NanoTC[unitTeam] = {} end
			NanoTC[unitTeam][unitID] = {Spring.GetUnitPosition(unitID)}
			gadget:UpdateClosestNanoTCTable(unitTeam)
		end
	end
	
	function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
		if enabled ~= true then return end
		if not attackerDefID then return end
		if not unitDefID then return end
		if not info[attackerTeam] then return end
		if not info[attackerTeam][attackerDefID] then return end
		if not info[unitTeam] then return end
		if not info[unitTeam][unitDefID] then return end
		if Spring.AreTeamsAllied(unitTeam,attackerTeam) then return end
		local h,maxh,_ = Spring.GetUnitHealth(unitID)
		damage = math.min(h,damage)
		if paralyzer then damage = damage * 0.2 end
		if attackerDefID and attackerTeam then
			local count = Spring.GetTeamUnitDefCount(attackerTeam, attackerDefID)
			if count > 0 then
				ratio2 = 30/count
			else
				ratio2 = 30
			end
		end
		local ratio = damage/maxh
		local killed_m = UnitDefs[unitDefID].metalCost * ratio
		local killed_e = UnitDefs[unitDefID].energyCost * ratio
		info[attackerTeam][attackerDefID].killed_cost = info[attackerTeam][attackerDefID].killed_cost + killed_m + killed_e/60
		info[attackerTeam][attackerDefID].avgkilled_cost = info[attackerTeam][attackerDefID].killed_cost / info[attackerTeam][attackerDefID].n
	end
	
	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
		if enabled ~= true then return end
		if not NanoTC[unitTeam] then NanoTC[unitTeam] = {} end
		NanoTC[unitTeam][unitID] = nil
		gadget:UpdateClosestNanoTCTable(unitTeam)
		for ct, id in pairs(Spring.GetTeamList()) do
			if SeenBuildings[id] then
				SeenBuildings[id][unitID] = nil
			end
		end
	end

	function gadget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
		if enabled ~= true then return end
		gadget:UnitDestroyed(unitID, unitDefID, oldTeam)
		gadget:UnitFinished(unitID, unitDefID, newTeam)	
	end

	
	function gadget:GameFrame(f)
		if enabled ~= true then return end
		for id, cell in pairs(celltoscan) do
			if f%300 == id%300 then
				for size, metatable in pairs(defidpersizetype) do
					local pos = GG.AiHelpers.NewPlacementHandler.GetPosFromID(id)
					for buildtype, unitDefID in pairs(metatable) do
						gadget:SetCellValue(GG.AiHelpers.NewPlacementHandler.GetIDFromPos(pos.x, pos.z, size), size, buildtype,(Spring.TestBuildOrder(unitDefID, pos.x + size/2, Spring.GetGroundHeight(pos.x + size/2, pos.z+size/2), pos.z+size/2, "s") >= 1 and Spring.TestBuildOrder(unitDefID, pos.x + size/2, Spring.GetGroundHeight(pos.x + size/2, pos.z+size/2), pos.z+size/2, "e") >= 1))
						celltoscan[id] = nil
					end
				end
			end
		end
	end

	function gadget:SetCellValue(id, size, buildtype, value)
		cells[size][buildtype][id] = value
	end
	
	function gadget:ScanCell(id)
		celltoscan[id] = true
	end
	
	function gadget:UpdateClosestNanoTCTable(teamID)
		if teamID then
			ClosestNanoTC[teamID] = nil
		end
	end

end