local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Auto Repair Idle Builders",
		desc = "Idle mobile builders automatically repair nearby damaged allied units within a leash radius based on movement state",
		author = "Flameink",
		date = "2026-03-23",
		license = "GNU GPL, v2 or later",
		layer = -2, -- before widgets that consume area commands, buggeroff
		enabled = true,
	}
end

----------------------------------------------------------------
-- Speedups
----------------------------------------------------------------
local spGetMyTeamID = Spring.GetLocalTeamID
local spGetTeamUnits = Spring.GetTeamUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitVelocity = Spring.GetUnitVelocity
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitStates = Spring.GetUnitStates
local spGetUnitCommandCount = Spring.GetUnitCommandCount
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetUnitWorkerTask = Spring.GetUnitWorkerTask
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGiveOrderArrayToUnit = Spring.GiveOrderArrayToUnit
local spValidUnitID = Spring.ValidUnitID
local spGetGameFrame = Spring.GetGameFrame
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spFindUnitCmdDesc = Spring.FindUnitCmdDesc
local spGetUnitCmdDescs = Spring.GetUnitCmdDescs

local CMD_REPAIR = CMD.REPAIR
local CMD_MOVE = CMD.MOVE
local CMD_RECLAIM = CMD.RECLAIM
local CMD_STOCKPILE = CMD.STOCKPILE
local CMD_REMOVE = CMD.REMOVE
local CMD_INSERT = CMD.INSERT
local CMDTYPE_ICON_MODE = CMDTYPE.ICON_MODE
local ALLY_UNITS = Spring.ALLY_UNITS

local CMD_OPT_INTERNAL = CMD.OPT_INTERNAL
local CMD_OPT_SHIFT = CMD.OPT_SHIFT

----------------------------------------------------------------
-- Constants
----------------------------------------------------------------
local LEASH_EXTRA = {
	[-1] = 0, -- Structure
	[0] = 0, -- hold position
	[1] = 110, -- maneuver
	[2] = 210, -- roam
}
local DEFAULT_LEASH_EXTRA = 100
local POLL_INTERVAL = Game.gameSpeed
local RECLAIM_BLACKLIST_DURATION = 60 * Game.gameSpeed
local PENDING_TIMEOUT = 2.5 * Game.gameSpeed

----------------------------------------------------------------
-- Static lookup (built once from UnitDefs)
----------------------------------------------------------------
local isMobileBuilder = {}
local builderBuildDist = {}
local cachedUnitDefs = {}

local maxUnitRadius = 0
local maxReclaimRange = 0

for unitDefID, unitDef in pairs(UnitDefs) do
	if
		unitDef.isBuilder
		and (unitDef.canAssist or unitDef.canResurrect)
		and unitDef.canMove
		and unitDef.speed > 0
		and not unitDef.isFactory
	then
		isMobileBuilder[unitDefID] = true
		builderBuildDist[unitDefID] = unitDef.buildDistance
	end

	local canReclaim = unitDef.isBuilder and unitDef.canReclaim or false
	if canReclaim then
		local reclaimRange = unitDef.buildDistance or 0
		if reclaimRange > maxReclaimRange then
			maxReclaimRange = reclaimRange
		end
	end

	cachedUnitDefs[unitDefID] = {
		radius = unitDef.radius,
		canReclaim = canReclaim,
		repairable = unitDef.repairable,
	}
	if unitDef.radius > maxUnitRadius then
		maxUnitRadius = unitDef.radius
	end
end

----------------------------------------------------------------
-- Runtime state
----------------------------------------------------------------
local myTeam = spGetMyTeamID()

-- [unitID] = { homeX, homeY, homeZ }
local idleBuilders = {}

-- [builderID] = { targetID, homeX, homeY, homeZ, orderFrame, returning }
local activeRepairs = table.ensureTable(WG, "InIdleWorkerTask")

-- [unitID] = expiryFrame
local reclaimBlacklist = {}

-- [reclaimerID] = targetID
local activeReclaimers = {}

-- [reclaimerID] = true
local seenReclaimers = {}

-- [builderID] = targetID
local pendingRepairs = {}

-- [builderID] = targetID
local removeRepairs = {}

-- [builderID] = { homeX, homeY, homeZ }
local pendingHomes = {}

-- [builderID] = { homeX, homeY, homeZ }
local removeHomes = {}

-- [cmdID] = boolean
local stateCommands = {}

