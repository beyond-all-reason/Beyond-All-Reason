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

function gadget:AllowCommand(unitID, unitDefID, issuerTeamID, cmdID, cmdParams, cmdOptions)
    if cmdID == CMD_GUARD then
        local targetUnitID = cmdParams[1]
        local targetAllyTeamID = spGetUnitAllyTeam(targetUnitID)
        if spAreTeamsAllied(issuerTeamID, targetAllyTeamID) then
            return true
        else
            return false
        end
    end
    return true
end
