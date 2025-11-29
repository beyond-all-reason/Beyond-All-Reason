local widget = widget ---@type Widget

-- Include the substitution logic directly with a shorter alias
local SubLogic = VFS.Include("luaui/Include/blueprint_substitution/logic.lua")

function widget:GetInfo()
	return {
		name = "Pregame Queue",
		desc = "Drawing and queue handling for pregame building",
		author = "Hobo Joe, based on buildmenu from assorted authors",
		date = "May 2023",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end


-- Localized functions for performance
local mathAbs = math.abs
local mathCeil = math.ceil
local mathFloor = math.floor
local mathMax = math.max
local tableInsert = table.insert
local tableRemove = table.remove

-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame
local spGetMyTeamID = Spring.GetMyTeamID
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spGetGroundHeight = Spring.GetGroundHeight
local spEcho = Spring.Echo

local spTestBuildOrder = Spring.TestBuildOrder

local buildQueue = {}
local selBuildQueueDefID
local facingMap = { south = 0, east = 1, north = 2, west = 3 }

local buildModeState = {
	startPosition = nil,
	endPosition = nil,
	buildPositions = {},
	mode = nil,
	buildAroundTarget = nil,
	spacing = 0,
}

local isSpec = Spring.GetSpectatingState()
local myTeamID = spGetMyTeamID()
local preGamestartPlayer = spGetGameFrame() == 0 and not isSpec
local startDefID = Spring.GetTeamRulesParam(myTeamID, "startUnit")
local prevStartDefID = startDefID
local isMetalMap = false

local unitshapes = {}

local cachedAlphaResults
local cachedStartPosition
local cachedQueueMetrics
local cachedQueueLineVerts

local BUILD_MODE = {
	SINGLE = 0,
	LINE = 1,
	GRID = 2,
	BOX = 3,
	AROUND = 4
}

local SQUARE_SIZE = 8
local BUILD_SQUARE_SIZE = SQUARE_SIZE * 2
local BUILDING_COUNT_FUDGE_FACTOR = 1.4
local BUILDING_DETECTION_TOLERANCE = 10
local HALF = 0.5

local function buildFacingHandler(command, line, args)
	if not (preGamestartPlayer and selBuildQueueDefID) then
		return
	end

	local facing = Spring.GetBuildFacing()
	local action = args and args[1]
	if action == "inc" then
		facing = (facing + 1) % 4
		Spring.SetBuildFacing(facing)
		return true
	elseif action == "dec" then
		facing = (facing - 1) % 4
		Spring.SetBuildFacing(facing)
		return true
	elseif action and facingMap[action] then
		Spring.SetBuildFacing(facingMap[action])
		return true
	end
end

local function buildSpacingHandler(command, line, args)
	if not (preGamestartPlayer and selBuildQueueDefID) then
		return
	end

	local action = args and args[1]
	if action == "inc" then
		buildModeState.spacing = buildModeState.spacing + 1
		return true
	elseif action == "dec" then
		buildModeState.spacing = mathMax(0, buildModeState.spacing - 1)
		return true
	end
end

------------------------------------------
---          QUEUE HANDLING            ---
------------------------------------------
local function handleBuildMenu(shift)
	local grid = WG["gridmenu"]
	if not grid or not grid.clearCategory or not grid.getAlwaysReturn or not grid.setCurrentCategory then
		return
	end

	if shift and grid.getAlwaysReturn() then
		grid.setCurrentCategory(nil)
	elseif not shift then
		grid.clearCategory()
	end
end

local FORCE_SHOW_REASON = "gui_pregame_build"
local function setPreGamestartDefID(uDefID)
	selBuildQueueDefID = uDefID

	if preGamestartPlayer then
		WG["pregame-unit-selected"] = uDefID or -1
	end

	if WG["buildinggrid"] ~= nil and WG["buildinggrid"].setForceShow ~= nil then
		WG["buildinggrid"].setForceShow(FORCE_SHOW_REASON, uDefID ~= nil, uDefID)
	end

	if WG["easyfacing"] ~= nil and WG["easyfacing"].setForceShow ~= nil then
		WG["easyfacing"].setForceShow(FORCE_SHOW_REASON, uDefID ~= nil, uDefID)
	end

	local isMex = UnitDefs[uDefID] and UnitDefs[uDefID].extractsMetal > 0

	if isMex then
		if Spring.GetMapDrawMode() ~= "metal" then
			Spring.SendCommands("ShowMetalMap")
		end
	elseif Spring.GetMapDrawMode() == "metal" then
		Spring.SendCommands("ShowStandard")
	end

	return true
end

local function GetUnitCanCompleteQueue(unitID)
	local unitDefID = Spring.GetUnitDefID(unitID)
	if unitDefID == startDefID then
		return true
	end

	-- What can this unit build ?
	local buildableUnits = {}
	local unitBuildOptions = UnitDefs[unitDefID].buildOptions
	for i = 1, #unitBuildOptions do
		buildableUnits[unitBuildOptions[i]] = true
	end

	-- Can it build everything that was queued ?
	for i = 1, #buildQueue do
		if not buildableUnits[buildQueue[i][1]] then
			return false
		end
	end

	return true
end

local function clearPregameBuildQueue()
	if not preGamestartPlayer then
		return
	end

	setPreGamestartDefID()
	buildQueue = {}

	return true
end

local function buildmenuPregameDeselectHandler()
	if not (preGamestartPlayer and selBuildQueueDefID) then
		return
	end

	setPreGamestartDefID()

	return true
end

local function convertBuildQueueFaction(previousFactionSide, currentFactionSide)
	Spring.Log("gui_pregame_build", LOG.DEBUG, string.format("Calling SubLogic.processBuildQueueSubstitution (in-place) from %s to %s for %d queue items.", previousFactionSide, currentFactionSide, #buildQueue))
	local result = SubLogic.processBuildQueueSubstitution(buildQueue, previousFactionSide, currentFactionSide)
	
	if result.substitutionFailed then
		spEcho(string.format("[gui_pregame_build] %s", result.summaryMessage))
	end
end

local function handleSelectedBuildingConversion(currentSelDefID, prevFactionSide, currentFactionSide, currentSelBuildData)
	if not currentSelDefID then
		Spring.Log("gui_pregame_build", LOG.WARNING, "handleSelectedBuildingConversion: Called with nil currentSelDefID.")
		return currentSelDefID
	end

	local newSelDefID = SubLogic.getEquivalentUnitDefID(currentSelDefID, currentFactionSide)

	if newSelDefID ~= currentSelDefID then
		setPreGamestartDefID(newSelDefID)
		if currentSelBuildData then
			currentSelBuildData[1] = newSelDefID
		end
		local newUnitDef = UnitDefs[newSelDefID]
		local successMsg = "[Pregame Build] Selected item converted to " .. (newUnitDef and (newUnitDef.humanName or newUnitDef.name) or ("UnitDefID " .. tostring(newSelDefID)))
		spEcho(successMsg)
	else
		if prevFactionSide ~= currentFactionSide then
			local originalUnitDef = UnitDefs[currentSelDefID]
			local originalUnitName = originalUnitDef and (originalUnitDef.humanName or originalUnitDef.name) or ("UnitDefID " .. tostring(currentSelDefID))
			Spring.Log("gui_pregame_build", LOG.INFO, string.format("Selected item '%s' remains unchanged for %s faction (or was already target faction).", originalUnitName, currentFactionSide))
		else
			Spring.Log("gui_pregame_build", LOG.DEBUG, string.format("selBuildQueueDefID %s remained unchanged (sides were the same: %s).", tostring(currentSelDefID), currentFactionSide))
		end
	end
	return newSelDefID
end

------------------------------------------
---               INIT                 ---
------------------------------------------
function widget:Initialize()
	widgetHandler:AddAction("stop", clearPregameBuildQueue, nil, "p")
	widgetHandler:AddAction("buildfacing", buildFacingHandler, nil, "p")
	widgetHandler:AddAction("buildspacing", buildSpacingHandler, nil, "p")
	widgetHandler:AddAction("buildmenu_pregame_deselect", buildmenuPregameDeselectHandler, nil, "p")

	Spring.Log(widget:GetInfo().name, LOG.INFO, "Pregame Queue Initializing. Local SubLogic is assumed available.")

	-- Get our starting unit
	if preGamestartPlayer then
		if not startDefID or startDefID ~= Spring.GetTeamRulesParam(myTeamID, "startUnit") then
			startDefID = Spring.GetTeamRulesParam(myTeamID, "startUnit")
		end
	end

	isMetalMap = WG["resource_spot_finder"].isMetalMap

	WG["pregame-build"] = {}
	WG["pregame-build"].getPreGameDefID = function()
		return selBuildQueueDefID
	end
	WG["pregame-build"].setPreGamestartDefID = function(value)
		local inBuildOptions = {}
		-- Ensure startDefID is valid before trying to access UnitDefs[startDefID]
		if startDefID and UnitDefs[startDefID] and UnitDefs[startDefID].buildOptions then
		    for _, opt in ipairs(UnitDefs[startDefID].buildOptions) do
			    inBuildOptions[opt] = true
		    end
		else
		    Spring.Log(widget:GetInfo().name, LOG.WARNING, "setPreGamestartDefID: startDefID is nil or invalid, cannot determine build options.")
        end

		if inBuildOptions[value] then
			setPreGamestartDefID(value)
		else
			setPreGamestartDefID(nil)
		end
	end

	WG["pregame-build"].setBuildQueue = function(value)
		buildQueue = value
	end
	WG["pregame-build"].getBuildQueue = function()
		return buildQueue
	end
	WG["pregame-build"].getBuildPositions = function()
		return buildModeState.buildPositions
	end
	widgetHandler:RegisterGlobal("GetPreGameDefID", WG["pregame-build"].getPreGameDefID)
	widgetHandler:RegisterGlobal("GetBuildQueue", WG["pregame-build"].getBuildQueue)
end

local function GetBuildingDimensions(unitDefID, facing)
	local buildingDef = UnitDefs[unitDefID]
	if not buildingDef then return 0, 0 end

	local FACING_WEST_OR_EAST = 1
	if facing % 2 == FACING_WEST_OR_EAST then
		return SQUARE_SIZE * buildingDef.zsize, SQUARE_SIZE * buildingDef.xsize
	else
		return SQUARE_SIZE * buildingDef.xsize, SQUARE_SIZE * buildingDef.zsize
	end
end

local function snapPosition(unitDefID, pos, facing)
	local result = { x = 0, y = pos.y, z = 0 }
	local buildingWidth, buildingHeight = GetBuildingDimensions(unitDefID, facing or 0)

	if mathFloor(buildingWidth / BUILD_SQUARE_SIZE) % 2 > 0 then
		result.x = mathFloor(pos.x / BUILD_SQUARE_SIZE) * BUILD_SQUARE_SIZE + SQUARE_SIZE
	else
		result.x = mathFloor((pos.x + SQUARE_SIZE) / BUILD_SQUARE_SIZE) * BUILD_SQUARE_SIZE
	end

	if mathFloor(buildingHeight / BUILD_SQUARE_SIZE) % 2 > 0 then
		result.z = mathFloor(pos.z / BUILD_SQUARE_SIZE) * BUILD_SQUARE_SIZE + SQUARE_SIZE
	else
		result.z = mathFloor((pos.z + SQUARE_SIZE) / BUILD_SQUARE_SIZE) * BUILD_SQUARE_SIZE
	end
	
	return result
end

local function fillRow(startX, startZ, stepX, stepZ, count, facing)
	local result = {}
	for _ = 1, count do
		local groundY = spGetGroundHeight(startX, startZ)
		result[#result + 1] = { x = startX, y = groundY, z = startZ, facing = facing }
		startX = startX + stepX
		startZ = startZ + stepZ
	end
	return result
end

local function calculateBuildingPlacementSteps(unitDefID, startPos, endPos, spacing, facing)
	local buildingWidth, buildingHeight = GetBuildingDimensions(unitDefID, facing)
	local delta = { x = endPos.x - startPos.x, z = endPos.z - startPos.z }
	
	local xSize = buildingWidth + SQUARE_SIZE * spacing * 2
	local zSize = buildingHeight + SQUARE_SIZE * spacing * 2
	
	local xCount = mathFloor((mathAbs(delta.x) + xSize * BUILDING_COUNT_FUDGE_FACTOR) / xSize)
	local zCount = mathFloor((mathAbs(delta.z) + zSize * BUILDING_COUNT_FUDGE_FACTOR) / zSize)

	local xStep = mathFloor((delta.x > 0) and xSize or -xSize)
	local zStep = mathFloor((delta.z > 0) and zSize or -zSize)

	return xStep, zStep, xCount, zCount, delta
end

local function getBuildPositionsSingle(unitDefID, facing, startPos)
	if not startPos then
		return {}
	end

	local snappedPos = snapPosition(unitDefID, startPos, facing)
	local groundY = spGetGroundHeight(snappedPos.x, snappedPos.z)
	return { { x = snappedPos.x, y = groundY, z = snappedPos.z, facing = facing } }
end

local function getBuildPositionsLine(unitDefID, facing, startPos, endPos, spacing)
	if not startPos or not endPos then
		return {}
	end
	
	local snappedStart = snapPosition(unitDefID, startPos, facing)
	local snappedEnd = snapPosition(unitDefID, endPos, facing)
	
	local xStep, zStep, xCount, zCount, delta = calculateBuildingPlacementSteps(unitDefID, snappedStart, snappedEnd, spacing or 0, facing)
	
	local xGreaterThanZ = mathAbs(delta.x) > mathAbs(delta.z)

	if xGreaterThanZ then
		zStep = xStep * delta.z / (delta.x ~= 0 and delta.x or 1)
	else
		xStep = zStep * delta.x / (delta.z ~= 0 and delta.z or 1)
	end

	return fillRow(snappedStart.x, snappedStart.z, xStep, zStep, xGreaterThanZ and xCount or zCount, facing)
end

local function getBuildPositionsGrid(unitDefID, facing, startPos, endPos, spacing)
	if not startPos or not endPos then
		return {}
	end
	
	local snappedStart = snapPosition(unitDefID, startPos, facing)
	local snappedEnd = snapPosition(unitDefID, endPos, facing)

	local xStep, zStep, xCount, zCount = calculateBuildingPlacementSteps(unitDefID, snappedStart, snappedEnd, spacing or 0, facing)

	local result = {}
	local currentRowZ = snappedStart.z
	for rowIndex = 1, zCount do
		if rowIndex % 2 == 0 then
			table.append(result, fillRow(snappedStart.x + (xCount - 1) * xStep, currentRowZ, -xStep, 0, xCount, facing))
		else
			table.append(result, fillRow(snappedStart.x, currentRowZ, xStep, 0, xCount, facing))
		end
		currentRowZ = currentRowZ + zStep
	end
	
	return result
end

local function getBuildPositionsBox(unitDefID, facing, startPos, endPos, spacing)
	if not startPos or not endPos then
		return {}
	end
	
	local snappedStart = snapPosition(unitDefID, startPos, facing)
	local snappedEnd = snapPosition(unitDefID, endPos, facing)

	local xStep, zStep, xCount, zCount = calculateBuildingPlacementSteps(unitDefID, snappedStart, snappedEnd, spacing or 0, facing)

	local result = {}

	if xCount > 1 and zCount > 1 then
		-- Left side: start from bottom-left + 1 up, go up (positive Z)
		table.append(result, fillRow(snappedStart.x, snappedStart.z + zStep, 0, zStep, zCount - 1, facing))
		-- Top side: start from top-left + 1 right, go right (positive X)
		table.append(result, fillRow(snappedStart.x + xStep, snappedStart.z + (zCount - 1) * zStep, xStep, 0, xCount - 1, facing))
		-- Right side: start from top-right, go down (negative Z)
		table.append(result, fillRow(snappedStart.x + (xCount - 1) * xStep, snappedStart.z + (zCount - 2) * zStep, 0, -zStep, zCount - 1, facing))
		-- Bottom side: start from bottom-right, go left (negative X)
		table.append(result, fillRow(snappedStart.x + (xCount - 2) * xStep, snappedStart.z, -xStep, 0, xCount - 1, facing))
	elseif xCount == 1 then
		table.append(result, fillRow(snappedStart.x, snappedStart.z, 0, zStep, zCount, facing))
	elseif zCount == 1 then
		table.append(result, fillRow(snappedStart.x, snappedStart.z, xStep, 0, xCount, facing))
	end
	
	return result
end

local function getBuildPositionsAround(unitDefID, facing, target)
	if not target then
		return {}
	end

	local targetBuildingWidth, targetBuildingHeight = GetBuildingDimensions(target.unitDefID, target.facing)
	local currentBuildingWidth, currentBuildingHeight = GetBuildingDimensions(unitDefID, facing)

	local widthBuildingCount = mathCeil((targetBuildingWidth + 2 * currentBuildingWidth) / currentBuildingWidth)
	local heightBuildingCount = mathCeil((targetBuildingHeight + 2 * currentBuildingHeight) / currentBuildingHeight)

	local perimeterWidth = widthBuildingCount * currentBuildingWidth
	local perimeterHeight = heightBuildingCount * currentBuildingHeight

	local startX = target.x - perimeterWidth * HALF + currentBuildingWidth * HALF
	local startZ = target.z - perimeterHeight * HALF + currentBuildingHeight * HALF

	local result = {}

	local sides = {
		-- top (south)
		{z = target.z + targetBuildingHeight * HALF + currentBuildingHeight * HALF, count = widthBuildingCount, step = currentBuildingWidth, facing = 0, axis = "x"},
		-- bottom (north)
		{z = target.z - targetBuildingHeight * HALF - currentBuildingHeight * HALF, count = widthBuildingCount, step = currentBuildingWidth, facing = 2, axis = "x"},
		-- left (west)
		{x = target.x - targetBuildingWidth * HALF - currentBuildingWidth * HALF, count = heightBuildingCount, step = currentBuildingHeight, facing = 3, axis = "z"},
		-- right (east)
		{x = target.x + targetBuildingWidth * HALF + currentBuildingWidth * HALF, count = heightBuildingCount, step = currentBuildingHeight, facing = 1, axis = "z"}
	}

	for _, side in ipairs(sides) do
		for i = 0, side.count - 1 do
			local pos = {x = side.x or startX, y = 0, z = side.z or startZ, facing = side.facing}
			if side.axis == "x" then
				pos.x = startX + i * side.step
			else
				pos.z = startZ + i * side.step
			end
			tableInsert(result, pos)
		end
	end

	return result
end

local function determineBuildMode(modKeys, buildAroundTarget, startPosition)
	local alt, ctrl, meta, shift = unpack(modKeys)

	local isMex = UnitDefs[selBuildQueueDefID] and UnitDefs[selBuildQueueDefID].extractsMetal > 0
	if isMex and not isMetalMap then
		return BUILD_MODE.SINGLE
	end

	if shift and ctrl and buildAroundTarget then
		return BUILD_MODE.AROUND
	elseif shift and startPosition then
		if alt and ctrl then
			return BUILD_MODE.BOX
		elseif alt and not ctrl then
			return BUILD_MODE.GRID
		elseif not alt and not ctrl then
			return BUILD_MODE.LINE
		end
	end

	return BUILD_MODE.SINGLE
end

local BUILD_POSITION_FUNCTIONS = {
	[BUILD_MODE.SINGLE] = getBuildPositionsSingle,
	[BUILD_MODE.LINE] = getBuildPositionsLine,
	[BUILD_MODE.GRID] = getBuildPositionsGrid,
	[BUILD_MODE.BOX] = getBuildPositionsBox,
	[BUILD_MODE.AROUND] = getBuildPositionsAround
}

local function getGhostBuildingUnderCursor(mouseX, mouseY)
	local _, cursorWorldPositionRaw = spTraceScreenRay(mouseX, mouseY, true, false, false, false)
	if not cursorWorldPositionRaw then
		return nil
	end
	local cursorWorldPosition = { x = cursorWorldPositionRaw[1], y = cursorWorldPositionRaw[2], z = cursorWorldPositionRaw[3]}

	for buildingIndex = #buildQueue, 1, -1 do
		local buildingData = buildQueue[buildingIndex]
		if buildingData[1] > 0 then
			local ghostPosition = {
				x = buildingData[2],
				y = buildingData[3],
				z = buildingData[4]
			}
			local distanceToBuilding = math.distance2d(cursorWorldPosition.x, cursorWorldPosition.z, ghostPosition.x, ghostPosition.z)
			local buildingWidth, buildingHeight = GetBuildingDimensions(buildingData[1], buildingData[5] or 0)
			local maximumDetectionDistance = mathMax(buildingWidth * HALF, buildingHeight * HALF) + BUILDING_DETECTION_TOLERANCE

			if distanceToBuilding <= maximumDetectionDistance then
				return {
					unitDefID = buildingData[1],
					x = buildingData[2],
					y = buildingData[3],
					z = buildingData[4],
					facing = buildingData[5] or 0
				}
			end
		end
	end

	return nil
end

local function DoBuildingsClash(buildingData1, buildingData2)
	local building1Width, building1Height = GetBuildingDimensions(buildingData1[1], buildingData1[5])
	local building2Width, building2Height = GetBuildingDimensions(buildingData2[1], buildingData2[5])

	local halfBuilding1Width, halfBuilding1Height = building1Width * HALF, building1Height * HALF
	local halfBuilding2Width, halfBuilding2Height = building2Width * HALF, building2Height * HALF

	local xDistance = mathAbs(buildingData1[2] - buildingData2[2])
	local zDistance = mathAbs(buildingData1[4] - buildingData2[4])

	return xDistance < halfBuilding1Width + halfBuilding2Width and zDistance < halfBuilding1Height + halfBuilding2Height
end

local function removeUnitShape(id)
	if unitshapes[id] then
		WG.StopDrawUnitShapeGL4(unitshapes[id])
		unitshapes[id] = nil
	end
end

local function addUnitShape(id, unitDefID, px, py, pz, rotationY, teamID, alpha)
	if unitshapes[id] then
		removeUnitShape(id)
	end
	unitshapes[id] = WG.DrawUnitShapeGL4(unitDefID, px, py, pz, rotationY, alpha or 1, teamID, nil, nil, nil, widget:GetInfo().name)
	return unitshapes[id]
end

local function DrawBuilding(buildData, borderColor, drawRanges, alpha)
	local bDefID, bx, by, bz, facing = buildData[1], buildData[2], buildData[3], buildData[4], buildData[5]
	local buildingWidth, buildingHeight = GetBuildingDimensions(bDefID, facing)
	local halfBuildingWidth, halfBuildingHeight = buildingWidth * HALF, buildingHeight * HALF

	gl.DepthTest(false)
	gl.Color(borderColor)

	gl.Shape(GL.LINE_LOOP, {
		{ v = { bx - halfBuildingWidth, by, bz - halfBuildingHeight } },
		{ v = { bx + halfBuildingWidth, by, bz - halfBuildingHeight } },
		{ v = { bx + halfBuildingWidth, by, bz + halfBuildingHeight } },
		{ v = { bx - halfBuildingWidth, by, bz + halfBuildingHeight } },
	})

	if drawRanges then
		local isMex = UnitDefs[bDefID] and UnitDefs[bDefID].extractsMetal > 0
		if isMex then
			gl.Color(1.0, 0.0, 0.0, 0.5)
			gl.DrawGroundCircle(bx, by, bz, Game.extractorRadius, 50)
		end

	end
	if WG.StopDrawUnitShapeGL4 then
		local id = buildData[1]
			.. "_"
			.. buildData[2]
			.. "_"
			.. buildData[3]
			.. "_"
			.. buildData[4]
			.. "_"
			.. buildData[5]
		addUnitShape(id, buildData[1], buildData[2], buildData[3], buildData[4], buildData[5] * (math.pi / 2), myTeamID, alpha)
	end
end

local function isUnderwater(unitDefID)
	return UnitDefs[unitDefID].modCategories.underwater
end

local function getMouseWorldPosition(unitDefID, x, y)
	local _, pos = spTraceScreenRay(x, y, true, false, false, isUnderwater(unitDefID))
	if pos then
		local buildFacing = Spring.GetBuildFacing()
		local posX = pos.x or pos[1]
		local posY = pos.y or pos[2]
		local posZ = pos.z or pos[3]
		local bx, by, bz = Spring.Pos2BuildPos(unitDefID, posX, posY, posZ, buildFacing)
		return { x = bx, y = by, z = bz }
	end
	return nil
end

local UPDATE_PERIOD = 1 / 30
local updateTime = 0
function widget:Update(dt)
	if not preGamestartPlayer or not selBuildQueueDefID then
		return
	end
	
	updateTime = updateTime + dt
	if updateTime < UPDATE_PERIOD then
		return
	end
	updateTime = 0
	
	local x, y, leftButton = spGetMouseState()
	
	if not leftButton then
		if buildModeState.startPosition and #buildModeState.buildPositions > 0 then
			local newBuildQueue = {}

			for _, buildPos in ipairs(buildModeState.buildPositions) do
				local buildPosX = buildPos.x
				local buildPosY = buildPos.y
				local buildPosZ = buildPos.z
				local buildPosFacing = buildPos.facing
				local posX, posY, posZ = Spring.Pos2BuildPos(selBuildQueueDefID, buildPosX, buildPosY, buildPosZ, buildPosFacing or Spring.GetBuildFacing())
				local buildFacingPos = buildPosFacing or Spring.GetBuildFacing()
				local buildDataPos = { selBuildQueueDefID, posX, posY, posZ, buildFacingPos }

				local hasConflicts = false

				local cx, cy, cz = Spring.GetTeamStartPosition(myTeamID)
				if cx ~= -100 then
					local cbx, cby, cbz = Spring.Pos2BuildPos(startDefID, cx, cy, cz)
					if DoBuildingsClash(buildDataPos, { startDefID, cbx, cby, cbz, 1 }) then
						hasConflicts = true
					end
				end

				if not hasConflicts then
					for i = #buildQueue, 1, -1 do
						if buildQueue[i][1] > 0 and DoBuildingsClash(buildDataPos, buildQueue[i]) then
							tableRemove(buildQueue, i)
							hasConflicts = true
						end
					end
				end
				if not hasConflicts and Spring.TestBuildOrder(selBuildQueueDefID, posX, posY, posZ, buildFacingPos) == 0 then
					hasConflicts = true
				end
				if not hasConflicts then
					local isMex = UnitDefs[selBuildQueueDefID] and UnitDefs[selBuildQueueDefID].extractsMetal > 0
					if isMex and not isMetalMap then
						local spot = WG["resource_spot_finder"].GetClosestMexSpot(posX, posZ)
						local validPos = spot and WG["resource_spot_finder"].IsMexPositionValid(spot, posX, posZ) or false
						local spotIsTaken = spot and WG["resource_spot_builder"].SpotHasExtractorQueued(spot) or false
						if not validPos or spotIsTaken then
							hasConflicts = true
						end
					end
				end

				if not hasConflicts then
					tableInsert(newBuildQueue, buildDataPos)
				end
			end
			if #newBuildQueue > 0 then
				for _, buildDataPos in ipairs(newBuildQueue) do
					buildQueue[#buildQueue + 1] = buildDataPos
				end
			end
		end

		buildModeState.startPosition = nil
		buildModeState.buildPositions = {}
		return
	end
	
	local alt, ctrl, meta, shift = Spring.GetModKeyState()
	
	if not shift and buildModeState.startPosition then
		buildModeState.startPosition = nil
		buildModeState.buildPositions = {}
		return
	end
	
	if not buildModeState.startPosition then
		return
	end
	local modKeys = { alt, ctrl, meta, shift }
	
	local buildAroundTarget = getGhostBuildingUnderCursor(x, y)

	local endPosition = getMouseWorldPosition(selBuildQueueDefID, x, y)
	if not endPosition then
		return
	end

	buildModeState.endPosition = endPosition
	buildModeState.buildAroundTarget = buildAroundTarget

	local buildFacing = Spring.GetBuildFacing()
	local mode = determineBuildMode(modKeys, buildAroundTarget, buildModeState.startPosition)
	buildModeState.mode = mode

	if mode == BUILD_MODE.AROUND then
		buildModeState.buildPositions = BUILD_POSITION_FUNCTIONS[mode](selBuildQueueDefID, buildFacing, buildAroundTarget)
	elseif mode == BUILD_MODE.SINGLE then
		buildModeState.buildPositions = BUILD_POSITION_FUNCTIONS[mode](selBuildQueueDefID, buildFacing, endPosition)
	else
		buildModeState.buildPositions = BUILD_POSITION_FUNCTIONS[mode](selBuildQueueDefID, buildFacing, buildModeState.startPosition, endPosition, buildModeState.spacing)
	end
end

function widget:MousePress(mx, my, button)
	if Spring.IsGUIHidden() then
		return
	end

	if WG["topbar"] and WG["topbar"].showingQuit() then
		return
	end

	if not preGamestartPlayer then
		return
	end
	local _, _, meta, shift = Spring.GetModKeyState()

	if not selBuildQueueDefID then
		return false
	end

	local alt, ctrl = Spring.GetModKeyState()
	if button == 1 and shift and ctrl then
		local buildAroundTarget = getGhostBuildingUnderCursor(mx, my)
		if buildAroundTarget then
			local buildFacing = Spring.GetBuildFacing()
			local aroundPositions = BUILD_POSITION_FUNCTIONS[BUILD_MODE.AROUND](selBuildQueueDefID, buildFacing, buildAroundTarget)

			if #aroundPositions > 0 then
				local newBuildQueue = {}

				local filteredAroundPositions = {}
				for _, buildPos in ipairs(aroundPositions) do
					local buildPosX = buildPos.x
					local buildPosY = buildPos.y
					local buildPosZ = buildPos.z
					local buildPosFacing = buildPos.facing
					local posX, posY, posZ = Spring.Pos2BuildPos(selBuildQueueDefID, buildPosX, buildPosY, buildPosZ, buildPosFacing or buildFacing)
					local buildFacingPos = buildPosFacing or buildFacing
					local buildDataPos = { selBuildQueueDefID, posX, posY, posZ, buildFacingPos }

					local hasOverlap = false
					for i = 1, #buildQueue do
						if buildQueue[i][1] > 0 and DoBuildingsClash(buildDataPos, buildQueue[i]) then
							hasOverlap = true
							break
						end
					end

					if not hasOverlap then
						for _, existingPos in ipairs(filteredAroundPositions) do
							local existingPosX, existingPosY, existingPosZ = existingPos[2], existingPos[3], existingPos[4]
							local existingBuildData = { selBuildQueueDefID, existingPosX, existingPosY, existingPosZ, existingPos[5] }
							if DoBuildingsClash(buildDataPos, existingBuildData) then
								hasOverlap = true
								break
							end
						end
					end

					if not hasOverlap then
						tableInsert(filteredAroundPositions, buildDataPos)
					end
				end

				for _, buildDataPos in ipairs(filteredAroundPositions) do
					local posX, posY, posZ, buildFacingPos = buildDataPos[2], buildDataPos[3], buildDataPos[4], buildDataPos[5]

					local hasConflicts = false

					local cx, cy, cz = Spring.GetTeamStartPosition(myTeamID)
					if cx ~= -100 then
						local cbx, cby, cbz = Spring.Pos2BuildPos(startDefID, cx, cy, cz)
						if DoBuildingsClash(buildDataPos, { startDefID, cbx, cby, cbz, 1 }) then
							hasConflicts = true
						end
					end

					if not hasConflicts and Spring.TestBuildOrder(selBuildQueueDefID, posX, posY, posZ, buildFacingPos) == 0 then
						hasConflicts = true
					end

					local isMex = UnitDefs[selBuildQueueDefID] and UnitDefs[selBuildQueueDefID].extractsMetal > 0
					if not hasConflicts and isMex and not isMetalMap then
						local spot = WG["resource_spot_finder"].GetClosestMexSpot(posX, posZ)
						local validPos = spot and WG["resource_spot_finder"].IsMexPositionValid(spot, posX, posZ) or false
						local spotIsTaken = spot and WG["resource_spot_builder"].SpotHasExtractorQueued(spot) or false
						if not validPos or spotIsTaken then
							hasConflicts = true
						end
					end

					if not hasConflicts then
						tableInsert(newBuildQueue, buildDataPos)
					end
				end

				if #newBuildQueue > 0 then
					for _, buildDataPos in ipairs(newBuildQueue) do
						buildQueue[#buildQueue + 1] = buildDataPos
					end
				end

				return true
			end
		end
	end

	local _, pos = spTraceScreenRay(mx, my, true, false, false, isUnderwater(selBuildQueueDefID))
	if button == 1 then
		local isMex = UnitDefs[selBuildQueueDefID] and UnitDefs[selBuildQueueDefID].extractsMetal > 0
		if WG.ExtractorSnap then
			local snapPos = WG.ExtractorSnap.position
			if snapPos then
				pos = { snapPos.x, snapPos.y, snapPos.z }
			end
		end

		if not pos then
			return
		end

		local buildFacing = Spring.GetBuildFacing()
		local posX = pos.x or pos[1]
		local posY = pos.y or pos[2]
		local posZ = pos.z or pos[3]
		local bx, by, bz = Spring.Pos2BuildPos(selBuildQueueDefID, posX, posY, posZ, buildFacing)
		local buildData = { selBuildQueueDefID, bx, by, bz, buildFacing }
		local cx, cy, cz = Spring.GetTeamStartPosition(myTeamID)

		local alt, ctrl = Spring.GetModKeyState()

		local isMex = UnitDefs[selBuildQueueDefID] and UnitDefs[selBuildQueueDefID].extractsMetal > 0
		if shift and not buildModeState.startPosition and not (isMex and not isMetalMap) then
			buildModeState.startPosition = { x = bx, y = by, z = bz }
			buildModeState.endPosition = { x = bx, y = by, z = bz }
			buildModeState.buildPositions = {}
			return true
		end
		
		
		if (meta or not shift) and cx ~= -100 then
			local cbx, cby, cbz = Spring.Pos2BuildPos(startDefID, cx, cy, cz)

			if DoBuildingsClash(buildData, { startDefID, cbx, cby, cbz, 1 }) then
				return true
			end
		end

		if Spring.TestBuildOrder(selBuildQueueDefID, bx, by, bz, buildFacing) ~= 0 then
			local hasConflicts = false

			local cx, cy, cz = Spring.GetTeamStartPosition(myTeamID)
			if cx ~= -100 then
				local cbx, cby, cbz = Spring.Pos2BuildPos(startDefID, cx, cy, cz)
				if DoBuildingsClash(buildData, { startDefID, cbx, cby, cbz, 1 }) then
					hasConflicts = true
				end
			end

			if not hasConflicts then
				for i = #buildQueue, 1, -1 do
					if buildQueue[i][1] > 0 and DoBuildingsClash(buildData, buildQueue[i]) then
						tableRemove(buildQueue, i)
						hasConflicts = true
					end
				end
			end

			if not hasConflicts and isMex and not isMetalMap then
				local spot = WG["resource_spot_finder"].GetClosestMexSpot(bx, bz)
				local validPos = spot and WG["resource_spot_finder"].IsMexPositionValid(spot, bx, bz) or false
				local spotIsTaken = spot and WG["resource_spot_builder"].SpotHasExtractorQueued(spot) or false
				if not validPos or spotIsTaken then
					hasConflicts = true
				end
			end

			if not hasConflicts then
				if meta then
					tableInsert(buildQueue, 1, buildData)
				elseif shift then
					buildQueue[#buildQueue + 1] = buildData
					handleBuildMenu(shift)
				else
					if isMex then
						if WG.ExtractorSnap.position or isMetalMap then
							buildQueue = { buildData }
							handleBuildMenu(false)
						end
					else
						buildQueue = { buildData }
						handleBuildMenu(false)
					end
				end

				if not shift then
					setPreGamestartDefID(nil)
				end
			end
		end

		return true
	end

	if button == 3 then
		setPreGamestartDefID(nil)
		buildModeState.startPosition = nil
		buildModeState.buildPositions = {}
	end

	if button == 1 and #buildQueue > 0 and buildQueue[1][1]>0 then
		local _, pos = spTraceScreenRay(mx, my, true, false, false, isUnderwater(startDefID))
		if not pos then
			return
		end
		local cbx, cby, cbz = Spring.Pos2BuildPos(startDefID, pos[1], pos[2], pos[3])

		if DoBuildingsClash({ startDefID, cbx, cby, cbz, 1 }, buildQueue[1]) then
			return true
		end
	end

	if button == 3 and shift then
		local x, y, _ = spGetMouseState()
		local _, pos = spTraceScreenRay(x, y, true, false, false, true)
		if pos and pos[1] then
			local buildData = { -CMD.MOVE, pos[1], pos[2], pos[3], nil }

			buildQueue[#buildQueue + 1] = buildData
		end
	end

	if button == 3 and #buildQueue > 0 then
		tableRemove(buildQueue, #buildQueue)

		return true
	end
end

local function hasCacheExpired(currentStartPos, currentSelBuildData)
	local startPosChanged = not cachedStartPosition or
		cachedStartPosition.x ~= currentStartPos.x or
		cachedStartPosition.y ~= currentStartPos.y or
		cachedStartPosition.z ~= currentStartPos.z

	local currentMetrics = {
		firstItemCoords = buildQueue[1] and {buildQueue[1][2], buildQueue[1][3], buildQueue[1][4]} or nil,
		queueLength = #buildQueue
	}

	local queueChanged = not cachedQueueMetrics or
		currentMetrics.queueLength ~= cachedQueueMetrics.queueLength or
		(currentMetrics.firstItemCoords and cachedQueueMetrics.firstItemCoords and (
			currentMetrics.firstItemCoords[1] ~= cachedQueueMetrics.firstItemCoords[1] or
			currentMetrics.firstItemCoords[2] ~= cachedQueueMetrics.firstItemCoords[2] or
			currentMetrics.firstItemCoords[3] ~= cachedQueueMetrics.firstItemCoords[3]
		)) or
		(currentMetrics.firstItemCoords == nil) ~= (cachedQueueMetrics.firstItemCoords == nil)

	if startPosChanged or queueChanged then
		cachedStartPosition = {x = currentStartPos.x, y = currentStartPos.y, z = currentStartPos.z}
		cachedQueueMetrics = {
			firstItemCoords = currentMetrics.firstItemCoords and {unpack(currentMetrics.firstItemCoords)} or nil,
			queueLength = currentMetrics.queueLength
		}
		return true
	end
	return false
end

function widget:DrawWorld()
	if not WG.StopDrawUnitShapeGL4 then
		return
	end

	-- remove unit shape queue to re-add again later
	for id, _ in pairs(unitshapes) do
		removeUnitShape(id)
	end

	-- Avoid unnecessary overhead after buildqueue has been setup in early frames
	if spGetGameFrame() > 0 then
		widgetHandler:RemoveCallIn("DrawWorld")
		return
	end

	if not preGamestartPlayer then
		return
	end

	-- draw pregame build queue
	local ALPHA_SPAWNED = 1.0
	local ALPHA_DEFAULT = 0.5

	local BORDER_COLOR_SPAWNED = { 1.0, 0.0, 1.0, 0.7 }
	local BORDER_COLOR_NORMAL = { 0.3, 1.0, 0.3, 0.5 }
	local BORDER_COLOR_CLASH = { 0.7, 0.3, 0.3, 1.0 }
	local BORDER_COLOR_INVALID = { 1.0, 0.0, 0.0, 1.0 }
	local BORDER_COLOR_VALID = { 0.0, 1.0, 0.0, 1.0 }
	local BUILD_DISTANCE_COLOR = { 0.3, 1.0, 0.3, 0.6 }
	local BUILD_LINES_COLOR = { 0.3, 1.0, 0.3, 0.6 }

	gl.LineWidth(1.49)

	-- We need data about currently selected building, for drawing clashes etc
	local selBuildData
	if selBuildQueueDefID then
		local x, y, _ = spGetMouseState()
		local _, pos = spTraceScreenRay(x, y, true, false, false, isUnderwater(selBuildQueueDefID))
		if pos then
			local buildFacing = Spring.GetBuildFacing()
			local bx, by, bz = Spring.Pos2BuildPos(selBuildQueueDefID, pos[1], pos[2], pos[3], buildFacing)
			selBuildData = { selBuildQueueDefID, bx, by, bz, buildFacing }
		end
	end

	if startDefID ~= Spring.GetTeamRulesParam(myTeamID, "startUnit") then
		startDefID = Spring.GetTeamRulesParam(myTeamID, "startUnit")
	end


	local sx, sy, sz = Spring.GetTeamStartPosition(myTeamID) -- Returns 0, 0, 0 when none chosen (was -100, -100, -100 previously)
	--should startposition not match 0,0,0 and no commander is placed, then there is a green circle on the map till one is placed
	--TODO: be based on the map, if position is changed from default(?)
	local startChosen = (sx ~= 0) or (sy ~=0) or (sz~=0)
	if startChosen and startDefID then
		-- Correction for start positions in the air
		sy = spGetGroundHeight(sx, sz)

		-- Draw start units build radius
		gl.Color(BUILD_DISTANCE_COLOR)
		local buildDistance = Spring.GetGameRulesParam("overridePregameBuildDistance") or UnitDefs[startDefID].buildDistance
		if buildDistance then
			gl.DrawGroundCircle(sx, sy, sz, buildDistance, 40)
		end
	end

	-- Check for faction change
	if prevStartDefID ~= startDefID then
        local prevDefName = prevStartDefID and UnitDefs[prevStartDefID] and UnitDefs[prevStartDefID].name
        local currentDefName = startDefID and UnitDefs[startDefID] and UnitDefs[startDefID].name

        local previousFactionSide = prevDefName and SubLogic.getSideFromUnitName(prevDefName)
        local currentFactionSide = currentDefName and SubLogic.getSideFromUnitName(currentDefName)

        if previousFactionSide and currentFactionSide and previousFactionSide ~= currentFactionSide then
            convertBuildQueueFaction(previousFactionSide, currentFactionSide) 
            if selBuildQueueDefID then
                selBuildQueueDefID = handleSelectedBuildingConversion(selBuildQueueDefID, previousFactionSide, currentFactionSide, selBuildData)
            end
        elseif previousFactionSide and currentFactionSide and previousFactionSide == currentFactionSide then
            Spring.Log(widget:GetInfo().name, LOG.DEBUG, string.format(
                "Sides determined but are the same (%s), no conversion needed.", currentFactionSide))
        else
            Spring.Log(widget:GetInfo().name, LOG.WARNING, string.format(
                "Could not determine sides for conversion: prevDefID=%s (name: %s), currentDefID=%s (name: %s). Names might be unhandled by SubLogic.getSideFromUnitName, or SubLogic itself might be incomplete from a non-critical load error.", 
                tostring(prevStartDefID), tostring(prevDefName), tostring(startDefID), tostring(currentDefName)))
        end
        prevStartDefID = startDefID
	end

	local alphaResults = cachedAlphaResults
	local cacheExpired = hasCacheExpired({x = sx, y = sy, z = sz}, selBuildData)

	if not alphaResults or cacheExpired then
		alphaResults = { queueAlphas = {}, selectedAlpha = ALPHA_DEFAULT }

		local getBuildQueueSpawnStatus = WG["getBuildQueueSpawnStatus"]
		if getBuildQueueSpawnStatus then
			local spawnStatus = getBuildQueueSpawnStatus(buildQueue, selBuildData)

			for i = 1, #buildQueue do
				local isSpawned = spawnStatus.queueSpawned[i] or false
				alphaResults.queueAlphas[i] = isSpawned and ALPHA_SPAWNED or ALPHA_DEFAULT
			end

			alphaResults.selectedAlpha = spawnStatus.selectedSpawned and ALPHA_SPAWNED or ALPHA_DEFAULT
		end

		cachedAlphaResults = alphaResults
	end

	if not cachedQueueLineVerts or cacheExpired then
		cachedQueueLineVerts = startChosen and { { v = { sx, sy, sz } } } or {}
		for b = 1, #buildQueue do
			local buildData = buildQueue[b]

			if buildData[1] > 0 then
				local alpha = alphaResults.queueAlphas[b] or ALPHA_DEFAULT

				if alpha < ALPHA_SPAWNED then
					cachedQueueLineVerts[#cachedQueueLineVerts + 1] = { v = { buildData[2], buildData[3], buildData[4] } }
				end
			else
				cachedQueueLineVerts[#cachedQueueLineVerts + 1] = { v = { buildData[2], buildData[3], buildData[4] } }
			end
		end
	end
	local queueLineVerts = cachedQueueLineVerts

	for b = 1, #buildQueue do
		local buildData = buildQueue[b]

		if buildData[1] > 0 then
			local alpha = alphaResults.queueAlphas[b] or ALPHA_DEFAULT
			local isSpawned = alpha >= ALPHA_SPAWNED
			local borderColor = isSpawned and BORDER_COLOR_SPAWNED or BORDER_COLOR_NORMAL

			if selBuildData and DoBuildingsClash(selBuildData, buildData) then
				DrawBuilding(buildData, BORDER_COLOR_CLASH, false, alpha)
			else
				DrawBuilding(buildData, borderColor, false, alpha)
			end
		end
	end

	-- Draw queue lines
	gl.Color(BUILD_LINES_COLOR)
	gl.LineStipple("springdefault")
	gl.Shape(GL.LINE_STRIP, queueLineVerts)
	gl.LineStipple(false)

	local function convertBuildPosToPreviewData(buildPos, buildFacing)
		local posX, posY, posZ = Spring.Pos2BuildPos(selBuildQueueDefID, buildPos.x, buildPos.y, buildPos.z, buildPos.facing or buildFacing)
		local buildFacingPos = buildPos.facing or buildFacing
		return { selBuildQueueDefID, posX, posY, posZ, buildFacingPos }
	end

	local function checkCommanderClash(previewBuildData, cx, cy, cz)
		if cx == -100 then
			return false
		end
		local cbx, cby, cbz = Spring.Pos2BuildPos(startDefID, cx, cy, cz)
		return DoBuildingsClash(previewBuildData, { startDefID, cbx, cby, cbz, 1 })
	end

	local function checkMexValidity(posX, posZ, isMex)
		if not isMex or isMetalMap then
			return true
		end
		local spot = WG["resource_spot_finder"] and WG["resource_spot_finder"].GetClosestMexSpot and WG["resource_spot_finder"].GetClosestMexSpot(posX, posZ)
		local validPos = spot and WG["resource_spot_finder"].IsMexPositionValid and WG["resource_spot_finder"].IsMexPositionValid(spot, posX, posZ) or false
		local spotIsTaken = spot and WG["resource_spot_builder"] and WG["resource_spot_builder"].SpotHasExtractorQueued and WG["resource_spot_builder"].SpotHasExtractorQueued(spot) or false
		return validPos and not spotIsTaken
	end

	local function isBuildAroundModeActive()
		local alt, ctrl, meta, shift = Spring.GetModKeyState()
		if not (shift and ctrl) then
			return false, nil
		end
		local x, y = spGetMouseState()
		local buildAroundTarget = getGhostBuildingUnderCursor(x, y)
		return buildAroundTarget ~= nil, buildAroundTarget
	end

	local showPreview = false
	local previewPositions = {}
	local isBuildAroundMode = false

	if buildModeState.startPosition and #buildModeState.buildPositions > 0 and selBuildQueueDefID then
		showPreview = true
		previewPositions = buildModeState.buildPositions
	elseif selBuildQueueDefID then
		local buildAroundActive, buildAroundTarget = isBuildAroundModeActive()
		if buildAroundActive then
			local buildFacing = Spring.GetBuildFacing()
			previewPositions = BUILD_POSITION_FUNCTIONS[BUILD_MODE.AROUND](selBuildQueueDefID, buildFacing, buildAroundTarget)
			if #previewPositions > 0 then
				showPreview = true
				isBuildAroundMode = true
			end
		end
	end

	if showPreview then
		local buildFacing = Spring.GetBuildFacing()
		local cx, cy, cz = Spring.GetTeamStartPosition(myTeamID)
		local isMex = UnitDefs[selBuildQueueDefID] and UnitDefs[selBuildQueueDefID].extractsMetal > 0

		local previewSpawnStatus = {}
		local getBuildQueueSpawnStatus = WG["getBuildQueueSpawnStatus"]
		if getBuildQueueSpawnStatus then
			local tempQueue = {}
			for _, b in ipairs(buildQueue) do
				tableInsert(tempQueue, b)
			end

			local validPreviewPositions = {}

			for _, buildPos in ipairs(previewPositions) do
				local previewBuildData = convertBuildPosToPreviewData(buildPos, buildFacing)
				local hasConflicts = false

				if isBuildAroundMode then
					for _, existingPos in ipairs(validPreviewPositions) do
						if DoBuildingsClash(previewBuildData, existingPos) then
							hasConflicts = true
							break
						end
					end
				end

				if not hasConflicts then
					tableInsert(validPreviewPositions, previewBuildData)
				end
			end

			local validPreviewCount = 0
			for _, previewBuildData in ipairs(validPreviewPositions) do
				local posX, posY, posZ, buildFacingPos = previewBuildData[2], previewBuildData[3], previewBuildData[4], previewBuildData[5]
				local isValid = Spring.TestBuildOrder(selBuildQueueDefID, posX, posY, posZ, buildFacingPos) ~= 0
				local clashesWithCommander = checkCommanderClash(previewBuildData, cx, cy, cz)
				local mexValid = checkMexValidity(posX, posZ, isMex)

				if not clashesWithCommander and isValid and mexValid then
					tableInsert(tempQueue, previewBuildData)
					validPreviewCount = validPreviewCount + 1
				end
			end

			if validPreviewCount > 0 then
				local spawnStatus = getBuildQueueSpawnStatus(tempQueue, nil)
				for i = #buildQueue + 1, #tempQueue do
					previewSpawnStatus[i - #buildQueue] = spawnStatus.queueSpawned[i] or false
				end
			end
		end

		local filteredPreviewPositions = {}
		local filteredPreviewBuildData = {}
		for _, buildPos in ipairs(previewPositions) do
			local previewBuildData = convertBuildPosToPreviewData(buildPos, buildFacing)
			local hasOverlap = false

			if isBuildAroundMode then
				for _, existingBuildData in ipairs(filteredPreviewBuildData) do
					if DoBuildingsClash(previewBuildData, existingBuildData) then
						hasOverlap = true
						break
					end
				end

				if not hasOverlap then
					for i = 1, #buildQueue do
						if buildQueue[i][1] > 0 and DoBuildingsClash(previewBuildData, buildQueue[i]) then
							hasOverlap = true
							break
						end
					end
				end
			end

			if not hasOverlap then
				tableInsert(filteredPreviewPositions, buildPos)
				tableInsert(filteredPreviewBuildData, previewBuildData)
			end
		end

		local previewIndex = 1
		for _, buildPos in ipairs(filteredPreviewPositions) do
			local previewBuildData = convertBuildPosToPreviewData(buildPos, buildFacing)
			local posX, posY, posZ, buildFacingPos = previewBuildData[2], previewBuildData[3], previewBuildData[4], previewBuildData[5]
			local isValid = Spring.TestBuildOrder(selBuildQueueDefID, posX, posY, posZ, buildFacingPos) ~= 0
			local clashesWithCommander = checkCommanderClash(previewBuildData, cx, cy, cz)

			if clashesWithCommander then
				DrawBuilding(previewBuildData, BORDER_COLOR_CLASH, false, ALPHA_DEFAULT)
			elseif isValid then
				local mexValid = checkMexValidity(posX, posZ, isMex)
				if mexValid then
					local wouldBeSpawned = previewSpawnStatus[previewIndex] or false
					local borderColor = wouldBeSpawned and BORDER_COLOR_SPAWNED or BORDER_COLOR_VALID
					local previewAlpha = wouldBeSpawned and ALPHA_SPAWNED or ALPHA_DEFAULT
					DrawBuilding(previewBuildData, borderColor, false, previewAlpha)
					previewIndex = previewIndex + 1
				else
					DrawBuilding(previewBuildData, BORDER_COLOR_INVALID, false, ALPHA_DEFAULT)
				end
			else
				DrawBuilding(previewBuildData, BORDER_COLOR_INVALID, false, ALPHA_DEFAULT)
			end
		end
	end

	local showSelectedBuilding = true
	if buildModeState.startPosition then
		showSelectedBuilding = false
	else
		local buildAroundActive = isBuildAroundModeActive()
		if buildAroundActive then
			showSelectedBuilding = false
		end
	end

	if selBuildData and showSelectedBuilding then
		local isMex = UnitDefs[selBuildQueueDefID] and UnitDefs[selBuildQueueDefID].extractsMetal > 0
		local testOrder = spTestBuildOrder(
			selBuildQueueDefID,
			selBuildData[2],
			selBuildData[3],
			selBuildData[4],
			selBuildData[5]
		) ~= 0
		
		local isSelectedSpawned = false
		local selectedAlpha = ALPHA_DEFAULT
		local getBuildQueueSpawnStatus = WG["getBuildQueueSpawnStatus"]
		if getBuildQueueSpawnStatus and testOrder then
			local spawnStatus = getBuildQueueSpawnStatus(buildQueue, selBuildData)
			isSelectedSpawned = spawnStatus.selectedSpawned or false
			selectedAlpha = isSelectedSpawned and ALPHA_SPAWNED or ALPHA_DEFAULT
		end
		
		if not isMex then
			local color = testOrder and (isSelectedSpawned and BORDER_COLOR_SPAWNED or BORDER_COLOR_VALID) or BORDER_COLOR_INVALID
			DrawBuilding(selBuildData, color, true, selectedAlpha)
		elseif isMex then
			if WG.ExtractorSnap.position or isMetalMap then
				local color = testOrder and (isSelectedSpawned and BORDER_COLOR_SPAWNED or BORDER_COLOR_VALID) or BORDER_COLOR_INVALID
				DrawBuilding(selBuildData, color, true, selectedAlpha)
			else
				DrawBuilding(selBuildData, BORDER_COLOR_INVALID, true, selectedAlpha)
			end
		else
			local color = testOrder and (isSelectedSpawned and BORDER_COLOR_SPAWNED or BORDER_COLOR_VALID) or BORDER_COLOR_INVALID
			DrawBuilding(selBuildData, color, true, selectedAlpha)
		end
	end

	-- Reset gl
	gl.Color(1, 1, 1, 1)
	gl.LineWidth(1.0)
end

function widget:GameFrame(n)
	-- Avoid unnecessary overhead after buildqueue has been setup in early frames
	if #buildQueue == 0 then
		widgetHandler:RemoveCallIn("GameFrame")
		widgetHandler:RemoveWidget()
		return
	end

	-- handle the pregame build queue
	if not (n <= 90 and n > 1) then
		return
	end

	-- inform gadget how long is our queue
	local t = 0
	for i = 1, #buildQueue do
		if buildQueue[i][1] > 0 then
			t = t + UnitDefs[buildQueue[i][1]].buildTime
		end
	end
	if startDefID then
		local buildTime = t / UnitDefs[startDefID].buildSpeed
		Spring.SendCommands("luarules initialQueueTime " .. buildTime)
	end

	local tasker
	-- Search for our starting unit
	local units = Spring.GetTeamUnits(spGetMyTeamID())
	for u = 1, #units do
		local uID = units[u]
		if GetUnitCanCompleteQueue(uID) then
			tasker = uID
			if Spring.GetUnitRulesParam(uID, "startingOwner") == Spring.GetMyPlayerID() then
				-- we found our com even if cooping, assigning queue to this particular unit
				break
			end
		end
	end
	if tasker then
		for b = 1, #buildQueue do
			local buildData = buildQueue[b]
			Spring.GiveOrderToUnit(
				tasker,
				-buildData[1],
				{ buildData[2], buildData[3], buildData[4], buildData[5] },
				{ "shift" }
			)
		end
		buildQueue = {}
	end
end

function widget:GameStart()
	preGamestartPlayer = false

	-- Ensure startDefID is current for GameStart logic, though DrawWorld might have already updated prevStartDefID
	local currentStartDefID_GS = Spring.GetTeamRulesParam(myTeamID, "startUnit")
	if startDefID ~= currentStartDefID_GS then
	    Spring.Log("gui_pregame_build", LOG.DEBUG, string.format("GameStart: startDefID (%s) differs from current rules param (%s). Updating.", tostring(startDefID), tostring(currentStartDefID_GS)))
	    startDefID = currentStartDefID_GS
	end

	if prevStartDefID ~= startDefID then
		local prevDefName = prevStartDefID and UnitDefs[prevStartDefID] and UnitDefs[prevStartDefID].name
		local currentDefName = startDefID and UnitDefs[startDefID] and UnitDefs[startDefID].name

		local previousFactionSide = prevDefName and SubLogic.getSideFromUnitName(prevDefName)
		local currentFactionSide = currentDefName and SubLogic.getSideFromUnitName(currentDefName)

		if previousFactionSide and currentFactionSide and previousFactionSide ~= currentFactionSide then
			convertBuildQueueFaction(previousFactionSide, currentFactionSide)
		elseif previousFactionSide and currentFactionSide and previousFactionSide == currentFactionSide then
			-- Sides are the same, no conversion needed.
		else
			Spring.Log("gui_pregame_build", LOG.WARNING, string.format("Could not determine sides for conversion in GameStart: prevDefID=%s, currentDefID=%s", tostring(prevStartDefID), tostring(startDefID)))
		end
		prevStartDefID = startDefID
	end


	-- Deattach pregame action handlers
	widgetHandler:RemoveAction("stop")
	widgetHandler:RemoveAction("buildfacing")
	widgetHandler:RemoveAction("buildspacing")
	widgetHandler:RemoveAction("buildmenu_pregame_deselect")
end

function widget:Shutdown()
	-- Stop drawing all ghosts
	if WG.StopDrawUnitShapeGL4 then
		for id, _ in pairs(unitshapes) do
			removeUnitShape(id)
		end
	end
	widgetHandler:DeregisterGlobal("GetPreGameDefID")
	widgetHandler:DeregisterGlobal("GetBuildQueue")

	WG["pregame-build"] = nil
	if WG["buildinggrid"] ~= nil and WG["buildinggrid"].setForceShow ~= nil then
		WG["buildinggrid"].setForceShow(FORCE_SHOW_REASON, false)
	end

	if WG["easyfacing"] ~= nil and WG["easyfacing"].setForceShow ~= nil then
		WG["easyfacing"].setForceShow(FORCE_SHOW_REASON, false)
	end
end

function widget:GetConfigData()
	return {
		buildQueue = buildQueue,
		gameID = Game.gameID and Game.gameID or Spring.GetGameRulesParam("GameID"),
	}
end

function widget:SetConfigData(data)
	if
		data.buildQueue
		and spGetGameFrame() == 0
		and data.gameID
		and data.gameID == (Game.gameID and Game.gameID or Spring.GetGameRulesParam("GameID"))
	then
		buildQueue = data.buildQueue
	end
end
