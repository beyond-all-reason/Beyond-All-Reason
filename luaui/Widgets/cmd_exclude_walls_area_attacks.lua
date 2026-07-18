local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name 		= "Exclude walls from area attacks",
		desc 		= "Removes walls and neutrals from area attacks if other units are present",
		date		= "April 2025",
		author		= "Slouse",
		license 	= "GNU GPL, v2 or later",
		layer 		= 1,
		enabled 	= true
	}
end

-- Keep in sync with unit_areaattack_limiter.lua
local BATCH_LIMIT = 30

local commandAreaToUnits = {
	[CMD.ATTACK] = true,
	[GameCMD.UNIT_SET_TARGET] = true,
	[GameCMD.UNIT_SET_TARGET_NO_GROUND] = true,
}

local commandClearOrders = {
	[GameCMD.UNIT_SET_TARGET]           = CMD.CMD_UNIT_CANCEL_TARGET,
	[GameCMD.UNIT_SET_TARGET_NO_GROUND] = CMD.CMD_UNIT_CANCEL_TARGET,
}
for cmdID in pairs(commandAreaToUnits) do
	commandClearOrders[cmdID] = commandClearOrders[cmdID] or CMD.STOP
end

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitNeutral = Spring.GetUnitNeutral
local spGetSelectedUnits = Spring.GetSelectedUnits

local CMD_ATTACK = CMD.ATTACK

local excludedUnitsDefID = {}
local isBomberUnitDef = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.objectify then
		excludedUnitsDefID[unitDefID] = true
	end
	-- Matching with unit_areaattack_limiter:
	if (unitDef.weapons and unitDef.weapons[1] and WeaponDefs[unitDef.weapons[1].weaponDef].type == "AircraftBomb")
		or string.find(unitDef.name, "armlance")
		or string.find(unitDef.name, "cortitan")
		or string.find(unitDef.name, "legatorpbomber") then
		isBomberUnitDef[unitDefID] = true
	end
end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts)
	if not commandAreaToUnits[cmdID] or #cmdParams ~= 4 then
		return
	end

	local selectedUnits = spGetSelectedUnits()

	if cmdID == CMD_ATTACK then
		-- Deterministic handoff: if limiter would kick in (non-bomber overflow),
		-- do not consume this command so LuaRules areaattack limiter can process it.
		local nonBomberCount = 0
		for i = 1, #selectedUnits do
			local unitDefID = spGetUnitDefID(selectedUnits[i])
			if not (unitDefID and isBomberUnitDef[unitDefID]) then
				nonBomberCount = nonBomberCount + 1
				if nonBomberCount > BATCH_LIMIT then
					return false
				end
			end
		end
	end

	local append = cmdOpts.shift
	local cmdX, _, cmdZ, cmdRadius = unpack(cmdParams)
	local areaUnits = Spring.GetUnitsInCylinder(cmdX, cmdZ, cmdRadius, Spring.ENEMY_UNITS)

	local excludeTargets = false
	local includeTargets = false
	-- Need to clear orders if not in shift, since just sending the first one
	-- as not-shift would sometimes fail if that unit is in the end not valid
	local newCommands = append and {{ commandClearOrders[cmdID], unitID, 0 }} or {}
	local count = #newCommands
	for i = 1, #areaUnits do
		local unitID = areaUnits[i]
		local unitDefID = spGetUnitDefID(unitID)
		if excludedUnitsDefID[unitDefID] or spGetUnitNeutral(unitID) then
			excludeTargets = true
		else
			includeTargets = true
			count = count + 1
			newCommands[count] = { cmdID, unitID, cmdOpts }
		end
	end

	if excludeTargets and includeTargets then
		cmdOpts.shift = true
		Spring.GiveOrderArrayToUnitArray(selectedUnits, newCommands)
		return true
	else
		return false
	end
end
