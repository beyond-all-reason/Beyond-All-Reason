function widget:GetInfo()
	return {
		name = "API Resource Spot Builder",
		desc = "Handles construction of metal extractors and geothermal power plants for other widgets",
		author = "Google Frog, NTG (file handling), Chojin (metal map), Doo (multiple enhancements), Floris (mex placer/upgrader), Tarte (maintenance/geothermal)",
		version = "2.0",
		date = "Oct 23, 2010; last update: April 12, 2022",
		license = "GNU GPL, v2 or later",
		handler = true,
		layer = 0,
		enabled = true  --  loaded by default?
	}
end

------------------------------------------------------------
-- Config
------------------------------------------------------------
local t1geoThreshold = 300 --any building producing this much or less is considered tier 1
local t1mexThreshold = 0.001 --any building producing this much or less is considered tier 1

------------------------------------------------------------
-- Speedups
------------------------------------------------------------
local CMD_STOP = CMD.STOP
local CMD_GUARD = CMD.GUARD
local CMD_OPT_RIGHT = CMD.OPT_RIGHT

local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetGroundHeight = Spring.GetGroundHeight
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetTeamUnits = Spring.GetTeamUnits
local spGetMyTeamID = Spring.GetMyTeamID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitDefID = Spring.GetUnitDefID

local selectedUnits = spGetSelectedUnits()

local Game_extractorRadius = Game.extractorRadius
local tasort = table.sort
local taremove = table.remove

------------------------------------------------------------
-- Other variables
------------------------------------------------------------
local lastInsertedOrder

------------------------------------------------------------
-- unit tables
------------------------------------------------------------
local mexConstructors = {}
local mexConstructorsDef = {}
local mexConstructorsT2 = {}
local mexBuildings = {}

local geoConstructors = {}
local geoConstructorsDef = {}
local geoConstructorsT2 = {}
local geoBuildings = {}

local unitWaterDepth = {}
local unitXsize = {}

------------------------------------------------------------
-- populate unit tables
------------------------------------------------------------

for uDefID, uDef in pairs(UnitDefs) do
	if uDef.extractsMetal > 0 then
		mexBuildings[uDefID] = uDef.extractsMetal
	end
	local customParams = uDef.customParams or {}
	if customParams.geothermal then
		geoBuildings[uDefID] = uDef.energyMake
	end
	if uDef.isBuilding then
		unitWaterDepth[uDefID] = { uDef.minWaterDepth, uDef.maxWaterDepth }
		unitXsize[uDefID] = uDef.xsize
	end
end

for uDefID, uDef in pairs(UnitDefs) do
	if uDef.buildOptions then
		local maxExtractMetal = 0
		local maxProduceEnergy = 0
		for i, option in ipairs(uDef.buildOptions) do
			if mexBuildings[option] then
				maxExtractMetal = math.max(maxExtractMetal, mexBuildings[option])
				if mexConstructorsDef[uDefID] then
					mexConstructorsDef[uDefID].buildings = mexConstructorsDef[uDefID].buildings + 1
					mexConstructorsDef[uDefID].building[mexConstructorsDef[uDefID].buildings] = option * -1
				else
					mexConstructorsDef[uDefID] = { buildings = 1, building = { [1] = option * -1 } }
				end
			end
			if geoBuildings[option] then
				maxProduceEnergy = math.max(maxProduceEnergy, geoBuildings[option])
				if geoConstructorsDef[uDefID] then
					geoConstructorsDef[uDefID].buildings = geoConstructorsDef[uDefID].buildings + 1
					geoConstructorsDef[uDefID].building[geoConstructorsDef[uDefID].buildings] = option * -1
				else
					geoConstructorsDef[uDefID] = { buildings = 1, building = { [1] = option * -1 } }
				end
			end
		end
		if maxExtractMetal > t1mexThreshold then
			mexConstructorsT2[uDefID] = true
		end
		if maxProduceEnergy > t1geoThreshold then
			geoConstructorsT2[uDefID] = true
		end
	end
end

------------------------------------------------------------
-- Helper functions (Math stuff)
------------------------------------------------------------

local function Distance(x1, z1, x2, z2)
	return (x1 - x2) * (x1 - x2) + (z1 - z2) * (z1 - z2)
end

local function GetClosestPosition(x, z, positions)
	local bestPos
	local bestDist = math.huge
	for i = 1, #positions do
		local pos = positions[i]
		local dx, dz = x - pos.x, z - pos.z
		local dist = dx * dx + dz * dz
		if dist < bestDist then
			bestPos = pos
			bestDist = dist
		end
	end
	return bestPos
