
if not gadgetHandler:IsSyncedCode() then
	return
end


function gadget:GetInfo()
	return {
		name      = "Hound Weapon Toggle",
		desc      = "Adds a command to hounds to allow weapon switching",
		author    = "Hobo Joe",
		date      = "March 2024",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

include("luarules/configs/customcmds.h.lua")

local spInsertUnitCmdDesc  	= Spring.InsertUnitCmdDesc
local spEditUnitCmdDesc    	= Spring.EditUnitCmdDesc
local spFindUnitCmdDesc    	= Spring.FindUnitCmdDesc
local spCallCOBScript 		= Spring.CallCOBScript


local isHound = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.name == 'armfido' then
		isHound[unitDefID] = true
	end
end

local houndWeaponCmdDesc = {
	id = CMD_HOUND_WEAPON_TOGGLE,
	type = CMDTYPE.ICON_MODE,
	tooltip = 'hound_weapon_toggle_tooltip',
	name = 'hound_weapon_toggle',
	cursor = 'cursornormal',
	action = 'hound_weapon_toggle',
	params = { 1, "hound_weapon_gauss", "hound_weapon_plasma" },
}


local function setHoundWeaponState(unitID, state)
	local cmdDescID = spFindUnitCmdDesc(unitID, CMD_HOUND_WEAPON_TOGGLE)
	if cmdDescID then
		houndWeaponCmdDesc.params[1] = state
		spEditUnitCmdDesc(unitID, cmdDescID, {params = houndWeaponCmdDesc.params})
		spCallCOBScript(unitID, "SetWeaponType", 0, state)
	end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	-- accepts: CMD_HOUND_WEAPON_TOGGLE
	if isHound[unitDefID] then
		setHoundWeaponState(unitID, cmdParams[1])
		return false  -- command was used
	end
	return true  -- command was not used
end


--------------------------------------------------------------------------------
-- Unit Handling
--------------------------------------------------------------------------------

function gadget:UnitCreated(unitID, unitDefID)
	if isHound[unitDefID] then
		houndWeaponCmdDesc.params[1] = 1
		spInsertUnitCmdDesc(unitID, houndWeaponCmdDesc)
	end
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_HOUND_WEAPON_TOGGLE)
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
	end
end

--------------------------------------------------------------------------------
