local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "API Builder Queue",
		desc = "Provides builder queue data tracking and management for other widgets",
		author = "SuperKitowiec (extracted from 'Show Builder Queue' by WarXperiment, Decay, Floris)",
		date = "August 26, 2025",
		license = "GNU GPL, v2 or later",
		version = 1,
		layer = 0,
		enabled = true
	}
end

--------------------------------------------------------------------------------
-- Spring API Imports
--------------------------------------------------------------------------------

local spGetUnitCommands = Spring.GetUnitCommands
local spGetUnitCommandCount = Spring.GetUnitCommandCount
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitPosition = Spring.GetUnitPosition
local spGetAllUnits = Spring.GetAllUnits
local spEcho = Spring.Echo

-- Localize frequently used functions
local mathFloor = math.floor
local mathAbs = math.abs
local mathMin = math.min
local tableInsert = table.insert
local tableRemove = table.remove
local pairs = pairs
local ipairs = ipairs

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local MAX_QUEUE_DEPTH = 800
local MAX_UNITS_PROCESSED_PER_UPDATE = 20
local PERIODIC_CHECK_DIVISOR = 30 -- every n ticks of UPDATE_INTERVAL
local DEEP_CHECK_DIVISOR = 150 -- every n ticks of UPDATE_INTERVAL
local PERIODIC_UPDATE_INTERVAL = 0.12 -- in seconds
local COMMAND_PROCESSING_DELAY = 0.13
local MIN_CHECK_INTERVAL = 0.25 -- minimum seconds between full GetUnitCommands for same builder

-- Numeric key shifts for commandId: unitDefId(16b) | positionX(16b) | positionZ(16b) = 48 bits (safe in 53-bit double)
local POS_SHIFT = 65536         -- 2^16
local UDEF_SHIFT = 4294967296   -- 2^32

--------------------------------------------------------------------------------
-- State Management
--------------------------------------------------------------------------------

---@type table<string, BuildCommandEntry>
local buildCommands = {}
local unitBuildCommands = {}
local commandIdToCreatedUnitIdMap = {}
local createdUnitIdToCommandIdMap = {}
local unitsAwaitingCommandProcessing = {}
local buildersList = {}
local lastQueueDepth = {}
local lastCheckTime = {}

-- Queue sharing: cache newCommands sets by content hash within a batch
-- so builders with identical queues share one GetUnitCommands call
local sharedQueueCache = {}  -- queueDepth -> {hash=..., newCommands=..., queue=...}
local sharedQueueGeneration = 0
local tableRefCount = {}  -- table -> number of builders referencing it

local tablePool = {}
local tablePoolSize = 0
local function releaseTable(t)
	for k in pairs(t) do
		t[k] = nil
	end
	tablePoolSize = tablePoolSize + 1
	tablePool[tablePoolSize] = t
end
local function acquireTable(t)
	tableRefCount[t] = (tableRefCount[t] or 0) + 1
end

local function releaseRef(t)
	local count = tableRefCount[t]
	if not count then
		-- Not ref-counted, safe to release to pool
		releaseTable(t)
		return
	end
	count = count - 1
	if count <= 0 then
		tableRefCount[t] = nil
		releaseTable(t)
	else
		tableRefCount[t] = count
	end
end

-- Event system for notifying consumers
local Event = {
	onBuildCommandAdded = 'onBuildCommandAdded',
	onBuildCommandRemoved = 'onBuildCommandRemoved',
	onUnitCreated = 'onUnitCreated',
	onUnitFinished = 'onUnitFinished',
	onBuilderDestroyed = 'onBuilderDestroyed',
}

local eventCallbacks = {
	[Event.onBuildCommandAdded] = {},
	[Event.onBuildCommandRemoved] = {},
	[Event.onUnitCreated] = {},
	[Event.onUnitFinished] = {},
	[Event.onBuilderDestroyed] = {}
}

local elapsedSeconds = 0
local nextUpdateTime = PERIODIC_UPDATE_INTERVAL
local periodicCheckCounter = 1

local function getTable()
	if tablePoolSize > 0 then
		local t = tablePool[tablePoolSize]
		tablePool[tablePoolSize] = nil
		tablePoolSize = tablePoolSize - 1
		return t
	end
	return {}
end

-- Pool for buildCommand objects to reduce allocations
local buildCommandPool = {}
local poolSize = 0

local function getBuildCommand()
	if poolSize > 0 then
		local cmd = buildCommandPool[poolSize]
		buildCommandPool[poolSize] = nil
		poolSize = poolSize - 1
		return cmd
	end
	return {}
end

