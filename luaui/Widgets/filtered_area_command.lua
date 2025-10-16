local widget = widget ---@type RulesUnsyncedCallins

function widget:GetInfo()
	return {
		name = "Area Command Filter",
		desc = "Hold Alt or Ctrl with an area command (Reclaim, Load, Attack, etc.) centered on a unit or feature to filter targets.",
		author = "SuperKitowiec. Based on Specific Unit Reclaimer and Loader by Google Frog",
		date = "October 16, 2025",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end
local spGiveOrderToUnitArray = Spring.GiveOrderToUnitArray
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spTraceScreenRay = Spring.TraceScreenRay
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetFeatureDefID = Spring.GetFeatureDefID
local spGetFeaturesInCylinder = Spring.GetFeaturesInCylinder
local spGetSpectatingState = Spring.GetSpectatingState
local spGetGameFrame = Spring.GetGameFrame
local spGetMyTeamID = Spring.GetMyTeamID
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spIsReplay = Spring.IsReplay
local log = Spring.Echo

local ENEMY_TEAM_ID = -4

local myTeamID
local myAllyTeamID
local gameStarted

local function giveOrders(cmdId, selectedUnits, filteredTargets, options)
	local count = 0
	for _, targetId in ipairs(filteredTargets) do
		local cmdOpts = {}
		if count > 0 or (options.shift and not options.meta) then
			table.insert(cmdOpts, "shift")
		end
		if options.meta and not options.shift then
			spGiveOrderToUnitArray(selectedUnits, CMD.INSERT, { 0, cmdId, 0, targetId }, CMD.OPT_ALT)
		else
			spGiveOrderToUnitArray(selectedUnits, cmdId, { targetId }, cmdOpts)
		end
		count = count + 1
	end
end

local function splitTargets(selectedUnits, filteredTargets)
	local unitTargetsMap = {}
	for unitIdx, selectedUnitId in ipairs(selectedUnits) do
		unitTargetsMap[selectedUnitId] = {}
		for targetIdx, targetUnitId in ipairs(filteredTargets) do
			if targetIdx % #filteredTargets == unitIdx % #filteredTargets or unitIdx % #selectedUnits == targetIdx % #selectedUnits then
				table.insert(unitTargetsMap[selectedUnitId], targetUnitId)
			end
		end
	end
	return unitTargetsMap
end

--- Each unit gets a chunk of the queue
local function splitOrders(cmdId, selectedUnits, filteredTargets, options)
	local unitTargetsMap = splitTargets(selectedUnits, filteredTargets)
	for targetId, targets in pairs(unitTargetsMap) do
		giveOrders(cmdId, { targetId }, targets, options)
	end
end

--- All units share the same order queue. Queue can be distributed with shift+meta
local function defaultHandler(cmdId, selectedUnits, filteredTargets, options)
	if options.shift and options.meta then
		splitOrders(cmdId, selectedUnits, filteredTargets, options)
	else
		giveOrders(cmdId, selectedUnits, filteredTargets, options)
	end
end

--- Each transport picks one target
local function loadUnitsHandler(cmdId, selectedUnits, filteredTargets, options)
	local unitTargetsMap = splitTargets(selectedUnits, filteredTargets)
	for targetId, targets in pairs(unitTargetsMap) do
		if #targets > 0 then
			giveOrders(cmdId, { targetId }, { targets[1] }, options)
		end
	end
end

local TargetType = {
	Feature = "feature",
	Unit = "unit",
}

---@class CommandConfig
---@field handle function
---@field targetType "feature" | "unit"
---@field skipAlliedUnits? boolean

---@type table<number, CommandConfig>
local allowedCommands = {
	[CMD.ATTACK] = { handle = defaultHandler, targetType = TargetType.Unit, skipAlliedUnits = true },
	[CMD.GUARD] = { handle = defaultHandler, targetType = TargetType.Unit },
	[CMD.RECLAIM] = { handle = defaultHandler, targetType = TargetType.Unit },
	[CMD.REPAIR] = { handle = defaultHandler, targetType = TargetType.Unit },
	[CMD.CAPTURE] = { handle = defaultHandler, targetType = TargetType.Unit },
	[GameCMD.UNIT_SET_TARGET] = { handle = defaultHandler, targetType = TargetType.Unit },
	[GameCMD.UNIT_SET_TARGET_NO_GROUND] = { handle = defaultHandler, targetType = TargetType.Unit },
	[CMD.RESURRECT] = { handle = defaultHandler, targetType = TargetType.Feature },
	[CMD.LOAD_UNITS] = { handle = loadUnitsHandler, targetType = TargetType.Unit },
}

local function filterUnits(targetId, cmdX, cmdZ, radius, options, skipAlliedUnits)
	local filteredTargets = {}
	local unitDefId = spGetUnitDefID(targetId)
	if not unitDefId then
		return nil
	end

	local isEnemyTarget = (spGetUnitAllyTeam(targetId) ~= myAllyTeamID)

	local unitsInArea
	if isEnemyTarget then
		unitsInArea = spGetUnitsInCylinder(cmdX, cmdZ, radius, ENEMY_TEAM_ID)
	elseif not skipAlliedUnits then
		unitsInArea = spGetUnitsInCylinder(cmdX, cmdZ, radius, myTeamID)
	end
	if not unitsInArea then
		return nil
	end

	for i = 1, #unitsInArea do
		local unitID = unitsInArea[i]
		if options.ctrl or (options.alt and spGetUnitDefID(unitID) == unitDefId) then
			table.insert(filteredTargets, unitID)
		end
	end
	return filteredTargets
end

local function filterFeatures(targetId, cmdX, cmdZ, radius, options)
	local filteredTargets = {}
	local featureDefId = spGetFeatureDefID(targetId)
	if not featureDefId then
		return nil
	end

	local featuresInArea = spGetFeaturesInCylinder(cmdX, cmdZ, radius)
	if not featuresInArea then
		return nil
	end

	for i = 1, #featuresInArea do
		local featureId = featuresInArea[i]
		if options.alt and spGetFeatureDefID(featureId) == featureDefId then
			-- featureId is normalised to Game.maxUnits + featureId because of:
			-- https://springrts.com/wiki/Lua_CMDs#CMDTYPE.ICON_UNIT_FEATURE_OR_AREA
			-- "expect 1 parameter in return (unitid or Game.maxUnits+featureid)"
			featureId = Game.maxUnits + featureId
			table.insert(filteredTargets, featureId)
		end
	end
	return filteredTargets
end

function widget:CommandNotify(cmdId, params, options)
	if not (options.alt or options.ctrl) then
		return false
	end

	if #params ~= 4 then
		return false
	end

	local currentCommand = allowedCommands[cmdId]
	if not currentCommand then
		return false
	end

	local selectedUnits = spGetSelectedUnits()
	if #selectedUnits == 0 then
		return false
	end

	local cmdX, cmdY, cmdZ, radius = params[1], params[2], params[3], params[4]
	local mouseX, mouseY = spWorldToScreenCoords(cmdX, cmdY, cmdZ)
	local targetType, targetId = spTraceScreenRay(mouseX, mouseY)

	if targetType ~= currentCommand.targetType then
		return false
	end

	local filteredTargets

	if currentCommand.targetType == TargetType.Unit then
		filteredTargets = filterUnits(targetId, cmdX, cmdZ, radius, options, currentCommand.skipAlliedUnits)
	elseif currentCommand.targetType == TargetType.Feature then
		filteredTargets = filterFeatures(targetId, cmdX, cmdZ, radius, options)
	end

	if not filteredTargets or #filteredTargets == 0 then
		return false
	end

	currentCommand.handle(cmdId, selectedUnits, filteredTargets, options)
	return true
end

local function maybeRemoveSelf()
	if spGetSpectatingState() and (spGetGameFrame() > 0 or gameStarted) then
		widgetHandler:RemoveWidget()
	end
end

function widget:GameStart()
	gameStarted = true
	maybeRemoveSelf()
end

function widget:PlayerChanged(playerID)
	maybeRemoveSelf()
	myTeamID = spGetMyTeamID()
	myAllyTeamID = spGetMyAllyTeamID()
end

function widget:Initialize()
	myTeamID = spGetMyTeamID()
	myAllyTeamID = spGetMyAllyTeamID()

	if spIsReplay() or spGetGameFrame() > 0 then
		maybeRemoveSelf()
	end
end
