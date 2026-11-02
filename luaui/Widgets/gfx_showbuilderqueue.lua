local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Show Builder Queue",
		desc = "Shows buildings about to be built",
		author = "WarXperiment, Decay, Floris, SuperKitowiec",
		date = "February 15, 2010",
		license = "GNU GPL, v2 or later",
		version = 9,
		layer = 55,
		enabled = true,
	}
end

local shapeOpacity = 0.24
local maxUnitShapes = 4096
local maxQueueDepth = 4
local assistGhostInterval = 0.2

-- Localized functions for performance
local tableInsert = table.insert
local mathFloor = math.floor
local mathMin = math.min
local halfPi = math.pi / 2

local spGetGroundHeight = Spring.GetGroundHeight
local spGetSpectatingState = Spring.GetSpectatingState
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitCommandCount = Spring.GetUnitCommandCount
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitBuildFacing = Spring.GetUnitBuildFacing
local spGetUnitTeam = Spring.GetUnitTeam

local CMD_REPAIR = CMD.REPAIR

local builderQueueAPI --- @type BuilderQueueApi
local builderQueueApiCallbacks = {} --- @type BuilderQueueEventCallback[]

--Changelog
-- before v2 developed by WarXperiment
-- v2 [teh]decay - fixed crash: Error in DrawWorld(): [string "LuaUI/Widgets/unit_showbuild.lua"]:82: bad argument #1 to 'GetTeamColor' (number expected, got no value)
-- v3 [teh]decay - updated for spring 98 engine -- project page on github: https://github.com/jamerlan/unit_showbuild
-- v4 Floris - lots of performance increases
-- v5 Floris - cleanup, polishing and fixes
-- v6 Floris - limited to not show when (would be) icon
-- v7 Floris - simplified/cleanup
-- v8 Floris - GL4 unit shape rendering
-- v9 SuperKitowiec - Extract builder queue related code to api_builder_queue.lua.

local myPlayerId = Spring.GetLocalPlayerID()
local _, fullView, _ = spGetSpectatingState()

local reInitialize

local isBuilder = {}
local isBuildOption = {}
local unitWaterlineMap = {} -- ensure proper display of submerged buildings
for unitDefId, unitDefinition in ipairs(UnitDefs) do
	if unitDefinition.isBuilder and not unitDefinition.isFactory and unitDefinition.buildOptions[1] then
		isBuilder[unitDefId] = true
		for _, optionDefId in ipairs(unitDefinition.buildOptions) do
			isBuildOption[optionDefId] = true
		end
	end
	if unitDefinition.waterline and unitDefinition.waterline > 0 then
		unitWaterlineMap[unitDefId] = unitDefinition.waterline
	end
end

local numUnitShapes = 0
local unitShapes = {}
local removedUnitShapes = {}

local assistGhosts = {}
local assistedFrameDefIds = {}
local assistGhostTimer = 0

--- @param buildCommand BuildCommandEntry
local function drawUnitShape(shapeId, unitDefId, groundHeight, buildCommand)
	if not WG.DrawUnitShapeGL4 then
		widget:Shutdown()
	end
	local px = buildCommand.positionX
	local pz = buildCommand.positionZ
	local rotationY = buildCommand.rotation and (buildCommand.rotation * halfPi) or 0
	local teamId = buildCommand.teamId
	local py = groundHeight

	if numUnitShapes < maxUnitShapes and not removedUnitShapes[shapeId] then
		unitShapes[shapeId] = WG.DrawUnitShapeGL4(unitDefId, px, py - 0.01, pz, rotationY, shapeOpacity, teamId)
		numUnitShapes = numUnitShapes + 1
		return unitShapes[shapeId]
	else
		return nil
	end
end

local function removeUnitShape(shapeId)
	if not unitShapes[shapeId] then
		return
	end
	if not WG.StopDrawUnitShapeGL4 then
		widget:Shutdown()
	elseif shapeId and unitShapes[shapeId] then
		WG.StopDrawUnitShapeGL4(unitShapes[shapeId])
		numUnitShapes = numUnitShapes - 1
		unitShapes[shapeId] = nil
		removedUnitShapes[shapeId] = true
	end
end

-- Event handlers for API notifications
--- @param id string
--- @param buildCommand BuildCommandEntry
local function onBuildCommandAdded(id, buildCommand)
	if unitShapes[id] or removedUnitShapes[id] then
		return
	end
	local unitDefId = buildCommand.unitDefId
	local groundHeight = spGetGroundHeight(buildCommand.positionX, buildCommand.positionZ)
	if unitWaterlineMap[unitDefId] then
		groundHeight = math.max(groundHeight, -1 * unitWaterlineMap[unitDefId])
	end
	drawUnitShape(id, unitDefId, groundHeight, buildCommand)
end

local function onBuildCommandRemoved(commandId)
	removeUnitShape(commandId)
end

--- @param buildCommand BuildCommandEntry
local function onBuildCommandTeamChanged(id, buildCommand)
	if unitShapes[id] then
		removeUnitShape(id)
		removedUnitShapes[id] = nil
		onBuildCommandAdded(id, buildCommand)
	end
end

local function onUnitCreated(_, _, commandId)
	removeUnitShape(commandId)
end

local function onUnitFinished(_, commandId)
	removeUnitShape(commandId)
end

