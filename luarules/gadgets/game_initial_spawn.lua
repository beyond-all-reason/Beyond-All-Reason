
function gadget:GetInfo()
    return {
        name      = 'Initial Spawn',
        desc      = 'Handles initial spawning of units',
        author    = 'Niobium',
        version   = 'v1.0',
        date      = 'April 2011',
        license   = 'GNU GPL, v2 or later',
        layer     = 0,
        enabled   = true
    }
end

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
    return false
end

----------------------------------------------------------------
-- Config
----------------------------------------------------------------
local changeStartUnitRegex = '^\138(%d+)$'
local startUnitParamName = 'startUnit'

----------------------------------------------------------------
-- Var
----------------------------------------------------------------
local armcomDefID = UnitDefNames.armcom.id
local corcomDefID = UnitDefNames.corcom.id

local validStartUnits = {
    [armcomDefID] = true,
    [corcomDefID] = true,
}
local spawnTeams = {} -- spawnTeams[teamID] = allyID

----------------------------------------------------------------
-- Speedups
----------------------------------------------------------------
local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetTeamInfo = Spring.GetTeamInfo
local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spSetTeamRulesParam = Spring.SetTeamRulesParam
local spGetTeamStartPosition = Spring.GetTeamStartPosition
local spGetAllyTeamStartBox = Spring.GetAllyTeamStartBox
local spCreateUnit = Spring.CreateUnit
local spGetGroundHeight = Spring.GetGroundHeight

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------
function gadget:Initialize()
    local gaiaTeamID = Spring.GetGaiaTeamID()
    local teamList = Spring.GetTeamList()
    for i = 1, #teamList do
        local teamID = teamList[i]
        if teamID ~= gaiaTeamID then
            local _, _, _, _, teamSide, teamAllyID = spGetTeamInfo(teamID)
            if teamSide == 'core' then
                spSetTeamRulesParam(teamID, startUnitParamName, corcomDefID)
            else
                spSetTeamRulesParam(teamID, startUnitParamName, armcomDefID)
            end
            spawnTeams[teamID] = teamAllyID
        end
    end
end

if tonumber((Spring.GetModOptions() or {}).mo_allowfactionchange) == 1 then
    function gadget:RecvLuaMsg(msg, playerID)
        local startUnit = tonumber(msg:match(changeStartUnitRegex))
        if startUnit and validStartUnits[startUnit] then
            local _, _, playerIsSpec, playerTeam = spGetPlayerInfo(playerID)
            if not playerIsSpec then
                spSetTeamRulesParam(playerTeam, startUnitParamName, startUnit)
                return true
            end
        end
    end
end

function gadget:GameStart()
    for teamID, allyID in pairs(spawnTeams) do
        local startUnit = spGetTeamRulesParam(teamID, startUnitParamName)
        local startX, _, startZ = spGetTeamStartPosition(teamID)
        if startX <= 0 or startZ <= 0 then
            local xmin, zmin, xmax, zmax = spGetAllyTeamStartBox(allyID)
            startX = 0.5 * (xmin + xmax)
            startZ = 0.5 * (zmin + zmax)
        end
        spCreateUnit(startUnit, startX, spGetGroundHeight(startX, startZ), startZ, 0, teamID)
    end
end