local repairOrders = {
	{ CMD_REPAIR, 0, CMD_OPT_INTERNAL + CMD_OPT_SHIFT },
	{ CMD_MOVE, { 0, 0, 0 }, CMD_OPT_INTERNAL + CMD_OPT_SHIFT },
}

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function isUnitAlive(unitID)
	return spValidUnitID(unitID) and not spGetUnitIsDead(unitID)
end

local function getLeashRadius(unitID)
	local unitDefID = spGetUnitDefID(unitID)
	local buildDist = builderBuildDist[unitDefID] or 0
	local states = spGetUnitStates(unitID)
	return buildDist + (LEASH_EXTRA[states.movestate] or DEFAULT_LEASH_EXTRA)
end

local function willExitLeash(unitID, homeX, homeZ, leash)
	local tx, _, tz = spGetUnitPosition(unitID)
	if not tx then
		return true
	end

	local leashSq = leash * leash
	local dx, dz = tx - homeX, tz - homeZ
	if dx * dx + dz * dz > leashSq then
		return true
	end

	local vx, _, vz = spGetUnitVelocity(unitID)
	if vx then
		local px, pz = dx + vx * POLL_INTERVAL, dz + vz * POLL_INTERVAL
		if px * px + pz * pz > leashSq then
			return true
		end
	end

	return false
end

local function isAutomatic(options)
	return math.bit_and(options, CMD_OPT_INTERNAL) ~= 0
end

local function getRepairTag(builderID, targetID)
	for index = 1, spGetUnitCommandCount(builderID) or 0 do
		local cmdID, cmdOptions, cmdTag, cmdTargetID = spGetUnitCurrentCommand(builderID, index)
		if cmdID == CMD_REPAIR and cmdTargetID == targetID and isAutomatic(cmdOptions) then
			return cmdTag
		elseif cmdID ~= CMD_MOVE or not isAutomatic(cmdOptions) then -- buggeroff
			return
		end
	end
end

local function getHomeTag(builderID, info)
	for index = 1, spGetUnitCommandCount(builderID) or 0 do
		local cmdID, cmdOptions, cmdTag, x, _, z = spGetUnitCurrentCommand(builderID, index)
		if cmdID ~= CMD_MOVE or not isAutomatic(cmdOptions) then -- buggeroff
			return
		elseif x == info.homeX and z == info.homeZ then
			return cmdTag
		end
	end
end

local function sendHome(builderID, info, repairTag)
	repairTag = repairTag or getRepairTag(builderID, info.targetID)
	if repairTag then
		spGiveOrderToUnit(builderID, CMD_REMOVE, repairTag)
	end
	info.returning = true
end

local function removeQueuedHome(builderID, homeX, homeZ)
	for index = spGetUnitCommandCount(builderID) or 0, 1, -1 do
		local cmdID, cmdOptions, cmdTag, x, _, z = spGetUnitCurrentCommand(builderID, index)
		if cmdID == CMD_MOVE and x == homeX and z == homeZ and isAutomatic(cmdOptions) then
			spGiveOrderToUnit(builderID, CMD_REMOVE, cmdTag)
			return
		end
	end
end

local function removeBuilder(unitID)
	idleBuilders[unitID] = nil
	activeRepairs[unitID] = nil
end

local function removeTarget(unitID)
	for builderID, info in pairs(activeRepairs) do
		if info.targetID == unitID and not info.returning then
			if isUnitAlive(builderID) then
				sendHome(builderID, info)
			else
				activeRepairs[builderID] = nil
			end
		end
	end
end

local function hasActiveReclaimers(targetID)
	for _, tid in pairs(activeReclaimers) do
		if tid == targetID then
			return true
		end
	end

	return false
end

local function onReclaimerStopped(reclaimerID)
	local targetID = activeReclaimers[reclaimerID]
	if not targetID then
		return
	end

	activeReclaimers[reclaimerID] = nil
	seenReclaimers[reclaimerID] = nil
	if not hasActiveReclaimers(targetID) then
		reclaimBlacklist[targetID] = spGetGameFrame() + RECLAIM_BLACKLIST_DURATION
	end
end

local function isReclaimingUnit(reclaimerID, targetID)
	local cmdID, taskTargetID = spGetUnitWorkerTask(reclaimerID)
	return cmdID == CMD_RECLAIM and taskTargetID == targetID
end

local function findAllyReclaimerOf(targetID)
	local tx, _, tz = spGetUnitPosition(targetID)
	if not tx then
		return nil
	end

	local nearby = spGetUnitsInCylinder(tx, tz, maxReclaimRange, ALLY_UNITS)
	for i = 1, #nearby do
		local uID = nearby[i]
		if uID ~= targetID and cachedUnitDefs[spGetUnitDefID(uID)].canReclaim and isReclaimingUnit(uID, targetID) then
			return uID
		end
	end
