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
		enabled = true
	}
end

local CMD_AREA_MEX = GameCMD.AREA_MEX

local spGetActiveCommand = Spring.GetActiveCommand
local spGetUnitCommands = Spring.GetUnitCommands
local spGetMapDrawMode = Spring.GetMapDrawMode
local spGetUnitPosition = Spring.GetUnitPosition
local spGetSelectedUnits = Spring.GetSelectedUnits
local spSendCommands = Spring.SendCommands
local taremove = table.remove

local toggledMetal, retoggleLos
local selectedMex
local selectedUnits
local mexConstructors
local mexBuildings
local metalSpots

local metalMap = false
local controllerAreaMexWarnings = {}
local IssueAreaMex


local function setAreaMexType(uDefID)
	selectedMex = -uDefID
end

function widget:Initialize()
	metalSpots = WG['resource_spot_finder'].metalSpotsList
	metalMap = WG['resource_spot_finder'].isMetalMap
	mexBuildings = WG["resource_spot_builder"].GetMexBuildings()
	mexConstructors = WG["resource_spot_builder"].GetMexConstructors()

	WG['areamex'] = {}
	WG['areamex'].setAreaMexType = function(uDefID)
		setAreaMexType(uDefID)
	end

	WG.controllerAreaMex = WG.controllerAreaMex or {}
	WG.controllerAreaMex.issueArea = function(x, y, z, radius, opts)
		local areaParams
		local areaOptions = opts
		if type(x) == "table" then
			areaParams = x
			areaOptions = y
		else
			areaParams = { x, y, z, radius }
		end
		return IssueAreaMex(areaParams, areaOptions, "controller")
	end
end


---Gets the position of the last command in a unit's queue, or nil if the queue is empty
---@param unitID number
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
---@param constructorIds table All mex constructors
---@param buildingId number Specific mex that we want to build
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
						tX, tZ = tX+x, tZ+z
						builderCount = builderCount + 1
					end
				end
			end
		end
	end

	if builderCount == 0 then return end
	return { x = tX / builderCount, z = tZ / builderCount }
end


