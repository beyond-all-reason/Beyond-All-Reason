local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Auto Repair Idle Builders",
		desc    = "Idle mobile builders automatically repair nearby damaged allied units within a leash radius based on movement state",
		author  = "Flameink",
		date    = "2026-03-23",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true
	}
end

----------------------------------------------------------------
-- Speedups
----------------------------------------------------------------
local spGetMyTeamID          = Spring.GetMyTeamID
local spGetTeamUnits         = Spring.GetTeamUnits
local spGetUnitDefID         = Spring.GetUnitDefID
local spGetUnitPosition      = Spring.GetUnitPosition
local spGetUnitHealth        = Spring.GetUnitHealth
local spGetUnitStates        = Spring.GetUnitStates
local spGetUnitCommandCount  = Spring.GetUnitCommandCount
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetUnitIsBeingBuilt  = Spring.GetUnitIsBeingBuilt
local spGetUnitIsDead        = Spring.GetUnitIsDead
local spGetUnitsInCylinder   = Spring.GetUnitsInCylinder
local spGiveOrderToUnit      = Spring.GiveOrderToUnit
local spValidUnitID          = Spring.ValidUnitID
local spGetGameFrame         = Spring.GetGameFrame
local spGetSelectedUnits     = Spring.GetSelectedUnits

local CMD_REPAIR  	 = CMD.REPAIR
local CMD_MOVE    	 = CMD.MOVE
local CMD_RECLAIM    = CMD.RECLAIM
local CMD_MOVE_STATE = CMD.MOVE_STATE

local ALLY_UNITS = Spring.ALLY_UNITS

-- Known issues
-- This doesn't take into account the width of the unit being repaired, so the hold 
-- position radius is too small. It's good to be conservative, but we should update
-- this later to properly take the width into account.

----------------------------------------------------------------
-- Constants
----------------------------------------------------------------
local LEASH_EXTRA = {
	[0] = 0,     -- hold position
	[1] = 100,   -- maneuver
	[2] = 200,   -- roam
}
local DEFAULT_LEASH_EXTRA = 100
local POLL_INTERVAL = 30                 -- every 1 second (30 fps)
local RECLAIM_BLACKLIST_DURATION = 1800  -- 60 seconds * 30 fps

----------------------------------------------------------------
-- Static lookup (built once from UnitDefs)
----------------------------------------------------------------
local isMobileBuilder = {}
local builderBuildDist = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isBuilder and (unitDef.canAssist or unitDef.canResurrect) and unitDef.canMove and not unitDef.isFactory then
		isMobileBuilder[unitDefID] = true
		builderBuildDist[unitDefID] = unitDef.buildDistance
	end
end

----------------------------------------------------------------
-- Runtime state
----------------------------------------------------------------
local myTeam = spGetMyTeamID()

-- [unitID] = { homeX, homeY, homeZ }
local idleBuilders = {}

-- [builderID] = { targetID, homeX, homeY, homeZ }
local activeRepairs = {}

-- [unitID] = expiryFrame
local reclaimBlacklist = {}

-- [reclaimerID] = targetID
local activeReclaimers = {}

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
	local extra = DEFAULT_LEASH_EXTRA
	if states then
		extra = LEASH_EXTRA[states.movestate] or DEFAULT_LEASH_EXTRA
	end
	return buildDist + extra
end

local function sendHome(builderID, info)
	spGiveOrderToUnit(builderID, CMD_MOVE, { info.homeX, info.homeY, info.homeZ }, 0)
	activeRepairs[builderID] = nil
end

local function removeBuilder(unitID)
	idleBuilders[unitID] = nil
	activeRepairs[unitID] = nil
end

local function removeTarget(unitID)
	for builderID, info in pairs(activeRepairs) do
		if info.targetID == unitID then
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
		if tid == targetID then return true end
	end
	return false
end

local function onReclaimerStopped(reclaimerID)
	local targetID = activeReclaimers[reclaimerID]
	if not targetID then return end
	activeReclaimers[reclaimerID] = nil
	if not hasActiveReclaimers(targetID) then
		reclaimBlacklist[targetID] = spGetGameFrame() + RECLAIM_BLACKLIST_DURATION
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
	for _, unitID in ipairs(spGetTeamUnits(myTeam)) do
		local unitDefID = spGetUnitDefID(unitID)
		if isMobileBuilder[unitDefID] and spGetUnitCommandCount(unitID) == 0 then
			local x, y, z = spGetUnitPosition(unitID)
			idleBuilders[unitID] = { homeX = x, homeY = y, homeZ = z }
		end
	end
end

function widget:Shutdown()
	idleBuilders = {}
	activeRepairs = {}
	reclaimBlacklist = {}
	activeReclaimers = {}
end

function widget:PlayerChanged()
	myTeam = spGetMyTeamID()
	if maybeRemoveSelf() then
		return
	end
	idleBuilders = {}
	activeRepairs = {}
	activeReclaimers = {}
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
	if unitTeam ~= myTeam then return end
	onReclaimerStopped(unitID)
	if not isMobileBuilder[unitDefID] then return end
	local x, y, z = spGetUnitPosition(unitID)
	idleBuilders[unitID] = { homeX = x, homeY = y, homeZ = z }
	activeRepairs[unitID] = nil
