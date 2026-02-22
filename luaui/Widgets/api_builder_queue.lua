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
local stringFormat = string.format
local tableInsert = table.insert
local tableRemove = table.remove
local pairs = pairs
local ipairs = ipairs
local osClock = os.clock

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local MAX_QUEUE_DEPTH = 2000

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
local lastUpdateTime = 0
local nextUpdateTime = 0.12
local periodicCheckCounter = 1

-- Reusable table for checkBuilder to reduce allocations
local tempCurrentCommands = {}

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
	cmd.builderCount = nil
	cmd.unitDefId = nil
	cmd.teamId = nil
	cmd.positionX = nil
	cmd.positionY = nil
	cmd.positionZ = nil
	cmd.rotation = nil
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
---
local function generateId(unitDefId, positionX, positionZ)
	-- Direct concatenation is faster than string.format for simple cases
	return unitDefId .. '_' .. positionX .. '_' .. positionZ
end

local function removeBuilderFromCommand(commandId, unitId)
	local command = buildCommands[commandId]
	if command and command.builderIds[unitId] then
		command.builderIds[unitId] = nil
		command.builderCount = command.builderCount - 1
		if command.builderCount == 0 then
			local commandData = command
			buildCommands[commandId] = nil
			recycleBuildCommand(commandData)
			notifyEvent(Event.onBuildCommandRemoved, commandId, commandData)
		end
	end
end

local function clearBuilderCommands(unitId)
	if not unitBuildCommands[unitId] then
		return
	end

	for commandId, _ in pairs(unitBuildCommands[unitId]) do
		removeBuilderFromCommand(commandId, unitId)
	end
	unitBuildCommands[unitId] = nil
end

local function checkBuilder(unitId)
	local queueDepth = spGetUnitCommandCount(unitId)
	if not queueDepth or queueDepth <= 0 then
		clearBuilderCommands(unitId)
		return
	end

	-- Reuse table instead of creating new one every call
	local currentCommands = tempCurrentCommands
	-- Clear previous data
	for k in pairs(currentCommands) do
		currentCommands[k] = nil
	end

	local queue = spGetUnitCommands(unitId, mathMin(queueDepth, MAX_QUEUE_DEPTH))

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
			local commandId = generateId(unitDefId, positionX, positionZ)

			currentCommands[commandId] = true

			if commandIdToCreatedUnitIdMap[commandId] == nil then
				local isNewCommand = false
				local buildCommand = buildCommands[commandId]
				if buildCommand == nil then
					buildCommand = getBuildCommand() --- @class BuildCommandEntry
					buildCommand.builderCount = 0
					buildCommand.unitDefId = unitDefId
					buildCommand.teamId = spGetUnitTeam(unitId)
					buildCommand.positionX = positionX
					buildCommand.positionY = mathFloor(params[2])
					buildCommand.positionZ = positionZ
					buildCommand.rotation = params[4] and mathFloor(params[4]) or 0
					buildCommand.builderIds = buildCommand.builderIds or {}
					buildCommands[commandId] = buildCommand
					isNewCommand = true
				end

				if not buildCommand.builderIds[unitId] then
					buildCommand.builderIds[unitId] = true
					buildCommand.builderCount = buildCommand.builderCount + 1
				end

				if isNewCommand then
					notifyEvent(Event.onBuildCommandAdded, commandId, buildCommand)
				end
			end
		end
	end

	-- Step 2: Compare old commands with current commands to find what was removed
	local oldCommands = unitBuildCommands[unitId]
	if oldCommands then
		for oldCommandId, _ in pairs(oldCommands) do
			if not currentCommands[oldCommandId] then
				removeBuilderFromCommand(oldCommandId, unitId)
			end
		end
	end

	-- Store current commands for this unit (create new table since we reuse tempCurrentCommands)
	local commandsCopy = {}
	for cmdId in pairs(currentCommands) do
		commandsCopy[cmdId] = true
	end
	unitBuildCommands[unitId] = commandsCopy
end

local function clearUnit(unitId)
	if not createdUnitIdToCommandIdMap[unitId] then
		return
	end
	local commandId = createdUnitIdToCommandIdMap[unitId]
	local commandData = buildCommands[commandId]
	buildCommands[commandId] = nil
	commandIdToCreatedUnitIdMap[commandId] = nil
	createdUnitIdToCommandIdMap[unitId] = nil
	if commandData then
		recycleBuildCommand(commandData)
	end
	notifyEvent(Event.onUnitFinished, unitId, commandId, commandData)
end

local function processNewBuildCommands()
	local currentTime = osClock()
	for unitId, commandClockTime in pairs(unitsAwaitingCommandProcessing) do
		if currentTime > commandClockTime then
			checkBuilder(unitId)
			unitsAwaitingCommandProcessing[unitId] = nil
		end
	end
end

local function periodicBuilderCheck()
	periodicCheckCounter = periodicCheckCounter + 1
	for unitId, _ in pairs(unitBuildCommands) do
		--- Load balancer which ensures that at most 30 units are checked per frame
		if (unitId + periodicCheckCounter) % 30 == 1 and not unitsAwaitingCommandProcessing[unitId] then
			checkBuilder(unitId)
		end
	end
end

local function resetStateAndReinitialize()
	buildCommands = {}
	unitBuildCommands = {}
	commandIdToCreatedUnitIdMap = {}
	createdUnitIdToCommandIdMap = {}
	unitsAwaitingCommandProcessing = {}

	-- Re-scan all units
	local allUnits = spGetAllUnits()
	local allUnitsLen = #allUnits
	for i = 1, allUnitsLen do
		local unitId = allUnits[i]
		if buildersList[spGetUnitDefID(unitId)] then
			checkBuilder(unitId)
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
		if commandEntry.builderCount > 0 then
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
		nextUpdateTime = elapsedSeconds + 0.12
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
		unitsAwaitingCommandProcessing[unitId] = osClock() + 0.13
	end
end

function widget:UnitCreated(unitId, unitDefId)
	local x, _, z = spGetUnitPosition(unitId)
	if x then
		local commandId = generateId(unitDefId, mathFloor(x), mathFloor(z))
		local commandData = buildCommands[commandId]
		buildCommands[commandId] = nil
		commandIdToCreatedUnitIdMap[commandId] = unitId
		createdUnitIdToCommandIdMap[unitId] = commandId
		notifyEvent(Event.onUnitCreated, unitId, unitDefId, commandId, commandData)
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
