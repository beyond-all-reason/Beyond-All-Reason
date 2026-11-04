local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "API Resource Spot Builder (mex/geo)",
		desc = "Handles construction of metal extractors and geothermal power plants for other widgets",
		author = "Hobo Joe, badosu, Google Frog, NTG, Chojin, Doo, Floris, Tarte",
		version = "2.0",
		date = "Oct 23, 2010; last update: April 12, 2022",
		license = "GNU GPL, v2 or later",
		layer = -1, -- load before all widgets that need these mex/geo building tools
		enabled = true,
		hidden = true, -- other widgets need this one, so it is not the player's to toggle
	}
end

-- Localized functions for performance
local mathAbs = math.abs
local mathMax = math.max

-- Localized Spring API for performance
local spGetUnitTeam = Spring.GetUnitTeam

------------------------------------------------------------
-- Speedups
------------------------------------------------------------
local CMD_GUARD = CMD.GUARD

local spGetBuildFacing = Spring.GetBuildFacing
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetGroundHeight = Spring.GetGroundHeight
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spPos2BuildPos = Spring.Pos2BuildPos
local spGetTeamUnits = Spring.GetTeamUnits
local spGetMyTeamID = Spring.GetLocalTeamID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGetGameFrame = Spring.GetGameFrame
local spGetUnitCommandCount = Spring.GetUnitCommandCount
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand

local selectedUnits = spGetSelectedUnits()
local selectedBuilders = {}

local Game_extractorRadius = Game.extractorRadius

local isPregame = Spring.GetGameFrame() == 0 and not Spring.GetSpectatingState()

------------------------------------------------------------
-- unit tables
------------------------------------------------------------

--- What one builder can put on a resource spot. Every unit of a given unit def
--- shares one of these, so the instance and the def registries below hold the
--- same tables under different keys.
---@class ResourceSpotConstructor
---@field buildings integer How many entries `building` holds, and the cursor the fill loop appends at.
---@field building (-UnitDefID)[] Build commands, i.e. negated extractor unit def IDs.

---@type table<UnitID, ResourceSpotConstructor?>
local mexConstructors = {}
---@type table<UnitDefID, ResourceSpotConstructor?>
local mexConstructorsDef = {}
--- Extractors, by how much metal each one pulls from a spot.
---@type table<UnitDefID, number?>
local mexBuildings = {}

---@type table<UnitID, ResourceSpotConstructor?>
local geoConstructors = {}
---@type table<UnitDefID, ResourceSpotConstructor?>
local geoConstructorsDef = {}
--- Geothermal plants and how much energy each one makes.
---@type table<UnitDefID, number?>
local geoBuildings = {}

--- Extractors that only produce metal or energy, so every faction has one.
---@type table<UnitDefID, true?>
local standardExtractors = {}

--- Units that can hold build orders.
---@type table<UnitDefID, true?>
local builderDefs = {}
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
	-- Standard extractors produce just metal / energy and are available to all factions.
	if customParams.standardextractor then
		standardExtractors[uDefID] = true
	end
end

for uDefID, uDef in pairs(UnitDefs) do
	if uDef.buildOptions then
		if uDef.buildOptions[1] then
			builderDefs[uDefID] = true
		end
		local maxExtractMetal = 0
		local maxProduceEnergy = 0
		for _, option in ipairs(uDef.buildOptions) do
			if mexBuildings[option] then
				maxExtractMetal = mathMax(maxExtractMetal, mexBuildings[option])
				if mexConstructorsDef[uDefID] then
					mexConstructorsDef[uDefID].buildings = mexConstructorsDef[uDefID].buildings + 1
					mexConstructorsDef[uDefID].building[mexConstructorsDef[uDefID].buildings] = option * -1
				else
					mexConstructorsDef[uDefID] = { buildings = 1, building = { [1] = option * -1 } }
				end
			end
			if geoBuildings[option] then
				maxProduceEnergy = mathMax(maxProduceEnergy, geoBuildings[option])
				if geoConstructorsDef[uDefID] then
					geoConstructorsDef[uDefID].buildings = geoConstructorsDef[uDefID].buildings + 1
					geoConstructorsDef[uDefID].building[geoConstructorsDef[uDefID].buildings] = option * -1
				else
					geoConstructorsDef[uDefID] = { buildings = 1, building = { [1] = option * -1 } }
				end
			end
		end
	end
