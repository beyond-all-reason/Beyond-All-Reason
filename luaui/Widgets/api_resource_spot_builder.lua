function widget:GetInfo()
	return {
		name = "API Resource Spot Builder (mex/geo)",
		desc = "Handles construction of metal extractors and geothermal power plants for other widgets",
		author = "Hobo Joe, badosu, Google Frog, NTG, Chojin, Doo, Floris, Tarte",
		version = "2.0",
		date = "Oct 23, 2010; last update: April 12, 2022",
		license = "GNU GPL, v2 or later",
		handler = true,
		layer = -1, -- load before all widgets that need these mex/geo building tools
		enabled = true
	}
end

------------------------------------------------------------
-- Speedups
------------------------------------------------------------
local CMD_STOP = CMD.STOP
local CMD_GUARD = CMD.GUARD
local CMD_OPT_RIGHT = CMD.OPT_RIGHT
local CMD_OPT_ALT = CMD.OPT_ALT
local CMD_OPT_CTRL = CMD.OPT_CTRL
local CMD_OPT_META = CMD.OPT_META
local CMD_OPT_SHIFT = CMD.OPT_SHIFT

local spGetBuildFacing = Spring.GetBuildFacing
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetGroundHeight = Spring.GetGroundHeight
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spPos2BuildPos = Spring.Pos2BuildPos
local spGetTeamUnits = Spring.GetTeamUnits
local spGetMyTeamID = Spring.GetMyTeamID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitDefID = Spring.GetUnitDefID

local selectedUnits = spGetSelectedUnits()

local Game_extractorRadius = Game.extractorRadius

local isPregame = Spring.GetGameFrame() == 0 and not Spring.GetSpectatingState()


------------------------------------------------------------
-- unit tables
------------------------------------------------------------
local mexConstructors = {}
local mexConstructorsDef = {}
local mexBuildings = {}

local geoConstructors = {}
local geoConstructorsDef = {}
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
	end
end


------------------------------------------------------------
-- Building logic
------------------------------------------------------------

---Checks if there is an existing extractor (mex or geo) in the given spot
---@param spot table
local function spotHasExtractor(spot)
	local units = Spring.GetUnitsInCylinder(spot.x, spot.z, Game_extractorRadius)
	local type = spot.isMex and mexBuildings or geoBuildings
	for j=1, #units do
		if type[spGetUnitDefID(units[j])] then return units[j] end
	end
	return false
end


---Checks if there is an existing command among the current builders to make an extractor on the given spot
---@param spot table
---@param builders table which units will have their queues checked - doing a global check is too expensive
local function spotHasExtractorQueued(spot, builders)
	builders = builders or selectedUnits

	-- annoying pregame stuff
	local function checkQueue(queue)
		for j=1, #queue do
			local command = queue[j]
			local id = command.id and -command.id or command[1]
			local x = command.params and command.params[1] or command[2]
			local z = command.params and command.params[3] or command[4]
			if(mexBuildings[id] or geoBuildings[id]) then
				local dist = math.distance2dSquared(spot.x, spot.z, x, z)
				-- Save a sqrt by multiplying by 4
				-- Note that this is calculating by diameter, and could be too aggressive on maps with closely spaced mexes
				-- Reduce this radius if there are cases found where mex spots get missed when in close proximity
				if dist < Game_extractorRadius * Game_extractorRadius then
					return true
				end
			end
		end
		return false
	end

	if isPregame then
		local queue = WG['pregame-build'].getBuildQueue()
		return checkQueue(queue)

	else
		for i=1, #builders do
			local hasOrder = checkQueue(Spring.GetCommandQueue(builders[i], 100))
			if hasOrder then
				return true
			end
		end
	end
	return false
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
			if(extractionAmount > bestExtraction) then
				bestExtraction = extractionAmount
				bestExtractor = buildingID
			end
		end
	end
	return bestExtractor
end


---extractorCanBeUpgraded
---@param currentExtractorUuid number uuid of current extractor
---@param newExtractorId number unitDefID of new extractor
local function extractorCanBeUpgraded(currentExtractorUuid, newExtractorId)
	local isAllied = Spring.AreTeamsAllied(spGetMyTeamID(), Spring.GetUnitTeam(currentExtractorUuid))
	if not isAllied then
		return false
	end

	local currentExtractorId = spGetUnitDefID(currentExtractorUuid)
	local newExtractor = UnitDefs[newExtractorId]
	local newExtractorStrength = mexBuildings[newExtractorId] or geoBuildings[newExtractorId]
	local currentExtractorStrength = mexBuildings[currentExtractorId] or geoBuildings[currentExtractorId]

	if not (newExtractorStrength and currentExtractorStrength) then
		return false
	end

	local newExtractorIsSpecial = newExtractor.stealth or #newExtractor.weapons > 0

	if(newExtractorStrength > currentExtractorStrength) then
		return true
	end
	if(newExtractorStrength == currentExtractorStrength and newExtractorIsSpecial) then
		return true
	end
	if currentExtractorStrength == newExtractorStrength then
		return false
	end

	return false
