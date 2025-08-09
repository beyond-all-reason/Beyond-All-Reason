
local Units = VFS.Include("LuaRules/Gadgets/team_transfer/units.lua")
local Resources = VFS.Include("LuaRules/Gadgets/team_transfer/resources.lua")

local Teammates = {}

-- Cache expensive lookups (updated only when needed)
local cachedSharingTax = nil
local allianceCache = {}  -- Cache team alliance status

local function GetSharingTax()
    if cachedSharingTax == nil then
        cachedSharingTax = Spring.GetModOptions().tax_resource_sharing_amount or 0
    end
    return cachedSharingTax
end

local function AreTeamsAllied(teamA, teamB)
    -- Use cached alliance status to avoid expensive C++ calls
    local cacheKey = teamA * 1000 + teamB  -- Simple hash for team pair
    if allianceCache[cacheKey] == nil then
        allianceCache[cacheKey] = Spring.AreTeamsAllied(teamA, teamB)
    end
    return allianceCache[cacheKey]
end

-- Allow external refresh of cached values (e.g., if alliances or mod options change)
function Teammates.RefreshCaches()
    cachedSharingTax = nil
    allianceCache = {}
end

-- For backward compatibility
function Teammates.RefreshSharingTax()
    Teammates.RefreshCaches()
end

-- High-level team-to-team transfer operations
function Teammates.TakeFromTeam(playerData, targetTeam)
    local unitsTransferred = 0
    local units = Spring.GetTeamUnits(targetTeam)
    
    for _, unitID in ipairs(units) do
        local udid = Spring.GetUnitDefID(unitID)
        if udid and TeamTransfer.ValidateTransfer(unitID, udid, targetTeam, playerData.teamID, TeamTransfer.REASON.TAKEN) then
            if Spring.TransferUnitWithReason(unitID, playerData.teamID, TeamTransfer.REASON.TAKEN) then
                unitsTransferred = unitsTransferred + 1
            end
        end
    end
    
    -- Transfer resources too
    Resources.GiveEverythingTo(targetTeam, playerData.teamID)
    
    return unitsTransferred
end

function Teammates.CaptureFromTeam(playerData, targetTeam)
    local unitsTransferred = 0
    local units = Spring.GetTeamUnits(targetTeam)
    
    for _, unitID in ipairs(units) do
        local udid = Spring.GetUnitDefID(unitID)
        if udid and TeamTransfer.ValidateTransfer(unitID, udid, targetTeam, playerData.teamID, TeamTransfer.REASON.CAPTURED) then
            if Spring.TransferUnitWithReason(unitID, playerData.teamID, TeamTransfer.REASON.CAPTURED) then
                unitsTransferred = unitsTransferred + 1
            end
        end
    end
    
    -- Capture includes resource seizure
    Resources.GiveEverythingTo(targetTeam, playerData.teamID)
    
    return unitsTransferred
end

function Teammates.GiveToTeam(playerData, targetTeam, selectedUnits)
    local unitsTransferred = 0
    local units = selectedUnits or Spring.GetTeamUnits(playerData.teamID)
    
    for _, unitID in ipairs(units) do
        local udid = Spring.GetUnitDefID(unitID)
        if udid and Spring.GetUnitTeam(unitID) == playerData.teamID then
            if TeamTransfer.ValidateTransfer(unitID, udid, playerData.teamID, targetTeam, TeamTransfer.REASON.GIVEN) then
                if Spring.TransferUnitWithReason(unitID, targetTeam, TeamTransfer.REASON.GIVEN) then
                    unitsTransferred = unitsTransferred + 1
                end
            end
        end
    end
    
    return unitsTransferred
end

-- Team relationship validation
function Teammates.TeamHasActiveHumanPlayers(teamID)
    for _, pid in ipairs(Spring.GetPlayerList()) do
        local _, active, _, playerTeamID, _, _, isAI = Spring.GetPlayerInfo(pid)
        if playerTeamID == teamID and (type(isAI) ~= 'boolean' or isAI == false) and active then
            return true
        end
    end
    return false
end

function Teammates.CanTakeFrom(fromTeam, toTeam)
    if not Spring.AreTeamsAllied(fromTeam, toTeam) then
        return false, "Can only take from allied teams"
    end
    if Teammates.TeamHasActiveHumanPlayers(fromTeam) then
        return false, "Team has active human players"
    end
    return true
end

