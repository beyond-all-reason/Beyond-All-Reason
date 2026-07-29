local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Exclude walls from area attacks",
		desc = "Stops walls from being included in area attacks if units are present",
		date = "April 2025",
		author = "Slouse",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

local CMD_UNIT_CANCEL_TARGET = GameCMD.UNIT_CANCEL_TARGET
local CMD_UNIT_SET_TARGET = GameCMD.UNIT_SET_TARGET
local CMD_ATTACK = CMD.ATTACK
local CMD_STOP = CMD.STOP

local excludedUnitsDefID = {}

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitNeutral = Spring.GetUnitNeutral
local spGetSelectedUnits = Spring.GetSelectedUnits

-- Keep in sync with unit_areaattack_limiter.lua
local BATCH_LIMIT = 30

local isBombWeapon = {}
for weaponDefID, weaponDef in pairs(WeaponDefs) do
	if weaponDef.type == "AircraftBomb" then
		isBombWeapon[weaponDefID] = true
	end
end

local isBomberUnitDef = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if (unitDef.weapons and unitDef.weapons[1] and isBombWeapon[unitDef.weapons[1].weaponDef]) or string.find(unitDef.name, "armlance") or string.find(unitDef.name, "cortitan") or string.find(unitDef.name, "legatorpbomber") then
		isBomberUnitDef[unitDefID] = true
	end
end

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
		newCmds[1] = { stopCmd, {}, {} }
	end
	newCmds[#newCmds + 1] = { cmdID, unitID, CMD.OPT_SHIFT }
end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts)
	if (cmdID ~= CMD_UNIT_SET_TARGET and cmdID ~= CMD_ATTACK) or #cmdParams ~= 4 then
		return
	end

	if cmdID == CMD_ATTACK then
		-- Deterministic handoff: if limiter would kick in (non-bomber overflow),
		-- do not consume this command so LuaRules areaattack limiter can process it.
		local selectedUnits = spGetSelectedUnits()
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

	local cmdX, _, cmdZ, cmdRadius = unpack(cmdParams)
	local areaUnits = Spring.GetUnitsInCylinder(cmdX, cmdZ, cmdRadius, Spring.ENEMY_UNITS)

	local newCmds = {}
	local somethingWasExcluded = false
	for i = 1, #areaUnits do
		local unitID = areaUnits[i]
		local unitDefID = spGetUnitDefID(unitID)

		if not excludedUnitsDefID[unitDefID] then
			addNewCommand(newCmds, unitID, cmdOpts, cmdID)
		elseif not spGetUnitNeutral(unitID) then
			addNewCommand(newCmds, unitID, cmdOpts, cmdID)
		else
			somethingWasExcluded = true
		end
	end
	if #newCmds > 0 and somethingWasExcluded then
		Spring.GiveOrderArrayToUnitArray(spGetSelectedUnits(), newCmds)
		return true
	end
end