end

------------------------------------------------------------
-- Building logic
------------------------------------------------------------

---Checks if there is an existing extractor (mex or geo) in the given spot
---@param spot table
local function spotHasExtractor(spot)
	local units = spGetUnitsInCylinder(spot.x, spot.z, Game_extractorRadius)
	local type = spot.isMex and mexBuildings or geoBuildings
	for j = 1, #units do
		if type[spGetUnitDefID(units[j])] then
			return units[j]
		end
	end
	return false
end

------------------------------------------------------------
-- Queued build orders
------------------------------------------------------------

-- Build orders of the selected builders (in pregame: the pregame queue) as parallel arrays.
-- Walked once per game frame instead of once per spot and caller. Orders given while paused
-- don't advance the frame, so UnitCommand and SelectionChanged mark the scan stale too.
local QUEUE_SCAN_LIMIT = 100
local queuedCount = 0
local queuedDefs, queuedX, queuedZ, queuedFacing = {}, {}, {}, {}
local queueScanFrame -- nil when stale

local function scanBuildQueues(units)
	local count = 0
	for i = 1, #units do
		local unitID = units[i]
		-- nil if enemy unit is selected (with godmode on)
		local cmdCount = spGetUnitCommandCount(unitID) or 0
		if cmdCount > QUEUE_SCAN_LIMIT then
			cmdCount = QUEUE_SCAN_LIMIT
		end
		for j = 1, cmdCount do
			-- multiple returns, unlike GetUnitCommands which builds tables for every command
			local cmdID, _, _, x, _, z, facing = spGetUnitCurrentCommand(unitID, j)
			if cmdID and cmdID < 0 and z then
				count = count + 1
				queuedDefs[count] = -cmdID
				queuedX[count] = x
				queuedZ[count] = z
				queuedFacing[count] = facing or 1
			end
		end
	end
	queuedCount = count
end

local function scanPregameQueue()
	local count = 0
	local queue = WG["pregame-build"] and WG["pregame-build"].getBuildQueue() ---@type table<integer, table>?
	if queue then
		for i = 1, #queue do
			local buildData = queue[i]
			count = count + 1
			queuedDefs[count] = buildData[1]
			queuedX[count] = buildData[2]
			queuedZ[count] = buildData[4]
			queuedFacing[count] = buildData[5] -- nil for queued moves
		end
	end
	queuedCount = count
end

local function refreshBuildQueue()
	if isPregame then
		scanPregameQueue()
		queueScanFrame = nil
		return
	end
	local frame = spGetGameFrame()
	if queueScanFrame ~= frame then
		queueScanFrame = frame
		scanBuildQueues(selectedBuilders)
	end
end

local function setSelection(units)
	selectedUnits = units
	local count = 0
	for i = 1, #units do
		if builderDefs[spGetUnitDefID(units[i])] then
			count = count + 1
			selectedBuilders[count] = units[i]
		end
	end
	for i = #selectedBuilders, count + 1, -1 do
		selectedBuilders[i] = nil
	end
	queueScanFrame = nil
end

---Build orders queued by the selected builders, or the pregame queue before the game starts.
---The arrays are reused: read them right away and don't keep them.
---@return integer count
---@return table<integer, integer> unitDefIDs
---@return table<integer, number> xs
---@return table<integer, number> zs
---@return table<integer, integer?> facings nil for queued pregame moves
local function getSelectedBuildQueue()
	refreshBuildQueue()
	return queuedCount, queuedDefs, queuedX, queuedZ, queuedFacing
end

local function extractorQueuedOnSpot(spot)
	local sx, sz = spot.x, spot.z
	-- Note that this is calculating by diameter, and could be too aggressive on maps with closely spaced mexes
	-- Reduce this radius if there are cases found where mex spots get missed when in close proximity
	local radiusSqr = Game_extractorRadius * Game_extractorRadius
	for i = 1, queuedCount do
		local id = queuedDefs[i]
		if mexBuildings[id] or geoBuildings[id] then
			local dx, dz = queuedX[i] - sx, queuedZ[i] - sz
			if dx * dx + dz * dz < radiusSqr then
				return true
			end
		end
	end
	return false
end

