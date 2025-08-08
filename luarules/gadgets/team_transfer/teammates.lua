local TeamTransfer = VFS.Include("LuaRules/Gadgets/team_transfer/definitions.lua")
local Units = VFS.Include("LuaRules/Gadgets/team_transfer/units.lua")
local Resources = VFS.Include("LuaRules/Gadgets/team_transfer/resources.lua")

local Teammates = {}

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
function Teammates.CanTakeFrom(fromTeam, toTeam)
    if not Spring.AreTeamsAllied(fromTeam, toTeam) then
        return false, "Can only take from allied teams"
    end
    
    for _, pid in ipairs(Spring.GetPlayerList()) do
        local _, _, _, teamID, _, _, isAI = Spring.GetPlayerInfo(pid)
        if teamID == fromTeam and (type(isAI) ~= 'boolean' or isAI == false) then
            return false, "Team has human players"
        end
    end
    
    return true
end

function Teammates.CanCaptureFrom(fromTeam, toTeam)
    if Spring.AreTeamsAllied(fromTeam, toTeam) then
        return false, "Cannot capture from allied teams"
    end
    return true
end

function Teammates.CanGiveTo(fromTeam, toTeam)
    if not TeamTransfer.config.allowUnitSharing then
        return false, "Unit sharing is disabled"
    end
    
    if not TeamTransfer.config.allowEnemyUnitSharing and not Spring.AreTeamsAllied(fromTeam, toTeam) then
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

-- Target resolution for different command types
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

return Teammates
