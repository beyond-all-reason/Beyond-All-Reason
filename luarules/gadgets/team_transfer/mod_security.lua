-- Mod Option: Transfer To Enemies (hidden security setting)
-- Default: false (no enemy transfers allowed)
-- Purpose: Debug/creative mode override for normal alliance restrictions

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "mod_transfer_security",
        desc      = "Security policy: prevent transfers to enemy teams",
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

-- Mod Options (read at gadget load time)
local allowEnemyTransfers = Spring.GetModOptions().allow_enemy_transfers == "true" or false
local isCheatingEnabled = Spring.IsCheatingEnabled

-- Helper functions
local AreTeamsAllied = Spring.AreTeamsAllied
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

-- Security validation functions
local function SecurityValidateUnitTransfer(unitID, unitDefID, oldTeam, newTeam, reason)
    -- Allow if cheating enabled or explicit enemy transfers allowed
    if isCheatingEnabled() or allowEnemyTransfers then
        return true
    end
    
    -- Allow AI/Gaia team transfers
    if isNonPlayerTeam[oldTeam] or isNonPlayerTeam[newTeam] then
        return true
    end
    
    -- Only allow allied transfers
    return AreTeamsAllied(oldTeam, newTeam)
end

local function SecurityValidateResourceTransfer(oldTeam, newTeam, resourceType, amount)
    -- Allow if cheating enabled or explicit enemy transfers allowed
    if isCheatingEnabled() or allowEnemyTransfers then
        return true
    end
    
    -- Allow AI/Gaia team transfers
    if isNonPlayerTeam[oldTeam] or isNonPlayerTeam[newTeam] then
        return true
    end
    
    -- Only allow allied transfers
    return AreTeamsAllied(oldTeam, newTeam)
end

-- Security transform policies for the pipeline system
local function SecurityResourceTransformPolicy(transfer)
    if transfer.blocked then return transfer end
    
    -- Apply security check
    if not SecurityValidateResourceTransfer(transfer.srcTeam, transfer.dstTeam, transfer.resourceType, transfer.amount) then
        transfer.blocked = true
        transfer.blockReason = "Security policy: Enemy transfers not allowed"
        transfer.securityViolation = true
    else
        -- Add security metadata for other policies
        transfer.securityApproved = true
        transfer.isAlliedTransfer = AreTeamsAllied(transfer.srcTeam, transfer.dstTeam)
        transfer.involvesAI = isNonPlayerTeam[transfer.srcTeam] or isNonPlayerTeam[transfer.dstTeam]
    end
    
    return transfer
end

local function SecurityUnitTransformPolicy(transfer)
    if transfer.blocked then return transfer end
    
    -- Apply security check
    if not SecurityValidateUnitTransfer(transfer.unitID, transfer.unitDefID, transfer.oldTeam, transfer.newTeam, transfer.reason) then
        transfer.blocked = true
        transfer.blockReason = "Security policy: Enemy transfers not allowed"
        transfer.securityViolation = true
    else
        -- Add security metadata for other policies
        transfer.securityApproved = true
        transfer.isAlliedTransfer = AreTeamsAllied(transfer.oldTeam, transfer.newTeam)
        transfer.involvesAI = isNonPlayerTeam[transfer.oldTeam] or isNonPlayerTeam[transfer.newTeam]
    end
    
    return transfer
end

-- Implementation: Register transform policies with TeamTransfer system
function gadget:Initialize()
    BuildNonPlayerTeamList()
    
    -- Register security policies in the transform pipeline (priority 10 - runs first for security)
    GG.TeamTransfer.RegisterResourceTransformPolicy("Security", 10, SecurityResourceTransformPolicy)
    GG.TeamTransfer.RegisterUnitTransformPolicy("Security", 10, SecurityUnitTransformPolicy)
    
    Spring.Log("TeamTransfer", LOG.INFO, "Security pipeline policies loaded - Enemy transfers: " .. (allowEnemyTransfers and "ALLOWED" or "BLOCKED"))
end
