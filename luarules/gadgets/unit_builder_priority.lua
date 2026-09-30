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
		name = "Builder Priority", -- this once was named: Passive Builders v3
		desc = "Builders marked as low priority only use resources after others builder have taken their share",
		author = "BrainDamage, Bluestone",
		version = "1.01",
		date = "2024",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

-- Arbitrarily chosen heuristics to prevent stall in engine code.
local stallMarginIncMetal = 0.2
local stallMarginIncEnergy = 0.4 -- 2 builder-priority cycles
local stallMarginSto = 0.01

local passiveCons = {} -- passiveCons[teamID][builderID]
local passiveConsCount = {} -- passiveConsCount[teamID] = number of passive builders
local passiveConsOrder = {} ---@type table<TeamID, UnitID[]?> -- pairs() order of passiveCons[teamID], nil when stale

local nonPassiveCons = {} ---@type table<TeamID, UnitID[]> -- the team's other builders
local nonPassiveIndex = {} ---@type table<UnitID, integer?> -- position in nonPassiveCons[teamID]

local buildTargetFrame = {} ---@type table<UnitID, integer?> -- frame a passive builder last took ownership in

local realBuildSpeed = {} --build speed of builderID, as in UnitDefs (contains all builders)
local currentBuildSpeed = {} --build speed of builderID for current interval, not accounting for buildOwners special speed (contains only passive builders)
local cloakBuilderDefID = {} ---@type table<UnitID, UnitDefID?> -- builders that can cloak

local costID = {} -- costID[unitID] (contains all non-finished units)

local ruleName = "builderPriority"
local CMD_PRIORITY = GameCMD.PRIORITY ---@as integer
local PRIORITY_LOW = 0
local PRIORITY_HIGH = 1

---@type CommandDescription
local cmdPassiveDesc = {
	id = CMD_PRIORITY,
	name = "priority",
	action = "priority",
	type = CMDTYPE.ICON_MODE,
	tooltip = "Builder Mode: Low Priority restricts build when stalling on resources",
	params = { tostring(PRIORITY_HIGH), "Low Prio", "High Prio" },
}

local spInsertUnitCmdDesc = Spring.InsertUnitCmdDesc
local spFindUnitCmdDesc = Spring.FindUnitCmdDesc
local spGetUnitCmdDescs = Spring.GetUnitCmdDescs
local spEditUnitCmdDesc = Spring.EditUnitCmdDesc
local spGetTeamResources = Spring.GetTeamResources
local spGetTeamList = Spring.GetTeamList
local spSetUnitRulesParam = Spring.SetUnitRulesParam
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spGetUnitResources = Spring.GetUnitResources
local spSetUnitBuildSpeed = Spring.SetUnitBuildSpeed
local spGetUnitIsBuilding = Spring.GetUnitIsBuilding
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
local canCloak = {} ---@type table<UnitDefID, true?>
local cost = {} -- cost[unitDefID] = { metal, energy, buildTime }
local converterEnergyUsageParamName = "mmUse"

-- Reusable scratch arrays, indexed by position in passiveConsOrder[teamID]
local passiveMetal = {} ---@type table<integer, number|false> -- false when not building
local passiveEnergy = {} ---@type table<integer, number>
local passiveOwnedTarget = {} ---@type table<integer, UnitID|false> -- false when not the build target's owner

-- Build target owners set to a tiny build speed this frame, restored next frame
local nudgedCount = 0
local nudgedBuilder = {} ---@type table<integer, UnitID>
local nudgedTeam = {} ---@type table<integer, TeamID>

