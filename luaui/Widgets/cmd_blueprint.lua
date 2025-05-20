local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Blueprint",
		desc = "Saves and queues groups of unit blueprints",
		license = "GNU GPL, v2 or later",
		layer = 1, -- after gridmenu(0), to let factories use alt+xyz hotkeys
		enabled = true,
		handler = true,
	}
end

VFS.Include("luarules/configs/customcmds.h.lua")

-- types
-- =====

---@class SerializedBlueprintUnit
---@field unitName string unit def name
---@field position Point
---@field facing number

---@class SerializedBlueprint
---@field units SerializedBlueprintUnit[]
---@field spacing number
---@field facing number
---@field name string
---@field ordered boolean

-- optimization
-- ============

local SpringGetMouseState = Spring.GetMouseState
local SpringGetModKeyState = Spring.GetModKeyState
local SpringGetActiveCommand = Spring.GetActiveCommand
local SpringTraceScreenRay = Spring.TraceScreenRay
local SpringGetUnitPosition = Spring.GetUnitPosition

-- util
-- ====

---Packs the given arguments into a table; the opposite of unpack()
---@return table
local function pack(...)
	return { ... }
end

---Returns the next index in a circular sequence, handling modulo math as appropriate for 1-indexed arrays.
---@param index number The current index.
---@param length number The length of the sequence.
---@return number
local function nextIndex(index, length)
	return index % length + 1
end

---Returns the previous index in a circular sequence, handling modulo math as appropriate for 1-indexed arrays.
---@param index number The current index.
---@param length number The length of the sequence.
---@return number
local function prevIndex(index, length)
	return (index - 2 + length) % length + 1
end

---@param tbl1 table
---@param tbl2 table
---@return boolean
local function tablesEqual(tbl1, tbl2)
	if tbl1 == tbl2 then
		return true
	end

	if not tbl1 or not tbl2 then
		return false
	end

	for k, v in pairs(tbl1) do
		if v ~= tbl2[k] then
			return false
		end
	end

	for k, v in pairs(tbl2) do
		if v ~= tbl1[k] then
			return false
		end
	end

	return true
end

