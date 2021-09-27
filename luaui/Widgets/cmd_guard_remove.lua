
function widget:GetInfo()
	return {
		name      = "Guard Remove",
		desc      = "Removes non-terminating orders when they seem to have been used accidentally.",
		author    = "Google Frog",
		date      = "13 July 2017",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

include("keysym.h.lua")
VFS.Include("LuaRules/Configs/customcmds.h.lua")

--------------------------------------------------------------------------------
-- Epic Menu Options
--------------------------------------------------------------------------------

options_path = 'Settings/Unit Behaviour'
options = {
	keepTarget = {
		name = "Shift removes constructor guard",
		type = "bool",
		value = true,
		desc = "Removes non-terminating commands (guard and patrol) from constructor command queues when they have a command added to their queue.",
		noHotkey = true,
	},
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local doCommandRemove = false

local removableCommand = {
	[CMD.GUARD] = true,
	[CMD.PATROL] = true,
	--[CMD_ORBIT] = true,
	--[CMD_AREA_GUARD] = true,
}

local function IsValidUnit(unitID)
	local unitDefID = Spring.GetUnitDefID(unitID)
	return unitDefID and UnitDefs[unitDefID] and UnitDefs[unitDefID].isBuilder
end

function widget:CommandNotify(id, params, cmdOptions)
	if not doCommandRemove then
		return false
	end
	
	if not cmdOptions.shift then
		doCommandRemove = false
		return false
	end
	
	local units = Spring.GetSelectedUnits()
	for i = 1, #units do
		local unitID = units[i]
		if IsValidUnit(unitID) then
			local cmd = Spring.GetCommandQueue(unitID, -1)
			if cmd then
				for c = 1, #cmd do
					if removableCommand[cmd[c].id] then
						Spring.GiveOrderToUnit(unitID, CMD.REMOVE, {cmd[c].tag}, 0)
					end
				end
			end
		end
	end
	
	doCommandRemove = false
	return false
end

function widget:KeyPress(key, modifier, isRepeat)
	if not isRepeat and (key == KEYSYMS.LSHIFT or key == KEYSYMS.RSHIFT) then
		doCommandRemove = true
	end
end
