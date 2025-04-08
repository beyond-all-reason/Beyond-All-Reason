-- OUTLINE:
-- Low priority cons build either at their full speed or not at all.
-- The amount of res expense for high prio cons is calculated (as total expense - low prio cons expense) and the remainder is available to the low prio cons, if any.
-- We cycle through the low prio cons and allocate this expense until it runs out. All other low prio cons have their buildspeed set to 0.

-- ACTUALLY:
-- We only do the check every x frames (controlled by interval) and only allow low prio con(s) to act if doing so allows them to sustain their expense
--   until the next check, based on current expense allocations.
-- We allow the interval to be different for each team, because normally it would be wasteful to reconfigure every frame, but if a team has a high income and low
--   storage then not doing the check every frame would result in excessing resources that low prio builders could have used
-- We also pick one low prio con, per build target, and allow it a tiny build speed for 1 frame per interval, to prevent nanoframes that only have low prio cons
--   building them from decaying if a prolonged stall occurs.
-- We cache the buildspeeds of all low prio cons to prevent constant use of get/set callouts.

-- REASON:
-- AllowUnitBuildStep is damn expensive and is a serious perf hit if it is used for all this.

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = 'Builder Priority', 	-- this once was named: Passive Builders v3
        desc      = 'Builders marked as low priority only use resources after others builder have taken their share',
        author    = 'BrainDamage, Bluestone',
		version   = '1.01',
        date      = '2024',
        license   = 'GNU GPL, v2 or later',
        layer     = 0,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return
end

-- These values are supposedly engine-backed:
local stallMarginInc = 0.20
local stallMarginSto = 0.01

local passiveCons = {} -- passiveCons[teamID][builderID]

local buildTargets = {} --the unitIDs of build targets of passive builders
local buildTargetOwners = {} --each build target has one passive builder that doesn't turn fully off, to stop the building decaying

local canBuild = {} --builders[teamID][builderID], contains all builders
local realBuildSpeed = {} --build speed of builderID, as in UnitDefs (contains all builders)
local currentBuildSpeed = {} --build speed of builderID for current interval, not accounting for buildOwners special speed (contains only passive builders)

local costID = {} -- costID[unitID] (contains all non-finished units)

local ruleName = "builderPriority"

-- Translate between array-style and hash-style resource tables.
local resources = { "metal", "energy" } -- ipairs-able
resources["metal"] = 1 -- reverse-able
resources["energy"] = 2

VFS.Include('luarules/configs/customcmds.h.lua')
local CMD_PRIORITY = CMD_PRIORITY
local cmdPassiveDesc = {
      id      = CMD_PRIORITY,
      name    = 'priority',
      action  = 'priority',
      type    = CMDTYPE.ICON_MODE,
      tooltip = 'Builder Mode: Low Priority restricts build when stalling on resources',
      params  = {1, 'Low Prio', 'High Prio'}
}

local spInsertUnitCmdDesc = Spring.InsertUnitCmdDesc
local spFindUnitCmdDesc = Spring.FindUnitCmdDesc
local spGetUnitCmdDescs = Spring.GetUnitCmdDescs
local spEditUnitCmdDesc = Spring.EditUnitCmdDesc
local spGetTeamResources = Spring.GetTeamResources
local spGetTeamList = Spring.GetTeamList
local spSetUnitRulesParam = Spring.SetUnitRulesParam
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spSetUnitBuildSpeed = Spring.SetUnitBuildSpeed
local spGetUnitIsBuilding = Spring.GetUnitIsBuilding
local spValidUnitID = Spring.ValidUnitID
local spGetTeamInfo = Spring.GetTeamInfo
local spGetUnitTeam = Spring.GetUnitTeam
local simSpeed = Game.gameSpeed

local max = math.max
local floor = math.floor

local updateFrame = {}

local teamList
local deadTeamList = {}
local unitBuildSpeed = {}
local canPassive = {} -- canPassive[unitDefID] = nil / true
local cost = {} -- cost[unitDefID] = { metal, energy, buildTime }
local suspendBuilderPriority

