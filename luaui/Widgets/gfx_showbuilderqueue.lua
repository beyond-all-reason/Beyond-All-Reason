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

local shapeOpacity = 0.26
local maxUnitShapes = 4096

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

local myPlayerId = Spring.GetMyPlayerID()
local _, fullView, _ = Spring.GetSpectatingState()

local spGetGroundHeight = Spring.GetGroundHeight
local halfPi = math.pi / 2

local reInitialize

local numUnitShapes = 0
local unitShapes = {}
local removedUnitShapes = {}

local builderQueueAPI --- @type BuilderQueueApi
local builderQueueApiCallbacks = {} --- @type BuilderQueueEventCallback[]

-- Used to ensure proper display of submerged buildings
local unitWaterlineMap = {}

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

local function onUnitCreated(_, _, commandId)
	removeUnitShape(commandId)
end

local function onUnitFinished(_, commandId)
	removeUnitShape(commandId)
end

function widget:Initialize()
	if not WG.DrawUnitShapeGL4 then
		widgetHandler:RemoveWidget()
	else
		widget:Shutdown()    -- to clear first
	end

	if not WG.BuilderQueueApi then
		error("API Builder Queue is disabled")
		widget:Shutdown()
		return
	end

	builderQueueAPI = WG.BuilderQueueApi

	for unitDefId, unitDefinition in ipairs(UnitDefs) do
		if unitDefinition.waterline and unitDefinition.waterline > 0 then
			unitWaterlineMap[unitDefId] = unitDefinition.waterline
		end
	end

	-- Register event callbacks
	table.insert(builderQueueApiCallbacks, builderQueueAPI.OnBuildCommandAdded(onBuildCommandAdded))
	table.insert(builderQueueApiCallbacks, builderQueueAPI.OnBuildCommandRemoved(onBuildCommandRemoved))
	table.insert(builderQueueApiCallbacks, builderQueueAPI.OnUnitCreated(onUnitCreated))
	table.insert(builderQueueApiCallbacks, builderQueueAPI.OnUnitFinished(onUnitFinished))

	unitShapes = {}
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
	for _, callbackData in ipairs(builderQueueApiCallbacks) do
		builderQueueAPI.UnregisterCallback(callbackData.eventName, callbackData.callback)
	end
end

function widget:PlayerChanged(playerId)
	local prevFullView = fullView
	_, fullView, _ = Spring.GetSpectatingState()
	if playerId == myPlayerId and prevFullView ~= fullView then
		reInitialize = true
	end
end

local prevGuiHidden = Spring.IsGUIHidden()

function widget:Update()
	if not Spring.IsGUIHidden() then
		if reInitialize then
			reInitialize = nil
			widget:Initialize()
		end
		removedUnitShapes = {}
	end
	if Spring.IsGUIHidden() ~= prevGuiHidden then
		prevGuiHidden = Spring.IsGUIHidden()
		if prevGuiHidden then
			widget:Shutdown()
		else
			widget:Initialize()
		end
	end
end

