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
local passiveConsCount = {} -- passiveConsCount[teamID] = number of passive builders

local buildTargets = {} --the unitIDs of build targets of passive builders
local buildTargetOwnersByTeam = {} -- buildTargetOwnersByTeam[teamID] = {[builderID] = builtUnit}

local canBuild = {} --builders[teamID][builderID], contains all builders
local realBuildSpeed = {} --build speed of builderID, as in UnitDefs (contains all builders)
local currentBuildSpeed = {} --build speed of builderID for current interval, not accounting for buildOwners special speed (contains only passive builders)

local costID = {} -- costID[unitID] (contains all non-finished units)

local ruleName = "builderPriority"

-- Translate between array-style and hash-style resource tables.
local resources = { "metal", "energy" } -- ipairs-able
resources["metal"] = 1 -- reverse-able
resources["energy"] = 2

local CMD_PRIORITY = GameCMD.PRIORITY
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
local spGetUnitTeam = Spring.GetUnitTeam
local spGetAllUnits = Spring.GetAllUnits
local spGetUnitDefID = Spring.GetUnitDefID
local simSpeed = Game.gameSpeed

local mathMax = math.max
local mathFloor = math.floor

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

	for i = 1, #teamList do
		local teamID = teamList[i]
		-- Distribute initial update frames. They will drift on their own afterward.
		local gameFrame = Spring.GetGameFrame()
		if not updateFrame[teamID] then
			updateFrame[teamID] = gameFrame + (teamID % 6)
		end
		-- Reset team tracking for constructors and their build priority settings.
		canBuild[teamID] = canBuild[teamID] or {}
		passiveCons[teamID] = passiveCons[teamID] or {}
		passiveConsCount[teamID] = passiveConsCount[teamID] or 0
		buildTargetOwnersByTeam[teamID] = buildTargetOwnersByTeam[teamID] or {}
		Spring.SetTeamRulesParam(teamID, "suspendbuilderpriority", 0)
	end

	local allUnits = spGetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
        gadget:UnitCreated(unitID, spGetUnitDefID(unitID), spGetUnitTeam(unitID))
		if currentBuildSpeed[unitID] then
			spSetUnitBuildSpeed(unitID, currentBuildSpeed[unitID]) -- needed for luarules reloads
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
			local isPassive = (spGetUnitRulesParam(unitID, ruleName) == 1)
			if isPassive then
				passiveCons[teamID][unitID] = true
				passiveConsCount[teamID] = (passiveConsCount[teamID] or 0) + 1
			end
			currentBuildSpeed[unitID] = realBuildSpeed[unitID]
		end
    end

    costID[unitID] = cost[unitDefID]
end

function gadget:UnitFinished(unitID, unitDefID, teamID, builderID)
	costID[unitID] = nil
end

function gadget:UnitGiven(unitID, unitDefID, newTeamID, oldTeamID)
    if passiveCons[oldTeamID] and passiveCons[oldTeamID][unitID] then
        passiveCons[newTeamID][unitID] = passiveCons[oldTeamID][unitID]
        passiveCons[oldTeamID][unitID] = nil
		passiveConsCount[oldTeamID] = (passiveConsCount[oldTeamID] or 1) - 1
		passiveConsCount[newTeamID] = (passiveConsCount[newTeamID] or 0) + 1
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

    if passiveCons[teamID][unitID] then
		passiveCons[teamID][unitID] = nil
		passiveConsCount[teamID] = passiveConsCount[teamID] - 1
	end
    realBuildSpeed[unitID] = nil
    currentBuildSpeed[unitID] = nil

    costID[unitID] = nil
end