-- TODO: Absorb assist nofications into the builder queue API, probably.
local function updateAssistGhosts()
	local selectedUnits = spGetSelectedUnits()

	local hasAssistedFrame = false
	for frameId in pairs(assistedFrameDefIds) do
		assistedFrameDefIds[frameId] = nil
	end
	for i = 1, #selectedUnits do
		local unitId = selectedUnits[i]
		if isBuilder[spGetUnitDefID(unitId)] then
			for c = 1, mathMin(maxQueueDepth, spGetUnitCommandCount(unitId)) do
				local cmdId, _, _, paramX, paramY = spGetUnitCurrentCommand(unitId, c)
				if cmdId == CMD_REPAIR and paramX and not paramY and spGetUnitIsBeingBuilt(paramX) then
					local frameDefId = spGetUnitDefID(paramX)
					if isBuildOption[frameDefId] then
						assistedFrameDefIds[paramX] = frameDefId
						hasAssistedFrame = true
					end
				end
			end
		end
	end

	-- The engine draws build ghosts for selected units, but skips build-assisters.
	if hasAssistedFrame then
		for i = 1, #selectedUnits do
			local unitId = selectedUnits[i]
			if isBuilder[spGetUnitDefID(unitId)] then
				for c = 1, mathMin(maxQueueDepth, spGetUnitCommandCount(unitId)) do
					local cmdId, _, _, paramX, _, paramZ = spGetUnitCurrentCommand(unitId, c)
					if cmdId and cmdId < 0 and paramZ then
						for frameId, frameDefId in pairs(assistedFrameDefIds) do
							if frameDefId == -cmdId then
								local frameX, _, frameZ = spGetUnitPosition(frameId)
								if
									mathFloor(frameX) == mathFloor(paramX)
									and mathFloor(frameZ) == mathFloor(paramZ)
								then
									assistedFrameDefIds[frameId] = nil
								end
							end
						end
					end
				end
			end
		end
	end

	for frameId in pairs(assistGhosts) do
		if not assistedFrameDefIds[frameId] then
			removeUnitShape(frameId)
			assistGhosts[frameId] = nil
		end
	end

	for frameId, frameDefId in pairs(assistedFrameDefIds) do
		if not assistGhosts[frameId] then
			local frameX, _, frameZ = spGetUnitPosition(frameId)
			local assistGhost = {
				unitDefId = frameDefId,
				teamId = spGetUnitTeam(frameId),
				positionX = frameX,
				positionZ = frameZ,
				rotation = spGetUnitBuildFacing(frameId) or 0,
			}
			onBuildCommandAdded(frameId, assistGhost)
			if unitShapes[frameId] then
				assistGhosts[frameId] = assistGhost
			end
		end
	end
end

function widget:Initialize()
	if not WG.DrawUnitShapeGL4 then
		widgetHandler:RemoveWidget()
	else
		widget:Shutdown() -- to clear first
	end

	if not WG.BuilderQueueApi then
		error("API Builder Queue is disabled")
		widget:Shutdown()
		return
	end

	builderQueueAPI = WG.BuilderQueueApi

	-- Register event callbacks
	tableInsert(builderQueueApiCallbacks, builderQueueAPI.OnBuildCommandAdded(onBuildCommandAdded))
	tableInsert(builderQueueApiCallbacks, builderQueueAPI.OnBuildCommandRemoved(onBuildCommandRemoved))
	tableInsert(builderQueueApiCallbacks, builderQueueAPI.OnBuildCommandTeamChanged(onBuildCommandTeamChanged))
	tableInsert(builderQueueApiCallbacks, builderQueueAPI.OnUnitCreated(onUnitCreated))
	tableInsert(builderQueueApiCallbacks, builderQueueAPI.OnUnitFinished(onUnitFinished))

	unitShapes = {}
	assistGhosts = {}
	removedUnitShapes = {}
	numUnitShapes = 0

	-- Initialize shapes for existing build commands
	builderQueueAPI.ForEachActiveBuildCommand(function(commandId, commandData)
		onBuildCommandAdded(commandId, commandData)
	end)
end

function widget:Shutdown()
	if WG.StopDrawUnitShapeGL4 then
		for shapeId, _ in pairs(unitShapes) do
			removeUnitShape(shapeId)
		end
	end

	for i = 1, #builderQueueApiCallbacks do
		local callbackData = builderQueueApiCallbacks[i]
		builderQueueAPI.UnregisterCallback(callbackData.eventName, callbackData.callback)
		builderQueueApiCallbacks[i] = nil
	end
end

function widget:PlayerChanged(playerId)
	local prevFullView = fullView
	_, fullView, _ = spGetSpectatingState()
	if playerId == myPlayerId and prevFullView ~= fullView then
		reInitialize = true
	end
end

local prevGuiHidden = Spring.IsGUIHidden()

function widget:Update(dt)
	if not WG.BuilderQueueApi then
		error("API Builder Queue is disabled")
		widget:Shutdown()
		return
	end

	local isGuiHidden = Spring.IsGUIHidden()

	if not isGuiHidden then
		if reInitialize then
			reInitialize = nil
			widget:Initialize()
		end

		for k in pairs(removedUnitShapes) do
			removedUnitShapes[k] = nil
		end

		assistGhostTimer = assistGhostTimer - dt
		if assistGhostTimer <= 0 then
			assistGhostTimer = assistGhostInterval
			updateAssistGhosts()
		end
	end

	if isGuiHidden ~= prevGuiHidden then
		prevGuiHidden = isGuiHidden
		if isGuiHidden then
			widget:Shutdown()
		else
			widget:Initialize()
		end
	end
end

function widget:SelectionChanged()
	assistGhostTimer = 0
end

function widget:UnitFinished(unitId)
	if assistGhosts[unitId] then
		removeUnitShape(unitId)
		assistGhosts[unitId] = nil
	end
end

function widget:UnitDestroyed(unitId)
	if assistGhosts[unitId] then
		removeUnitShape(unitId)
		assistGhosts[unitId] = nil
	end
end
