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
local maxOrdersCheck = 50 --maximum amount of orders in unit queue to check for duplicate orders

------------------------------------------------------------
-- Speedups
------------------------------------------------------------
local CMD_STOP = CMD.STOP
local CMD_GUARD = CMD.GUARD
local CMD_OPT_RIGHT = CMD.OPT_RIGHT

local spGetBuildFacing = Spring.GetBuildFacing
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
local tacount = table.count


------------------------------------------------------------
-- Other variables
------------------------------------------------------------

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
end

for uDefID, uDef in pairs(UnitDefs) do
	if uDef.buildOptions then
		local maxExtractMetal = 0
		local maxProduceEnergy = 0
		for _, option in ipairs(uDef.buildOptions) do
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

local function distance2dSquared(x1, z1, x2, z2)
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


local function resourceSpotHasExistingExtractorCommand(x, z, builders)
	for i=1, #builders do
		local queue = Spring.GetCommandQueue(builders[i], 100)
		for j=1, #queue do
			local command = queue[j]
			local id = -command.id
			if(mexBuildings[id] or geoBuildings[id]) then
				local dist = distance2dSquared(x, z, command.params[1], command.params[3])
				-- Save a sqrt by multiplying by 4
				-- Note that this is calculating by diameter, and could be too aggressive on maps with closely spaced mexes
				-- Reduce this radius if there are cases found where mex spots get missed when in close proximity
				if dist < Game_extractorRadius * Game_extractorRadius then
					return true
				end
			end
		end
	end
	return false
end


-- Naive best match, ignores special mexes (exploiter etc), just finds highest extraction amount
local function getBestMexFromSelectedBuilders(units, constructorIds, extractors)
	local bestExtraction = 0
	local bestExtractor
	for i = 1, #units do
		-- only processes first mex option for each builder
		local id = units[i]
		local constructor = constructorIds[id]


		if constructor then
			local buildingID = -constructor.building[1]
			local extractionAmount = extractors[buildingID]
			if(extractionAmount > bestExtraction) then
				bestExtraction = extractionAmount
				bestExtractor = buildingID
			end
		end
	end
	return bestExtractor
end

-- Can any mex at this location be upgraded
local function canExtractorBeUpgraded(x, z, extractorId)

	local newExtractor = UnitDefs[extractorId]
	local newExtractorStrength = mexBuildings[extractorId] or geoBuildings[extractorId]
	local newExtractorIsSpecial = newExtractor.stealth or #newExtractor.weapons > 0

	local units = Spring.GetUnitsInCylinder(x, z, Game_extractorRadius)
	for i = 1, #units do
		local uid = units[i]
		local uDefId = spGetUnitDefID(uid)
		local currentExtractorStrength = mexBuildings[uDefId] or geoBuildings[uDefId] -- is an extractor
		local isAllied = Spring.AreTeamsAllied(spGetMyTeamID(), Spring.GetUnitTeam(uid))
		if currentExtractorStrength and isAllied then
			if(newExtractorStrength > currentExtractorStrength) then
				return true
			end
			if(newExtractorStrength == currentExtractorStrength and newExtractorIsSpecial) then
				return true
			end
		end
		if not currentExtractorStrength then -- is not an extractor
			return true
		end
	end

	if #units == 0 then
		return true
	end

	return false
end


