local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Area Mex",
		desc = "Adds a command to cap mexes in an area.",
		author = "Hobo Joe, Google Frog, NTG, Chojin , Doo, Floris, Tarte",
		date = "Oct 23, 2010, (last update: March 3, 2022)",
		license = "GNU GPL, v2 or later",
		handler = true,
		layer = 1,
		enabled = true
	}
end

VFS.Include("luarules/configs/customcmds.h.lua")

local spGetActiveCommand = Spring.GetActiveCommand
local spGetMapDrawMode = Spring.GetMapDrawMode
local spGetUnitPosition = Spring.GetUnitPosition
local spSendCommands = Spring.SendCommands
local taremove = table.remove

local toggledMetal, retoggleLos
local selectedMex
local selectedUnits
local mexConstructors
local mexBuildings
local metalSpots

local metalMap = false


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
end


---Finds all builders among selected units that can make the specified building, and gets their average position
---@param units table selected units
---@param constructorIds table All mex constructors
---@param buildingId number Specific mex that we want to build
---@return table { x, z }
local function getAvgPositionOfValidBuilders(units, constructorIds, buildingId)
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
					local x, _, z = spGetUnitPosition(id)
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
local function calculateCmdOrder(cmds, spots)
	local builderPos = getAvgPositionOfValidBuilders(selectedUnits, mexConstructors, selectedMex)
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


function widget:CommandNotify(id, params, options)
	if id ~= CMD_AREA_MEX then
		return
	end

	local cmdX, _, cmdZ, cmdRadius = params[1], params[2], params[3], params[4]
	local spots = getSpotsInArea(cmdX, cmdZ, cmdRadius)

	if not selectedMex then
		selectedMex = WG['resource_spot_builder'].GetBestExtractorFromBuilders(selectedUnits, mexConstructors, mexBuildings)
	end

	local alt, ctrl, meta, shift = Spring.GetModKeyState()
	local cmds = getCmdsForValidSpots(spots, shift)
	local sortedCmds = calculateCmdOrder(cmds, spots)


	WG['resource_spot_builder'].ApplyPreviewCmds(sortedCmds, mexConstructors, shift)

	selectedMex = nil

	if not options.shift then
		if WG["gridmenu"] then WG["gridmenu"].clearCategory() end
	end
	return true
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

