local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "team_transfer_security",
        desc      = "Security policies for team transfers (no sharing to enemies)",
        author    = "TheFatController",
        date      = "19 Jan 2008",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return
end

local AreTeamsAllied = Spring.AreTeamsAllied
local IsCheatingEnabled = Spring.IsCheatingEnabled

local isNonPlayerTeam = { [Spring.GetGaiaTeamID()] = true }

local function BuildNonPlayerTeamList()
    local teams = Spring.GetTeamList()
    for i=1,#teams do
        local _,_,_,isAiTeam = Spring.GetTeamInfo(teams[i],false)
        local isLuaAI = (Spring.GetTeamLuaAI(teams[i]) ~= nil)
        if isAiTeam or isLuaAI then
            isNonPlayerTeam[teams[i]] = true
        end
    end
end

function gadget:Initialize()
    BuildNonPlayerTeamList()

    -- Security policy: No sharing to enemies (unless cheating enabled)
    GG.TeamTransfer.RegisterResourceValidator("NoShareToEnemy", function(oldTeam, newTeam, resourceType, amount)
        if isNonPlayerTeam[oldTeam] or AreTeamsAllied(newTeam, oldTeam) or IsCheatingEnabled() then
            return true
        end
        return false
    end)

    -- Security policy: No unit transfers to enemies (unless cheating enabled)
    GG.TeamTransfer.RegisterUnitValidator("NoUnitTransferToEnemy", function(unitID, unitDefID, oldTeam, newTeam, reason)
        if isNonPlayerTeam[oldTeam] or AreTeamsAllied(newTeam, oldTeam) or IsCheatingEnabled() then
            return true
        end
        return false
    end)
end
