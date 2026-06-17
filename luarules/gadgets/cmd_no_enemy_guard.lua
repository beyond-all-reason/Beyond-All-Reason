local gadget = gadget ---@type Gadget

local CMD_GUARD = CMD.GUARD
local spAreTeamsAllied = Spring.AreTeamsAllied
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam

function gadget:GetInfo()
  return {
	name 	= "No Enemy Guard",
	desc	= "Block 'CMD_GUARD' command for enemy units",
	author	= "uBdead",
	date	= "May 2026",
	license	= "GNU GPL, v2 or later",
	layer	= 0,
	enabled = true,
  }
end

if not gadgetHandler:IsSyncedCode() then
    return false
end

function gadget:Initialize()
   gadgetHandler:RegisterAllowCommand(CMD_GUARD) 
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions)
    local targetUnitID = cmdParams[1]
    if not targetUnitID then
        return true -- No target unit, allow the command
    end

    local targetAllyTeamID = spGetUnitAllyTeam(targetUnitID)

    if targetAllyTeamID == nil then
        return true -- Target unit doesn't exist, allow the command
    end

    return spAreTeamsAllied(unitTeam, targetAllyTeamID)
end