for unitDefID, unitDef in pairs(UnitDefs) do
	-- All builders can have their build speeds changed via lua
    if unitDef.buildSpeed > 0 then
        unitBuildSpeed[unitDefID] = unitDef.buildSpeed
    end
    -- Units that can only repair, ressurrect, or capture don't have a passive mode (in this gadget)
	local prioritizes = ((unitDef.canAssist and unitDef.buildSpeed > 0) or #unitDef.buildOptions > 0)
    canPassive[unitDefID] = prioritizes and true or nil
	-- Minor speedup for determining total resource drain per frame/interval
	cost[unitDefID] = { unitDef.metalCost, unitDef.energyCost, unitDef.buildTime }
end

local function updateTeamList()
	teamList = spGetTeamList()
end

local isTeamSavingMetal = function(_) return false end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_PRIORITY)
	updateTeamList()
	
	for _, teamID in ipairs(teamList) do
		-- Distribute initial update frames. They will drift on their own afterward.
		local gameFrame = Spring.GetGameFrame()
		if not updateFrame[teamID] then
			updateFrame[teamID] = gameFrame + (teamID % 6)
		end
		-- Reset team tracking for constructors and their build priority settings.
		canBuild[teamID] = canBuild[teamID] or {}
		passiveCons[teamID] = passiveCons[teamID] or {}
		Spring.SetTeamRulesParam(teamID, "suspendbuilderpriority", 0)
	end

	for _,unitID in pairs(Spring.GetAllUnits()) do
        gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID), spGetUnitTeam(unitID))
		if currentBuildSpeed[unitID] then
			spSetUnitBuildSpeed(unitID, currentBuildSpeed[unitID]) -- needed for luarules reloads
		end
    end

	-- huge apologies for intruding on this gadget, but players have requested ability to put everything on hold to buy t2 as soon as possible (Unit Market)
	if (Spring.GetModOptions().unit_market) then
		isTeamSavingMetal = function(teamID)
			local isAiTeam = select(4,spGetTeamInfo(teamID))
			if not isAiTeam then
				return (GG.isTeamSaving and GG.isTeamSaving(teamID)) or false
			end
			return false
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, teamID)
	-- Units use their full build speed, by default.
    if unitBuildSpeed[unitDefID] then
        canBuild[teamID][unitID] = true
        realBuildSpeed[unitID] = unitBuildSpeed[unitDefID] or 0

		-- Only units that can build other units can use passive build priority.
		if canPassive[unitDefID] then
			spInsertUnitCmdDesc(unitID, cmdPassiveDesc)
			passiveCons[teamID][unitID] = (spGetUnitRulesParam(unitID, ruleName) == 1) or nil
			currentBuildSpeed[unitID] = realBuildSpeed[unitID]
		end
    end

    costID[unitID] = cost[unitDefID]
end

function gadget:UnitFinished(unitID, unitDefID, teamID, builderID)
    buildTargetOwners[unitID] = nil
	costID[unitID] = nil
end

function gadget:UnitGiven(unitID, unitDefID, newTeamID, oldTeamID)
    if passiveCons[oldTeamID] and passiveCons[oldTeamID][unitID] then
        passiveCons[newTeamID][unitID] = passiveCons[oldTeamID][unitID]
        passiveCons[oldTeamID][unitID] = nil
    end

    if canBuild[oldTeamID] and canBuild[oldTeamID][unitID] then
        canBuild[newTeamID][unitID] = true
        canBuild[oldTeamID][unitID] = nil
    end
end

function gadget:UnitTaken(unitID, unitDefID, oldTeamID, newTeamID)
    gadget:UnitGiven(unitID, unitDefID, newTeamID, oldTeamID)
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID)
    canBuild[teamID][unitID] = nil

    passiveCons[teamID][unitID] = nil
    realBuildSpeed[unitID] = nil
    currentBuildSpeed[unitID] = nil
    buildTargetOwners[unitID] = nil

    costID[unitID] = nil
end


function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
    -- accepts CMD_PRIORITY
    -- track which cons are set to passive
    if canPassive[unitDefID] then
        local cmdIdx = spFindUnitCmdDesc(unitID, CMD_PRIORITY)
        if cmdIdx and suspendBuilderPriority == 0 then
            local cmdDesc = spGetUnitCmdDescs(unitID, cmdIdx, cmdIdx)[1]
            cmdDesc.params[1] = cmdParams[1]
            spEditUnitCmdDesc(unitID, cmdIdx, cmdDesc)
            spSetUnitRulesParam(unitID,ruleName,cmdParams[1])
			if cmdParams[1] == 0 then --
				passiveCons[teamID][unitID] = true
			elseif realBuildSpeed[unitID] then
				spSetUnitBuildSpeed(unitID, realBuildSpeed[unitID])
				currentBuildSpeed[unitID] = realBuildSpeed[unitID]
				passiveCons[teamID][unitID] = nil
			end
        end
        return false -- Allowing command causes command queue to be lost if command is unshifted
    end
    return true
end

