local TeamTransfer = VFS.Include("LuaRules/Gadgets/team_transfer/definitions.lua")

local Units = {}

local function logInfo(msg) Spring.Log("TeamTransfer", LOG.INFO, msg) end
local function logWarn(msg) Spring.Log("TeamTransfer", LOG.WARNING, msg) end

function Units.ChangeTeamWithReason(unitID, oldTeam, newTeam, reason)
    if reason == TeamTransfer.REASON.TAKEN then
        return Units.HandleTake(unitID, oldTeam, newTeam)
    elseif reason == TeamTransfer.REASON.SOLD then
        return Units.HandleSold(unitID, oldTeam, newTeam)
    elseif reason == TeamTransfer.REASON.CAPTURED then
        return Units.HandleCaptured(unitID, oldTeam, newTeam)
    elseif reason == TeamTransfer.REASON.GIVEN then
        return Units.HandleGiven(unitID, oldTeam, newTeam)
    elseif reason == TeamTransfer.REASON.SCAVENGED then
        return Units.HandleScavenged(unitID, oldTeam, newTeam)
    elseif reason == TeamTransfer.REASON.UPGRADED then
        return Units.HandleUpgraded(unitID, oldTeam, newTeam)
    elseif reason == TeamTransfer.REASON.RECLAIMED then
        return Units.HandleReclaimed(unitID, oldTeam, newTeam)
    elseif reason == TeamTransfer.REASON.DECORATION then
        return Units.HandleDecoration(unitID, oldTeam, newTeam)
    elseif reason == TeamTransfer.REASON.IDLE_PLAYER_TAKEOVER then
        return Units.HandleIdleTakeover(unitID, oldTeam, newTeam)
    elseif reason == TeamTransfer.REASON.DEV_TRANSFER then
        logInfo("Dev transfer: Unit " .. unitID .. " from team " .. oldTeam .. " to team " .. newTeam)
        return true
    end
    logWarn("Unknown transfer reason: " .. tostring(reason))
    return true
end

function Units.HandleTake(unitID, oldTeam, newTeam)
    local oldAllyTeam = select(4, Spring.GetTeamInfo(oldTeam))
    local newAllyTeam = select(4, Spring.GetTeamInfo(newTeam))
    if oldAllyTeam ~= newAllyTeam then
        logWarn("Take blocked: Can only take from allied teams")
        return false
    end
    for _, pid in ipairs(Spring.GetPlayerList()) do
        local _, _, _, teamID, _, _, isAI = Spring.GetPlayerInfo(pid)
        if teamID == oldTeam and (type(isAI) ~= 'boolean' or isAI == false) then
            logWarn("Take blocked: Team " .. oldTeam .. " has human players")
            return false
        end
    end
    logInfo("Take transfer: Unit " .. unitID .. " from team " .. oldTeam .. " to team " .. newTeam)
    return true
end

function Units.HandleSold(unitID, oldTeam, newTeam)
    if not Spring.ValidUnitID(unitID) then return false end
    if not Spring.AreTeamsAllied(oldTeam, newTeam) then
        logWarn("Market transfer blocked: Teams not allied")
        return false
    end
    logInfo("Market transfer: Unit " .. unitID .. " sold from team " .. oldTeam .. " to team " .. newTeam)
    return true
end

function Units.HandleCaptured(unitID, oldTeam, newTeam)
    local oldAllyTeam = select(4, Spring.GetTeamInfo(oldTeam))
    local newAllyTeam = select(4, Spring.GetTeamInfo(newTeam))
    if oldAllyTeam == newAllyTeam then
        logWarn("Capture blocked: Cannot capture from allied teams")
        return false
    end
    logInfo("Capture transfer: Unit " .. unitID .. " captured from enemy team " .. oldTeam .. " to team " .. newTeam)
    return true
end

function Units.HandleGiven(unitID, oldTeam, newTeam)
    if Spring.IsTeamFull and Spring.IsTeamFull(newTeam) then
        logWarn("Given transfer blocked: Team " .. newTeam .. " is at unit capacity")
        return false
    end
    logInfo("Given transfer: Unit " .. unitID .. " shared from team " .. oldTeam .. " to team " .. newTeam)
    return true
end

function Units.HandleScavenged(unitID, oldTeam, newTeam)
    if Spring.ValidUnitID(unitID) then
        Spring.SetUnitHealth(unitID, {capture = 0.95})
        local maxHealth = Spring.GetUnitMaxHealth(unitID)
        Spring.SetUnitHealth(unitID, {health = maxHealth})
        logInfo("Scavenger transfer: Unit " .. unitID .. " captured from team " .. oldTeam .. " to team " .. newTeam)
    end
    return true
end

function Units.HandleUpgraded(unitID, oldTeam, newTeam)
    _G.transferredUnits = _G.transferredUnits or {}
    _G.transferredUnits[unitID] = Spring.GetGameFrame()
    logInfo("Upgrade transfer: Unit " .. unitID .. " ownership from team " .. oldTeam .. " to team " .. newTeam)
    return true
end

function Units.HandleReclaimed(unitID, oldTeam, newTeam)
    logInfo("Reclaimed transfer: Unit " .. unitID .. " reclaimed from team " .. oldTeam .. " to team " .. newTeam)
    return true
end

function Units.HandleDecoration(unitID, oldTeam, newTeam)
    logInfo("Decoration transfer: Unit " .. unitID .. " from team " .. oldTeam .. " to team " .. newTeam)
    return true
end

function Units.HandleIdleTakeover(unitID, oldTeam, newTeam)
    local oldAllyTeam = select(4, Spring.GetTeamInfo(oldTeam))
    local newAllyTeam = select(4, Spring.GetTeamInfo(newTeam))
    if oldAllyTeam ~= newAllyTeam then
        logWarn("Idle takeover blocked: Can only take from allied teams")
        return false
    end
    for _, pid in ipairs(Spring.GetPlayerList()) do
        local _, active, _, teamID, _, _, isAI = Spring.GetPlayerInfo(pid)
        if teamID == oldTeam and (type(isAI) ~= 'boolean' or isAI == false) and active then
            logWarn("Idle takeover blocked: Team " .. oldTeam .. " has active human players")
            return false
        end
    end
    logInfo("Idle player takeover: Unit " .. unitID .. " from team " .. oldTeam .. " to team " .. newTeam)
    return true
end

return Units