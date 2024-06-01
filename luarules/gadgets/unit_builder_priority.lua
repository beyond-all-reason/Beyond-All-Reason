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

function gadget:GetInfo()
    return {
        name      = 'Builder Priority', 	-- this once was named: Passive Builders v3
        desc      = 'Builders marked as low priority only use resources after others builder have taken their share',
        author    = 'BrainDamage, Bluestone',
        date      = 'Why is date even relevant',
        license   = 'GNU GPL, v2 or later',
        layer     = 0,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return
end

local CMD_PRIORITY = 34571

local stallMarginInc = 0.2
local stallMarginSto = 0.01

local passiveCons = {} -- passiveCons[teamID][builderID]

local buildTargets = {} --the unitIDs of build targets of passive builders
local buildTargetOwners = {} --each build target has one passive builder that doesn't turn fully off, to stop the building decaying

local canBuild = {} --builders[teamID][builderID], contains all builders
local realBuildSpeed = {} --build speed of builderID, as in UnitDefs (contains all builders)
local currentBuildSpeed = {} --build speed of builderID for current interval, not accounting for buildOwners special speed (contains only passive builders)

local costID = {} -- costID[unitID] (contains all units)

local ruleName = "builderPriority"

local resTable = {"metal","energy"}

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
local canPassive = {} -- canPassive[unitDefID] = nil / true
local cost = {} -- cost[unitDefID] = {metal=value,energy=value}
local unitBuildSpeed = {}
for unitDefID, unitDef in pairs(UnitDefs) do
    if unitDef.buildSpeed > 0 then
        unitBuildSpeed[unitDefID] = unitDef.buildSpeed
    end
    -- build the list of which unitdef can have low prio mode
    canPassive[unitDefID] = ((unitDef.canAssist and unitDef.buildSpeed > 0) or #unitDef.buildOptions > 0)
    cost[unitDefID] = { buildTime = unitDef.buildTime }
    for _,resName in pairs(resTable) do
        cost[unitDefID][resName] = unitDef[resName .. "Cost"]
    end
end

local function updateTeamList()
	teamList = spGetTeamList()
end

local isTeamSavingMetal = function(_) return false end

function gadget:Initialize()
    for _,unitID in pairs(Spring.GetAllUnits()) do
        gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID), spGetUnitTeam(unitID))
    end
	updateTeamList()
	
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
    if canPassive[unitDefID] or unitBuildSpeed[unitDefID] then
        canBuild[teamID] = canBuild[teamID] or {}
        canBuild[teamID][unitID] = true
        realBuildSpeed[unitID] = unitBuildSpeed[unitDefID] or 0
    end
    if canPassive[unitDefID] then
        spInsertUnitCmdDesc(unitID, cmdPassiveDesc)
        if not passiveCons[teamID] then passiveCons[teamID] = {} end
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

	if not passiveCons[teamID] then passiveCons[teamID] = {} end
    passiveCons[teamID][unitID] = nil
    realBuildSpeed[unitID] = nil
    currentBuildSpeed[unitID] = nil
    buildTargetOwners[unitID] = nil

    costID[unitID] = nil
end


