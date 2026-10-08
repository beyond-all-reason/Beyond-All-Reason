local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Area Mex",
		desc = "Adds a command to cap mexes in an area.",
		author = "Hobo Joe, Google Frog, NTG, Chojin , Doo, Floris, Tarte, Baldric",
		date = "Oct 23, 2010, (last update: March 3, 2022)",
		license = "GNU GPL, v2 or later",
		handler = true,
		layer = 1,
		enabled = true,
	}
end

local CMD_AREA_MEX = GameCMD.AREA_MEX

local spGetActiveCommand = Spring.GetActiveCommand
local spGetUnitCommands = Spring.GetUnitCommands
local spGetMapDrawMode = Spring.GetMapDrawMode
local spGetUnitPosition = Spring.GetUnitPosition
local spSendCommands = Spring.SendCommands
local taremove = table.remove

local toggledMetal, retoggleLos
local selectedMex
local selectedUnits = Spring.GetSelectedUnits()
local mexConstructors
local mexBuildings
local metalSpots

local metalMap = false

local function getPregame()
	local pregame = WG["pregame-build"]
	if Spring.GetGameFrame() == 0 and pregame and pregame.getStartBuildOptions then
		local options = pregame.getStartBuildOptions()
		if options then
			return pregame, options
		end
	end
end

local function activatePregame(unitDefID)
	local pregame, options = getPregame()
	if not pregame or metalMap then
		return false
	end
	for _, id in ipairs(options) do
		if id == unitDefID and mexBuildings[id] then
			-- Ask the engine to draw/handle the usual area cursor and drag gesture.
			Spring.ForceLayoutUpdate()
			if not Spring.SetActiveCommand("areamex") then
				return false
			end
			selectedMex = id
			pregame.setPreGamestartDefID(nil)
			return true
		end
	end
	return false
end

local function setAreaMexType(uDefID)
	selectedMex = -uDefID
end

function widget:Initialize()
	if not WG.resource_spot_builder or not WG.resource_spot_finder then
		Spring.Echo("Area Mex: the mex/geo resource spot API is missing, disabling")
		widgetHandler:RemoveWidget()
		return
	end

	metalSpots = WG.resource_spot_finder.metalSpotsList
	metalMap = WG.resource_spot_finder.isMetalMap
	mexBuildings = WG.resource_spot_builder.GetMexBuildings()
	mexConstructors = WG.resource_spot_builder.GetMexConstructors()

	WG.areamex = { activatePregame = activatePregame }
	WG.areamex.setAreaMexType = function(uDefID)
		setAreaMexType(uDefID)
	end
end