local function recycleBuildCommand(cmd)
	-- Clear the command data
	cmd.id = nil
	cmd.builderCount = nil
	cmd.unitDefId = nil
	cmd.teamId = nil
	cmd.positionX = nil
	cmd.positionY = nil
	cmd.positionZ = nil
	cmd.rotation = nil
	cmd.isCreated = nil
	cmd.isFinished = nil
	if cmd.builderIds then
		for k in pairs(cmd.builderIds) do
			cmd.builderIds[k] = nil
		end
	end

	-- Return to pool
	poolSize = poolSize + 1
	buildCommandPool[poolSize] = cmd
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

-- Cache builder unit defs for faster lookup
local unitDefsLen = #UnitDefs
for unitDefId = 1, unitDefsLen do
	local unitDefinition = UnitDefs[unitDefId]
	if unitDefinition.isBuilder and not unitDefinition.isFactory and unitDefinition.buildOptions[1] then
		buildersList[unitDefId] = true
	end
end

--------------------------------------------------------------------------------
-- Event System Functions
--------------------------------------------------------------------------------

local function notifyEvent(eventName, ...)
	local callbacks = eventCallbacks[eventName]
	if callbacks then
		local callbacksLen = #callbacks
		for i = 1, callbacksLen do
			callbacks[i](...)
		end
	end
end

---@param eventName string
---@param callback function()
local function registerCallback(eventName, callback)
	local callbacks = eventCallbacks[eventName]
	if callbacks then
		tableInsert(callbacks, callback)
		---@class BuilderQueueEventCallback
		return {eventName = eventName, callback = callback}
	else
		spEcho("Warn: Unknown event name " .. eventName)
		return nil
	end
end

local function unregisterCallback(eventName, callback)
	local callbacks = eventCallbacks[eventName]
	if callbacks then
		local callbacksLen = #callbacks
		for i = 1, callbacksLen do
			if callbacks[i] == callback then
				tableRemove(callbacks, i)
				return
			end
		end
	else
		spEcho("Warn: Unknown event name " .. eventName)
	end
end

--------------------------------------------------------------------------------
-- Core Functions
--------------------------------------------------------------------------------

local function removeBuilderFromCommand(commandId, unitId)
	local command = buildCommands[commandId]
	if command and command.builderIds[unitId] then
		command.builderIds[unitId] = nil
		command.builderCount = command.builderCount - 1

		if command.builderCount == 0 then

			local createdUnitId = commandIdToCreatedUnitIdMap[commandId]
			if createdUnitId then
				createdUnitIdToCommandIdMap[createdUnitId] = nil
				commandIdToCreatedUnitIdMap[commandId] = nil
			end

			local commandData = command
			buildCommands[commandId] = nil
			notifyEvent(Event.onBuildCommandRemoved, commandId, commandData)
			recycleBuildCommand(commandData)
		end
	end
end

local function clearBuilderCommands(unitId)
	lastQueueDepth[unitId] = nil
	local oldCommands = unitBuildCommands[unitId]
	if not oldCommands then
		return
	end

	for commandId, _ in pairs(oldCommands) do
		removeBuilderFromCommand(commandId, unitId)
	end
	releaseRef(oldCommands)
	unitBuildCommands[unitId] = nil
end

