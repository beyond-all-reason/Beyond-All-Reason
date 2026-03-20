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

local MAX_QUEUE_DEPTH = 2000
local MAX_UNITS_PROCESSED_PER_UPDATE = 50
local PERIODIC_CHECK_DIVISOR = 30 -- every n ticks of UPDATE_INTERVAL
local DEEP_CHECK_DIVISOR = 150 -- every n ticks of UPDATE_INTERVAL
local PERIODIC_UPDATE_INTERVAL = 0.12 -- in seconds
local COMMAND_PROCESSING_DELAY = 0.13

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
local commandLookup = {}

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

local tablePool = {}
local tablePoolSize = 0

local function getTable()
	if tablePoolSize > 0 then
		local t = tablePool[tablePoolSize]
		tablePool[tablePoolSize] = nil
		tablePoolSize = tablePoolSize - 1
		return t
	end
	return {}
end

local function releaseTable(t)
	for k in pairs(t) do
		t[k] = nil
	end
	tablePoolSize = tablePoolSize + 1
	tablePool[tablePoolSize] = t
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

local function generateId(unitDefId, positionX, positionZ)
	return unitDefId .. '_' .. positionX .. '_' .. positionZ
end

local function removeBuilderFromCommand(commandId, unitId)
	local command = buildCommands[commandId]
	if command and command.builderIds[unitId] then
		command.builderIds[unitId] = nil
		command.builderCount = command.builderCount - 1

		if command.builderCount == 0 then
			local uDef = command.unitDefId
			local pX = command.positionX
			local pZ = command.positionZ
			if commandLookup[uDef] and commandLookup[uDef][pX] then
				commandLookup[uDef][pX][pZ] = nil
			end

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
	releaseTable(oldCommands)
	unitBuildCommands[unitId] = nil
end

local function checkBuilder(unitId, forceUpdate)
	local queueDepth = spGetUnitCommandCount(unitId)
	if not queueDepth or queueDepth <= 0 then
		clearBuilderCommands(unitId)
		return
	end

	if not forceUpdate and lastQueueDepth[unitId] == queueDepth then
		return
	end
	lastQueueDepth[unitId] = queueDepth

	local queue = spGetUnitCommands(unitId, mathMin(queueDepth, MAX_QUEUE_DEPTH))
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

			local lookupX = commandLookup[unitDefId]
			if not lookupX then
				lookupX = {}
				commandLookup[unitDefId] = lookupX
			end
			local lookupZ = lookupX[positionX]
			if not lookupZ then
				lookupZ = {}
				lookupX[positionX] = lookupZ
			end

			local commandId = lookupZ[positionZ]
			if not commandId then
				commandId = generateId(unitDefId, positionX, positionZ)
				lookupZ[positionZ] = commandId
			end

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
		releaseTable(oldCommands)
	end

	unitBuildCommands[unitId] = newCommands
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
	commandLookup = {}
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

	processNewBuildCommands()

	if elapsedSeconds > nextUpdateTime then
		nextUpdateTime = elapsedSeconds + PERIODIC_UPDATE_INTERVAL
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

		local commandId
		if commandLookup[unitDefId] and commandLookup[unitDefId][positionX] then
			commandId = commandLookup[unitDefId][positionX][positionZ]
		end

		if not commandId then
			commandId = generateId(unitDefId, positionX, positionZ)
		end

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
