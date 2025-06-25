local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name 		= "Exclude walls from area attacks",
		desc 		= "Stops walls from being included in area attacks if units are present",
		date		= "April 2025",
		author		= "Slouse",
		license 	= "GNU GPL, v2 or later",
		layer 		= 1,
		enabled 	= true
	}
end

local CMD_UNIT_CANCEL_TARGET = GameCMD.UNIT_CANCEL_TARGET
local CMD_UNIT_SET_TARGET = GameCMD.UNIT_SET_TARGET
local CMD_ATTACK = CMD.ATTACK
local CMD_STOP = CMD.STOP

local excludedUnitsDefID = {}

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitNeutral = Spring.GetUnitNeutral

for id, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.objectify then
		excludedUnitsDefID[id] = true
	end
end

local function addNewCommand(newCmds, unitID, cmdOpts, cmdID)
	if #newCmds == 0 and not cmdOpts.shift then
		-- Need to clear orders if not in shift, since just sending the first one
		-- as not-shift would sometimes fail if that unit is in the end not valid
		local stopCmd = (cmdID == CMD_ATTACK) and CMD_STOP or CMD_UNIT_CANCEL_TARGET
		newCmds[1] = {stopCmd, {}, {}}
	end
	newCmds[#newCmds + 1] = {cmdID, unitID, CMD.OPT_SHIFT}
end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts)
	if (cmdID ~= CMD_UNIT_SET_TARGET and cmdID ~= CMD_ATTACK) or #cmdParams ~= 4 then
		return
	end

	local cmdX, _, cmdZ, cmdRadius = unpack(cmdParams)
	local areaUnits = Spring.GetUnitsInCylinder(cmdX, cmdZ, cmdRadius, Spring.ENEMY_UNITS)

	local newCmds = {}
	local somethingWasExcluded = false
	for i = 1, #areaUnits do
		local unitID = areaUnits[i]
		local unitDefID = spGetUnitDefID(unitID)

		if not excludedUnitsDefID[unitDefID] then
			addNewCommand(newCmds, unitID, cmdOpts, cmdID, (cmdID == CMD_ATTACK) and CMD_STOP or CMD_UNIT_CANCEL_TARGET)
		elseif not spGetUnitNeutral(unitID) then	
			addNewCommand(newCmds, unitID, cmdOpts, cmdID, (cmdID == CMD_ATTACK) and CMD_STOP or CMD_UNIT_CANCEL_TARGET)
		else
			somethingWasExcluded = true
		end
	end
	if #newCmds > 0 and somethingWasExcluded then
		Spring.GiveOrderArrayToUnitArray(Spring.GetSelectedUnits(), newCmds)
		return true
	end
end


