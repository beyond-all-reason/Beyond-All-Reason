-- OUTLINE:
-- Passive cons build either at their full speed or not at all.
-- The amount of res expense for non-passive cons is calculated (as total expense - passive cons expense) and the remainder is available to the passive cons, if any.
-- We cycle through the passive cons and allocate this expense until it runs out. All other passive cons have their buildspeed set to 0.

-- ACTUALLY:
-- We only do the check every x frames (controlled by interval) and only allow passive con(s) to act if doing so allows them to sustain their expense
--   until the next check, based on current expense allocations.
-- We allow the interval to be different for each team, because normally it would be wasteful to reconfigure every frame, but if a team has a high income and low 
--   storage then not doing the check every frame would result in excessing resources that passive builders could have used
-- We also pick one passive con, per build target, and allow it a tiny build speed for 1 frame per interval, to prevent nanoframes that only have passive cons 
--   building them from decaying if a prolonged stall occurs.
-- We cache the buildspeeds of all passive cons to prevent constant use of get/set callouts.

-- REASON:
-- AllowUnitBuildStep is damn expensive and is a serious perf hit if it is used for all this.

function gadget:GetInfo()
    return {
        name      = 'Passive Builders v3',
        desc      = 'Builders marked as passive only use resources after others builder have taken their share',
        author    = 'BD, Bluestone',
        date      = 'Why is date even relevant',
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
-- Var
----------------------------------------------------------------
local CMD_PASSIVE = 34571

local stallMarginInc = 0.2
local stallMarginSto = 0.01

local canPassive = {} -- canPassive[unitDefID] = nil / true

local passiveCons = {} -- passiveCons[teamID][builderID]
local teamStalling = {} -- teamStalling[teamID] = {resName = res leftover after non-passive cons took their share}

local buildTargets = {} --the unitIDs of build targets of passive builders
local buildTargetOwners = {} --each build target has one passive builder that doesn't turn fully off, to stop the building decaying

local canBuild = {} --builders[teamID][builderID], contains all builders
local realBuildSpeed = {} --build speed of builderID, as in UnitDefs (contains all builders)
local currentBuildSpeed = {} --build speed of builderID for current interval, not accounting for buildOwners special speed (contains only passive builders)

local cost = {} -- cost[unitDefID] = {metal=value,energy=value} 
local costID = {} -- costID[unitID] (contains all units)

local ruleName = "passiveBuilders"

local resTable = {"metal","energy"}

local cmdPassiveDesc = {
      id      = CMD_PASSIVE,
      name    = 'passive',
      action  = 'passive',
      type    = CMDTYPE.ICON_MODE,
      tooltip = 'Building Mode: Passive wont build when stalling',
      params  = {0, 'Active', 'Passive'}
}

----------------------------------------------------------------
-- Speedups
----------------------------------------------------------------
local spInsertUnitCmdDesc = Spring.InsertUnitCmdDesc
local spFindUnitCmdDesc = Spring.FindUnitCmdDesc
local spGetUnitCmdDescs = Spring.GetUnitCmdDescs
local spEditUnitCmdDesc = Spring.EditUnitCmdDesc
local spGetTeamResources = Spring.GetTeamResources
local spGetTeamList = Spring.GetTeamList
local spSetUnitRulesParam = Spring.SetUnitRulesParam
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetUnitIsBuilding = Spring.GetUnitIsBuilding
local spGetUnitCurrentBuildPower = Spring.GetUnitCurrentBuildPower
local spGetUnitDefID = Spring.GetUnitDefID
local spSetUnitBuildSpeed = Spring.SetUnitBuildSpeed
local spGetUnitIsBuilding = Spring.GetUnitIsBuilding
local spValidUnitID = Spring.ValidUnitID
local simSpeed = Game.gameSpeed

local min = math.min
local max = math.max
local floor = math.floor

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------
function gadget:Initialize()
    -- build the list of which unitdef can have passive mode
    for unitDefID, uDef in pairs(UnitDefs) do
        canPassive[unitDefID] = ((uDef.canAssist and uDef.buildSpeed > 0) or #uDef.buildOptions > 0)
        cost[unitDefID] = {}
        cost[unitDefID].buildTime = uDef.buildTime
        for _,resName in pairs(resTable) do
            cost[unitDefID][resName] = uDef[resName .. "Cost"]
        end
    end
    
    for _,unitID in pairs(Spring.GetAllUnits()) do
        gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
    end
end

function gadget:UnitCreated(unitID, unitDefID, teamID)
    if UnitDefs[unitDefID].buildSpeed>0 or canPassive[unitDefID] then
        canBuild[teamID] = canBuild[teamID] or {}
        canBuild[teamID][unitID] = true
        realBuildSpeed[unitID] = UnitDefs[unitDefID].buildSpeed or 0
    end    
    if canPassive[unitDefID] then
        spInsertUnitCmdDesc(unitID, cmdPassiveDesc)
        passiveCons[teamID] = passiveCons[teamID] or {}
        passiveCons[teamID][unitID] = spGetUnitRulesParam(unitID,ruleName) == 1 or nil
        currentBuildSpeed[unitID] = realBuildSpeed[unitID]
        spSetUnitBuildSpeed(unitID, currentBuildSpeed[unitID]) -- to handle luarules reloads correctly
    end
    
    costID[unitID] = cost[unitDefID]
end

function gadget:UnitGiven(unitID, unitDefID, newTeamID, oldTeamID)
    if passiveCons[oldTeamID] and passiveCons[oldTeamID][unitID] then
        passiveCons[newTeamID] = passiveCons[newTeamID] or {}
        passiveCons[newTeamID][unitID] = passiveCons[oldTeamID][unitID]
        passiveCons[oldTeamID][unitID] = nil
    end
    
    if canBuild[oldTeamID] and canBuild[oldTeamID][unitID] then
        canBuild[newTeamID] = canBuild[newTeamID] or {}
        canBuild[newTeamID][unitID] = true
        canBuild[oldTeamID][unitID] = nil
    end
end

function gadget:UnitTaken(unitID, unitDefID, oldTeamID, newTeamID)
    gadget:UnitGiven(unitID, unitDefID, newTeamID, oldTeamID)
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID)
    canBuild[teamID] = canBuild[teamID] or {}
    canBuild[teamID][unitID] = nil

    passiveCons[teamID] = passiveCons[teamID] or {}    
    passiveCons[teamID][unitID] = nil
    realBuildSpeed[unitID] = nil
    currentBuildSpeed[unitID] = nil
    buildTargetOwners[unitID] = nil
    
    costID[unitID] = nil
end


function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, synced)
    -- track which cons are set to passive
    if cmdID == CMD_PASSIVE and canPassive[unitDefID] then
        local cmdIdx = spFindUnitCmdDesc(unitID, CMD_PASSIVE)
        local cmdDesc = spGetUnitCmdDescs(unitID, cmdIdx, cmdIdx)[1]
        cmdDesc.params[1] = cmdParams[1]
        spEditUnitCmdDesc(unitID, cmdIdx, cmdDesc)
        spSetUnitRulesParam(unitID,ruleName,cmdParams[1])
        passiveCons[teamID] = passiveCons[teamID] or {}
        if cmdParams[1] == 1 then --
            passiveCons[teamID][unitID] = true
        else
            spSetUnitBuildSpeed(unitID, realBuildSpeed[unitID])
            currentBuildSpeed[unitID] = realBuildSpeed[unitID]
            passiveCons[teamID][unitID] = nil        
        end
        return false -- Allowing command causes command queue to be lost if command is unshifted
    end
    return true