---Checks if there is an existing command among the current builders to make an extractor on the given spot
---@param spot table
---@param builders table? which units will have their queues checked (default: the selected units) - doing a global check is too expensive
local function spotHasExtractorQueued(spot, builders)
	if builders and builders ~= selectedUnits and not isPregame then
		scanBuildQueues(builders)
		queueScanFrame = nil -- the arrays no longer hold the selection's orders
	else
		refreshBuildQueue()
	end
	return extractorQueuedOnSpot(spot)
end

---Gets the naive best extractor, ignores special mexes (exploiter etc), just finds highest extraction amount
---@param units table selected units
---@param constructorIds table builder types to check
---@param extractors table valid extractors, useful to specify specific types or check only geos etc
local function getBestExtractorFromBuilders(units, constructorIds, extractors)
	local bestExtraction = 0
	local bestExtractor
	for i = 1, #units do
		-- only processes first mex option for each builder
		local id = units[i]
		local constructor = constructorIds[id]

		if constructor then
			local buildingID = -constructor.building[1]
			local extractionAmount = extractors[buildingID]
			if extractionAmount > bestExtraction then
				bestExtraction = extractionAmount
				bestExtractor = buildingID
			end
		end
	end
	return bestExtractor
end

---Whether an allied extractor can be replaced: higher techlevel or same-tier higher yield always upgrades; otherwise specialty extractors (does more than just produce metal/energy) may replace standard extractors/other specialty extractors.
---@param currentExtractorUuid UnitID
---@param newExtractorId UnitDefID
---@return boolean
local function extractorCanBeUpgraded(currentExtractorUuid, newExtractorId)
	local isAllied = Spring.AreTeamsAllied(spGetMyTeamID(), spGetUnitTeam(currentExtractorUuid))
	if not isAllied then
		return false
	end

	local currentExtractorId = spGetUnitDefID(currentExtractorUuid)
	if currentExtractorId == newExtractorId then
		return false
	end

	local newExtractor = UnitDefs[newExtractorId]
	local currentExtractor = UnitDefs[currentExtractorId]

	local newTechLevel = math.floor(tonumber(newExtractor.customParams.techlevel) or 1)
	local currentTechLevel = math.floor(tonumber(currentExtractor.customParams.techlevel) or 1)
	if newTechLevel < currentTechLevel then
		return false
	elseif newTechLevel > currentTechLevel then
		return true
	end

	local newExtractorStrength = mexBuildings[newExtractorId] or geoBuildings[newExtractorId]
	local currentExtractorStrength = mexBuildings[currentExtractorId] or geoBuildings[currentExtractorId]
	if not (newExtractorStrength and currentExtractorStrength) then
		return false
	end

	if newExtractorStrength > currentExtractorStrength then
		return true
	end

	local newIsStandard = standardExtractors[newExtractorId]
	return not newIsStandard
end

---Returns true if the specified extractor be built on this spot - considers upgrades and sidegrades
---@param spot table
---@param extractorId table
---@return boolean
local function extractorCanBeBuiltOnSpot(spot, extractorId)
	local units = spGetUnitsInCylinder(spot.x, spot.z, Game_extractorRadius)

	for i = 1, #units do
		local uid = units[i]
		local uDefId = spGetUnitDefID(uid)
		local isExtractor = spot.isMex and mexBuildings[uDefId] or geoBuildings[uDefId]
		if isExtractor and (spGetUnitIsBeingBuilt(uid) or not extractorCanBeUpgraded(uid, extractorId)) then
			return false
		end
	end

	return true
end

-- Spot answers only change with the simulation, so they are kept for the rest of the game frame
---@type table<table, { [1]: integer, [2]: UnitDefID, [3]: boolean }>
local spotChecks = setmetatable({}, { __mode = "k" })