function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
    -- track which cons are set to passive
    if cmdID == CMD_PRIORITY and canPassive[unitDefID] then
        local cmdIdx = spFindUnitCmdDesc(unitID, CMD_PRIORITY)
        if cmdIdx then
            local cmdDesc = spGetUnitCmdDescs(unitID, cmdIdx, cmdIdx)[1]
            cmdDesc.params[1] = cmdParams[1]
            spEditUnitCmdDesc(unitID, cmdIdx, cmdDesc)
            spSetUnitRulesParam(unitID,ruleName,cmdParams[1])
			if not passiveCons[teamID] then passiveCons[teamID] = {} end
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

	-- calculate how much expense each passive con would require, and how much total expense the non-passive cons require
	local nonPassiveConsTotalExpenseEnergy = 0
	local nonPassiveConsTotalExpenseMetal = 0
	local passiveConsExpense = {}
	if not passiveCons[teamID] then
		passiveCons[teamID] = {}
	end
	if canBuild[teamID] then
		for builderID in pairs(canBuild[teamID]) do
			local builtUnit = spGetUnitIsBuilding(builderID)
			local targetCosts = builtUnit and costID[builtUnit] or nil
			if builtUnit and targetCosts and realBuildSpeed[builderID] then	-- added check for realBuildSpeed[builderID] else line below could error (unsure why)
				local rate = realBuildSpeed[builderID] / targetCosts.buildTime
				for _,resName in pairs(resTable) do
					local expense = targetCosts[resName]
					if expense <= 1 then -- metal maker costs 1 metal, don't stall because of that
						expense = 0
					else
						expense = expense * rate
					end
					if passiveCons[teamID][builderID] then
						if not passiveConsExpense[builderID] then
							passiveConsExpense[builderID] = {energy=0, metal=expense}	-- because metal is set as first key
						else
							passiveConsExpense[builderID][resName] = expense
						end
						if not buildTargets[builtUnit] then
							buildTargetOwners[builderID] = builtUnit
							buildTargets[builtUnit] = true
						end
					else
						if resName == 'energy' then
							nonPassiveConsTotalExpenseEnergy = nonPassiveConsTotalExpenseEnergy + expense
						else
							nonPassiveConsTotalExpenseMetal = nonPassiveConsTotalExpenseMetal + expense
						end
					end
				end
			end
		end
	end

	-- calculate how much expense passive cons will be allowed
	local teamStallingEnergy, teamStallingMetal
	for _,resName in pairs(resTable) do
		local cur, stor, _, inc, _, share, sent, rec  = spGetTeamResources(teamID, resName)
		stor = stor * share -- consider capacity only up to the share slider
		local reservedExpense = (resName == 'energy' and nonPassiveConsTotalExpenseEnergy or nonPassiveConsTotalExpenseMetal) -- we don't want to touch this part of expense
		if resName == 'energy' then
			teamStallingEnergy = cur - max(inc*stallMarginInc,stor*stallMarginSto) - 1 + (interval)*(inc-reservedExpense+rec-sent)/simSpeed --amount of res available to assign to passive builders (in next interval); leave a tiny bit left over to avoid engines own "stall mode"
		else
			teamStallingMetal = cur - max(inc*stallMarginInc,stor*stallMarginSto) - 1 + (interval)*(inc-reservedExpense+rec-sent)/simSpeed --amount of res available to assign to passive builders (in next interval); leave a tiny bit left over to avoid engines own "stall mode"
		end
	end

	-- work through passive cons allocating as much expense as we have left
	for builderID in pairs(passiveCons[teamID]) do
		-- find out if we have used up all the expense available to passive builders yet
		local wouldStall = false
		if teamStallingEnergy or teamStallingMetal then
			if passiveConsExpense[builderID] then
				if teamStallingEnergy then
					local passivePullEnergy = (interval*passiveConsExpense[builderID]['energy']/simSpeed)
					if passivePullEnergy > 0 then
						local newPullEnergy = teamStallingEnergy - passivePullEnergy
						if newPullEnergy <= 0 then
							wouldStall = true
						else
							teamStallingEnergy = newPullEnergy
						end
					end
				end
				if teamStallingMetal then
					local passivePullMetal = (interval*passiveConsExpense[builderID]['metal']/simSpeed)
					if passivePullMetal > 0 then
						local newPullMetal = teamStallingMetal - passivePullMetal
						if newPullMetal <= 0 then
							wouldStall = true
						else
							teamStallingMetal = newPullMetal
						end
					end
				end
			end
		end

		-- turn this passive builder on/off as appropriate
		local wantedBuildSpeed = (wouldStall or not passiveConsExpense[builderID]) and 0 or realBuildSpeed[builderID]
		if currentBuildSpeed[builderID] ~= wantedBuildSpeed then
			spSetUnitBuildSpeed(builderID, wantedBuildSpeed)
			currentBuildSpeed[builderID] = wantedBuildSpeed
		end

		-- override buildTargetOwners build speeds for a single frame; let them build at a tiny rate to prevent nanoframes from possibly decaying
		if (buildTargetOwners[builderID] and currentBuildSpeed[builderID] == 0) then
			spSetUnitBuildSpeed(builderID, 0.001) --(*)
		end
	end
end


local function GetUpdateInterval(teamID)
	local maxInterval = 1
	for _,resName in pairs(resTable) do
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
	--Spring.Echo("interval: "..maxInterval)
	return maxInterval
end

function gadget:TeamDied(teamID)
	deadTeamList[teamID] = true
end

function gadget:TeamChanged(teamID)
	updateTeamList()
end

function gadget:GameFrame(n)
    for builderID, builtUnit in pairs(buildTargetOwners) do
        if spValidUnitID(builderID) and spGetUnitIsBuilding(builderID) == builtUnit then
			local teamID = spGetUnitTeam(builderID)
			if not isTeamSavingMetal(teamID) then
            	spSetUnitBuildSpeed(builderID, currentBuildSpeed[builderID])
			end
        end
    end
	buildTargetOwners = {}
    buildTargets = {}

	for i=1, #teamList do
		local teamID = teamList[i]
		if not deadTeamList[teamID] and not isTeamSavingMetal(teamID) then -- isnt dead
			if n == updateFrame[teamID] then
				local interval = GetUpdateInterval(teamID)
				UpdatePassiveBuilders(teamID, interval)
				updateFrame[teamID] = n + interval
			elseif not updateFrame[teamID] or updateFrame[teamID] < n then
				updateFrame[teamID] = n + GetUpdateInterval(teamID)
			end
		end
    end
end