local function UpdatePassiveBuilders(teamID, interval)
	-- calculate how much expense each passive con would require
	-- and how much total expense the non-passive cons require
	local nonPassiveConsTotalExpenseEnergy = 0
	local nonPassiveConsTotalExpenseMetal = 0
	local passiveConsExpense = {}
	local passiveTeamCons = passiveCons[teamID]
	suspendBuilderPriority = Spring.GetTeamRulesParam(teamID, "suspendbuilderpriority")

	for builderID in pairs(canBuild[teamID]) do
		local builtUnit = spGetUnitIsBuilding(builderID)
		local targetCosts = (builtUnit and costID[builtUnit]) or nil
		if builtUnit and targetCosts then
			local mcost, ecost = targetCosts[1], targetCosts[2]
			local rate = realBuildSpeed[builderID] / targetCosts[3]
			-- Add an exception for basic metal converters, which each cost 1 metal.
			-- Don't stall over something so small and that may be needed to recover.
			mcost = mcost <= 1 and 0 or mcost * rate
			ecost = ecost * rate
			if passiveTeamCons[builderID] then
				passiveConsExpense[builderID] = { mcost, ecost }
				if not buildTargets[builtUnit] then
					buildTargets[builtUnit] = true
					buildTargetOwners[builderID] = builtUnit
				end
			else
				nonPassiveConsTotalExpenseMetal = nonPassiveConsTotalExpenseMetal + mcost
				nonPassiveConsTotalExpenseEnergy = nonPassiveConsTotalExpenseEnergy + ecost
			end
		end
	end

	-- calculate how much expense passive cons will be allowed
	local teamStallingEnergy, teamStallingMetal
	local cur, stor, inc, share, sent, rec, _

	cur, stor, _, inc, _, share, sent, rec = spGetTeamResources(teamID, "metal")
	-- consider capacity only up to the share slider
	stor = stor * share
	-- amount of res available to assign to passive builders (in next interval)
	-- leave a tiny bit left over to avoid engines own "stall mode"
	teamStallingMetal = cur - max(inc*stallMarginInc, stor*stallMarginSto) - 1 + (interval)*(nonPassiveConsTotalExpenseMetal+inc+rec-sent)/simSpeed

	cur, stor, _, inc, _, share, sent, rec = spGetTeamResources(teamID, "energy")
	stor = stor * share
	teamStallingEnergy = cur - max(inc*stallMarginInc, stor*stallMarginSto) - 1 + (interval)*(nonPassiveConsTotalExpenseEnergy+inc+rec-sent)/simSpeed

	-- work through passive cons allocating as much expense as we have left
	for builderID in pairs(passiveTeamCons) do
		-- find out if we have used up all the expense available to passive builders yet
		local wouldStall = false
		local conExpense = passiveConsExpense[builderID]
		if conExpense then
			local passivePullMetal = conExpense[1] * (interval / simSpeed)
			local passivePullEnergy = conExpense[2] * (interval / simSpeed)
			local newPullMetal = teamStallingMetal - passivePullMetal
			local newPullEnergy = teamStallingEnergy - passivePullEnergy
			if passivePullMetal > 0 or passivePullEnergy > 0 then
				-- Stalling in one resource stalls in the other (if both resource types are used)
				if (newPullMetal <= 0 and passivePullMetal > 0) or (newPullEnergy <= 0 and passivePullEnergy > 0) then
					wouldStall = true
				else
					teamStallingMetal = newPullMetal
					teamStallingEnergy = newPullEnergy
				end
			end
		end

		-- turn this passive builder on/off as appropriate
		local wantedBuildSpeed = wouldStall and 0 or realBuildSpeed[builderID]
		if currentBuildSpeed[builderID] ~= wantedBuildSpeed and suspendBuilderPriority == 0 then
			spSetUnitBuildSpeed(builderID, wantedBuildSpeed)
			currentBuildSpeed[builderID] = wantedBuildSpeed
		end

		-- override buildTargetOwners build speeds for a single frame;
		-- let them build at a tiny rate to prevent nanoframes from possibly decaying
		if (buildTargetOwners[builderID] and currentBuildSpeed[builderID] == 0 and suspendBuilderPriority == 0) then
			spSetUnitBuildSpeed(builderID, 0.001) --(*)
		end
	end
end


local function GetUpdateInterval(teamID)
	local maxInterval = 1
	for _, resName in ipairs(resources) do
		local _, stor, _, inc = spGetTeamResources(teamID, resName)
		local resMaxInterval
		if inc > 0 then
			resMaxInterval = floor(stor*simSpeed/inc)+1 -- how many frames would it take to fill our current storage based on current income?
		else
			resMaxInterval = 6
		end
		if resMaxInterval > maxInterval then
			maxInterval = resMaxInterval
		end
	end
	if maxInterval > 6 then maxInterval = 6 end
	return maxInterval
end

function gadget:GameFrame(n)
    for builderID, builtUnit in pairs(buildTargetOwners) do
        if spValidUnitID(builderID) and spGetUnitIsBuilding(builderID) == builtUnit then
			local teamID = spGetUnitTeam(builderID)
			suspendBuilderPriority = Spring.GetTeamRulesParam (teamID, "suspendbuilderpriority")
			if not isTeamSavingMetal(teamID) and suspendBuilderPriority == 0 then
            	spSetUnitBuildSpeed(builderID, currentBuildSpeed[builderID])
			end
        end
    end
	buildTargetOwners = {}
    buildTargets = {}

	for i=1, #teamList do
		local teamID = teamList[i]
		if not deadTeamList[teamID] and not isTeamSavingMetal(teamID) then
			if n >= updateFrame[teamID] then
				local interval = GetUpdateInterval(teamID)
				UpdatePassiveBuilders(teamID, interval)
				updateFrame[teamID] = n + interval
			end
		end
    end
end

function gadget:TeamDied(teamID)
	deadTeamList[teamID] = true
end

function gadget:TeamChanged(teamID)
	updateTeamList()
end