end

----------------------------------------------------------------
-- Setup / teardown
----------------------------------------------------------------
local function maybeRemoveSelf()
	if Spring.GetSpectatingState() and (spGetGameFrame() > 0) or Spring.IsReplay() then
		widgetHandler:RemoveWidget()
		return true
	end
end

function widget:Initialize()
	myTeam = spGetMyTeamID()
	if maybeRemoveSelf() then
		return
	end

	activeRepairs = table.ensureTable(WG, "InIdleWorkerTask")

	for _, unitID in ipairs(spGetTeamUnits(myTeam)) do
		local unitDefID = spGetUnitDefID(unitID)
		if isMobileBuilder[unitDefID] and spGetUnitCommandCount(unitID) == 0 then
			local x, y, z = spGetUnitPosition(unitID)
			idleBuilders[unitID] = { homeX = x, homeY = y, homeZ = z }
		end
	end
end

function widget:Shutdown()
	for unitID in pairs(activeRepairs) do
		activeRepairs[unitID] = nil
	end
	idleBuilders = {}
	reclaimBlacklist = {}
	activeReclaimers = {}
	seenReclaimers = {}
	pendingRepairs = {}
	removeRepairs = {}
	pendingHomes = {}
	removeHomes = {}
end

function widget:PlayerChanged()
	local previousTeam = myTeam
	myTeam = spGetMyTeamID()
	if maybeRemoveSelf() then
		return
	end
	if myTeam == previousTeam then
		return
	end

	idleBuilders = {}
	for unitID in pairs(activeRepairs) do
		activeRepairs[unitID] = nil
	end
	activeReclaimers = {}
	seenReclaimers = {}
	pendingRepairs = {}
	removeRepairs = {}
	pendingHomes = {}
	removeHomes = {}
	for _, unitID in ipairs(spGetTeamUnits(myTeam)) do
		local unitDefID = spGetUnitDefID(unitID)
		if isMobileBuilder[unitDefID] and spGetUnitCommandCount(unitID) == 0 then
			local x, y, z = spGetUnitPosition(unitID)
			idleBuilders[unitID] = { homeX = x, homeY = y, homeZ = z }
		end
	end
end

----------------------------------------------------------------
-- Unit lifecycle
----------------------------------------------------------------
function widget:UnitIdle(unitID, unitDefID, unitTeam)
	if unitTeam ~= myTeam then
		return
	end

	onReclaimerStopped(unitID)
	if not isMobileBuilder[unitDefID] then
		return
	end

	local x, y, z = spGetUnitPosition(unitID)
	idleBuilders[unitID] = { homeX = x, homeY = y, homeZ = z }
	activeRepairs[unitID] = nil
end

function widget:MetaUnitAdded(unitID, unitDefID, unitTeam)
	if spGetUnitIsDead(unitID) or unitTeam ~= myTeam or not isMobileBuilder[unitDefID] then
		return
	end

	if spGetUnitCommandCount(unitID) == 0 then
		local x, y, z = spGetUnitPosition(unitID)
		idleBuilders[unitID] = { homeX = x, homeY = y, homeZ = z }
	end
end

function widget:MetaUnitRemoved(unitID)
	removeBuilder(unitID)
	removeTarget(unitID)
	onReclaimerStopped(unitID)
	reclaimBlacklist[unitID] = nil
	pendingRepairs[unitID] = nil
	removeRepairs[unitID] = nil
	pendingHomes[unitID] = nil
	removeHomes[unitID] = nil
end

function widget:UnitDestroyed(unitID)
	removeBuilder(unitID)
	removeTarget(unitID)
	onReclaimerStopped(unitID)
	reclaimBlacklist[unitID] = nil
	pendingRepairs[unitID] = nil
	removeRepairs[unitID] = nil
	pendingHomes[unitID] = nil
	removeHomes[unitID] = nil
end

----------------------------------------------------------------
-- Command interception
----------------------------------------------------------------
local function isStateCommand(unitID, cmdID)
	if cmdID == CMD_STOCKPILE then
		return true
	end
	local state = stateCommands[cmdID]
	if state == nil then
		local index = spFindUnitCmdDesc(unitID, cmdID)
		if not index then
			return false
		end
		local desc = spGetUnitCmdDescs(unitID, index, index)[1]
		state = desc.type == CMDTYPE_ICON_MODE or desc.queueing == false
		stateCommands[cmdID] = state
	end
	return state
end