function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
    -- accepts CMD_PRIORITY
    -- track which cons are set to passive
    if canPassive[unitDefID] then
        local cmdIdx = spFindUnitCmdDesc(unitID, CMD_PRIORITY)
        local suspend = Spring.GetTeamRulesParam(teamID, "suspendbuilderpriority") or 0
        if cmdIdx and suspend == 0 then
            local cmdDesc = spGetUnitCmdDescs(unitID, cmdIdx, cmdIdx)[1]
            cmdDesc.params[1] = cmdParams[1]
            spEditUnitCmdDesc(unitID, cmdIdx, cmdDesc)
            spSetUnitRulesParam(unitID,ruleName,cmdParams[1])
			if cmdParams[1] == 0 then
				if not passiveCons[teamID][unitID] then
					passiveCons[teamID][unitID] = true
					passiveConsCount[teamID] = (passiveConsCount[teamID] or 0) + 1
				end
			elseif realBuildSpeed[unitID] then
				spSetUnitBuildSpeed(unitID, realBuildSpeed[unitID])
				currentBuildSpeed[unitID] = realBuildSpeed[unitID]
				if passiveCons[teamID][unitID] then
					passiveCons[teamID][unitID] = nil
					passiveConsCount[teamID] = passiveConsCount[teamID] - 1
				end
			end
        end
        return false -- Allowing command causes command queue to be lost if command is unshifted
    end
    return true
end

local function UpdatePassiveBuilders(teamID, interval)
	-- Early exit if no passive builders for this team
	if not passiveConsCount[teamID] or passiveConsCount[teamID] == 0 then
		return
	end

	local passiveTeamCons = passiveCons[teamID]
	suspendBuilderPriority = Spring.GetTeamRulesParam(teamID, "suspendbuilderpriority")

	if suspendBuilderPriority ~= 0 then
		return
	end

	-- calculate how much expense each passive con would require
	-- and how much total expense the non-passive cons require
	local nonPassiveConsTotalExpenseEnergy = 0
	local nonPassiveConsTotalExpenseMetal = 0
	local passiveConsExpense = {}
	local teamBuildTargetOwners = buildTargetOwnersByTeam[teamID]

	-- Clear previous team's build target owners
	for k in pairs(teamBuildTargetOwners) do
		teamBuildTargetOwners[k] = nil
	end

	-- First pass: only check passive builders that are building
	for builderID in pairs(passiveTeamCons) do
		local builtUnit = spGetUnitIsBuilding(builderID)
		if builtUnit then
			local targetCosts = costID[builtUnit]
			if targetCosts then
				local mcost, ecost = targetCosts[1], targetCosts[2]
				local rate = realBuildSpeed[builderID] / targetCosts[3]
				-- Add an exception for basic metal converters, which each cost 1 metal.
				-- Don't stall over something so small and that may be needed to recover.
				mcost = mcost <= 1 and 0 or mcost * rate
				ecost = ecost * rate
				passiveConsExpense[builderID] = { mcost, ecost }
				if not buildTargets[builtUnit] then
					buildTargets[builtUnit] = true
					teamBuildTargetOwners[builderID] = builtUnit
				end
			end
		end
	end

	-- Second pass: check non-passive builders ONLY if we have passive builders
	if next(passiveConsExpense) then
		local teamBuilders = canBuild[teamID]
		for builderID in pairs(teamBuilders) do
			if not passiveTeamCons[builderID] then
				local builtUnit = spGetUnitIsBuilding(builderID)
				if builtUnit then
					local targetCosts = costID[builtUnit]
					if targetCosts then
						local mcost, ecost = targetCosts[1], targetCosts[2]
						local rate = realBuildSpeed[builderID] / targetCosts[3]
						mcost = mcost <= 1 and 0 or mcost * rate
						ecost = ecost * rate
						nonPassiveConsTotalExpenseMetal = nonPassiveConsTotalExpenseMetal + mcost
						nonPassiveConsTotalExpenseEnergy = nonPassiveConsTotalExpenseEnergy + ecost
					end
				end
			end
		end
	end

	-- calculate how much expense passive cons will be allowed
	local cur, stor, inc, share, sent, rec
	local intervalOverSpeed = interval / simSpeed

	cur, stor, _, inc, _, share, sent, rec = spGetTeamResources(teamID, "metal")
	stor = stor * share
	local teamStallingMetal = cur - mathMax(inc*stallMarginInc, stor*stallMarginSto) - 1 + (interval)*(nonPassiveConsTotalExpenseMetal+inc+rec-sent)/simSpeed

	cur, stor, _, inc, _, share, sent, rec = spGetTeamResources(teamID, "energy")
	stor = stor * share
	local teamStallingEnergy = cur - mathMax(inc*stallMarginInc, stor*stallMarginSto) - 1 + (interval)*(nonPassiveConsTotalExpenseEnergy+inc+rec-sent)/simSpeed

	-- work through passive cons allocating as much expense as we have left
	for builderID in pairs(passiveTeamCons) do
		local conExpense = passiveConsExpense[builderID]
		local wouldStall = false

		if conExpense then
			local passivePullMetal = conExpense[1] * intervalOverSpeed
			local passivePullEnergy = conExpense[2] * intervalOverSpeed
			if passivePullMetal > 0 or passivePullEnergy > 0 then
				-- Stalling in one resource stalls in the other (if both resource types are used)
				if (teamStallingMetal - passivePullMetal <= 0 and passivePullMetal > 0) or
				   (teamStallingEnergy - passivePullEnergy <= 0 and passivePullEnergy > 0) then
					wouldStall = true
				else
					teamStallingMetal = teamStallingMetal - passivePullMetal
					teamStallingEnergy = teamStallingEnergy - passivePullEnergy
				end
			end
		end

		-- turn this passive builder on/off as appropriate
		local wantedBuildSpeed = wouldStall and 0 or realBuildSpeed[builderID]
		local currentSpeed = currentBuildSpeed[builderID]
		if currentSpeed ~= wantedBuildSpeed then
			spSetUnitBuildSpeed(builderID, wantedBuildSpeed)
			currentBuildSpeed[builderID] = wantedBuildSpeed
		end

		-- override buildTargetOwners build speeds for a single frame;
		-- let them build at a tiny rate to prevent nanoframes from possibly decaying
		if teamBuildTargetOwners[builderID] and currentSpeed == 0 then
			spSetUnitBuildSpeed(builderID, 0.001)
		end
	end
