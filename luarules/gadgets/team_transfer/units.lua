

local Units = {}
-- Default built-in validator (permissive). Real rules are registered via RegisterValidator.
function Units.AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, reason)
    return true
end
-- Core transfer orchestrator for units
function Units.TransferUnit(unitID, newTeam, reason)
    local oldTeam = Spring.GetUnitTeam(unitID)
    if not oldTeam or oldTeam == newTeam then return true end

    local unitDefID = Spring.GetUnitDefID(unitID)
    if not unitDefID then return false end

    -- Use global API (will be injected by gadget)
    local ok = GG.TeamTransfer.ValidateUnitTransfer(unitID, unitDefID, oldTeam, newTeam, reason)
    if not ok then return false end

    local success = Spring.TransferUnitWithReason(unitID, newTeam, reason)
    if success then GG.TeamTransfer.NotifyUnitTransfer(unitID, unitDefID, oldTeam, newTeam, reason) end
    return success
end




local function logInfo(msg) Spring.Log("TeamTransfer", LOG.INFO, msg) end
local function logWarn(msg) Spring.Log("TeamTransfer", LOG.WARNING, msg) end

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



return Units