end


---Returns true if the specified extractor be built on this spot - considers upgrades and sidegrades
---@param spot table
---@param extractorId table
---@return boolean
local function extractorCanBeBuiltOnSpot(spot, extractorId)
	local units = Spring.GetUnitsInCylinder(spot.x, spot.z, Game_extractorRadius)

	if #units == 0 then
		return true
	end

	for i = 1, #units do
		local uid = units[i]
		local uDefId = spGetUnitDefID(uid)
		local isExtractor = spot.isMex and mexBuildings[uDefId] or geoBuildings[uDefId]
		local canUpgrade = extractorCanBeUpgraded(uid, extractorId)
		local isBeingBuilt, _ = spGetUnitIsBeingBuilt(uid)
		if(isExtractor and (not canUpgrade or isBeingBuilt)) then
			return false
		end
	end

	return true
end


---Finds the nearest unoccupied resource spot from the provided list
---@param x number
---@param z number
---@param spotsIn table
---@param extractor table unitDefID
local function findNearestValidSpotForExtractor(x, z, spotsIn, extractor)
	-- sort spots by distance
	local spots = table.copy(spotsIn)
	table.sort(spots, function(a, b)
		return math.distance2dSquared(a.x, a.z, x, z) < math.distance2dSquared(b.x, b.z, x, z)
	end)
	for i = 1, #spots do
		local spot = spots[i]
		local existingExtractor = spotHasExtractor(spot)
		local hasExtractorQueued = spotHasExtractorQueued(spot)
		if not existingExtractor and not hasExtractorQueued then
			return spot
		end

		local canBeBuilt = extractorCanBeBuiltOnSpot(spot, extractor)
		if canBeBuilt and not hasExtractorQueued then
			return spot
		end
	end
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
				if -buildable == buildingId then -- assume that it's a valid extractor based on previous steps
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
		local queue = Spring.GetCommandQueue(uid, 10)
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
	-- Doo: Dispersion function changed; we don't care if #mainBuilder > #secondaryBuilders because secondary don't need to be give two guard cmds, so it's just a simple modulo function
	
	for i, uid in pairs(secondaryBuilders) do
		local targetIndex = (i%#mainBuilders ~= 0 and i%#mainBuilders) or #mainBuilders
		local mainBuilderId = mainBuilders[targetIndex]
		if not shift then
			spGiveOrderToUnit(uid, CMD_GUARD, { mainBuilderId }, { })
		end
		-- if we give a guard order on a unit already guarded with shift, it will get cancelled
		-- so do some queue analysis and avoid duplicate commands
		if shift and not hasExistingGuardOrder(uid) then
			spGiveOrderToUnit(uid, CMD_GUARD, { mainBuilderId }, { "shift" })
		end
	end

	if #mainBuilders == 0 then return end
	return mainBuilders
end


local function previewMetalMapExtractorCommand(params, extractor)
	local buildingId = -extractor
	local facing = spGetBuildFacing() or 1
	local x, y, z = spPos2BuildPos(extractor, params[1], params[2], params[3])
	local targetOwner = spGetMyTeamID()

	if x and z then
		return { math.abs(buildingId), x, y, z, facing, targetOwner }
	end
	return nil
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
		targetPos = { x=occupiedPos[1], y=occupiedPos[2], z=occupiedPos[3] }
		targetOwner = Spring.GetUnitTeam(occupiedSpot)	-- because gadget "Mex Upgrade Reclaimer" will share a t2 mex build upon ally t1 mex
	else
		local buildingPositions = WG['resource_spot_finder'].GetBuildingPositions(spot, -buildingId, 0, true)
		targetPos = math.getClosestPosition(cmdX, cmdZ, buildingPositions)
		targetOwner = spGetMyTeamID()
	end
	if targetPos then
		local newx, newz = targetPos.x, targetPos.z
		finalCommand = { math.abs(buildingId), newx, spGetGroundHeight(newx, newz), newz, facing, targetOwner }
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

	local _, ctrl , meta, _ = Spring.GetModKeyState()
	
	local insert = ctrl -- default is meta for split and ctrl for insert (maybe disable ctrl altogether)
	local split = meta
	
	if meta and (#cmds == 1 or #mainBuilders <=1 ) then -- invert split/insert when single cmds or single units (no splitting can be done)
		insert = meta
		split = false
	end


	local unitArray = {} -- make unit array to avoid extra work
	for i = 1, #mainBuilders do
		unitArray[#unitArray + 1] = mainBuilders[i]
	end
	local fakeShift = {}
	for i = 1, #cmds do
		local cmd = cmds[i]
		local orderParams = { cmd[2], cmd[3], cmd[4], cmd[5] }

		if insert then -- put at front of queue
			-- cmd insert layout is really weird, it needs to be formatted like:
			-- { CMD.INSERT, { queue_pos, cmd_id, opt, params_flattened, }, { "alt }}
			-- this an engine command so index starts at 0. Increment position by command count
			if not split then -- Unchanged
				Spring.GiveOrderToUnitArray(unitArray, CMD.INSERT, {i-1, -buildingId, 0, unpack(orderParams) }, { "alt" })
			else
				local temp =((i%(#unitArray) ~= 0) and (i%(#unitArray))) or #unitArray -- i turns into  (1;#unitArray) => this splits cmds across builders equally
				while (temp) <= #unitArray do -- temp turns into temp + #cmds until temp > unitArray => this splits all builders across #cmds equally
					Spring.GiveOrderToUnit(unitArray[temp],CMD.INSERT, {(math.floor(i/(#unitArray))), -buildingId, 0, unpack(orderParams) }, { "alt" })
					temp = temp + #cmds
				end
			end
		else
			-- we don't want to give a stop command to clear queue because it plays an unwanted sound
			-- issuing any command without shift will clear the queue for us,
			-- so we use the real shift value for the first command, then we force shift for all the others
			-- since any commands passed to this function are intended to be queued, not discarded.
			-- NEVER USE TERNARIES WITH OUTCOME VALUES THAT CAN BE FALSE
			if not split then -- Unchanged
				fakeShift = false
				if i == 1 then
					fakeShift = shift
				else
					fakeShift = true
				end
				local opt = fakeShift and { "shift" } or { }
				Spring.GiveOrderToUnitArray(unitArray, -buildingId, orderParams, opt)
			else
				local temp = ((i%(#unitArray) ~= 0) and (i%(#unitArray))) or #unitArray  -- i turns into  (1;#unitArray) => this splits cmds across builders equally
				fakeShift[temp] = false
				if (math.floor(i/(#unitArray))) == 0 then -- First command in temp's queue so we apply shift
					fakeShift[temp] = shift
				else -- next command in temp's queue so we don't apply shift anymore
					fakeShift[temp] = true
				end
				local opt = fakeShift[temp] and { "shift" } or { }
				while (temp) <= #unitArray do -- temp turns into temp + #cmds until temp > unitArray => this splits all builders across #cmds equally
					Spring.GiveOrderToUnit(unitArray[temp], -buildingId, orderParams, opt)
					temp = temp + #cmds
				end
			end
		end
	end
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


function widget:GameStart()
	isPregame = false
end


function widget:Initialize()
	local units = spGetTeamUnits(spGetMyTeamID())
	for i = 1, #units do
		local id = units[i]
		widget:UnitCreated(id, spGetUnitDefID(id))
	end

	--make interfaces available to other widgets:
	WG['resource_spot_builder'] = { }
	WG['resource_spot_builder'].ExtractorCanBeBuiltOnSpot = extractorCanBeBuiltOnSpot
	WG['resource_spot_builder'].ExtractorCanBeUpgraded = extractorCanBeUpgraded
	WG['resource_spot_builder'].FindNearestValidSpotForExtractor = findNearestValidSpotForExtractor
	WG['resource_spot_builder'].PreviewExtractorCommand = PreviewExtractorCommand
	WG['resource_spot_builder'].ApplyPreviewCmds = ApplyPreviewCmds
	WG['resource_spot_builder'].SpotHasExtractorQueued = spotHasExtractorQueued
	WG['resource_spot_builder'].GetBestExtractorFromBuilders = getBestExtractorFromBuilders

	----------------------------------------------
	-- builders and buildings - MEX
	----------------------------------------------

	WG['resource_spot_builder'].GetMexConstructors = function()
		return mexConstructors
	end

	WG['resource_spot_builder'].GetMexBuildings = function()
		return mexBuildings
	end

	WG['resource_spot_builder'].GetGeoConstructors = function()
		return geoConstructors
	end

	WG['resource_spot_builder'].GetGeoBuildings = function()
		return geoBuildings
	end
end