---Get all mex spots in an area
---@param x number
---@param z number
---@param radius number
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
local function getCmdsForValidSpots(spots, shift)
	local cmds = {}
	for i = 1, #spots do
		local spot = spots[i]
		local spotHasQueue = shift and WG["resource_spot_builder"].SpotHasExtractorQueued(spot) or false
		if not spotHasQueue then
			local pos = { spot.x, spot.y, spot.z }
			local cmd = WG['resource_spot_builder'].PreviewExtractorCommand(pos, selectedMex, spot)
			if cmd then
				cmds[#cmds + 1] = cmd
			end
		end
	end
	return cmds
end


---Nearest neighbor search. Spots are passed in to do minor weighting based on mex value
---@param cmds table
---@param spots table
---@param shift boolean Whether shift was held (appending to existing queue)
local function calculateCmdOrder(cmds, spots, shift)
	local builderPos = getAvgPositionOfValidBuilders(selectedUnits, mexConstructors, selectedMex, shift)
	if not builderPos then return end
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


local function getAreaParam(params, key, index)
	if params[key] ~= nil then
		return params[key]
	end
	return params[index]
end


local function isFiniteNumber(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end


local function warnControllerAreaMex(reason)
	if controllerAreaMexWarnings[reason] then
		return
	end
	controllerAreaMexWarnings[reason] = true
	Spring.Echo("[AreaMex] Controller Area Mex ignored: " .. reason)
end


local function validateAreaParams(areaParams, source)
	if type(areaParams) ~= "table" then
		if source == "controller" then
			warnControllerAreaMex("missing area params")
		end
		return nil, "missing area params"
	end

	local cmdX = getAreaParam(areaParams, "x", 1)
	local cmdY = getAreaParam(areaParams, "y", 2)
	local cmdZ = getAreaParam(areaParams, "z", 3)
	local cmdRadius = getAreaParam(areaParams, "radius", 4)

	if not isFiniteNumber(cmdX) or not isFiniteNumber(cmdZ) or (cmdY ~= nil and not isFiniteNumber(cmdY)) then
		if source == "controller" then
			warnControllerAreaMex("invalid area position")
		end
		return nil, "invalid area position"
	end

	if not isFiniteNumber(cmdRadius) or cmdRadius <= 0 then
		if source == "controller" then
			warnControllerAreaMex("invalid area radius")
		end
		return nil, "invalid area radius"
	end

	return cmdX, cmdY, cmdZ, cmdRadius
end


local function getOptionShift(options)
	if type(options) ~= "table" then
		return false, false
	end
	if options.shift ~= nil then
		return options.shift == true, true
	end
	for i = 1, #options do
		if options[i] == "shift" then
			return true, true
		end
	end
	return false, false
end


IssueAreaMex = function(areaParams, areaOptions, source)
	local cmdX, cmdY, cmdZ, cmdRadius = validateAreaParams(areaParams, source)
	if not cmdX then
		return false, cmdY
	end

	if type(metalSpots) ~= "table" then
		return false, "metal spots unavailable"
	end

	local resourceSpotBuilder = WG['resource_spot_builder']
	if type(resourceSpotBuilder) ~= "table"
		or type(resourceSpotBuilder.GetBestExtractorFromBuilders) ~= "function"
		or type(resourceSpotBuilder.PreviewExtractorCommand) ~= "function"
		or type(resourceSpotBuilder.SpotHasExtractorQueued) ~= "function"
		or type(resourceSpotBuilder.ApplyPreviewCmds) ~= "function"
	then
		return false, "resource spot builder unavailable"
	end
	if type(mexConstructors) ~= "table" or type(mexBuildings) ~= "table" then
		return false, "mex builder data unavailable"
	end

	if type(selectedUnits) ~= "table" and type(spGetSelectedUnits) == "function" then
		selectedUnits = spGetSelectedUnits()
	end
	if type(selectedUnits) ~= "table" or #selectedUnits <= 0 then
		return false, "no selected units"
	end

	local spots = getSpotsInArea(cmdX, cmdZ, cmdRadius)

	if not selectedMex then
		selectedMex = resourceSpotBuilder.GetBestExtractorFromBuilders(selectedUnits, mexConstructors, mexBuildings)
	end
	if not selectedMex then
		return false, "no mex builder selected"
	end

	local optionShift, hasOptionShift = getOptionShift(areaOptions)
	local _, _, _, shift = Spring.GetModKeyState()
	if source == "controller" then
		shift = hasOptionShift and optionShift or false
	end
	local cmds = getCmdsForValidSpots(spots, shift)
	local sortedCmds = calculateCmdOrder(cmds, spots, shift)

	local ok, err = pcall(resourceSpotBuilder.ApplyPreviewCmds, sortedCmds, mexConstructors, shift)

	selectedMex = nil

	if not ok then
		if source == "controller" then
			warnControllerAreaMex("failed to issue mex build orders")
		end
		return false, tostring(err)
	end

	if source ~= "controller" and not hasOptionShift then
		optionShift = shift
	end
	if not optionShift then
		if WG["gridmenu"] then WG["gridmenu"].clearCategory() end
	end
	return true
end


function widget:CommandNotify(id, params, options)
	if id ~= CMD_AREA_MEX then
		return
	end

	return IssueAreaMex(params, options, "mouse")
end


-- Adjust map view mode as needed
function widget:Update(dt)
	local _, cmd, _ = spGetActiveCommand()
	if cmd == CMD_AREA_MEX then
		if spGetMapDrawMode() ~= 'metal' then
			if Spring.GetMapDrawMode() == "los" then
				retoggleLos = true
			end
			spSendCommands('ShowMetalMap')
			toggledMetal = true
		end
	else
		if toggledMetal then
			spSendCommands('ShowStandard')
			if retoggleLos then
				Spring.SendCommands("togglelos")
				retoggleLos = nil
			end
			toggledMetal = false
		end
	end
end


function widget:Shutdown()
	if WG.controllerAreaMex then
		WG.controllerAreaMex.issueArea = nil
	end
end


function widget:SelectionChanged(sel)
	selectedUnits = sel
end


function widget:CommandsChanged()
	if not metalMap then
		if selectedUnits and #selectedUnits > 0 then
			local customCommands = widgetHandler.customCommands
			for i = 1, #selectedUnits do
				if WG['resource_spot_builder'] and WG['resource_spot_builder'].GetMexConstructors()[selectedUnits[i]] then
					customCommands[#customCommands + 1] = {
						id = CMD_AREA_MEX,
						type = CMDTYPE.ICON_AREA,
						tooltip = 'Define an area (with metal spots in it) to make metal extractors in',
						name = 'Mex',
						cursor = 'areamex',
						action = 'areamex',
					}
					return
				end
			end
		end
	end
end

