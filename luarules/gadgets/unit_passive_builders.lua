-- OUTLINE:
-- Passive cons build either at their full speed or not at all.
-- The amount of res expense for non-passive cons is calculated (as total expense - passive cons expensive) and the remainder is available to the passive cons, if any.
-- We cycle through the passive cons and allocate this expense until it runs out. All other passive cons have their buildspeed set to 0.

-- ACTUALLY:
-- We only do the check every x frames (controlled by interval) and only allow passive con(s) to act if doing so allows them to sustain their expense
--   until the next check, based on current expense allocations.
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
local stallMarginSto = 0.025

local canPassive = {} -- canPassive[unitDefID] = nil / true
local cost = {} -- cost[unitDefID] = {metal=value,energy=value}
local costID = {}
local teamStalling = {} -- teamStalling[teamID] = {resName=leftover}
local passiveCons = {}

local realBuildSpeed = {} --build speed of unitID
local currentBuildSpeed = {} --build speed of unitID for current interval, not account for the special frame on which build target owners are allowed to build at a tiny rate

local interval = 6 -- recalc once every this many frames
local buildTargets = {} --the unitIDs of build targets
local buildTargetOwners = {} --each build target has one passive builder that doesn't turn fully off, to stop the building decaying

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
	if canPassive[unitDefID] then
		spInsertUnitCmdDesc(unitID, cmdPassiveDesc)
        passiveCons[teamID] = passiveCons[teamID] or {}
        passiveCons[teamID][unitID] = spGetUnitRulesParam(unitID,ruleName) == 1 or nil
        realBuildSpeed[unitID] = UnitDefs[unitDefID].buildSpeed or 0
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
end

function gadget:UnitTaken(unitID, unitDefID, oldTeamID, newTeamID)
	gadget:UnitGiven(unitID, unitDefID, newTeamID, oldTeamID)
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID)
	costID[unitID] = nil
    passiveCons[teamID] = passiveCons[teamID] or {}    
	passiveCons[teamID][unitID] = nil
    realBuildSpeed[unitID] = nil
    currentBuildSpeed[unitID] = nil
    buildTargetOwners[unitID] = nil
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

function gadget:GameFrame(n)
    if n%interval==1 then
        --see (*) below
        for builderID,builtUnit in pairs(buildTargetOwners) do
            if not spValidUnitID(builderID) or not spGetUnitIsBuilding(builderID)==builtUnit then
                buildTargetOwners[builderID] = nil
                buildTargets[builtUnit] = nil
            else
                spSetUnitBuildSpeed(builderID, currentBuildSpeed[builderID])
            end
        end
    end

    if n%interval~=0 then return end
    
    buildTargets = {}
	for _,teamID in pairs(spGetTeamList()) do
		--calculate how much expense passive cons would require
		local passiveConsTotalExpense = {}
        local passiveConsExpense = {}
		for builderID in pairs(passiveCons[teamID] or {}) do
			passiveConsExpense[builderID] = {}
            local builtUnit = spGetUnitIsBuilding(builderID)
            local targetCosts = builtUnit and costID[builtUnit] or nil
			if builtUnit and targetCosts then
                local rate = realBuildSpeed[builderID]/targetCosts.buildTime
				for _,resName in pairs(resTable) do
					passiveConsTotalExpense[resName] = (passiveConsTotalExpense[resName] or 0 ) + targetCosts[resName]*rate
                    passiveConsExpense[builderID][resName] = targetCosts[resName]*rate
                end
                if not buildTargets[builtUnit] then
                    buildTargetOwners[builderID] = builtUnit
                    buildTargets[builtUnit] = true
                end
            else
				for _,resName in pairs(resTable) do
                    passiveConsExpense[builderID][resName] = 0
                end            
			end
		end
        
        --calculate how much pull passive cons will be allowed
		teamStalling[teamID] = {}
		for _,resName in pairs(resTable) do
			local cur, stor, pull, inc, exp, share, sent, rec, exc = spGetTeamResources(teamID, resName)
			stor = stor * share -- consider capacity only up to the share slider
			local reservedExpense = exp - (passiveConsTotalExpense[resName] or 0) -- we don't want to touch this part of expense
			teamStalling[teamID][resName] = cur - min(inc*stallMarginInc,stor*stallMarginSto) - 1 - (interval)*(inc+rec-sent-reservedExpense)/simSpeed --amount of res available to assign to passive builders (in current sim frame); leave a tiny bit left over to avoid engines own "stall mode"
        end
        
        --work through passive cons allocating as much expense as we have left
        local wouldStall = false
        for builderID in pairs(passiveCons[teamID] or {}) do
            -- find out if we have used up all the expense available to passive builders yet
            local newPulls = {}
            if not wouldStall and passiveConsExpense[builderID] then
                for resName,allocatedPull in pairs(teamStalling[teamID]) do
                    newPulls[resName] = allocatedPull - passiveConsExpense[builderID][resName]
                    if newPulls[resName] <= 0 then
                        wouldStall = true
                    end
                end
            end
            
            --turn this passive builder on/off as appropriate
            if wouldStall then
                if currentBuildSpeed[builderID] ~= 0 then
                    spSetUnitBuildSpeed(builderID, 0) 
                    currentBuildSpeed[builderID] = 0
                end
            else
                teamStalling[teamID] = newPulls
                if currentBuildSpeed[builderID] <= 0.01 then
                    spSetUnitBuildSpeed(builderID, realBuildSpeed[builderID])
                    currentBuildSpeed[builderID] = realBuildSpeed[builderID]
                end
            end    
            
            --override buildTargetOwners build speeds for a single frame; let them build at a tiny rate to prevent nanoframes from possibly decaying        
            if buildTargetOwners[builderID] then
                spSetUnitBuildSpeed(builderID, 0.001) --(*)
            end
            
            --Spring.Echo(currentBuildSpeed[builderID])
        end
	end
end