end

local updateFrame = {}

function gadget:GameFrame(n)
    -- see (*) below
    for builderID,builtUnit in pairs(buildTargetOwners) do
        if spValidUnitID(builderID) and spGetUnitIsBuilding(builderID)==builtUnit then
            spSetUnitBuildSpeed(builderID, currentBuildSpeed[builderID])
        end
        buildTargetOwners[builderID] = nil
        buildTargets[builtUnit] = nil
    end  

    buildTargets = {}
    for _,teamID in pairs(spGetTeamList()) do
        if n==updateFrame[teamID] then
            local interval = GetUpdateInterval(teamID)
            UpdatePassiveBuilders(teamID, interval)
            updateFrame[teamID] = n + interval
        elseif not updateFrame[teamID] or updateFrame[teamID] < n then
            updateFrame[teamID] = n + GetUpdateInterval(teamID)        
        end
    end
end

function GetUpdateInterval(teamID)
    local maxInterval = 1
    for _,resName in pairs(resTable) do
        local cur, stor, pull, inc, exp, share, sent, rec, exc = spGetTeamResources(teamID, resName)
        local resMaxInterval
        if inc>0 then
            resMaxInterval = floor(stor*simSpeed/inc)+1 -- how many frames would it take to fill our current storage based on current income?
        else
            resMaxInterval = 6
        end
        maxInterval = max(maxInterval, resMaxInterval)
    end
    maxInterval = min(6, maxInterval)
    --Spring.Echo("interval: "..maxInterval)
    return maxInterval