---@param a Point
---@param b Point
---@return Point
local function subtractPoints(a, b)
	local result = {}
	for i = 1, math.max(#a, #b) do
		result[i] = (a[i] or 0) - (b[i] or 0)
	end
	return result
end

---Automatically maintains opengl display lists for a given function, in a memoize-like format.
---
---The returned function can be called exactly like the original, but will create or use a display list when
---appropriate. Call "invalidate" on the return function to clear the cache (such as if global data changes, or the
---lists are no longer needed).
---@param originalFunc function The function to create lists for.
---@return table The decorated function.
local function glListCache(originalFunc)
	local cache = {}

	local function clearCache()
		for key, listID in pairs(cache) do
			gl.DeleteList(listID)
		end
		cache = {}
	end

	local function decoratedFunc(...)
		local rawParams = { ... }
		local params = {}
		for index, value in ipairs(rawParams) do
			if index > 1 then
				table.insert(params, value)
			end
		end

		local key = table.toString(params)

		if cache[key] == nil then
			local function fn()
				originalFunc(unpack(params))
			end
			cache[key] = gl.CreateList(fn)
		end

		gl.CallList(cache[key])
	end

	return setmetatable({}, {
		__call = decoratedFunc,
		__index = {
			invalidate = clearCache,
			getCache = function()
				return cache
			end,
			getListID = function(...)
				local params = { ... }
				local key = table.toString(params)
				return cache[key]
			end
		}
	})
end

---@return number
local currentBlueprintUnitID = 0
local function nextBlueprintUnitID()
	currentBlueprintUnitID = currentBlueprintUnitID + 1
	return currentBlueprintUnitID
end

-- widget code
-- ===========

local sounds = {
	createBlueprint = "LuaUI/Sounds/buildbar_add.wav",
	deleteBlueprint = "LuaUI/Sounds/buildbar_rem.wav",
	selectBlueprint = "LuaUI/Sounds/buildbar_hover.wav",
	activateBlueprint = "LuaUI/Sounds/buildbar_add.wav",
	spacing = "LuaUI/Sounds/buildbar_hover.wav",
	facing = "LuaUI/Sounds/buildbar_hover.wav",
}

local keyConfig = VFS.Include("luaui/configs/keyboard_layouts.lua")
local currentLayout
local actionHotkeys

---maximum number of units in a saved blueprint
local BLUEPRINT_UNIT_LIMIT = 100

---maximum total number of orders in a given blueprint placement command
local BLUEPRINT_ORDER_LIMIT = 400

local CMD_BLUEPRINT_PLACE_DESCRIPTION = {
	id = CMD_BLUEPRINT_PLACE,
	type = CMDTYPE.ICON_MAP,
	name = "Place Blueprint",
	cursor = nil,
	action = "blueprint_place",
}

local CMD_BLUEPRINT_CREATE_DESCRIPTION = {
	id = CMD_BLUEPRINT_CREATE,
	type = CMDTYPE.ICON,
	name = "Save Blueprint",
	cursor = nil,
	action = "blueprint_create",
}

local BLUEPRINT_FILE_PATH = "LuaUI/Config/blueprints.json"

---@type Blueprint[]
local blueprints = {}

local selectedBlueprintIndex = nil

local blueprintPlacementActive = false

local state = {
	---@type Point|nil
	---non-nil implies that we are dragging
	startPosition = nil,

	---@type Point
	---end of drag motion (basically current mouse position)
	endPosition = nil,

	---@type Blueprint
	blueprint = nil,

	---@type boolean[]
	modKeys = nil,

	---@type string
	---one of WG["api_blueprint"].BUILD_MODES
	mode = nil,

	---@type number|nil
	targetID = nil,

	---@type number[]
	---{ x, y, z, facing }
	buildPositions = nil,
}

local blueprintBuildableUnitDefs = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isBuilding then
		blueprintBuildableUnitDefs[unitDefID] = true
	elseif unitDef.isBuilder and not unitDef.canMove and not unitDef.isFactory then
		-- nanos
		blueprintBuildableUnitDefs[unitDefID] = true
	elseif unitDef.customParams.mine then
		-- mines
		blueprintBuildableUnitDefs[unitDefID] = true
	end
end

local blueprintCommandableUnitDefs = {}
for builderUnitDefID, unitDef in pairs(UnitDefs) do
	for _, buildingUnitDefID in pairs(unitDef.buildOptions or {}) do
		if blueprintBuildableUnitDefs[buildingUnitDefID] then
			blueprintCommandableUnitDefs[builderUnitDefID] = true
			break
		end
	end
end

local function getSelectedBlueprint()
	return blueprints[selectedBlueprintIndex]
end

local function setSelectedBlueprintIndex(index)
	selectedBlueprintIndex = index

	if not selectedBlueprintIndex then
		WG["api_blueprint"].setActiveBlueprint(nil)
	end

	if blueprintPlacementActive and index ~= nil and index > 0 then
		Spring.Echo("[Blueprint] selected blueprint #" .. selectedBlueprintIndex)
	end
end

local function getMouseWorldPosition(blueprint, x, y)
	local _, pos = SpringTraceScreenRay(x, y, true, true, false, not blueprint.floatOnWater)
	if pos then
		pos = WG["api_blueprint"].snapBlueprint(
			blueprint,
			pos,
			blueprint.facing
		)
	end

	return pos
end

local function determineBuildMode(modKeys, targetID)
	local alt, ctrl, meta, shift = unpack(modKeys)

	local mode = nil

	if shift and ctrl and targetID then
		mode = WG["api_blueprint"].BUILD_MODES.AROUND
	elseif shift and state.startPosition then
		if alt and ctrl then
			mode = WG["api_blueprint"].BUILD_MODES.BOX
		elseif alt and not ctrl then
			mode = WG["api_blueprint"].BUILD_MODES.GRID
		elseif not alt and ctrl then
			mode = WG["api_blueprint"].BUILD_MODES.SNAPLINE
		elseif not alt and not ctrl then
			mode = WG["api_blueprint"].BUILD_MODES.LINE
		end
	else
		mode = WG["api_blueprint"].BUILD_MODES.SINGLE
	end

	return mode
end

local function determineBuildModeArgs(mode, startPosition, endPosition, targetID, spacing)
	if mode == WG["api_blueprint"].BUILD_MODES.AROUND then
		return { targetID }
	elseif mode == WG["api_blueprint"].BUILD_MODES.SINGLE then
		return { endPosition }
	else
		return { startPosition, endPosition, spacing }
	end
end

local function postProcessBlueprint(bp)
	-- precompute some useful information
	bp.dimensions = pack(WG["api_blueprint"].getBlueprintDimensions(bp))
	bp.floatOnWater = table.any(bp.units, function(u)
		return UnitDefs[u.unitDefID].floatOnWater
	end)
	bp.minBuildingDimension = table.reduce(bp.units, function(acc, u)
		local w, h = WG["api_blueprint"].getBuildingDimensions(
			u.unitDefID,
			0
		)
		if acc then
			return math.min(w, h, acc)
		else
			return math.min(w, h)
		end
	end, nil)
end

local function createBlueprint(unitIDs, ordered)
	if #unitIDs > BLUEPRINT_UNIT_LIMIT then
		Spring.Echo(string.format("[Blueprint] can only save %d units (attempted to save %d)", BLUEPRINT_UNIT_LIMIT, #unitIDs))
		return true
	end

	local buildableUnits = table.filterArray(unitIDs, function(unitID)
		local unitDefID = Spring.GetUnitDefID(unitID)
		return blueprintBuildableUnitDefs[unitDefID]
	end)

	if #buildableUnits == 0 then
		Spring.Echo("[Blueprint] no units saved")
		return
	end

	local xMin, xMax, zMin, zMax = WG["api_blueprint"].getUnitsBounds(table.map(
		buildableUnits,
		function(unitID)
			local x, y, z = SpringGetUnitPosition(unitID)
			return {
				position = { x, y, z },
				unitDefID = Spring.GetUnitDefID(unitID),
				facing = Spring.GetUnitBuildFacing(unitID),
			}
		end
	))
	local center = { (xMin + xMax) / 2, 0, (zMin + zMax) / 2 }

	local blueprint = {
		spacing = 0,
		facing = 0,
		name = "",
		ordered = ordered,
		units = table.map(
			buildableUnits,
			function(unitID)
				local x, y, z = SpringGetUnitPosition(unitID)
				local facing = Spring.GetUnitBuildFacing(unitID)

				return {
					blueprintUnitID = nextBlueprintUnitID(),
					unitDefID = Spring.GetUnitDefID(unitID),
					position = subtractPoints({ x, y, z }, center),
					facing = facing
				}
			end
		)
	}

	postProcessBlueprint(blueprint)

	blueprints[#blueprints + 1] = blueprint

	Spring.Echo("[Blueprint] saved " .. #blueprint.units .. " units into blueprint #" .. #blueprints)

	if #blueprints == 1 then
		setSelectedBlueprintIndex(1)
	end
end

local function deleteBlueprint(index)
	if index == nil or index > #blueprints then
		error("invalid blueprint index")
		return
	end

	table.remove(blueprints, index)

	Spring.Echo("[Blueprint] deleted blueprint #" .. index)

	if #blueprints == 0 then
		setSelectedBlueprintIndex(nil)
	elseif selectedBlueprintIndex > #blueprints then
		setSelectedBlueprintIndex(selectedBlueprintIndex - 1)
	elseif index < selectedBlueprintIndex then
		setSelectedBlueprintIndex(selectedBlueprintIndex - 1)
	end
end

local function setBlueprintFacing(facing)
	local bp = getSelectedBlueprint()

	if not bp then
		return
	end

	bp.facing = facing
	bp.dirty = true
end

local function setBlueprintSpacing(spacing)
	local bp = getSelectedBlueprint()

	if not bp then
		return
	end

	bp.spacing = spacing
	bp.dirty = true
end

local function updateBuildingGridState(active, blueprint)
	if WG['buildinggrid'] == nil then
		return
	end

	if active then
		local unitDefID = UnitDefNames["armuwms"].id
		if blueprint and blueprint.floatOnWater then
			-- if we have any floating units, pass a generic floating unit to buildinggrid
			unitDefID = UnitDefNames["armfmkr"].id
		end
		WG['buildinggrid'].setForceShow(
			widget:GetInfo().name,
			active and blueprint ~= nil,
			unitDefID
		)
	else
		WG['buildinggrid'].setForceShow(widget:GetInfo().name, false)
	end
end

local function setBlueprintPlacementActive(active)
	if blueprintPlacementActive ~= active then
		state = {}
	end

	blueprintPlacementActive = active

	if active then
		widget:SelectionChanged(Spring.GetSelectedUnits())

		Spring.PlaySoundFile(sounds.activateBlueprint, 0.75, "ui")
	else
		WG["api_blueprint"].setActiveBlueprint(nil)
		WG["api_blueprint"].setBlueprintPositions({})
	end

	updateBuildingGridState(active, getSelectedBlueprint())
end

-- callins
-- =======

local function set(tbl)
	local result = {}
	for _, v in ipairs(tbl) do
		result[v] = true
	end
	return result
end

local selectedUnitsOrder = {}
local selectedUnitsSet = {}
local pendingBoxSelect = false

local function updateSelectedUnits(selection)
	-- filter all by buildable
	local buildable = table.filterArray(
		selection,
		function(unitID)
			return blueprintBuildableUnitDefs[Spring.GetUnitDefID(unitID)]
		end
	)
	table.sort(buildable)
	local buildableSet = set(buildable)

	-- remove from selectionOrder and selectedUnitsSet anything not present here
	local toRemove = {}
	for unitID in pairs(selectedUnitsSet) do
		if not buildableSet[unitID] then
			toRemove[unitID] = true
		end
	end
	selectedUnitsOrder = table.filterArray(selectedUnitsOrder, function(unitID)
		return toRemove[unitID] == nil
	end)
	selectedUnitsSet = table.filterTable(selectedUnitsSet, function(_, unitID)
		return toRemove[unitID] == nil
	end)

	-- add all units that aren't in selectedUnitsSet to selectionOrder and selectedUnitsSet
	for _, unitID in ipairs(buildable) do
		if not selectedUnitsSet[unitID] then
			table.insert(selectedUnitsOrder, unitID)
			selectedUnitsSet[unitID] = true
		end
	end
end

local prevActiveCommand = nil
local prevStartPosition = nil

local UPDATE_PERIOD = 1 / 30
local totalTime = 0
local t = 0
function widget:Update(dt)
	totalTime = totalTime + dt
	t = t + dt
	if t < UPDATE_PERIOD then
		return
	end
	t = 0

	if pendingBoxSelect and not Spring.GetSelectionBox() then
		updateSelectedUnits(Spring.GetSelectedUnits())
		pendingBoxSelect = false
	end

	local _, cmdID = SpringGetActiveCommand()
	if cmdID ~= prevActiveCommand then
		setBlueprintPlacementActive(cmdID == CMD_BLUEPRINT_PLACE)
		prevActiveCommand = cmdID
	end

	local blueprint = getSelectedBlueprint()

	if not blueprintPlacementActive or not blueprint then
		return
	end

	local x, y, leftButton = SpringGetMouseState()

	if not leftButton then
		state.startPosition = nil
	end

	local blueprintChanged = false
	if blueprint ~= state.blueprint or blueprint.dirty then
		blueprintChanged = true
		state.blueprint = blueprint
		blueprint.dirty = false

		WG["api_blueprint"].setActiveBlueprint(blueprint)
		updateBuildingGridState(true, blueprint)
	end

	local modKeysChanged = false
	local modKeys = pack(SpringGetModKeyState())
	if not tablesEqual(modKeys, state.modKeys) then
		modKeysChanged = true
		state.modKeys = modKeys
	end

	local targetIDChanged = false
	local targetType, targetID = SpringTraceScreenRay(x, y, false, true, false, not blueprint.floatOnWater)
	targetID = targetType == "unit" and targetID or nil
	if targetID ~= state.targetID then
		targetIDChanged = true
		state.targetID = targetID
	end

	local startPositionChanged = false
	if state.startPosition ~= prevStartPosition then
		startPositionChanged = true
		prevStartPosition = state.startPosition
	end

	local modeChanged = false
	if modKeysChanged or targetIDChanged or startPositionChanged then
		local newMode = determineBuildMode(modKeys, targetID)
		if newMode ~= state.mode then
			modeChanged = true
			state.mode = newMode
		end
	end

	local endPositionChanged = false
	local endPosition = getMouseWorldPosition(blueprint, x, y)
	if endPosition then
		endPosition[2] = 0
	end
	if not tablesEqual(state.endPosition, endPosition) then
		endPositionChanged = true
		state.endPosition = endPosition
	end

	if endPositionChanged or modeChanged or targetIDChanged or blueprintChanged then
		state.buildPositions = WG["api_blueprint"].calculateBuildPositions(
			blueprint,
			state.mode,
			unpack(determineBuildModeArgs(
				state.mode, state.startPosition, state.endPosition, state.targetID, blueprint.spacing
			))
		)
		WG["api_blueprint"].setBlueprintPositions(state.buildPositions)
	end
end

local drawCursorText = glListCache(function(index)
	local text
	if index then
		text = "\255\220\220\240Blueprint #" .. tostring(index)
	else
		text = "\255\240\220\220No Blueprints"
	end

	gl.Text(text, 15, -12, 40, "ao")

	local hotkeys = {
		{
			name = "Next",
			key = keyConfig.sanitizeKey(actionHotkeys["blueprint_next"], currentLayout),
		},
		{
			name = "Previous",
			key = keyConfig.sanitizeKey(actionHotkeys["blueprint_prev"], currentLayout),
		},
		{
			name = "Delete",
			key = keyConfig.sanitizeKey(actionHotkeys["blueprint_delete"], currentLayout),
		},
	}

	local hotkeyText = ""
	for _, hk in ipairs(hotkeys) do
		local name, key = hk.name, hk.key
		if not key or string.len(key) == 0 then
			key = "<none>"
		end
		hotkeyText = hotkeyText .. string.format(
			"\255\255\215\100%s\255\240\240\240 - %s\n",
			key,
			name
		)
	end

	gl.Text(hotkeyText, 30, -55, 18, "ao")
end)

local function reloadBindings()
	currentLayout = Spring.GetConfigString("KeyboardLayout", "qwerty")
	actionHotkeys = VFS.Include("luaui/Include/action_hotkeys.lua")
	drawCursorText.invalidate()
end

function widget:DrawScreenEffects()
	if not blueprintPlacementActive then
		return
	end

	local x, y = SpringGetMouseState()
	if not x or not y then
		return
	end

	gl.PushMatrix()

	gl.Translate(x, y, 0)
	drawCursorText(selectedBlueprintIndex)

	gl.PopMatrix()
end

function widget:SelectionChanged(selection)
	-- track selected builders
	if blueprintPlacementActive then
		local builders = table.filterArray(
			selection,
			function(unitID)
				return blueprintCommandableUnitDefs[Spring.GetUnitDefID(unitID)]
			end
		)

		WG["api_blueprint"].setActiveBuilders(builders)
	end

	-- track selection order (skip if we're still box selecting)
	if Spring.GetSelectionBox() then
		pendingBoxSelect = true
	else
		updateSelectedUnits(selection)
	end
end

function widget:CommandsChanged()
	local selectedUnits = Spring.GetSelectedUnits()
	if #selectedUnits > 0 then
		local addPlaceCommand = false
		local addCreateCommand = false
		local customCommands = widgetHandler.customCommands

		for i = 1, #selectedUnits do
			if blueprintCommandableUnitDefs[Spring.GetUnitDefID(selectedUnits[i])] then
				addPlaceCommand = true
			end
			if blueprintBuildableUnitDefs[Spring.GetUnitDefID(selectedUnits[i])] then
				addCreateCommand = true
			end
		end

		if addPlaceCommand then
			customCommands[#customCommands + 1] = CMD_BLUEPRINT_PLACE_DESCRIPTION
		end

		if addCreateCommand then
			customCommands[#customCommands + 1] = CMD_BLUEPRINT_CREATE_DESCRIPTION
		end
	end
end

-- action handlers
-- ===============

local function handleBlueprintNextAction()
	if not blueprintPlacementActive then
		return
	end

	if #blueprints == 0 then
		Spring.Echo("[Blueprint] no saved blueprints")
		return
	end

	setSelectedBlueprintIndex(nextIndex(selectedBlueprintIndex, #blueprints))

	Spring.PlaySoundFile(sounds.selectBlueprint, 0.75, "ui")

	return true
end

local function handleBlueprintPrevAction()
	if not blueprintPlacementActive then
		return
	end

	if #blueprints == 0 then
		Spring.Echo("[Blueprint] no blueprints")
		return
	end

	setSelectedBlueprintIndex(prevIndex(selectedBlueprintIndex, #blueprints))

	Spring.PlaySoundFile(sounds.selectBlueprint, 0.75, "ui")

	return true
end

local function handleBlueprintCreateAction()
	local unitIDs = selectedUnitsOrder

	createBlueprint(unitIDs, true)
	setSelectedBlueprintIndex(#blueprints)

	Spring.PlaySoundFile(sounds.createBlueprint, 0.75, "ui")

	return true
end

local function handleBlueprintDeleteAction()
	if not blueprintPlacementActive then
		return
	end

	if #blueprints == 0 then
		Spring.Echo("[Blueprint] no blueprints to delete")
		return
	end

	if selectedBlueprintIndex == nil then
		Spring.Echo("[Blueprint] no blueprint selected")
		return
	end

	deleteBlueprint(selectedBlueprintIndex)

	Spring.PlaySoundFile(sounds.deleteBlueprint, 0.75, "ui")

	return true
end

local FACING_MAP = { south = 0, east = 1, north = 2, west = 3 }
local function handleFacingAction(_, _, args)
	local bp = getSelectedBlueprint()
	if not blueprintPlacementActive or not bp then
		return
	end

	local newFacing = nil
	if args and args[1] == "inc" then
		newFacing = (bp.facing + 1) % 4
	elseif args and args[1] == "dec" then
		newFacing = (bp.facing - 1) % 4
	elseif args and FACING_MAP[args[1]] then
		newFacing = FACING_MAP[args[1]]
	end

	if newFacing then
		setBlueprintFacing(newFacing)

		Spring.PlaySoundFile(sounds.facing, 0.75, "ui")

		return true
	end
end

local function handleSpacingAction(_, _, args)
	local bp = getSelectedBlueprint()
	if not blueprintPlacementActive or not bp then
		return
	end

	local minSpacing = math.floor(
		-(math.min(bp.dimensions[1], bp.dimensions[2]) - bp.minBuildingDimension)
			/ WG["api_blueprint"].BUILD_SQUARE_SIZE
	)

	local newSpacing = nil
	if args and args[1] == "inc" then
		newSpacing = bp.spacing + 1
	elseif args and args[1] == "dec" then
		newSpacing = bp.spacing - 1
	end

	newSpacing = math.max(minSpacing, newSpacing)

	if newSpacing then
		setBlueprintSpacing(newSpacing)

		Spring.PlaySoundFile(sounds.spacing, 0.75, "ui")

		return true
	end
end

function widget:MousePress(x, y, button)
	if button ~= 1 or not blueprintPlacementActive or not getSelectedBlueprint() then
		return
	end

	local blueprint = getSelectedBlueprint()
	local pos = getMouseWorldPosition(blueprint, x, y)
	state.startPosition = pos

	return false
end

local MOUSE_WHEEL_RATE_LIMIT = 1 / 15
local lastMouseWheelChange = nil
function widget:MouseWheel(up, value)
	if not blueprintPlacementActive or state.startPosition then
		return
	end

	local alt, ctrl, meta, shift = unpack(state.modKeys or {})

	if not alt then
		return
	end

	if lastMouseWheelChange and totalTime - lastMouseWheelChange < MOUSE_WHEEL_RATE_LIMIT then
		-- hasn't been long enough, but still consume the event
		return true
	end

	lastMouseWheelChange = totalTime

	if up then
		handleBlueprintNextAction()
	else
		handleBlueprintPrevAction()
	end

	return true
end

local function createBuildingComparator(sortSpec)
	return function(a, b)
		a = pack(Spring.Pos2BuildPos(a.unitDefID, a.position[1], a.position[2], a.position[3], a.facing))
		b = pack(Spring.Pos2BuildPos(b.unitDefID, b.position[1], b.position[2], b.position[3], b.facing))
		for _, index in ipairs(sortSpec) do
			local ascending = index > 0
			index = math.abs(index)
			if a[index] ~= b[index] then
				return (a[index] < b[index]) == ascending
			end
		end
		return false
	end
end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts)
	if cmdID == CMD_BLUEPRINT_CREATE then
		handleBlueprintCreateAction()
	elseif cmdID == CMD_BLUEPRINT_PLACE then
		local selectedBlueprint = getSelectedBlueprint()

		if not selectedBlueprint then
			Spring.Echo("[Blueprint] no active blueprints")
			return false
		end

		local builders = table.filterArray(Spring.GetSelectedUnits(),
			function(unitID)
				return blueprintCommandableUnitDefs[Spring.GetUnitDefID(unitID)]
			end
		)

		local buildPositionsLimit = BLUEPRINT_ORDER_LIMIT / (#(selectedBlueprint.units) * #builders)

		local buildings = {}

		-- cache for each rotation of the blueprint, filled as needed
		local blueprintRotations = {}

		-- set up sorting for buildings within a blueprint
		local buildingComparator
		if #(state.buildPositions) > 1 and state.startPosition and state.endPosition then
			-- sort in the direction the blueprint was placed
			local delta = subtractPoints(state.endPosition, state.startPosition)
			local xSort = delta[1] >= 0 and 1 or -1
			local zSort = delta[3] >= 0 and 3 or -3
			if math.abs(delta[1]) > math.abs(delta[3]) then
				buildingComparator = createBuildingComparator({ xSort, zSort })
			else
				buildingComparator = createBuildingComparator({ zSort, xSort })
			end
		else
			-- sort by (z ascending, x ascending)
			buildingComparator = createBuildingComparator({ 3, 1 })
		end

		-- combine the units from all blueprints into a single list
		for i, pos in ipairs(state.buildPositions) do
			if i > buildPositionsLimit then
				Spring.Echo(string.format(
					"[Blueprint] limiting orders to no more than %d",
					BLUEPRINT_ORDER_LIMIT
				))
				break
			end
			local facing = pos[4] or 0
			if not blueprintRotations[facing] then
				blueprintRotations[facing] = WG["api_blueprint"].rotateBlueprint(
					selectedBlueprint,
					selectedBlueprint.facing + facing
				)
				if not selectedBlueprint.ordered then
					table.sort(blueprintRotations[facing].units, buildingComparator)
				end
			end
			local blueprint = blueprintRotations[facing]
			table.append(buildings, table.map(blueprint.units, function(bpu)
				local x = pos[1] + bpu.position[1]
				local z = pos[3] + bpu.position[3]
				local y = Spring.GetGroundHeight(x, z)

				local sx, sy, sz = Spring.Pos2BuildPos(bpu.unitDefID, x, y, z, bpu.facing)

				return {
					blueprintUnitID = bpu.blueprintUnitID,
					unitDefID = bpu.unitDefID,
					position = { sx, sy, sz },
					facing = bpu.facing
				}
			end))
		end

		local newOpts = table.copy(cmdOpts)
		newOpts.shift = true
		local orders = table.map(buildings, function(bp, i)
			return {
				-bp.unitDefID,
				{
					bp.position[1],
					bp.position[2],
					bp.position[3],
					bp.facing
				},
				i == 1 and cmdOpts or newOpts,
			}
		end)

		Spring.GiveOrderArrayToUnitArray(builders, orders, false)

		local alt, ctrl, meta, shift = unpack(state.modKeys)
		if not shift then
			setBlueprintPlacementActive(false)
		end

		-- successfully consumed the event
		return true
	end
end

-- saving/loading
-- ==============

---@param blueprint Blueprint
---@return SerializedBlueprint
local function serializeBlueprint(blueprint)
	return {
		name = blueprint.name,
		spacing = blueprint.spacing,
		facing = blueprint.facing,
		ordered = blueprint.ordered,
		units = table.map(blueprint.units, function(blueprintUnit)
			return {
				unitName = UnitDefs[blueprintUnit.unitDefID].name,
				position = blueprintUnit.position,
				facing = blueprintUnit.facing
			}
		end),
	}
end

---@param serializedBlueprint SerializedBlueprint
---@return Blueprint
local function deserializeBlueprint(serializedBlueprint)
	local result = table.copy(serializedBlueprint)
	result.units = table.map(serializedBlueprint.units, function(serializedBlueprintUnit)
		return {
			blueprintUnitID = nextBlueprintUnitID(),
			unitDefID = UnitDefNames[serializedBlueprintUnit.unitName].id,
			position = serializedBlueprintUnit.position,
			facing = serializedBlueprintUnit.facing
		}
	end)

	postProcessBlueprint(result)

	return result
end

local function loadBlueprintsFromFile()
	local file = io.open(BLUEPRINT_FILE_PATH, "r")

	if not file then
		Spring.Echo("Failed to open blueprints file for reading: " .. BLUEPRINT_FILE_PATH)
		return
	end

	local content = file:read("*all")

	file:close()

	local decoded = Json.decode(content)

	if decoded == nil then
		Spring.Echo("Failed to decode blueprints file JSON: " .. BLUEPRINT_FILE_PATH)
		return
	end

	if type(decoded.savedBlueprints) ~= "table" then
		decoded.savedBlueprints = {}
	end

	blueprints = table.map(decoded.savedBlueprints, deserializeBlueprint)

	if #blueprints == 0 then
		setSelectedBlueprintIndex(nil)
	elseif not selectedBlueprintIndex or selectedBlueprintIndex > #blueprints then
		setSelectedBlueprintIndex(1)
	end
end

local function saveBlueprintsToFile()
	local file = io.open(BLUEPRINT_FILE_PATH, "w")

	if not file then
		Spring.Echo("Failed to open blueprints file for writing: " .. BLUEPRINT_FILE_PATH)
		return
	end

	local savedBlueprintsToWrite = blueprints
	if #savedBlueprintsToWrite == 0 then
		savedBlueprintsToWrite = 0
	else
		savedBlueprintsToWrite = table.map(savedBlueprintsToWrite, serializeBlueprint)
	end

	local encoded = Json.encode({
		savedBlueprints = savedBlueprintsToWrite
	})

	if encoded == nil then
		Spring.Echo("Failed to encode blueprints file JSON: " .. BLUEPRINT_FILE_PATH)
		return
	end

	file:write(encoded)

	file:close()
end

local loadedBlueprints = false

function widget:Initialize()
	if not WG["api_blueprint"] then
		widgetHandler:RemoveWidget(self)
		return
	end

	reloadBindings()

	WG['cmd_blueprint'] = {
		reloadBindings = reloadBindings,
	}

	loadBlueprintsFromFile()
	loadedBlueprints = true

	widgetHandler.actionHandler:AddAction(self, "blueprint_create", handleBlueprintCreateAction, nil, "p")
	widgetHandler.actionHandler:AddAction(self, "blueprint_next", handleBlueprintNextAction, nil, "p")
	widgetHandler.actionHandler:AddAction(self, "blueprint_prev", handleBlueprintPrevAction, nil, "p")
	widgetHandler.actionHandler:AddAction(self, "blueprint_delete", handleBlueprintDeleteAction, nil, "p")
	widgetHandler.actionHandler:AddAction(self, "buildfacing", handleFacingAction, nil, "p")
	widgetHandler.actionHandler:AddAction(self, "buildspacing", handleSpacingAction, nil, "p")

	widget:SelectionChanged(Spring.GetSelectedUnits())
end

function widget:Shutdown()
	if WG["api_blueprint"] then
		WG["api_blueprint"].setActiveBlueprint(nil)
		WG["api_blueprint"].setBlueprintPositions({})
	end

	WG['cmd_blueprint'] = nil

	drawCursorText.invalidate()

	updateBuildingGridState(false)

	if loadedBlueprints then
		saveBlueprintsToFile()
	end

	widgetHandler.actionHandler:RemoveAction(self, "blueprint_create", "p")
	widgetHandler.actionHandler:RemoveAction(self, "blueprint_next", "p")
	widgetHandler.actionHandler:RemoveAction(self, "blueprint_prev", "p")
	widgetHandler.actionHandler:RemoveAction(self, "blueprint_delete", "p")
	widgetHandler.actionHandler:RemoveAction(self, "buildfacing", "p")
	widgetHandler.actionHandler:RemoveAction(self, "buildspacing", "p")
end