local function BuildResourceExtractors(params, options, isGuard, justDraw, constructorIds, extractors, spots, checkDuplicateOrders)		-- when isGuard: needs to be a table of the unit pos: { x = ux, y = uy, z = uz }
	local cx, _, cz, cr = params[1], params[2], params[3], params[4]
	if not cr or cr < Game_extractorRadius then cr = Game_extractorRadius end
	local units = selectedUnits


	-- Get highest producing building and constructor
	local chosenExtractor

	local extractorCount = tacount(extractors)
	if(extractorCount == 1) then
		-- If calling with a specified mex type, just grab that
		local key, _ = next(extractors)
		chosenExtractor = key
	else
		chosenExtractor = getBestMexFromSelectedBuilders(units, constructorIds, extractors)
	end


	if not chosenExtractor then
		Spring.Echo("Failed to find a constructor/extractor match")
		return
	end

	-- Add highest producing constructors to mainBuilders table + give guard orders to "inferior" constructors
	local mainBuilders = {}
	local ux, uz, aveX, aveZ = 0, 0, 0, 0
	local latestMainBuilder
	local secondaryBuilders = {}
	for i = 1, #units do
		local id = units[i]
		local constructor = constructorIds[id]
		if constructor then
			-- iterate over constructor options to see if it can make the chosen extractor
			for _, buildingId in pairs(constructor.building) do
				if -buildingId == chosenExtractor and extractors[chosenExtractor] then
					-- found match
					local x, _, z = spGetUnitPosition(id)
					if z then
						ux, uz = ux+x, uz+z
						latestMainBuilder = id
						mainBuilders[#mainBuilders + 1] = id
						if justDraw then
							break -- prevent complex calculations further down the line
						end
					end
				else
					secondaryBuilders[#secondaryBuilders + 1] = id
				end
			end

		end
	end

	-- order secondary builders to guard main builders, equally dispersed
	if not justDraw then
		local index = 1
		for i, uid in pairs(secondaryBuilders) do
			if not options.shift then
				spGiveOrderToUnit(uid, CMD_STOP, {}, CMD_OPT_RIGHT)
			end
			local mainBuilderId = mainBuilders[index]
			spGiveOrderToUnit(uid, CMD_GUARD, { mainBuilderId }, { "shift" })
			index = index + 1
			if index > #mainBuilders then index = 1 end
		end
	end

	if #mainBuilders == 0 then return end
	aveX, aveZ = ux/#mainBuilders, uz/#mainBuilders

	-- Get available mex spots within area
	local commands = {}
	local mexes = isGuard and { isGuard } or spots -- only need the mex/spot we guard if that is the case
	for k = 1, #mexes do
		local mex = mexes[k]
		if not (mex.x % 16 == 8) then mexes[k].x = mexes[k].x + 8 - (mex.x % 16) end
		if not (mex.z % 16 == 8) then mexes[k].z = mexes[k].z + 8 - (mex.z % 16) end
		mex.x, mex.z = mexes[k].x, mexes[k].z
		if distance2dSquared(cx, cz, mex.x, mex.z) < cr * cr then
			-- Skip mex spots that have queued mexes already
			-- only searches selected builders, and only checks when shift is held
			if options.shift then
				if not resourceSpotHasExistingExtractorCommand(mex.x, mex.z, mainBuilders) then
					if canExtractorBeUpgraded(mex.x, mex.z, chosenExtractor) then
						commands[#commands + 1] = { x = mex.x, z = mex.z, d = distance2dSquared(aveX, aveZ, mex.x, mex.z) }
					end
				end
			else
				if canExtractorBeUpgraded(mex.x, mex.z, chosenExtractor) then
					commands[#commands + 1] = { x = mex.x, z = mex.z, d = distance2dSquared(aveX, aveZ, mex.x, mex.z) }
				end
			end
		end
	end

	-- Order available mex spots based on distance
	local orderedCommands = {}
	local sort = function(a, b)
		return a.d < b.d
	end
	while #commands > 0 do
		tasort(commands, sort)
		orderedCommands[#orderedCommands + 1] = commands[1]
		aveX, aveZ = commands[1].x, commands[1].z
		taremove(commands, 1)
		for _, com in pairs(commands) do
			com.d = distance2dSquared(aveX, aveZ, com.x, com.z)
		end
	end

	-- Shift key not used = give stop command first
	if not justDraw and not options.shift then
		checkDuplicateOrders = false -- no need to check for duplicate orders
		for ct = 1, #mainBuilders do
			spGiveOrderToUnit(mainBuilders[ct], CMD_STOP, {}, CMD_OPT_RIGHT)
		end
	end

	-- Give the actual mex build orders
	local facing = spGetBuildFacing() or 1
	local queuedMexes = {}
	for ct = 1, #mainBuilders do
		local id = mainBuilders[ct]
		local mexOrders = {}

		if checkDuplicateOrders then
			local mexOrdersCount = 0
			for _, order in pairs(Spring.GetUnitCommands(id, maxOrdersCheck)) do
				if extractors[-order["id"]] then
					mexOrdersCount = mexOrdersCount + 1
					mexOrders[mexOrdersCount] = order
				end
			end
		end

		for i = 1, #orderedCommands do
			local command = orderedCommands[i]
			local constructor = constructorIds[id]
			for j = 1, constructor.buildings do
				local buildingId = -chosenExtractor
				local targetPos, targetOwner
				local occupiedMex = IsSpotOccupied({x = command.x, z =command.z})
				if occupiedMex then
					local occupiedPos = { spGetUnitPosition(occupiedMex) }
					targetPos = {x=occupiedPos[1], y=occupiedPos[2], z=occupiedPos[3]}
					targetOwner = Spring.GetUnitTeam(occupiedMex)	-- because gadget "Mex Upgrade Reclaimer" will share a t2 mex build upon ally t1 mex
				else

					local closestResourceSpot = GetClosestPosition(command.x, command.z, spots);
					local buildingPositions = WG['resource_spot_finder'].GetBuildingPositions(closestResourceSpot, -buildingId, 0, true)
					targetPos = GetClosestPosition(command.x, command.z, buildingPositions)
					targetOwner = spGetMyTeamID()
				end
				if targetPos then
					local newx, newz = targetPos.x, targetPos.z
					local orderParams = { newx, spGetGroundHeight(newx, newz), newz, facing }

					local duplicateFound = false

					if checkDuplicateOrders then
						for mI, mexOrder in pairs(mexOrders) do
							if mexOrder["id"] == buildingId then
								local mParams = mexOrder["params"]
								if mParams[1] == orderParams[1] and mParams[2] == orderParams[2] and mParams[3] == orderParams[3] and mParams[4] == orderParams[4] then
									duplicateFound = true
									mexOrders[mI] = nil
									break
								end
							end
						end
					end

					if not(checkDuplicateOrders and duplicateFound) then
						queuedMexes[#queuedMexes+1] = { id, math.abs(buildingId), newx, spGetGroundHeight(newx, newz), newz, targetOwner }

						if not justDraw then
							spGiveOrderToUnit(id, buildingId, orderParams, { "shift" })
						end
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

function widget:UnitTaken(unitID, unitDefID, _, newTeam)
	if not mexConstructors[unitID] or geoConstructors[unitID] then
		widget:UnitCreated(unitID, unitDefID, newTeam)
	end
end

function widget:UnitGiven(unitID, unitDefID, newTeam)
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

	-- This gets called *every frame* by cmd_rclick_quick_build_resource_extractor
	WG['resource_spot_builder'].BuildMex = function(params, options, isGuard, justDraw, noToggleOrder, buildingID)

		local buildings = {}
		if(buildingID) then
			buildings[-buildingID] = UnitDefs[-buildingID].extractsMetal
		else
			buildings = mexBuildings
		end

		return BuildResourceExtractors (params, options, isGuard, justDraw, mexConstructors, buildings, WG['resource_spot_finder'].metalSpotsList, noToggleOrder)
	end

	WG['resource_spot_builder'].BuildGeothermal = function(params, options, isGuard, justDraw)
		return BuildResourceExtractors (params, options, isGuard, justDraw, geoConstructors, geoBuildings, WG['resource_spot_finder'].geoSpotsList)
	end

	----------------------------------------------
	-- builders and buildings - MEX
	----------------------------------------------

	WG['resource_spot_builder'].GetMexConstructor = function(unitID)
		return mexConstructors[unitID]
	end

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