for unitDefID, unitDef in pairs(UnitDefs) do
	-- All builders can have their build speeds changed via lua
	if unitDef.buildSpeed > 0 then
		unitBuildSpeed[unitDefID] = unitDef.buildSpeed
	end
	-- Units that can only repair, resurrect, or capture don't have a passive mode (in this gadget)
	local prioritizes = ((unitDef.canAssist and unitDef.buildSpeed > 0) or #unitDef.buildOptions > 0)
	canPassive[unitDefID] = prioritizes and true or nil
	-- Same set as unit_cloak's, whose GG.GetUnitCloakEnergyPerSec returns 0 for other defs
	canCloak[unitDefID] = unitDef.canCloak and true or nil
	-- Minor speedup for determining total resource drain per frame/interval
	cost[unitDefID] = { unitDef.metalCost, unitDef.energyCost, unitDef.buildTime }
end

local function updateTeamList()
	teamList = spGetTeamList()
end

local function addNonPassive(teamID, unitID)
	local list = nonPassiveCons[teamID]
	local n = #list + 1
	list[n] = unitID
	nonPassiveIndex[unitID] = n
end

local function removeNonPassive(teamID, unitID)
	local list = nonPassiveCons[teamID]
	local index = nonPassiveIndex[unitID]
	if not index or list[index] ~= unitID then
		return false
	end
	local n = #list
	local last = list[n]
	list[index] = last
	nonPassiveIndex[last] = index
	list[n] = nil
	nonPassiveIndex[unitID] = nil
	return true
end

local function setPassive(teamID, unitID)
	passiveCons[teamID][unitID] = true
	passiveConsCount[teamID] = (passiveConsCount[teamID] or 0) + 1
	passiveConsOrder[teamID] = nil
end

local function clearPassive(teamID, unitID)
	passiveCons[teamID][unitID] = nil
	passiveConsCount[teamID] = passiveConsCount[teamID] - 1
	passiveConsOrder[teamID] = nil
end

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
		nonPassiveCons[teamID] = nonPassiveCons[teamID] or {}
		passiveCons[teamID] = passiveCons[teamID] or {}
		passiveConsCount[teamID] = passiveConsCount[teamID] or 0
		Spring.SetTeamRulesParam(teamID, "suspendbuilderpriority", 0)
	end

	local allUnits = spGetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		gadget:UnitCreated(unitID, spGetUnitDefID(unitID), spGetUnitTeam(unitID)) ---@diagnostic disable-line
		if currentBuildSpeed[unitID] then
			spSetUnitBuildSpeed(unitID, currentBuildSpeed[unitID]) -- needed for luarules reloads
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, teamID)
	-- Units use their full build speed, by default.
	if unitBuildSpeed[unitDefID] then
		realBuildSpeed[unitID] = unitBuildSpeed[unitDefID]
		if canCloak[unitDefID] then
			cloakBuilderDefID[unitID] = unitDefID
		end

		-- Only units that can build other units can use passive build priority.
		if canPassive[unitDefID] then
			spInsertUnitCmdDesc(unitID, cmdPassiveDesc)
			if spGetUnitRulesParam(unitID, ruleName) == PRIORITY_LOW then
				setPassive(teamID, unitID)
			end
			currentBuildSpeed[unitID] = unitBuildSpeed[unitDefID]
		end
		if not passiveCons[teamID][unitID] then
			addNonPassive(teamID, unitID)
		end
	end

	costID[unitID] = cost[unitDefID]
end

function gadget:UnitFinished(unitID, unitDefID, teamID, builderID)
	costID[unitID] = nil
	buildTargetFrame[unitID] = nil
end

function gadget:UnitGiven(unitID, unitDefID, newTeamID, oldTeamID)
	if passiveCons[oldTeamID] and passiveCons[oldTeamID][unitID] then
		setPassive(newTeamID, unitID)
		clearPassive(oldTeamID, unitID)
	elseif nonPassiveCons[oldTeamID] and removeNonPassive(oldTeamID, unitID) then
		addNonPassive(newTeamID, unitID)
	end
end

function gadget:UnitTaken(unitID, unitDefID, oldTeamID, newTeamID)
	gadget:UnitGiven(unitID, unitDefID, newTeamID, oldTeamID)
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID)
	if realBuildSpeed[unitID] then
		if passiveCons[teamID][unitID] then
			clearPassive(teamID, unitID)
		else
			removeNonPassive(teamID, unitID)
		end
		realBuildSpeed[unitID] = nil
		currentBuildSpeed[unitID] = nil
		cloakBuilderDefID[unitID] = nil
	end

	costID[unitID] = nil
	buildTargetFrame[unitID] = nil