local function releaseBuilder(unitID)
	local active = activeRepairs[unitID] ---@as table?
	if active then
		removeQueuedHome(unitID, active.homeX, active.homeZ)
	end
	if idleBuilders[unitID] or active then
		removeBuilder(unitID)
	end
end

local function removeQueuedRepair(builderID, targetID)
	for index = spGetUnitCommandCount(builderID) or 0, 1, -1 do
		local cmdID, cmdOptions, cmdTag, cmdTargetID = spGetUnitCurrentCommand(builderID, index)
		if cmdID == CMD_REPAIR and cmdTargetID == targetID and isAutomatic(cmdOptions) then
			spGiveOrderToUnit(builderID, CMD_REMOVE, cmdTag)
			return
		end
	end
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts)
	if unitTeam ~= myTeam then
		return
	end
	if cmdOpts.internal then
		if cmdID == CMD_REPAIR and cmdParams[1] == pendingRepairs[unitID] then
			pendingRepairs[unitID] = nil
			if not activeRepairs[unitID] then
				removeRepairs[unitID] = cmdParams[1]
			end
		elseif cmdID == CMD_MOVE and pendingHomes[unitID] then
			local home = pendingHomes[unitID]
			if cmdParams[1] == home.homeX and cmdParams[3] == home.homeZ then
				pendingHomes[unitID] = nil
				if not activeRepairs[unitID] then
					removeHomes[unitID] = home
				end
			end
		end
		return
	end
	if cmdID == CMD_REMOVE or (cmdID == CMD_INSERT and isAutomatic(cmdParams[3] or 0)) then
		return
	end
	local reclaimTargetID = activeReclaimers[unitID] ---@as ObjectID?
	if
		reclaimTargetID
		and not cmdOpts.shift
		and cmdID ~= CMD_INSERT
		and not (cmdID == CMD_RECLAIM and cmdParams[1] == reclaimTargetID)
		and not isStateCommand(unitID, cmdID)
	then
		onReclaimerStopped(unitID)
	end
	if (idleBuilders[unitID] or activeRepairs[unitID]) and not isStateCommand(unitID, cmdID) then
		releaseBuilder(unitID)
	end
end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts)
	local selectedUnits = spGetSelectedUnits()
	for _, unitID in ipairs(selectedUnits) do
		if
			(idleBuilders[unitID] or activeRepairs[unitID] or activeReclaimers[unitID])
			and not isStateCommand(unitID, cmdID)
		then
			onReclaimerStopped(unitID)
			releaseBuilder(unitID)
		end
	end

	if cmdID == CMD_RECLAIM and cmdParams and cmdParams[1] then
		local targetID = cmdParams[1]
		if targetID > 0 and #cmdParams == 1 and spValidUnitID(targetID) then
			local hasReclaimer = false
			for _, unitID in ipairs(selectedUnits) do
				if cachedUnitDefs[spGetUnitDefID(unitID)].canReclaim then
					activeReclaimers[unitID] = targetID
					hasReclaimer = true
				end
			end
			if hasReclaimer then
				reclaimBlacklist[targetID] = math.huge
			end
		end
	end
end