end

function widget:MetaUnitAdded(unitID, unitDefID, unitTeam)
	if spGetUnitIsDead(unitID) then return end
	if unitTeam ~= myTeam then return end
	if not isMobileBuilder[unitDefID] then return end
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
end

function widget:UnitDestroyed(unitID)
	removeBuilder(unitID)
	removeTarget(unitID)
	onReclaimerStopped(unitID)
	reclaimBlacklist[unitID] = nil
end

----------------------------------------------------------------
-- Command interception
----------------------------------------------------------------
function widget:CommandNotify(cmdID, cmdParams, cmdOpts)
	-- State changes (e.g. movestate) should not disrupt tracking
	if cmdID == CMD_MOVE_STATE then return end
	local selectedUnits = spGetSelectedUnits()

	-- Stop tracking reclaimers that received a new command
	for _, unitID in ipairs(selectedUnits) do
		onReclaimerStopped(unitID)
	end

	-- Remove all selected builders from tracking on manual commands
	for _, unitID in ipairs(selectedUnits) do
		if idleBuilders[unitID] or activeRepairs[unitID] then
			removeBuilder(unitID)
		end
	end

	-- Detect reclaim commands targeting a specific unit
	if cmdID == CMD_RECLAIM and cmdParams and cmdParams[1] then
		local targetID = cmdParams[1]
		if targetID > 0 and #cmdParams == 1 and spValidUnitID(targetID) then
			for _, unitID in ipairs(selectedUnits) do
				activeReclaimers[unitID] = targetID
			end
			reclaimBlacklist[targetID] = math.huge
		end
	end
end

----------------------------------------------------------------
-- Core loop
----------------------------------------------------------------
function widget:GameFrame(frame)
	if frame % POLL_INTERVAL ~= 0 then return end

	-- Phase 1: Clean expired reclaim blacklist entries
	for unitID, expiryFrame in pairs(reclaimBlacklist) do
		if frame >= expiryFrame then
			reclaimBlacklist[unitID] = nil
		end
	end

	-- Phase 2: Monitor active repairs
	for builderID, info in pairs(activeRepairs) do
		if not isUnitAlive(builderID) then
			activeRepairs[builderID] = nil
		elseif not isUnitAlive(info.targetID) or reclaimBlacklist[info.targetID] then
			sendHome(builderID, info)
		else
			local health, maxHealth = spGetUnitHealth(info.targetID)
			if health and health >= maxHealth then
				-- Repair complete
				sendHome(builderID, info)
			else
				-- Check if target has left leash radius
				local tx, _, tz = spGetUnitPosition(info.targetID)
				local dx, dz = tx - info.homeX, tz - info.homeZ
				local distSq = dx * dx + dz * dz
				local leash = getLeashRadius(builderID)
				if distSq > leash * leash then
					sendHome(builderID, info)
				else
					-- Check builder is still repairing (not overridden by player)
					local cmdID = spGetUnitCurrentCommand(builderID, 1)
					if cmdID ~= CMD_REPAIR then
						activeRepairs[builderID] = nil
					end
				end
			end
		end
	end

	-- Phase 3: Assign idle builders to repair targets
	for builderID, homePos in pairs(idleBuilders) do
		if activeRepairs[builderID] then
			-- Already assigned (shouldn't happen but guard against it)
		elseif spGetUnitCommandCount(builderID) > 0 then
			-- No longer idle
			idleBuilders[builderID] = nil
		elseif not isUnitAlive(builderID) then
			idleBuilders[builderID] = nil
		else
			local leash = getLeashRadius(builderID)
			local nearbyUnits = spGetUnitsInCylinder(homePos.homeX, homePos.homeZ, leash, ALLY_UNITS)

			local bestTarget = nil
			local bestDistSq = math.huge

			for _, candidateID in ipairs(nearbyUnits) do
				if candidateID ~= builderID
					and not reclaimBlacklist[candidateID]
					and not spGetUnitIsBeingBuilt(candidateID)
				then
					local health, maxHealth = spGetUnitHealth(candidateID)
					if health and maxHealth and health < maxHealth then
						local tx, _, tz = spGetUnitPosition(candidateID)
						local dx, dz = tx - homePos.homeX, tz - homePos.homeZ
						local distSq = dx * dx + dz * dz
						if distSq < bestDistSq then
							bestDistSq = distSq
							bestTarget = candidateID
						end
					end
				end
			end

			if bestTarget then
					spGiveOrderToUnit(builderID, CMD_REPAIR, bestTarget, 0)

				activeRepairs[builderID] = {
					targetID = bestTarget,
					homeX = homePos.homeX,
					homeY = homePos.homeY,
					homeZ = homePos.homeZ,
				}
				idleBuilders[builderID] = nil
			end
		end
	end
end