end


local function GetUpdateInterval(teamID)
	local maxInterval = 1
	for i = 1, #resources do
		local resName = resources[i]
		local _, stor, _, inc = spGetTeamResources(teamID, resName)
		local resMaxInterval
		if inc > 0 then
			resMaxInterval = mathFloor(stor*simSpeed/inc)+1 -- how many frames would it take to fill our current storage based on current income?
		else
			resMaxInterval = 6
		end
		if resMaxInterval > maxInterval then
			maxInterval = resMaxInterval
			if maxInterval >= 6 then
				return 6  -- Early exit when we hit the maximum
			end
		end
	end
	return maxInterval
end

function gadget:GameFrame(n)
	-- Process buildTargetOwners - only for teams that were just updated
	-- This is handled within UpdatePassiveBuilders now, but we need to restore speeds
	-- for owners from the previous frame
	for teamID, owners in pairs(buildTargetOwnersByTeam) do
		for builderID, builtUnit in pairs(owners) do
			if spValidUnitID(builderID) and spGetUnitIsBuilding(builderID) == builtUnit then
				local suspend = Spring.GetTeamRulesParam(teamID, "suspendbuilderpriority")
				if not isTeamSavingMetal(teamID) and suspend == 0 then
					local buildSpeed = currentBuildSpeed[builderID] or realBuildSpeed[builderID]
					if buildSpeed then
						spSetUnitBuildSpeed(builderID, buildSpeed)
					end
				end
			end
		end
	end

	-- Clear build targets (shared across all teams)
	for k in pairs(buildTargets) do
		buildTargets[k] = nil
	end

	-- Only process teams that have passive builders and are not dead
	for i = 1, #teamList do
		local teamID = teamList[i]
		if not deadTeamList[teamID] and not isTeamSavingMetal(teamID) then
			-- Skip teams with no passive builders
			if passiveConsCount[teamID] and passiveConsCount[teamID] > 0 then
				if n >= updateFrame[teamID] then
					local interval = GetUpdateInterval(teamID)
					UpdatePassiveBuilders(teamID, interval)
					updateFrame[teamID] = n + interval
				end
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