local function checkBuilder(unitId, forceUpdate)
	local queueDepth = spGetUnitCommandCount(unitId)
	if not queueDepth or queueDepth <= 0 then
		clearBuilderCommands(unitId)
		return
	end

	if not forceUpdate then
		if lastQueueDepth[unitId] == queueDepth then
			return
		end
		-- Per-builder cooldown to prevent rapid re-fetching
		local lastTime = lastCheckTime[unitId]
		if lastTime and (elapsedSeconds - lastTime) < MIN_CHECK_INTERVAL then
			return
		end
	end

	-- Check shared queue cache: if another builder with this depth was already
	-- processed in the current batch, try to share its result
	local cached = sharedQueueCache[queueDepth]
	local queue, queueLen
	local sharedNewCommands

	if cached and cached.generation == sharedQueueGeneration then
		-- Validate by comparing first build command position
		local probeQueue = spGetUnitCommands(unitId, 1)
		if probeQueue and probeQueue[1] then
			local probeCmd = probeQueue[1]
			if probeCmd.id == cached.firstCmdId then
				local pp = probeCmd.params
				if pp and cached.firstParamX == mathFloor(pp[1] or 0)
					and cached.firstParamZ == mathFloor(pp[3] or 0) then
					-- Same first command, likely identical queue — share result
					sharedNewCommands = cached.newCommands
				end
			end
		end
	end

	lastQueueDepth[unitId] = queueDepth
	lastCheckTime[unitId] = elapsedSeconds

	if sharedNewCommands then
		-- Reuse shared newCommands: just register this builder on each command
		for commandId in pairs(sharedNewCommands) do
			local buildCommand = buildCommands[commandId]
			if buildCommand and not buildCommand.builderIds[unitId] then
				buildCommand.builderIds[unitId] = true
				buildCommand.builderCount = buildCommand.builderCount + 1
			end
		end

		-- Remove old commands not in shared set
		local oldCommands = unitBuildCommands[unitId]
		if oldCommands then
			for oldCommandId in pairs(oldCommands) do
				if not sharedNewCommands[oldCommandId] then
					removeBuilderFromCommand(oldCommandId, unitId)
				end
			end
			releaseRef(oldCommands)
		end
		acquireTable(sharedNewCommands)
		unitBuildCommands[unitId] = sharedNewCommands
		return
	end

	-- Full fetch path
	local fetchCount = mathMin(queueDepth, MAX_QUEUE_DEPTH)
	queue = spGetUnitCommands(unitId, fetchCount)
	if not queue then return end

	local newCommands = getTable()

	-- Step 1: Process the current queue and identify active commands
	local queueLen = #queue
	for i = 1, queueLen do
		local queueCommand = queue[i]
		local cmdId = queueCommand.id

		if cmdId < 0 then
			local unitDefId = mathAbs(cmdId)
			local params = queueCommand.params
			local positionX = mathFloor(params[1])
			local positionZ = mathFloor(params[3])

			local commandId = unitDefId * UDEF_SHIFT + positionX * POS_SHIFT + positionZ

			local buildCommand = buildCommands[commandId]
			if not buildCommand then
				buildCommand = getBuildCommand() --- @class BuildCommandEntry
				buildCommand.id = commandId
				buildCommand.builderCount = 0
				buildCommand.unitDefId = unitDefId
				buildCommand.teamId = spGetUnitTeam(unitId)
				buildCommand.positionX = positionX
				buildCommand.positionY = mathFloor(params[2])
				buildCommand.positionZ = positionZ
				buildCommand.rotation = params[4] and mathFloor(params[4]) or 0
				buildCommand.isCreated = false
				buildCommand.isFinished = false
				buildCommand.builderIds = buildCommand.builderIds or {}

				buildCommands[commandId] = buildCommand
				notifyEvent(Event.onBuildCommandAdded, commandId, buildCommand)
			end

			newCommands[commandId] = true

			if not buildCommand.builderIds[unitId] then
				buildCommand.builderIds[unitId] = true
				buildCommand.builderCount = buildCommand.builderCount + 1
			end
		end
	end

	-- Step 2: Compare old commands with current commands to find what was removed
	local oldCommands = unitBuildCommands[unitId]
	if oldCommands then
		for oldCommandId, _ in pairs(oldCommands) do
			if not newCommands[oldCommandId] then
				removeBuilderFromCommand(oldCommandId, unitId)
			end
		end
		releaseRef(oldCommands)
	end

	unitBuildCommands[unitId] = newCommands

	-- Cache for queue sharing: store this result for other builders with same depth
	-- Mark as ref-counted since this table is now shared (original builder + cache)
	acquireTable(newCommands)
	local firstCmd = queue[1]
	local cacheEntry = sharedQueueCache[queueDepth]
	if not cacheEntry then
		cacheEntry = {}
		sharedQueueCache[queueDepth] = cacheEntry
	end
	cacheEntry.generation = sharedQueueGeneration
	cacheEntry.newCommands = newCommands
	if firstCmd then
		cacheEntry.firstCmdId = firstCmd.id
		local fp = firstCmd.params
		cacheEntry.firstParamX = fp and mathFloor(fp[1] or 0) or 0
		cacheEntry.firstParamZ = fp and mathFloor(fp[3] or 0) or 0
	else
		cacheEntry.firstCmdId = nil
		cacheEntry.firstParamX = 0
		cacheEntry.firstParamZ = 0
	end
end

local function clearUnit(unitId)
	local commandId = createdUnitIdToCommandIdMap[unitId]
	if not commandId then return end

	local commandData = buildCommands[commandId]
	if commandData then
		commandData.isFinished = true
		notifyEvent(Event.onUnitFinished, unitId, commandId, commandData)
	end
end

local function processNewBuildCommands()
	local processedUnits = 0
	for unitId, commandClockTime in pairs(unitsAwaitingCommandProcessing) do
		if elapsedSeconds > commandClockTime then
			checkBuilder(unitId, true)
			unitsAwaitingCommandProcessing[unitId] = nil

			processedUnits = processedUnits + 1
			if processedUnits >= MAX_UNITS_PROCESSED_PER_UPDATE then
				break
			end
		end
	end
end