function Teammates.HandleIdleTakeover(unitID, oldTeam, newTeam)
    local canTake, reason = Teammates.CanTakeFrom(oldTeam, newTeam)
    if not canTake then
        Spring.Log("TeamTransfer", LOG.WARNING, "Idle takeover blocked: " .. reason)
        return false
    end
    Spring.Log("TeamTransfer", LOG.INFO, "Idle player takeover: Unit " .. unitID .. " from team " .. oldTeam .. " to team " .. newTeam)
    return true
end

function Teammates.CanCaptureFrom(fromTeam, toTeam)
    if Spring.AreTeamsAllied(fromTeam, toTeam) then
        return false, "Cannot capture from allied teams"
    end
    return true
end

function Teammates.CanGiveTo(fromTeam, toTeam)
    -- Only allow transfers between allied teams
    if not Spring.AreTeamsAllied(fromTeam, toTeam) then
        return false, "Cannot give to enemy teams"
    end
    
    return true
end

-- Player data resolution helper
function Teammates.GetPlayerData(playerID)
    local actualPlayerID = -1
    local playerData = {}
    if playerID == 0 then
        for _, pid in ipairs(Spring.GetPlayerList()) do
            local name, active, spec, teamID, allyTeamID, income, isAI = Spring.GetPlayerInfo(pid)
            if type(isAI) ~= 'boolean' or isAI == false then
                actualPlayerID = pid
                playerData = { playerID = pid, teamID = teamID, allyTeamID = allyTeamID, name = name }
                break
            end
        end
    else
        actualPlayerID = playerID
        local name, active, spec, teamID, allyTeamID = Spring.GetPlayerInfo(playerID)
        playerData = { playerID = playerID, teamID = teamID, allyTeamID = allyTeamID, name = name }
    end
    return actualPlayerID ~= -1 and playerData or nil
end

function Teammates.GetTargetTeams(playerData, targetParam, selectionType)
    local targetTeams = {}
    local targetTeamID = (targetParam and targetParam ~= "") and tonumber(targetParam) or nil
    
    if selectionType == "specify_team" then
        if targetTeamID and Spring.GetTeamInfo(targetTeamID) then 
            table.insert(targetTeams, targetTeamID) 
        end
    elseif selectionType == "auto_idle_teams" then
        local teamList = targetTeamID and {targetTeamID} or Spring.GetTeamList(playerData.allyTeamID)
        for _, teamID in ipairs(teamList) do 
            if teamID ~= playerData.teamID then 
                table.insert(targetTeams, teamID) 
            end 
        end
    elseif selectionType == "specify_team_or_all_enemies" then
        if targetTeamID then
            if Spring.GetTeamInfo(targetTeamID) and not Spring.AreTeamsAllied(playerData.teamID, targetTeamID) then 
                table.insert(targetTeams, targetTeamID) 
            end
        else
            for _, teamID in ipairs(Spring.GetTeamList()) do 
                if teamID ~= playerData.teamID and not Spring.AreTeamsAllied(playerData.teamID, teamID) then 
                    table.insert(targetTeams, teamID) 
                end 
            end
        end
    end
    
    return targetTeams
end

function Teammates.TeamAutoShare(fromTeam, toTeam, energyAmount, metalAmount, 
                                targetEnergyStorage, targetMetalStorage,
                                targetEnergyCurrent, targetMetalCurrent, 
                                targetEnergyShare, targetMetalShare)
    
    -- Use teammate relationship validation (includes alliance check)
    local canShare, reason = Teammates.CanGiveTo(fromTeam, toTeam)
    if not canShare then
        -- Block the transfer by doing nothing
        return
    end
    
    local sharingTax = GetSharingTax()
    
    if energyAmount > 0 then
        local maxReceive = math.max(0, (targetEnergyStorage * targetEnergyShare) - targetEnergyCurrent)
        local taxedAmount = math.min(energyAmount * (1 - sharingTax), maxReceive)
        if taxedAmount > 0 then
            Spring.ShareTeamResource(fromTeam, toTeam, "energy", taxedAmount / (1 - sharingTax))
        end
    end
    
    if metalAmount > 0 then
        local maxReceive = math.max(0, (targetMetalStorage * targetMetalShare) - targetMetalCurrent)
        local taxedAmount = math.min(metalAmount * (1 - sharingTax), maxReceive)
        if taxedAmount > 0 then
            Spring.ShareTeamResource(fromTeam, toTeam, "metal", taxedAmount / (1 - sharingTax))
        end
    end
end

return Teammates