---Gets the position of the last command in a unit's queue, or nil if the queue is empty
---@param unitID UnitID
---@return number|nil x
---@return number|nil z
local function getLastQueuedPosition(unitID)
	local queue = spGetUnitCommands(unitID, -1)
	if queue and #queue > 0 then
		local lastCmd = queue[#queue]
		if lastCmd.params and #lastCmd.params >= 3 then
			return lastCmd.params[1], lastCmd.params[3]
		end
	end
	return nil, nil
end

---Finds all builders among selected units that can make the specified building, and gets their average position.
---When useQueueEnd is true, uses the position of the last queued command instead of the unit's current position.
---@param units table selected units
---@param constructorIds table<UnitID, ResourceSpotConstructor?> All mex constructors
---@param buildingId UnitDefID Specific mex that we want to build
---@param useQueueEnd boolean Whether to use the end-of-queue position (for shift-queuing)
---@return table { x, z }
local function getAvgPositionOfValidBuilders(units, constructorIds, buildingId, useQueueEnd)
	-- Add highest producing constructors to mainBuilders table + give guard orders to "inferior" constructors
	local builderCount = 0
	local tX, tZ = 0, 0
	for i = 1, #units do
		local id = units[i]
		local constructor = constructorIds[id]
		if constructor then
			-- iterate over constructor options to see if it can make the chosen extractor
			for _, buildable in pairs(constructor.building) do
				if -buildable == buildingId then -- assume that it's a valid extractor based on previous steps
					local x, z
					if useQueueEnd then
						x, z = getLastQueuedPosition(id)
					end
					if not x then
						local _
						x, _, z = spGetUnitPosition(id)
					end
					if z then
						tX, tZ = tX + x, tZ + z
						builderCount = builderCount + 1
					end
				end
			end
		end
	end

	if builderCount == 0 then
		return
	end
	return { x = tX / builderCount, z = tZ / builderCount }
end

---Get all mex spots in an area
---@param x number
---@param z number
---@param radius number
---@return table Array of spots within the specified area
local function getSpotsInArea(x, z, radius)
	local validSpots = {}

	for i = 1, #metalSpots do
		local spot = metalSpots[i]
		local dist = math.distance2dSquared(x, z, spot.x, spot.z)
		if dist < radius * radius then
			validSpots[#validSpots + 1] = spot
		end
	end
	return validSpots
end

---Make build commands for all passed in spots, but do not apply them
---@param spots table
---@return table An array of commands, in the same format as PreviewExtractorCommand
local function getCmdsForValidSpots(spots, keepQueue, buildOptions)
	local cmds, validSpots = {}, {}
	local candidates = selectedMex and { selectedMex } or buildOptions or {}
	for _, spot in ipairs(spots) do
		if not (keepQueue and WG.resource_spot_builder.SpotHasExtractorQueued(spot)) then
			local best, extraction = nil, 0
			for _, id in ipairs(candidates) do
				if mexBuildings[id] and mexBuildings[id] > extraction then
					local cmd = WG.resource_spot_builder.PreviewExtractorCommand({ spot.x, spot.y, spot.z }, id, spot)
					-- Live upgrades may be blocked by the mex they replace; the
					-- resource API and upgrade gadget handle that case.
					if
						cmd
						and (not buildOptions or Spring.TestBuildOrder(cmd[1], cmd[2], cmd[3], cmd[4], cmd[5]) ~= 0)
					then
						best, extraction = cmd, mexBuildings[id]
					end
				end
			end
			if best then
				cmds[#cmds + 1], validSpots[#validSpots + 1] = best, spot
			end
		end
	end
	-- Filtering must keep worth values aligned with their commands.
	return cmds, validSpots
end

---Nearest neighbor search. Spots are passed in to do minor weighting based on mex value
---@param cmds table
---@param spots table
---@param useQueueEnd boolean Whether to start the route at the existing queue end.
---@param fallback table Area center, used before the player chooses a spawn.
local function calculateCmdOrder(cmds, spots, useQueueEnd, fallback)
	local pregame = getPregame()
	local builderPos
	if pregame then
		local x, _, z = pregame.getBuildOrigin(useQueueEnd)
		builderPos = x and x >= 0 and { x = x, z = z } or fallback
	else
		builderPos = getAvgPositionOfValidBuilders(selectedUnits, mexConstructors, selectedMex, useQueueEnd)
	end
	if not builderPos then
		return {}
	end
	local orderedCommands = {}
	local pos = {}
	while #cmds > 0 do
		local shortestDist = math.huge
		local shortestIndex = -1
		for i = 1, #cmds do
			local dist = math.distance2dSquared(builderPos.x, builderPos.z, cmds[i][2], cmds[i][4])
			dist = dist / spots[i].worth
			if dist < shortestDist then
				shortestDist = dist
				shortestIndex = i
				pos = { x = cmds[i][2], z = cmds[i][4] }
			end
		end
		orderedCommands[#orderedCommands + 1] = cmds[shortestIndex]
		taremove(cmds, shortestIndex)
		taremove(spots, shortestIndex)
		builderPos = pos
	end
	return orderedCommands
end

local function getSelectedBuilderIDs()
	local builders = {}
	for i = 1, #selectedUnits do
		local unitID = selectedUnits[i]
		if mexConstructors[unitID] then
			builders[#builders + 1] = unitID
		end
	end
	return builders
end

---@return BuildingInfo[]
local function mapCommandsToBuildingInfos(cmds)
	local buildings = {}
	for i = 1, #cmds do
		local cmd = cmds[i]
		---@type BuildingInfo
		local buildingInfo = {}
		buildingInfo.unitDefID = cmd[1]
		buildingInfo.position = { cmd[2], cmd[3], cmd[4] }
		buildingInfo.facing = cmd[5]
		buildings[#buildings + 1] = buildingInfo
	end
	return buildings
end

function widget:CommandNotify(id, params, options)
	if id ~= CMD_AREA_MEX then
		return
	end

	if metalMap then
		return true
	end

	local cmdX, _, cmdZ, cmdRadius = params[1], params[2], params[3], params[4]
	if not cmdRadius or cmdRadius <= 0 then
		return true
	end

	local spots = getSpotsInArea(cmdX, cmdZ, cmdRadius)
	if WG.skip_allied_upgrade then
		spots = WG.skip_allied_upgrade.filterOutAlliedSpots(spots, mexBuildings)
	end

	local pregame, buildOptions = getPregame()
	if Spring.GetGameFrame() == 0 and not pregame then
		return true
	end
	if pregame then
		-- The player can change faction while the area cursor is active.
		local allowed = false
		for _, id in ipairs(buildOptions) do
			if id == selectedMex then
				allowed = true
			end
		end
		if not allowed then
			selectedMex = nil
		end
	elseif not selectedMex then
		selectedMex =
			WG.resource_spot_builder.GetBestExtractorFromBuilders(selectedUnits, mexConstructors, mexBuildings)
	end
	if not pregame and not selectedMex then
		return true
	end
	local shift, meta = options.shift, options.meta
	local mode = pregame and pregame.getInsertMode(shift, meta)
		or (WG.commandInsert and WG.commandInsert.GetInsertMode(options))
	local cmds, validSpots = getCmdsForValidSpots(spots, shift or meta or mode, buildOptions)
	local sortedCmds = calculateCmdOrder(cmds, validSpots, shift and not mode and not meta, { x = cmdX, z = cmdZ })

	local isBuildSplitActive = not pregame and WG.build_split and WG.build_split.isActive()
	if shift and isBuildSplitActive and #sortedCmds > 0 then
		local issueOrders
		if mode and WG.commandInsert then
			local api = WG.commandInsert
			issueOrders = function(ids, orders)
				return api.InsertCommands(ids, orders, options, mode)
			end
		end
		WG.build_split.splitBuildings(
			getSelectedBuilderIDs(),
			mapCommandsToBuildingInfos(sortedCmds),
			options,
			issueOrders
		)
	else
		WG.resource_spot_builder.ApplyPreviewCmds(sortedCmds, mexConstructors, shift, options)
	end

	selectedMex = nil

	if not options.shift then
		if WG.gridmenu then
			WG.gridmenu.clearCategory()
		end
	end
	return true
end

-- Adjust map view mode as needed
function widget:Update(dt)
	local _, cmd, _ = spGetActiveCommand()
	if cmd == CMD_AREA_MEX then
		if spGetMapDrawMode() ~= "metal" then
			if Spring.GetMapDrawMode() == "los" then
				retoggleLos = true
			end
			spSendCommands("ShowMetalMap")
			toggledMetal = true
		end
	else
		if toggledMetal then
			spSendCommands("ShowStandard")
			if retoggleLos then
				Spring.SendCommands("togglelos")
				retoggleLos = nil
			end
			toggledMetal = false
		end
	end
end

function widget:SelectionChanged(sel)
	selectedUnits = sel
end

function widget:CommandsChanged()
	if metalMap then
		return
	end
	local _, options = getPregame()
	local available = false
	if options then
		for _, id in ipairs(options) do
			if mexBuildings[id] then
				available = true
				break
			end
		end
	elseif Spring.GetGameFrame() > 0 then
		for _, id in ipairs(selectedUnits) do
			if mexConstructors[id] then
				available = true
				break
			end
		end
	end
	if available then
		widgetHandler.customCommands[#widgetHandler.customCommands + 1] = {
			id = CMD_AREA_MEX,
			type = CMDTYPE.ICON_AREA,
			tooltip = "Define an area (with metal spots in it) to make metal extractors in",
			name = "Mex",
			cursor = "areamex",
			action = "areamex",
		}
	end
end

function widget:Shutdown()
	WG.areamex = nil
end