end

function gadget:AllowCommand(
	unitID,
	unitDefID,
	teamID,
	cmdID,
	cmdParams,
	cmdOptions,
	cmdTag,
	playerID,
	fromSynced,
	fromLua
)
	-- accepts CMD_PRIORITY
	-- track which cons are set to passive
	if canPassive[unitDefID] then
		local cmdIdx = spFindUnitCmdDesc(unitID, CMD_PRIORITY)
		local suspend = spGetTeamRulesParam(teamID, "suspendbuilderpriority") or 0
		if cmdIdx and suspend == 0 then
			local cmdDesc = spGetUnitCmdDescs(unitID, cmdIdx, cmdIdx)[1] ---@as table ---@diagnostic disable-line: need-check-nil
			cmdDesc.params[1] = cmdParams[1]
			spEditUnitCmdDesc(unitID, cmdIdx, cmdDesc)
			spSetUnitRulesParam(unitID, ruleName, cmdParams[1])
			if cmdParams[1] == PRIORITY_LOW then
				if not passiveCons[teamID][unitID] then
					setPassive(teamID, unitID)
					removeNonPassive(teamID, unitID)
				end
			elseif realBuildSpeed[unitID] then
				spSetUnitBuildSpeed(unitID, realBuildSpeed[unitID])
				currentBuildSpeed[unitID] = realBuildSpeed[unitID]
				if passiveCons[teamID][unitID] then
					clearPassive(teamID, unitID)
					addNonPassive(teamID, unitID)
				end
			end
		end
		return false -- Allowing command causes command queue to be lost if command is unshifted
	end
	return true
end

-- Measured energy pull of the builders, cloak drain excluded
-- Note: This currently does not handle weapon energy pull and incorrectly considers it to be part of the builder
-- pull. It requires additional engine work to handle this correctly as there is no way to split out weapon
-- energy pull from builder pull.
local function sumEnergyPull(builders, count, getCloakEnergyPerSec)
	local total = 0.0
	for i = 1, count do
		local builderID = builders[i]
		local _, _, _, energyUse = spGetUnitResources(builderID)
		if energyUse and energyUse > 0 then
			local cloakDefID = cloakBuilderDefID[builderID]
			if cloakDefID and getCloakEnergyPerSec then
				energyUse = energyUse - getCloakEnergyPerSec(builderID, cloakDefID)
			end
			if energyUse > 0 then
				total = total + energyUse
			end
		end
	end
	return total
end

