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

local floor = math.floor

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
local periodicCheckCounter = 1

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

for unitDefId, unitDefinition in ipairs(UnitDefs) do
	if unitDefinition.isBuilder and not unitDefinition.isFactory and unitDefinition.buildOptions[1] then
		buildersList[unitDefId] = true
	end
end

--------------------------------------------------------------------------------
-- Event System Functions
--------------------------------------------------------------------------------

local function notifyEvent(eventName, ...)
	for _, callback in pairs(eventCallbacks[eventName] or {}) do
		callback(...)
	end
end

---@param eventName string
---@param callback function()
local function registerCallback(eventName, callback)
	if eventCallbacks[eventName] then
		table.insert(eventCallbacks[eventName], callback)
	else
		spEcho("Warn: Unknown event name " .. eventName)
	end
	---@class BuilderQueueEventCallback
	local callbackEntry = {}
	callbackEntry.eventName = eventName
	callbackEntry.callback = callback
	return callbackEntry
end

local function unregisterCallback(eventName, callback)
	if eventCallbacks[eventName] then
		for i, registeredCallback in ipairs(eventCallbacks[eventName]) do
			if registeredCallback == callback then
				table.remove(eventCallbacks[eventName], i)
				break
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
	return string.format('%s_%s_%s', unitDefId, positionX, positionZ)
end

local function removeBuilderFromCommand(commandId, unitId)
	local command = buildCommands[commandId]
	if command and command.builderIds[unitId] then
		command.builderIds[unitId] = nil
		command.builderCount = command.builderCount - 1
		if command.builderCount == 0 then
			local commandData = command
			buildCommands[commandId] = nil
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

	local currentCommands = {}
	local queue = spGetUnitCommands(unitId, math.min(queueDepth, MAX_QUEUE_DEPTH))

	-- Step 1: Process the current queue and identify active commands
	for i = 1, #queue do
		local queueCommand = queue[i]
		if queueCommand.id < 0 then
			local unitDefId = math.abs(queueCommand.id)
			local positionX = floor(queueCommand.params[1])
			local positionZ = floor(queueCommand.params[3])
			local commandId = generateId(unitDefId, positionX, positionZ)

			currentCommands[commandId] = true

			if commandIdToCreatedUnitIdMap[commandId] == nil then
				local isNewCommand = false
				if buildCommands[commandId] == nil then
					local buildCommand = {} --- @class BuildCommandEntry
					buildCommand.builderCount = 0
					buildCommand.unitDefId = unitDefId
					buildCommand.teamId = spGetUnitTeam(unitId)
					buildCommand.positionX = positionX
					buildCommand.positionY = floor(queueCommand.params[2])
					buildCommand.positionZ = positionZ
					buildCommand.rotation = queueCommand.params[4] and floor(queueCommand.params[4]) or 0
					buildCommand.builderIds = {}
					buildCommands[commandId] = buildCommand
					isNewCommand = true
				end

				if not buildCommands[commandId].builderIds[unitId] then
					buildCommands[commandId].builderIds[unitId] = true
					buildCommands[commandId].builderCount = buildCommands[commandId].builderCount + 1
				end

				if isNewCommand then
					notifyEvent(Event.onBuildCommandAdded, commandId, buildCommands[commandId])
				end
			end
		end
	end

	-- Step 2: Compare old commands with current commands to find what was removed
	if unitBuildCommands[unitId] then
		for oldCommandId, _ in pairs(unitBuildCommands[unitId]) do
			if not currentCommands[oldCommandId] then
				removeBuilderFromCommand(oldCommandId, unitId)
			end
		end
	end

	unitBuildCommands[unitId] = currentCommands
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
	notifyEvent(Event.onUnitFinished, unitId, commandId, commandData)
end

local function processNewBuildCommands()
	local currentTime = os.clock()
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
	for i = 1, #allUnits do
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
	if elapsedSeconds > lastUpdateTime + 0.12 then
		lastUpdateTime = elapsedSeconds
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
		unitsAwaitingCommandProcessing[unitId] = os.clock() + 0.13
	end
end

function widget:UnitCreated(unitId, unitDefId)
	local x, _, z = spGetUnitPosition(unitId)
	if x then
		local commandId = generateId(unitDefId, floor(x), floor(z))
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