---Whether the extractor may go on the spot: nothing is on it yet, or what is there can be upgraded
---(spotHasExtractor and extractorCanBeBuiltOnSpot in one unit query)
---@param spot table
---@param extractor UnitDefID
---@return boolean
local function spotAllowsExtractor(spot, extractor)
	local frame = spGetGameFrame()
	local check = spotChecks[spot] ---@type table?
	if check and check[1] == frame and check[2] == extractor then
		return check[3]
	end

	local units = spGetUnitsInCylinder(spot.x, spot.z, Game_extractorRadius)
	local isMex = spot.isMex
	local spotExtractors = isMex and mexBuildings or geoBuildings
	local occupied, blocked = false, false
	for i = 1, #units do
		local uid = units[i]
		local uDefId = spGetUnitDefID(uid)
		if spotExtractors[uDefId] then
			occupied = true
		end
		if
			not blocked
			and (isMex and mexBuildings[uDefId] or geoBuildings[uDefId])
			and (spGetUnitIsBeingBuilt(uid) or not extractorCanBeUpgraded(uid, extractor))
		then
			blocked = true
		end
	end
	local allowed = not (occupied and blocked)

	if check then
		check[1], check[2], check[3] = frame, extractor, allowed
	else
		spotChecks[spot] = { frame, extractor, allowed }
	end
	return allowed
end

local function spotIsValid(spot, extractor, shouldIgnoreAlreadyQueuedUpSpots)
	return spotAllowsExtractor(spot, extractor)
		and not (shouldIgnoreAlreadyQueuedUpSpots and extractorQueuedOnSpot(spot))
end

-- The previous answer is usually still the answer, or close to it. One per queue mode: the PIP asks
-- without shift while extractor snap asks with it, and their answers differ.
local lastFoundSpots = {} ---@type table<boolean, table?>

---Finds the nearest unoccupied resource spot from the provided list
---@param x number
---@param z number
---@param spots table
---@param extractor table unitDefID
---@param shouldIgnoreAlreadyQueuedUpSpots boolean?
local function findNearestValidSpotForExtractor(x, z, spots, extractor, shouldIgnoreAlreadyQueuedUpSpots)
	if not spots then
		return
	end
	shouldIgnoreAlreadyQueuedUpSpots = shouldIgnoreAlreadyQueuedUpSpots and true or false
	if shouldIgnoreAlreadyQueuedUpSpots then
		refreshBuildQueue()
	end
	local lastFoundSpot = lastFoundSpots[shouldIgnoreAlreadyQueuedUpSpots]

	-- The nearest spot is usually free, so test it before searching the rest
	local nearest, nearestDist
	local lastFoundDist ---@type number?
	for i = 1, #spots do
		local spot = spots[i]
		local dx, dz = spot.x - x, spot.z - z
		local dist = dx * dx + dz * dz
		if not nearestDist or dist < nearestDist then
			nearest, nearestDist = spot, dist
		end
		if spot == lastFoundSpot then
			lastFoundDist = dist
		end
	end
	if not nearest then
		return
	end
	if spotIsValid(nearest, extractor, shouldIgnoreAlreadyQueuedUpSpots) then
		lastFoundSpots[shouldIgnoreAlreadyQueuedUpSpots] = nearest
		return nearest
	end

	-- Only spots closer than the best one so far need testing
	local best, bestDist
	if
		lastFoundDist
		and lastFoundSpot ~= nearest
		and spotIsValid(lastFoundSpot, extractor, shouldIgnoreAlreadyQueuedUpSpots)
	then
		best, bestDist = lastFoundSpot, lastFoundDist
	end
	for i = 1, #spots do
		local spot = spots[i]
		if spot ~= nearest and spot ~= best then
			local dx, dz = spot.x - x, spot.z - z
			local dist = dx * dx + dz * dz
			if (not bestDist or dist < bestDist) and spotIsValid(spot, extractor, shouldIgnoreAlreadyQueuedUpSpots) then
				best, bestDist = spot, dist
			end
		end
	end
	lastFoundSpots[shouldIgnoreAlreadyQueuedUpSpots] = best
	return best
end