local function UpdatePassiveBuilders(
	teamID,
	frame,
	interval,
	mCur,
	mStor,
	mInc,
	mShare,
	mSent,
	mRec,
	eCur,
	eStor,
	eInc,
	eShare,
	eSent,
	eRec,
	ePull
)
	if spGetTeamRulesParam(teamID, "suspendbuilderpriority") ~= 0 then
		return
	end

	-- The allocation below favours cons in this order, so keep the order of the passiveCons table
	local passiveTeamCons = passiveConsOrder[teamID]
	if not passiveTeamCons then
		passiveTeamCons = {}
		for builderID in pairs(passiveCons[teamID]) do
			passiveTeamCons[#passiveTeamCons + 1] = builderID
		end
		passiveConsOrder[teamID] = passiveTeamCons
	end
	local passiveTeamConsCount = #passiveTeamCons

	-- calculate how much expense each passive con would require
	-- and how much total expense the non-passive cons require
	local nonPassiveConsTotalExpenseMetal = 0.0
	local nonPassiveConsTotalExpenseEnergy = 0.0
	local passiveConsTotalExpenseEnergy = 0.0

	-- First pass: check passive builders that are building, track their expense inline
	local anyPassiveBuilding = false
	for i = 1, passiveTeamConsCount do
		local builderID = passiveTeamCons[i]
		local builtUnit = spGetUnitIsBuilding(builderID)
		local targetCosts = builtUnit and costID[builtUnit] ---@as { [1]:number, [2]:number, [3]:number }?
		if targetCosts then
			local rate = realBuildSpeed[builderID] / targetCosts[3]
			local mcost = targetCosts[1]
			local ecost = targetCosts[2] * rate
			passiveMetal[i] = mcost <= 1 and 0 or mcost * rate
			passiveEnergy[i] = ecost
			passiveConsTotalExpenseEnergy = passiveConsTotalExpenseEnergy + ecost
			anyPassiveBuilding = true
			if buildTargetFrame[builtUnit] ~= frame then
				buildTargetFrame[builtUnit] = frame
				passiveOwnedTarget[i] = builtUnit
			else
				passiveOwnedTarget[i] = false
			end
		else
			passiveMetal[i] = false
			passiveOwnedTarget[i] = false
		end
	end

	-- Second pass: ONLY if we have passive builders building
	-- Metal/energy (non-passive): theoretical full-speed cost for reservation gate
	local nonPassiveTeamCons = nonPassiveCons[teamID]
	if anyPassiveBuilding then
		for i = 1, #nonPassiveTeamCons do
			local builderID = nonPassiveTeamCons[i]
			local builtUnit = spGetUnitIsBuilding(builderID)
			local targetCosts = builtUnit and costID[builtUnit] ---@as { [1]:number, [2]:number, [3]:number }?
			if targetCosts then
				local rate = realBuildSpeed[builderID] / targetCosts[3]
				local mcost = targetCosts[1]
				mcost = mcost <= 1 and 0 or mcost * rate
				local ecost = targetCosts[2] * rate
				nonPassiveConsTotalExpenseMetal = nonPassiveConsTotalExpenseMetal + mcost
				nonPassiveConsTotalExpenseEnergy = nonPassiveConsTotalExpenseEnergy + ecost
			end
		end
	end

	-- Resource accounting for the stall budget:
	--
	-- Metal: reserve theoretical full-speed metal for non-passive cons only
	--   (nonPassiveConsTotalExpenseMetal).
	--
	-- Energy: peel measured builder draw (minus cloak) out of ePull
	--   (minus converters) to get non-builder pull — cloak stays in
	--   that residual. Reserve non-builder pull plus theoretical full-speed
	--   non-passive con energy. Leave passive measured pull out so the
	--   allocation loop can re-test each passive at full realBuildSpeed.
	local durationSeconds = interval / simSpeed

	local mStorEff = mStor * mShare
	local teamStallingMetal = mCur
		- mathMax(mInc * stallMarginIncMetal, mStorEff * stallMarginSto)
		- 1
		+ durationSeconds * (mInc + mRec - mSent - nonPassiveConsTotalExpenseMetal)

	local eStorEff = eStor * eShare
	local eMargin = mathMax(eInc * stallMarginIncEnergy, eStorEff * stallMarginSto)
	local converterEnergyUse = spGetTeamRulesParam(teamID, converterEnergyUsageParamName) or 0
	local nonConverterEnergyPull = mathMax(0, ePull - converterEnergyUse)
	local teamStallingEnergy = eCur
		- eMargin
		- 1
		+ durationSeconds * (eInc + eRec - eSent - nonConverterEnergyPull - nonPassiveConsTotalExpenseEnergy)

	-- Peeling builder draw out of ePull only raises the budget: skip measuring it if every passive con fits anyway
	if anyPassiveBuilding and teamStallingEnergy - durationSeconds * passiveConsTotalExpenseEnergy <= 1 then
		local getCloakEnergyPerSec = GG.GetUnitCloakEnergyPerSec
		local nonPassiveConsEnergyPull = sumEnergyPull(nonPassiveTeamCons, #nonPassiveTeamCons, getCloakEnergyPerSec)
		local passiveConsEnergyPull = sumEnergyPull(passiveTeamCons, passiveTeamConsCount, getCloakEnergyPerSec)
		local nonBuilderEnergyPull =
			mathMax(0, nonConverterEnergyPull - nonPassiveConsEnergyPull - passiveConsEnergyPull)
		teamStallingEnergy = eCur
			- eMargin
			- 1
			+ durationSeconds * (eInc + eRec - eSent - nonBuilderEnergyPull - nonPassiveConsTotalExpenseEnergy)
	end

	-- work through passive cons allocating as much expense as we have left
	for i = 1, passiveTeamConsCount do
		local builderID = passiveTeamCons[i]
		local wouldStall = false

		local pMetal = passiveMetal[i]
		if pMetal then
			local passivePullMetal = pMetal * durationSeconds
			local passivePullEnergy = passiveEnergy[i] * durationSeconds
			if passivePullMetal > 0 or passivePullEnergy > 0 then
				if
					(teamStallingMetal - passivePullMetal <= 0 and passivePullMetal > 0)
					or (teamStallingEnergy - passivePullEnergy <= 0 and passivePullEnergy > 0)
				then
					wouldStall = true
				else
					teamStallingMetal = teamStallingMetal - passivePullMetal
					teamStallingEnergy = teamStallingEnergy - passivePullEnergy
				end
			end
		end

		-- turn this passive builder on/off as appropriate
		local wantedBuildSpeed = wouldStall and 0 or realBuildSpeed[builderID] ---@as number
		local currentSpeed = currentBuildSpeed[builderID]
		if currentSpeed ~= wantedBuildSpeed then
			spSetUnitBuildSpeed(builderID, wantedBuildSpeed)
			currentBuildSpeed[builderID] = wantedBuildSpeed
		end

		-- override buildTargetOwners build speeds for a single frame;
		-- let them build at a tiny rate to prevent nanoframes from possibly decaying
		local ownedTarget = passiveOwnedTarget[i]
		if currentSpeed == 0 and ownedTarget then
			spSetUnitBuildSpeed(builderID, 0.001)
			nudgedCount = nudgedCount + 1
			nudgedBuilder[nudgedCount] = builderID
			nudgedTeam[nudgedCount] = teamID
		end
	end
end

function gadget:GameFrame(n)
	-- Restore the build speeds overridden with 0.001 last frame, later if their team is suspended
	local keptCount = 0
	local suspendTeam, suspend
	for i = 1, nudgedCount do
		local builderID = nudgedBuilder[i]
		local teamID = nudgedTeam[i]
		if teamID ~= suspendTeam then
			suspendTeam = teamID
			suspend = spGetTeamRulesParam(teamID, "suspendbuilderpriority")
		end
		local buildSpeed = currentBuildSpeed[builderID] ---@as number?
		if buildSpeed then
			if suspend == 0 then
				spSetUnitBuildSpeed(builderID, buildSpeed)
			else
				keptCount = keptCount + 1
				nudgedBuilder[keptCount] = builderID
				nudgedTeam[keptCount] = teamID
			end
		end
	end
	nudgedCount = keptCount

	-- Only process teams that have passive builders and are not dead
	for i = 1, #teamList do
		local teamID = teamList[i]
		if not deadTeamList[teamID] then
			-- Skip teams with no passive builders
			if passiveConsCount[teamID] and passiveConsCount[teamID] > 0 then
				if n >= updateFrame[teamID] then
					-- Read resource data once for both interval calc and UpdatePassiveBuilders
					local mCur, mStor, _, mInc, _, mShare, mSent, mRec = spGetTeamResources(teamID, "metal")
					local eCur, eStor, ePull, eInc, _, eShare, eSent, eRec = spGetTeamResources(teamID, "energy")
					-- Inlined GetUpdateInterval: find max frames to fill storage for metal/energy (capped at 6)
					local interval = 1
					if mInc > 0 then
						local mi = mathFloor(mStor * simSpeed / mInc) + 1
						if mi > interval then
							interval = mi
						end
					end
					if interval < 6 and eInc > 0 then
						local ei = mathFloor(eStor * simSpeed / eInc) + 1
						if ei > interval then
							interval = ei
						end
					end
					if interval > 6 then
						interval = 6
					end
					UpdatePassiveBuilders(
						teamID,
						n,
						interval,
						mCur,
						mStor,
						mInc,
						mShare,
						mSent,
						mRec,
						eCur,
						eStor,
						eInc,
						eShare,
						eSent,
						eRec,
						ePull
					)
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