end

------------------------------------------------------------
-- Building logic
------------------------------------------------------------

local function IsSpotOccupied(spot)
	local units = Spring.GetUnitsInCylinder(spot.x, spot.z, Game_extractorRadius)
	for j=1, #units do
		if mexBuildings[spGetUnitDefID(units[j])]  then
			return units[j]
		end
	end
	return false
end

-- Is there any better and allied mex at this location? (returns false if there is)
local function NoAlliedMex(x, z, batchextracts)
	local mexesatspot = Spring.GetUnitsInCylinder(x, z, Game_extractorRadius)
	for i = 1, #mexesatspot do
		local uid = mexesatspot[i]
		if mexBuildings[spGetUnitDefID(uid)] and Spring.AreTeamsAllied(spGetMyTeamID(), Spring.GetUnitTeam(uid)) and mexBuildings[spGetUnitDefID(uid)] >= batchextracts then
			return false
		end
	end
	return true
end


local function BuildResourceExtractors(params, options, isGuard, justDraw, constructorIds, buildingIds, spots)		-- when isGuard: needs to be a table of the unit pos: { x = ux, y = uy, z = uz }
	local cx, cy, cz, cr = params[1], params[2], params[3], params[4]
	if not cr or cr < Game_extractorRadius then cr = Game_extractorRadius end
	local units = selectedUnits

	-- Get highest producing building and constructor
	local maxresourceextractor = 0
	local lastprocessedbestconstructor
	for i = 1, #units do
		local id = units[i]
		if constructorIds[id] then
			if buildingIds[(constructorIds[id].building[1]) * -1] > maxresourceextractor then
				maxresourceextractor = buildingIds[(constructorIds[id].building[1]) * -1]
				lastprocessedbestconstructor = id
			end
		end
	end

	-- Add highest producing constructors to mainBuilders table + give guard orders to "inferior" constructors
	local mainBuilders = {}
	local mainBuildersCount = 0
	local ux, uz, aveX, aveZ = 0, 0, 0, 0
	for i = 1, #units do
		local id = units[i]
		if constructorIds[id] then
			if buildingIds[(constructorIds[id].building[1]) * -1] == maxresourceextractor then
				local x, _, z = spGetUnitPosition(id)
				if z then
					ux, uz = ux+x, uz+z
					lastprocessedbestconstructor = id
					mainBuildersCount = mainBuildersCount + 1
					mainBuilders[mainBuildersCount] = id
				end
			else
				-- guard to a main builder
				if not justDraw then
					if not options.shift then
						spGiveOrderToUnit(id, CMD_STOP, {}, CMD_OPT_RIGHT)
					end
					spGiveOrderToUnit(id, CMD_GUARD, { lastprocessedbestconstructor }, { "shift" })
				end
			end
		end
	end

	if mainBuildersCount == 0 then return end
	aveX, aveZ = ux/mainBuildersCount, uz/mainBuildersCount

	-- Get available mex spots within area
	local commands = {}
	local commandsCount = 0
	local mexes = isGuard and { isGuard } or spots -- only need the mex/spot we guard if that is the case
	for k = 1, #mexes do
		local mex = mexes[k]
		if not (mex.x % 16 == 8) then mexes[k].x = mexes[k].x + 8 - (mex.x % 16) end
		if not (mex.z % 16 == 8) then mexes[k].z = mexes[k].z + 8 - (mex.z % 16) end
		mex.x, mex.z = mexes[k].x, mexes[k].z
		if Distance(cx, cz, mex.x, mex.z) < cr * cr then
			if NoAlliedMex(mex.x, mex.z, maxresourceextractor) then
				commandsCount = commandsCount + 1
				commands[commandsCount] = { x = mex.x, z = mex.z, d = Distance(aveX, aveZ, mex.x, mex.z) }
			end
		end
	end

	-- Order available mex spots based on distance
	local orderedCommands = {}
	while commandsCount > 0 do
		tasort(commands, function(a, b)
			return a.d < b.d
		end)
		orderedCommands[#orderedCommands + 1] = commands[1]
		aveX, aveZ = commands[1].x, commands[1].z
		taremove(commands, 1)
		for k, com in pairs(commands) do
			com.d = Distance(aveX, aveZ, com.x, com.z)
		end
		commandsCount = commandsCount - 1
	end

	-- Shift key not used = give stop command first
	if not justDraw and not options.shift then
		for ct = 1, mainBuildersCount do
			spGiveOrderToUnit(mainBuilders[ct], CMD_STOP, {}, CMD_OPT_RIGHT)
		end
	end

	-- Give the actual mex build orders
	local queuedMexes = {}
	for ct = 1, mainBuildersCount do
		local id = mainBuilders[ct]
		for i = 1, #orderedCommands do
			local command = orderedCommands[i]
			for j = 1, constructorIds[id].buildings do
				local targetPos, targetOwner
				local occupiedMex = IsSpotOccupied({x = command.x, z =command.z})
				if occupiedMex then
					local occupiedPos = { spGetUnitPosition(occupiedMex) }
					targetPos = {x=occupiedPos[1], y=occupiedPos[2], z=occupiedPos[3]}
					targetOwner = Spring.GetUnitTeam(occupiedMex)	-- because gadget "Mex Upgrade Reclaimer" will share a t2 mex build upon ally t1 mex
				else

					local closestResourceSpot = GetClosestPosition(command.x, command.z, spots);
					local buildingPositions = WG['resource_spot_finder'].GetBuildingPositions(closestResourceSpot, -constructorIds[id].building[j], 0, true)
					targetPos = GetClosestPosition(command.x, command.z, buildingPositions)
					targetOwner = spGetMyTeamID()
				end
				if targetPos then
					local newx, newz = targetPos.x, targetPos.z
					queuedMexes[#queuedMexes+1] = { id, math.abs(constructorIds[id].building[j]), newx, spGetGroundHeight(newx, newz), newz, targetOwner }
					if not justDraw then
						spGiveOrderToUnit(id, constructorIds[id].building[j], { newx, spGetGroundHeight(newx, newz), newz }, { "shift" })
						lastInsertedOrder = { command.x, command.z}
					end
					break
				end
			end
		end
	end

	if isGuard and #queuedMexes == 0 then
		return		-- no mex buildorder made so let move go through!
	end
	return queuedMexes
end

------------------------------------------------------------
-- Callins
------------------------------------------------------------

function widget:SelectionChanged(sel)
	selectedUnits = sel
end

function widget:UnitCreated(unitID, unitDefID)
	if mexConstructorsDef[unitDefID] then
		mexConstructors[unitID] = mexConstructorsDef[unitDefID]
	end
	if geoConstructorsDef[unitDefID] then
		geoConstructors[unitID] = geoConstructorsDef[unitDefID]
	end
end

function widget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	if not mexConstructors[unitID] or geoConstructors[unitID] then
		widget:UnitCreated(unitID, unitDefID, newTeam)
	end
end

function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if not mexConstructors[unitID] or geoConstructors[unitID] then
		widget:UnitCreated(unitID, unitDefID, newTeam)
	end
end


function widget:Initialize()
	local units = spGetTeamUnits(spGetMyTeamID())
	for i = 1, #units do
		local id = units[i]
		widget:UnitCreated(id, spGetUnitDefID(id))
	end

	--make interfaces available to other widgets:
	WG['resource_spot_builder'] = { }


	WG['resource_spot_builder'].BuildMex = function(params, options, isGuard, justDraw)
		return BuildResourceExtractors (params, options, isGuard, justDraw, mexConstructors, mexBuildings, WG['resource_spot_finder'].metalSpotsList)
	end

	WG['resource_spot_builder'].BuildGeothermal = function(params, options, isGuard, justDraw)
		return BuildResourceExtractors (params, options, isGuard, justDraw, geoConstructors, geoBuildings, WG['resource_spot_finder'].geoSpotsList)
	end

	----------------------------------------------
	-- builders and buildings - MEX
	----------------------------------------------

	WG['resource_spot_builder'].GetMexConstructors = function()
		return mexConstructors
	end

	WG['resource_spot_builder'].GetMexConstructorsDef = function()
		return mexConstructorsDef
	end

	WG['resource_spot_builder'].GetMexConstructorsT2 = function()
		return mexConstructorsT2
	end

	WG['resource_spot_builder'].GetMexBuildings = function()
		return mexBuildings
	end

	----------------------------------------------
	-- builders and buildings - Geothermal
	----------------------------------------------

	WG['resource_spot_builder'].GetGeoConstructors = function()
		return geoConstructors
	end

	WG['resource_spot_builder'].GetGeoConstructorsDef = function()
		return geoConstructorsDef
	end

	WG['resource_spot_builder'].GetGeoConstructorsT2 = function()
		return geoConstructorsT2
	end

	WG['resource_spot_builder'].GetGeoBuildings = function()
		return geoBuildings
	end
end