end

function UpdatePassiveBuilders(teamID, interval)
    --calculate how much expense each passive con would require, and how much total expense the non-passive cons require
    local nonPassiveConsTotalExpense = {}
    local passiveConsExpense = {}
    for builderID in pairs(canBuild[teamID] or {}) do
        local builtUnit = spGetUnitIsBuilding(builderID)
        local targetCosts = builtUnit and costID[builtUnit] or nil
        if builtUnit and targetCosts then
            local rate = realBuildSpeed[builderID]/targetCosts.buildTime
            for _,resName in pairs(resTable) do
                local expense = targetCosts[resName]*rate
                passiveCons[teamID] = passiveCons[teamID] or {}
                if passiveCons[teamID][builderID] then
                    passiveConsExpense[builderID] = passiveConsExpense[builderID] or {}
                    passiveConsExpense[builderID][resName] = expense
                    if not buildTargets[builtUnit] then -- see (*) below
                        buildTargetOwners[builderID] = builtUnit
                        buildTargets[builtUnit] = true
                    end
                else
                    nonPassiveConsTotalExpense[resName] = (nonPassiveConsTotalExpense[resName] or 0) + expense 
                end
            end
        end
    end
    
    --calculate how much expense passive cons will be allowed
    teamStalling[teamID] = {}    
    for _,resName in pairs(resTable) do
        local cur, stor, pull, inc, exp, share, sent, rec, exc = spGetTeamResources(teamID, resName)
        stor = stor * share -- consider capacity only up to the share slider
        local reservedExpense = nonPassiveConsTotalExpense[resName] or 0 -- we don't want to touch this part of expense
        teamStalling[teamID][resName] = cur - max(inc*stallMarginInc,stor*stallMarginSto) - 1 + (interval)*(inc-reservedExpense+rec-sent)/simSpeed --amount of res available to assign to passive builders (in next interval); leave a tiny bit left over to avoid engines own "stall mode"
        --Spring.Echo(resName, cur, min(inc*stallMarginInc,stor*stallMarginSto)+1, (interval)*(inc+rec-sent-reservedExpense)/simSpeed, wouldStall)
    end
    
    --work through passive cons allocating as much expense as we have left
    for builderID in pairs(passiveCons[teamID] or {}) do
        -- find out if we have used up all the expense available to passive builders yet
        local newPulls = {}
        local wouldStall = false
        if not wouldStall and passiveConsExpense[builderID] then
            for resName,allocatedExp in pairs(teamStalling[teamID]) do
                newPulls[resName] = allocatedExp - (interval)*passiveConsExpense[builderID][resName]/simSpeed
                if newPulls[resName] <= 0 then
                    wouldStall = true
                end
            end
        end
        
        -- record that use these resources
        if not wouldStall then
            teamStalling[teamID] = newPulls
        end
        --Spring.Echo("stall: "..(wouldStall and "true" or "false"))
        
        --turn this passive builder on/off as appropriate
        local wantedBuildSpeed = (wouldStall or not passiveConsExpense[builderID]) and 0 or realBuildSpeed[builderID]
        if currentBuildSpeed[builderID] ~= wantedBuildSpeed then
            spSetUnitBuildSpeed(builderID, wantedBuildSpeed) 
            currentBuildSpeed[builderID] = wantedBuildSpeed
        end
        
        --override buildTargetOwners build speeds for a single frame; let them build at a tiny rate to prevent nanoframes from possibly decaying        
        if buildTargetOwners[builderID] and currentBuildSpeed[builderID] == 0 then
            spSetUnitBuildSpeed(builderID, 0.001) --(*)
        end
        
    end
end