local function periodicBuilderCheck()
	periodicCheckCounter = periodicCheckCounter + 1
	for unitId, _ in pairs(unitBuildCommands) do
		if (unitId + periodicCheckCounter) % PERIODIC_CHECK_DIVISOR == 1 and not unitsAwaitingCommandProcessing[unitId] then
			local forceDeepCheck = ((unitId + periodicCheckCounter) % DEEP_CHECK_DIVISOR == 1)
			checkBuilder(unitId, forceDeepCheck)
		end
	end
end

local function resetStateAndReinitialize()
	buildCommands = {}
	unitBuildCommands = {}
	commandIdToCreatedUnitIdMap = {}
	createdUnitIdToCommandIdMap = {}
	unitsAwaitingCommandProcessing = {}
	lastQueueDepth = {}
	lastCheckTime = {}
	tableRefCount = {}
	sharedQueueCache = {}
	tablePool = {}
	tablePoolSize = 0

	-- Re-scan all units
	local allUnits = spGetAllUnits()
	local allUnitsLen = #allUnits
	for i = 1, allUnitsLen do
		local unitId = allUnits[i]
		if buildersList[spGetUnitDefID(unitId)] then
			checkBuilder(unitId, true)
		end
	end
end

--------------------------------------------------------------------------------
-- API Definition
--------------------------------------------------------------------------------

--- @class BuilderQueueApi
local BuilderQueueApi = {}

---@param callback fun(commandId: string, data: BuildCommandEntry)
function BuilderQueueApi.ForEachActiveBuildCommand(callback)
	for commandId, commandEntry in pairs(buildCommands) do
		-- Only yield commands that haven't been created yet to mirror old behavior
		if commandEntry.builderCount > 0 and not commandEntry.isCreated then
			callback(commandId, commandEntry)
		end
	end
end

BuilderQueueApi.OnBuildCommandAdded = function(callback) return registerCallback(Event.onBuildCommandAdded, callback) end
BuilderQueueApi.OnBuildCommandRemoved = function(callback) return registerCallback(Event.onBuildCommandRemoved, callback) end
BuilderQueueApi.OnUnitCreated = function(callback) return registerCallback(Event.onUnitCreated, callback) end
BuilderQueueApi.OnUnitFinished = function(callback) return registerCallback(Event.onUnitFinished, callback) end
BuilderQueueApi.OnBuilderDestroyed = function(callback) return registerCallback(Event.onBuilderDestroyed, callback) end
BuilderQueueApi.UnregisterCallback = unregisterCallback

--------------------------------------------------------------------------------
-- Widget Callins
--------------------------------------------------------------------------------

function widget:Initialize()
	resetStateAndReinitialize()
	WG.BuilderQueueApi = BuilderQueueApi
end

function widget:Update(dt)
	elapsedSeconds = elapsedSeconds + dt

	if elapsedSeconds > nextUpdateTime then
		nextUpdateTime = elapsedSeconds + PERIODIC_UPDATE_INTERVAL
		-- Advance shared queue generation so cache entries from previous tick expire
		sharedQueueGeneration = sharedQueueGeneration + 1
		processNewBuildCommands()
		periodicBuilderCheck()
	end
end

function widget:PlayerChanged(playerId)
	-- Clear all data when player changes (spectating state changes)
	local myPlayerId = Spring.GetMyPlayerID()
	if playerId == myPlayerId then
		resetStateAndReinitialize()
	end
end

function widget:UnitCommand(unitId, unitDefId)
	if buildersList[unitDefId] then
		unitsAwaitingCommandProcessing[unitId] = elapsedSeconds + COMMAND_PROCESSING_DELAY
	end
end

function widget:UnitCreated(unitId, unitDefId)
	local x, _, z = spGetUnitPosition(unitId)
	if x then
		local positionX = mathFloor(x)
		local positionZ = mathFloor(z)

		local commandId = unitDefId * UDEF_SHIFT + positionX * POS_SHIFT + positionZ

		local commandData = buildCommands[commandId]
		if commandData then
			-- Just flag it, let removeBuilderFromCommand clean the memory
			commandData.isCreated = true
			commandIdToCreatedUnitIdMap[commandId] = unitId
			createdUnitIdToCommandIdMap[unitId] = commandId

			notifyEvent(Event.onUnitCreated, unitId, unitDefId, commandId, commandData)
		end
	end
end

function widget:UnitFinished(unitId)
	clearUnit(unitId)
end

function widget:UnitDestroyed(unitId, unitDefId)
	if buildersList[unitDefId] then
		unitsAwaitingCommandProcessing[unitId] = nil
		clearBuilderCommands(unitId)
		notifyEvent(Event.onBuilderDestroyed, unitId, unitDefId)
	end
	clearUnit(unitId)
end

function widget:Shutdown()
	WG.BuilderQueueApi = nil
end