----------------------------------------------------------------
-- Core loop
----------------------------------------------------------------
function widget:GameFrame(frame)
	for builderID, targetID in pairs(removeRepairs) do
		removeQueuedRepair(builderID, targetID)
		removeRepairs[builderID] = nil
	end
	for builderID, home in pairs(removeHomes) do
		removeQueuedHome(builderID, home.homeX, home.homeZ)
		removeHomes[builderID] = nil
	end

	if frame % POLL_INTERVAL ~= 0 then
		return
	end

	for unitID, expiryFrame in pairs(reclaimBlacklist) do
		if frame >= expiryFrame then
			reclaimBlacklist[unitID] = nil
		end
	end

	-- Check if any seen reclaimers aren't reclaiming their unit anymore.
	-- Ordered reclaimers may be moving to the target, so wait for UnitIdle.
	for reclaimerID in pairs(seenReclaimers) do
		if not isUnitAlive(reclaimerID) or not isReclaimingUnit(reclaimerID, activeReclaimers[reclaimerID]) then
			onReclaimerStopped(reclaimerID)
		end
	end

	-- Monitor active repairs
	for builderID, info in pairs(activeRepairs) do
		if not isUnitAlive(builderID) then
			activeRepairs[builderID] = nil
		elseif pendingRepairs[builderID] then
			if frame - info.orderFrame >= PENDING_TIMEOUT then
				-- Command probably refused in gadget:AllowCommand
				pendingRepairs[builderID] = nil
				pendingHomes[builderID] = nil
				activeRepairs[builderID] = nil
				if spGetUnitCommandCount(builderID) == 0 then
					idleBuilders[builderID] = { homeX = info.homeX, homeY = info.homeY, homeZ = info.homeZ }
				end
			end
		elseif info.returning then
			if not getHomeTag(builderID, info) then
				activeRepairs[builderID] = nil
			end
		else
			local repairTag = getRepairTag(builderID, info.targetID)
			if not repairTag then
				if getHomeTag(builderID, info) then
					info.returning = true
				else
					activeRepairs[builderID] = nil
				end
			elseif
				not isUnitAlive(info.targetID)
				or reclaimBlacklist[info.targetID]
				or spGetUnitRulesParam(builderID, "wantcloak") == 1
			then
				sendHome(builderID, info, repairTag)
			else
				local health, maxHealth = spGetUnitHealth(info.targetID)
				if health and maxHealth and health >= maxHealth then
					sendHome(builderID, info, repairTag) -- Repair complete
				else
					local unitDefID = spGetUnitDefID(info.targetID)
					local unitDef = cachedUnitDefs[unitDefID]
					local leash = getLeashRadius(builderID) + unitDef.radius
					if willExitLeash(info.targetID, info.homeX, info.homeZ, leash) then
						sendHome(builderID, info, repairTag)
					end
				end
			end
		end
	end

	-- Assign idle builders to repair targets
	for builderID, homePos in pairs(idleBuilders) do
		local cloakState = spGetUnitRulesParam(builderID, "wantcloak")
		local wantsCloak = (cloakState and cloakState == 1)
		if activeRepairs[builderID] then
			-- Already assigned (shouldn't happen but guard against it)
		elseif not isUnitAlive(builderID) then
			idleBuilders[builderID] = nil
		elseif wantsCloak then
			-- It's still idle but wantscloak, so don't assign a target
		elseif (spGetUnitCommandCount(builderID) or 0) > 0 then
			-- No longer idle
			idleBuilders[builderID] = nil
		elseif spGetUnitStates(builderID)["repeat"] then
			-- The commands this widget issues end up getting repeated, which is weird.
		elseif spGetUnitIsBeingBuilt(builderID) then
			-- Giving orders to unbuilt units breaks factory guard.
		else
			local leash = getLeashRadius(builderID)
			local nearbyUnits = spGetUnitsInCylinder(homePos.homeX, homePos.homeZ, leash + maxUnitRadius, ALLY_UNITS)

			local bestTarget = nil
			local bestDistSq = math.huge

			for _, candidateID in ipairs(nearbyUnits) do
				local candidateDefID = spGetUnitDefID(candidateID)
				if
					candidateID ~= builderID
					and cachedUnitDefs[candidateDefID].repairable
					and not reclaimBlacklist[candidateID]
					and not spGetUnitIsBeingBuilt(candidateID)
				then
					local health, maxHealth = spGetUnitHealth(candidateID)
					if health and maxHealth and health < maxHealth then
						local tx, _, tz = spGetUnitPosition(candidateID)
						local dx, dz = tx - homePos.homeX, tz - homePos.homeZ
						local distSq = dx * dx + dz * dz
						local effectiveLeash = leash + cachedUnitDefs[candidateDefID].radius
						if
							distSq < bestDistSq
							and not willExitLeash(candidateID, homePos.homeX, homePos.homeZ, effectiveLeash)
						then
							bestDistSq = distSq
							bestTarget = candidateID
						end
					end
				end
			end

			if bestTarget then
				-- CommandNotify misses allied orders and our own area, patrol, and fight orders.
				-- When assigning a repair target, do a spot check for any friendly units missed.
				local allyReclaimerID = findAllyReclaimerOf(bestTarget)
				if allyReclaimerID then
					activeReclaimers[allyReclaimerID] = bestTarget
					seenReclaimers[allyReclaimerID] = true
					reclaimBlacklist[bestTarget] = math.huge
				else
					local homeParams = repairOrders[2][2]
					repairOrders[1][2] = bestTarget
					homeParams[1], homeParams[2], homeParams[3] = homePos.homeX, homePos.homeY, homePos.homeZ
					spGiveOrderArrayToUnit(builderID, repairOrders)

					homePos.targetID = bestTarget
					homePos.orderFrame = frame
					pendingRepairs[builderID] = bestTarget
					pendingHomes[builderID] = homePos
					activeRepairs[builderID] = homePos
					idleBuilders[builderID] = nil
				end
			end
		end
	end
end
