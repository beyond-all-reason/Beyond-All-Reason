local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name 		= "Exclude walls from area set target",
		desc 		= "Stops walls from being included in area set target if units are present",
		date		= "April 2025",
		author		= "Slouse",
		license 	= "GNU GPL, v2 or later",
		layer 		= 0,
		enabled 	= true
	}
end

local excludedUnitsDefID = {}
local newCmds
local somethingWasExcluded

local CMD_SET_TARGET = 34923

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitNeutral = Spring.GetUnitNeutral

for id, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.objectify then
		excludedUnitsDefID[id] = true
	end
end

local function addNewCommand(unitID, cmdOpts)
	local newCmdOpts = 0
	if #newCmds ~= 0 or cmdOpts.shift then
		newCmdOpts = CMD.OPT_SHIFT
	end
	newCmds[#newCmds + 1] = {CMD_SET_TARGET, unitID, newCmdOpts}
end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts)
	if cmdID ~= CMD_SET_TARGET or #cmdParams ~= 4 then
		return
	end

	local cmdX, cmdY, cmdZ, cmdRadius = unpack(cmdParams)
	local areaUnits = Spring.GetUnitsInCylinder(cmdX, cmdZ, cmdRadius)

	newCmds = {}
	somethingWasExcluded = false
	for i = 1, #areaUnits do
		local unitID = areaUnits[i]
		local unitDefID = spGetUnitDefID(unitID)

		if not excludedUnitsDefID[unitDefID] then
			addNewCommand(unitID, cmdOpts)
		else
			if not spGetUnitNeutral(unitID) then
				addNewCommand(unitID, cmdOpts)
			else
				somethingWasExcluded = true
			end
		end
	end

	if #newCmds > 0 and somethingWasExcluded then
		Spring.GiveOrderArrayToUnitArray(Spring.GetSelectedUnits(), newCmds)
		return true
	end
end