---Gives build order to the units that can make the selected building, all other builders get guard commands to the primary builders
---@param units table
---@param constructorIds table
---@param buildingId table
---@param shift table
---@return table main builders, the ones that can make the selected building
local function sortBuilders(units, constructorIds, buildingId, shift)
	-- Add highest producing constructors to mainBuilders table + give guard orders to "inferior" constructors
	local mainBuilders = {}
	local secondaryBuilders = {}
	for i = 1, #units do
		local id = units[i]
		local constructor = constructorIds[id]
		if constructor then
			-- iterate over constructor options to see if it can make the chosen extractor
			local canBuild = false
			for _, buildable in pairs(constructor.building) do
				if -buildable == buildingId then
					-- assume that it's a valid extractor based on previous steps
					mainBuilders[#mainBuilders + 1] = id
					canBuild = true
					break
				end
			end
			if not canBuild then
				secondaryBuilders[#secondaryBuilders + 1] = id
			end
		end
	end

	--------------------------------
	-- Small local functions to iterate over current builders and reduce command spam. Potentially expensive with 50+ selected cons
	local function isMainBuilderOfId(id)
		for i = 1, #mainBuilders do
			if mainBuilders[i] == id then
				return true
			end
		end
		return false
	end

	local function hasExistingGuardOrder(uid)
		-- GetUnitCommands returns nil if enemy unit is selected (with godmode on)
		local queue = Spring.GetUnitCommands(uid, 10) or {}
		for i = 1, #queue do
			local cmd = queue[i]
			if cmd.id == CMD_GUARD and (cmd.params and cmd.params[1] and isMainBuilderOfId(cmd.params[1])) then
				return true
			end
		end
		return false
	end
	-----------------------------------

	-- order secondary builders to guard main builders, equally dispersed
	local index = 1
	for i, uid in pairs(secondaryBuilders) do
		local mainBuilderId = mainBuilders[index]
		if not shift then
			spGiveOrderToUnit(uid, CMD_GUARD, { mainBuilderId }, {})
			index = index + 1
		end
		-- if we give a guard order on a unit already guarded with shift, it will get cancelled
		-- so do some queue analysis and avoid duplicate commands
		if shift and not hasExistingGuardOrder(uid) then
			spGiveOrderToUnit(uid, CMD_GUARD, { mainBuilderId }, { "shift" })
			index = index + 1
		end

		if index > #mainBuilders then
			index = 1
		end
	end

	if #mainBuilders == 0 then
		return
	end
	return mainBuilders
end

local function previewMetalMapExtractorCommand(params, extractor)
	local buildingId = -extractor
	local facing = spGetBuildFacing() or 1
	local x, y, z = spPos2BuildPos(extractor, params[1], params[2], params[3])
	local targetOwner = spGetMyTeamID()

	if x and z then
		return { mathAbs(buildingId), x, y, z, facing, targetOwner }
	end
	return nil
end

-- Buildable positions on a spot (a TestBuildOrder per position), kept for the rest of the game frame
---@type table<table, { frame: integer, unitDefID: UnitDefID, positions: table[] }>
local spotPositions = setmetatable({}, { __mode = "k" })

local function getBuildingPositions(spot, unitDefID)
	local frame = spGetGameFrame()
	local cached = spotPositions[spot]
	if cached and cached.frame == frame and cached.unitDefID == unitDefID then
		return cached.positions
	end
	local positions = WG.resource_spot_finder.GetBuildingPositions(spot, unitDefID, 0, true)
	if cached then
		cached.frame, cached.unitDefID, cached.positions = frame, unitDefID, positions
	else
		spotPositions[spot] = { frame = frame, unitDefID = unitDefID, positions = positions }
	end
	return positions
end

---Puts together build orders for ghost previews (e.g. mex snap). These orders can be fed directly to
---ApplyPreviewCmds to actually give the orders to units
---@param params table
---@param extractor table
---@param spot table must be a full spot, not just position. isMex or isGeo field required for things to work.
---@param metalMap boolean if this is for a metal map. If so it's used for upgrade visualizing only and takes a different code path.
---@return table format is { buildingId, x, y, z, facing, owner }
local function PreviewExtractorCommand(params, extractor, spot, metalMap)
	if metalMap and not spot then
		return previewMetalMapExtractorCommand(params, extractor)
	end
	local cmdX, _, cmdZ = params[1], params[2], params[3]

	-- Skip mex spots that have queued mexes already
	if not extractorCanBeBuiltOnSpot(spot, extractor) then
		return
	end

	-- Construct the actual mex build orders
	local facing = spGetBuildFacing() or 1
	local finalCommand

	local buildingId = -extractor
	local targetPos, targetOwner
	local occupiedSpot = spotHasExtractor(spot)
	if occupiedSpot then
		local occupiedPos = { spGetUnitPosition(occupiedSpot) }
		targetPos = { x = occupiedPos[1], y = occupiedPos[2], z = occupiedPos[3] }
		targetOwner = spGetUnitTeam(occupiedSpot) -- because gadget "Mex Upgrade Reclaimer" will share a t2 mex build upon ally t1 mex
	else
		local buildingPositions = getBuildingPositions(spot, -buildingId)
		targetPos = math.getClosestPosition(cmdX, cmdZ, buildingPositions)
		targetOwner = spGetMyTeamID()
	end
	if targetPos then
		local newx, newz = targetPos.x, targetPos.z
		finalCommand = { mathAbs(buildingId), newx, spGetGroundHeight(newx, newz), newz, facing, targetOwner }
	end
	return finalCommand
end

local function ApplyPreviewCmds(cmds, constructorIds, shift)
	if not cmds or #cmds <= 0 then
		return
	end
	local units = selectedUnits
	local buildingId = cmds[1][1] -- assume they are all the same building id
	local mainBuilders = sortBuilders(units, constructorIds, buildingId, shift)

	if not mainBuilders or #mainBuilders <= 0 then
		return
	end

	local _, _, meta, _ = Spring.GetModKeyState()

	local unitArray = {} -- make unit array to avoid extra work
	for i = 1, #mainBuilders do
		unitArray[#unitArray + 1] = mainBuilders[i]
	end

	for i = 1, #cmds do
		local cmd = cmds[i]
		local orderParams = { cmd[2], cmd[3], cmd[4], cmd[5] }

		if meta then
			-- put at front of queue
			-- cmd insert layout is really weird, it needs to be formatted like:
			-- { CMD.INSERT, { queue_pos, cmd_id, opt, params_flattened, }, { "alt }}
			-- this an engine command so index starts at 0. Increment position by command count
			Spring.GiveOrderToUnitArray(
				unitArray,
				CMD.INSERT,
				{ i - 1, -buildingId, 0, unpack(orderParams) },
				{ "alt" }
			)
		else
			-- we don't want to give a stop command to clear queue because it plays an unwanted sound
			-- issuing any command without shift will clear the queue for us,
			-- so we use the real shift value for the first command, then we force shift for all the others
			-- since any commands passed to this function are intended to be queued, not discarded.
			-- NEVER USE TERNARIES WITH OUTCOME VALUES THAT CAN BE FALSE
			local fakeShift = false
			if i == 1 then
				fakeShift = shift
			else
				fakeShift = true
			end
			local opt = fakeShift and { "shift" } or {}
			Spring.GiveOrderToUnitArray(unitArray, -buildingId, orderParams, opt)
		end
	end
end

------------------------------------------------------------
-- Callins
------------------------------------------------------------

function widget:SelectionChanged(sel)
	setSelection(sel)
end

function widget:UnitCommand()
	queueScanFrame = nil
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

function widget:GameStart()
	isPregame = false
end

function widget:Initialize()
	local units = spGetTeamUnits(spGetMyTeamID())
	for i = 1, #units do
		local id = units[i]
		widget:UnitCreated(id, spGetUnitDefID(id))
	end
	setSelection(spGetSelectedUnits())

	-- make interfaces available to other widgets:
	WG.resource_spot_builder = {
		ExtractorCanBeBuiltOnSpot = extractorCanBeBuiltOnSpot,
		ExtractorCanBeUpgraded = extractorCanBeUpgraded,
		FindNearestValidSpotForExtractor = findNearestValidSpotForExtractor,
		PreviewExtractorCommand = PreviewExtractorCommand,
		ApplyPreviewCmds = ApplyPreviewCmds,
		SpotHasExtractorQueued = spotHasExtractorQueued,
		GetSelectedBuildQueue = getSelectedBuildQueue,
		GetBestExtractorFromBuilders = getBestExtractorFromBuilders,
	}

	----------------------------------------------
	-- builders and buildings - MEX
	----------------------------------------------

	WG.resource_spot_builder.GetMexConstructors = function()
		return mexConstructors
	end

	WG.resource_spot_builder.GetMexBuildings = function()
		return mexBuildings
	end

	WG.resource_spot_builder.GetGeoConstructors = function()
		return geoConstructors
	end

	WG.resource_spot_builder.GetGeoBuildings = function()
		return geoBuildings
	end
end

function widget:Shutdown()
	WG.resource_spot_builder = nil
end
