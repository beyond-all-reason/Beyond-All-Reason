local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Commander Selector",
		desc = "Allows for proper keybind selection of any flavour of commanders",
		author = "Hornet, with some ZK raiding",
		date = "03 June 2024",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end


-- Localized functions for performance
local tableInsert = table.insert

-- Localized Spring API for performance
local spGetMyTeamID = Spring.GetMyTeamID

local myTeamID

local commanderDefIDs = {}
local commanderDefIDsList = {}
for udid, ud in pairs(UnitDefs) do
	if ud.customParams.iscommander then
		commanderDefIDs[udid] = true
		tableInsert(commanderDefIDsList, udid)
	end
end

-- We use unitIndex as a cursor for cycling on subsequent triggers
local unitIndex = 1

local function handleSelectComm(_, _, args)
	-- Parse action args
	local focusCamera = false
	local appendSelection = false
	local includeSelected = false

	for _, arg in pairs(args) do
		arg = string.lower(arg)

		if arg == "focus" then
			focusCamera = true
		elseif arg == "append" then
			appendSelection = true
		elseif arg == "includeselected" then
			includeSelected = true
		end
	end

	local selectedUnits = {}
	if not includeSelected then
		-- Fetch the current selected units that are commanders, we dont want to
		-- select an already selected unit if includeSelected is not passed
		for unitDefID, selUnits in pairs(Spring.GetSelectedUnitsSorted()) do
			if commanderDefIDs[unitDefID] then
				for _, unitID in ipairs(selUnits) do
					selectedUnits[unitID] = true
				end
			end
		end
	end

	-- Fetch all current commander units
	local units = {}
	local teamUnits = Spring.GetTeamUnitsByDefs(myTeamID, commanderDefIDsList)
	for _, unitID in ipairs(teamUnits) do
		if not selectedUnits[unitID] then
			tableInsert(units, unitID)
		end
	end

	local unitCount = #units

	-- if all comms are already selected, any of them becomes fair game
	if unitCount == 0 then
		units = teamUnits
		unitCount = #units
	end

	-- If no comms to select, nothing to do
	if unitCount < 1 then
		return
	end

	-- We sort the units by id, so we have a stable order on which our cursor
	-- can iterate
	table.sort(units)

	-- Proceed the cursor one step, we cycle back to the start when we reach
	-- the end
	unitIndex = ((unitIndex + 1) % unitCount) + 1

	local unitID = units[unitIndex]

	Spring.SelectUnit(unitID, appendSelection)

	if focusCamera then
		local x, y, z = Spring.GetUnitPosition(unitID)
		Spring.SetCameraTarget(x, y, z)
	end

	-- Halt the action chain, subsequent actions are not triggered
	return true
end

function widget:PlayerChanged()
	myTeamID = spGetMyTeamID()
end

function widget:Shutdown()
	widgetHandler:RemoveAction("selectcomm")
end

function widget:Initialize()
	-- if no commander defids, remove this widget
	if next(commanderDefIDs) == nil then
		widgetHandler:RemoveWidget(self)
		return
	end

	myTeamID = spGetMyTeamID()

	widgetHandler:AddAction("selectcomm", handleSelectComm, nil, "p")
end
