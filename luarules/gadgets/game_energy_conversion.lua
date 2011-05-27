
function gadget:GetInfo()
    return {
        name      = 'Energy Conversion',
        desc      = 'Handles converting energy to metal',
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
local alterLevelRegex = '^' .. string.char(137) .. '(%d+)$'
local mmLevelParamName = 'mmLevel'
local mmCapacityParamName = 'mmCapacity'
local mmUseParamName = 'mmUse'
local convertEfficiency = 0.02 -- 50:1
local convertCapacities = { -- Given as per-frame values, with 32 frames in a second.
        [UnitDefNames.armmakr.id]  = 1.875, [UnitDefNames.cormakr.id]  = 1.875,
        [UnitDefNames.armfmkr.id]  = 1.875, [UnitDefNames.corfmkr.id]  = 1.875,
        [UnitDefNames.armmmkr.id]  = 18.75, [UnitDefNames.cormmkr.id]  = 18.75,
        [UnitDefNames.armuwmmm.id] = 18.75, [UnitDefNames.coruwmmm.id] = 18.75,
    }

----------------------------------------------------------------
-- Vars
----------------------------------------------------------------
local teamList = {}
local teamCapacities = {}
local teamUsages = {}

----------------------------------------------------------------
-- Speedups
----------------------------------------------------------------
local min = math.min
local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spSetTeamRulesParam = Spring.SetTeamRulesParam
local spGetTeamResources = Spring.GetTeamResources
local spUseTeamResource = Spring.UseTeamResource
local spAddTeamResource = Spring.AddTeamResource
local spGetUnitHealth = Spring.GetUnitHealth

----------------------------------------------------------------
-- Functions
----------------------------------------------------------------
local function AdjustTeamCapacity(teamID, adjustment)
    local newCapacity = teamCapacities[teamID] + adjustment
    teamCapacities[teamID] = newCapacity
    spSetTeamRulesParam(teamID, mmCapacityParamName, 32 * newCapacity)
end

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------
function gadget:Initialize()
    teamList = Spring.GetTeamList()
    for i = 1, #teamList do
        local tID = teamList[i]
        teamCapacities[tID] = 0
        teamUsages[tID] = 0
        spSetTeamRulesParam(tID, mmLevelParamName, 0.75)
        spSetTeamRulesParam(tID, mmCapacityParamName, 0)
        spSetTeamRulesParam(tID, mmUseParamName, 0)
    end
end

function gadget:GameFrame(n)
    local postUsages = (n % 16 == 0)
    for i = 1, #teamList do
        local tID = teamList[i]
        local eCur, eStor = spGetTeamResources(tID, 'energy')
        local convertAmount = min(teamCapacities[tID], eCur - eStor * spGetTeamRulesParam(tID, mmLevelParamName))
        if convertAmount > 0 then
            spUseTeamResource(tID, 'energy', convertAmount)
            spAddTeamResource(tID, 'metal',  convertAmount * convertEfficiency)
            teamUsages[tID] = teamUsages[tID] + convertAmount
        end
        if postUsages then
            spSetTeamRulesParam(tID, mmUseParamName, 2 * teamUsages[tID])
            teamUsages[tID] = 0
        end
    end
end

function gadget:UnitFinished(uID, uDefID, uTeam)
    local convertCapacity = convertCapacities[uDefID]
    if convertCapacity then
        AdjustTeamCapacity(uTeam, convertCapacity)
    end
end

function gadget:UnitDestroyed(uID, uDefID, uTeam)
    local convertCapacity = convertCapacities[uDefID]
    if convertCapacity then
        local _, _, _, _, buildProg = spGetUnitHealth(uID)
        if buildProg == 1 then
            AdjustTeamCapacity(uTeam, -convertCapacity)
        end
    end
end

function gadget:UnitGiven(uID, uDefID, newTeam, oldTeam)
    local convertCapacity = convertCapacities[uDefID]
    if convertCapacity then
        local _, _, _, _, buildProg = spGetUnitHealth(uID)
        if buildProg == 1 then
            AdjustTeamCapacity(oldTeam, -convertCapacity)
            AdjustTeamCapacity(newTeam,  convertCapacity)
        end
    end
end

function gadget:RecvLuaMsg(msg, playerID)
    local newLevel = tonumber(msg:match(alterLevelRegex))
    if newLevel and newLevel >= 0 and newLevel <= 100 then
        local _, _, playerIsSpec, playerTeam = spGetPlayerInfo(playerID)
        if not playerIsSpec then
            spSetTeamRulesParam(playerTeam, mmLevelParamName, newLevel / 100)
            return true
        end
    end
end
