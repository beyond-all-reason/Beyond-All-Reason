if not RmlUi then
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Collision Volume Editor",
		desc = "RmlUi developer tool for live unit collision-volume editing",
		author = "BAR contributors",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1000003,
		enabled = false,
		handler = true, -- close/Escape persistently disable this opt-in developer widget
	}
end

local Spring = Spring
local WG = WG
local RmlUi = RmlUi
local widgetHandler = widgetHandler

local RML_PATH = "luaui/RmlWidgets/gui_collision_volume_editor/gui_collision_volume_editor.rml"
local MODEL_NAME = "collision_volume_editor_model"
local DOCUMENT_NAME = "collision_volume_editor"
local PACKET_PREFIX = "cve|"

local VOLUME_TYPES = {
	[0] = "Ellipsoid",
	[1] = "Cylinder",
	[2] = "Box",
	[3] = "Sphere",
}

local TYPE_DEF_NAMES = {
	[0] = "Ellipsoid",
	[1] = "Cyl",
	[2] = "Box",
	[3] = "Sphere",
}

local AXIS_NAMES = { [0] = "X", [1] = "Y", [2] = "Z" }
local FIELD_IDS = {
	sx = "cve-slider-sx", sy = "cve-slider-sy", sz = "cve-slider-sz",
	ox = "cve-slider-ox", oy = "cve-slider-oy", oz = "cve-slider-oz",
}

local state = {
	context = nil,
	document = nil,
	dmHandle = nil,
	rootElement = nil,
	dragHandle = nil,
	selectedUnitID = nil,
	selectedPieceIndex = 1,
	pieceNames = {},
	pieceTreeSupported = false,
	pieceMode = false,
	draggingField = nil,
	lastSliderValue = {},
	sliderBounds = { sx = 512, sy = 512, sz = 512, ox = 256, oy = 256, oz = 256 },
	refreshDelay = 0,
	refreshClock = 0,
	lobbyHidden = false,
	debugViewActive = false,
	projectNextUpdate = false,
	pendingAction = nil,
}

local draft = {
	sx = 1, sy = 1, sz = 1,
	ox = 0, oy = 0, oz = 0,
	volumeType = 3,
	testType = 1,
	axis = 2,
	enabled = true,
}

local function setModel(field, value)
	local dm = state.dmHandle
	if dm and dm[field] ~= value then
		dm[field] = value
	end
end

local function formatNumber(value)
	if math.abs(value - math.floor(value + 0.5)) < 0.0005 then
		return string.format("%.0f", value)
	end
	return (string.format("%.3f", value):gsub("0+$", ""):gsub("%.$", ""))
end

local function setStatus(message, isError)
	setModel("status", message or "")
	setModel("statusError", isError == true)
end

local function canEdit()
	if not state.selectedUnitID then
		setStatus("Select exactly one unit.", true)
		return false
	end
	if state.pieceMode and not state.pieceTreeSupported then
		setStatus("This unit must set usePieceCollisionVolumes=true and be respawned before piece volumes can become active.", true)
		return false
	end
	if not Spring.IsCheatingEnabled() then
		setStatus("Live collision edits require /cheat.", true)
		return false
	end
	return true
end

local function sendPacket(fields)
	Spring.SendLuaRulesMsg(PACKET_PREFIX .. table.concat(fields, "|"))
	state.refreshDelay = 0.15
end

local function volumeScope()
	return state.pieceMode and "piece" or "unit"
end

local function sendSnapshot()
	if state.selectedUnitID and Spring.IsCheatingEnabled() then
		sendPacket({ "snapshot", tostring(state.selectedUnitID) })
	end
end

local function sendDraft()
	if not canEdit() then
		return
	end

	sendPacket({
		"set",
		tostring(state.selectedUnitID),
		volumeScope(),
		tostring(state.pieceMode and state.selectedPieceIndex or 0),
		draft.enabled and "1" or "0",
		string.format("%.6f", draft.sx),
		string.format("%.6f", draft.sy),
		string.format("%.6f", draft.sz),
		string.format("%.6f", draft.ox),
		string.format("%.6f", draft.oy),
		string.format("%.6f", draft.oz),
		tostring(draft.volumeType),
		tostring(draft.testType),
		tostring(draft.axis),
	})
	state.pendingAction = "apply"
	setStatus("Applying synced collision volume...", false)
end

local function readCurrentVolume()
	local unitID = state.selectedUnitID
	if not unitID then
		return nil
	end

	local sx, sy, sz, ox, oy, oz, volumeType, testType, axis, disabled
	if state.pieceMode then
		sx, sy, sz, ox, oy, oz, volumeType, testType, axis, disabled =
			Spring.GetUnitPieceCollisionVolumeData(unitID, state.selectedPieceIndex)
	else
		sx, sy, sz, ox, oy, oz, volumeType, testType, axis, disabled =
			Spring.GetUnitCollisionVolumeData(unitID)
	end

	if not sx then
		return nil
	end
	return {
		sx = sx, sy = sy, sz = sz,
		ox = ox, oy = oy, oz = oz,
		volumeType = volumeType, testType = testType, axis = axis,
		enabled = not disabled,
	}
end

local function setSlider(field, value)
	if state.draggingField == field or not state.document then
		return
	end
	local valueString = formatNumber(value)
	if state.lastSliderValue[field] == valueString then
		return
	end
	local element = state.document:GetElementById(FIELD_IDS[field])
	if element then
		-- Preserve useful resolution for normal BAR units, but expand the range
		-- before writing unusually large imported volumes so RmlUi never clamps
		-- them and emits a destructive synthetic change event.
		if field:sub(1, 1) == "s" then
			local maximum = math.min(65536, math.max(512, math.ceil(value * 1.25)))
			if maximum > state.sliderBounds[field] then
				state.sliderBounds[field] = maximum
				element:SetAttribute("max", tostring(maximum))
			end
		else
			local bound = math.min(65536, math.max(256, math.ceil(math.abs(value) * 1.25)))
			if bound > state.sliderBounds[field] then
				state.sliderBounds[field] = bound
				element:SetAttribute("min", tostring(-bound))
				element:SetAttribute("max", tostring(bound))
			end
		end
		element:SetAttribute("value", valueString)
		state.lastSliderValue[field] = valueString
	end
end

local function projectDraftToModel()
	setModel("volumeType", draft.volumeType)
	setModel("typeName", VOLUME_TYPES[draft.volumeType] or "Unknown")
	setModel("axis", draft.axis)
	setModel("axisName", AXIS_NAMES[draft.axis] or "?")
	setModel("pieceEnabled", draft.enabled)

	for _, field in ipairs({ "sx", "sy", "sz", "ox", "oy", "oz" }) do
		setModel(field .. "Text", formatNumber(draft[field]))
		setSlider(field, draft[field])
	end
end

local function refreshCurrentVolume(force)
	local current = readCurrentVolume()
	if not current then
		setStatus("The selected unit or piece is no longer readable.", true)
		return false
	end

	local changed = force == true
	for _, field in ipairs({ "sx", "sy", "sz", "ox", "oy", "oz", "volumeType", "testType", "axis", "enabled" }) do
		if draft[field] ~= current[field] then
			draft[field] = current[field]
			changed = true
		end
	end
	if changed then
		projectDraftToModel()
	end
	return true
end

local function updatePieceLabel()
	local count = #state.pieceNames
	if count == 0 then
		setModel("pieceLabel", "No model pieces")
		return
	end
	local name = state.pieceNames[state.selectedPieceIndex] or "unnamed"
	setModel("pieceLabel", string.format(
		"%d / %d  -  %s  (config index %d)",
		state.selectedPieceIndex, count, name, state.selectedPieceIndex - 1
	))
end

local function detectPieceTree(unitID, unitDefID, mainDisabled)
	local unitDef = UnitDefs[unitDefID]
	local collisionVolume = unitDef and unitDef.collisionVolume
	return (collisionVolume and collisionVolume.defaultToPieceTree == true) or mainDisabled == true
end

local function clearSelection(message)
	state.selectedUnitID = nil
	state.pendingAction = nil
	state.selectedPieceIndex = 1
	state.pieceNames = {}
	state.pieceTreeSupported = false
	state.pieceMode = false
	setModel("hasUnit", false)
	setModel("pieceMode", false)
	setModel("pieceSupported", false)
	setModel("unitLabel", message or "Select exactly one unit")
	setModel("pieceLabel", "")
	setModel("pieceNotice", "")
	setStatus("Select exactly one visible unit to begin.", false)
end

local function selectUnit(unitID)
	local unitDefID = Spring.GetUnitDefID(unitID)
	if not unitDefID then
		clearSelection("Selected unit is not visible")
		return
	end

	local mainValues = { Spring.GetUnitCollisionVolumeData(unitID) }
	if not mainValues[1] then
		clearSelection("Selected unit is not in line of sight")
		return
	end

	state.selectedUnitID = unitID
	state.pendingAction = nil
	state.selectedPieceIndex = 1
	state.pieceNames = Spring.GetUnitPieceList(unitID) or {}
	state.pieceTreeSupported = detectPieceTree(unitID, unitDefID, mainValues[10])
	state.pieceMode = state.pieceTreeSupported and #state.pieceNames > 0
	state.lastSliderValue = {}

	local unitDef = UnitDefs[unitDefID]
	local humanName = (unitDef and (unitDef.translatedHumanName or unitDef.humanName or unitDef.name)) or "Unit"
	local internalName = (unitDef and unitDef.name) or "unknown"
	setModel("hasUnit", true)
	setModel("unitLabel", string.format("%s  [%s]  #%d", humanName, internalName, unitID))
	setModel("pieceSupported", state.pieceTreeSupported)
	setModel("pieceMode", state.pieceMode)
	if state.pieceTreeSupported then
		setModel("pieceNotice", "This unit uses live piece-tree collision volumes.")
	else
		setModel("pieceNotice", "Piece-tree mode is defined by usePieceCollisionVolumes and cannot be switched live; change the unit definition and respawn it.")
	end
	updatePieceLabel()
	sendSnapshot()
	refreshCurrentVolume(true)
	if Spring.IsCheatingEnabled() then
		setStatus("Live editing enabled. /debugcolvol is on.", false)
	else
		setStatus("Inspect and export are available; enter /cheat to edit.", true)
	end
end

local function updateSelection(selection)
	selection = selection or Spring.GetSelectedUnits()
	if #selection ~= 1 then
		clearSelection(#selection == 0 and "Select exactly one unit" or "Multiple units selected")
		return
	end
	selectUnit(selection[1])
end

local SCALE_AXIS = { sx = 0, sy = 1, sz = 2 }
local AXIS_SCALE = { [0] = "sx", [1] = "sy", [2] = "sz" }

-- Mirror CollisionVolume::FixTypeAndScale in the engine. Linking constrained
-- axes in the draft makes shrinking a sphere or cylinder possible; otherwise
-- the engine's max-axis normalization would make a single slider snap back.
local function normalizeDraftForShape(changedField)
	local changedAxis = SCALE_AXIS[changedField]
	if draft.volumeType == 3 then
		local diameter
		if changedAxis ~= nil then
			diameter = draft[changedField]
		else
			diameter = math.max(draft.sx, math.max(draft.sy, draft.sz))
		end
		draft.sx, draft.sy, draft.sz = diameter, diameter, diameter
	elseif draft.volumeType == 1 then
		local secondary = {}
		for axis = 0, 2 do
			if axis ~= draft.axis then
				secondary[#secondary + 1] = AXIS_SCALE[axis]
			end
		end
		local radius
		if changedAxis ~= nil and changedAxis ~= draft.axis then
			radius = draft[changedField]
		else
			radius = math.max(draft[secondary[1]], draft[secondary[2]])
		end
		draft[secondary[1]], draft[secondary[2]] = radius, radius
	end
end

local function onSetScope(_event, requestedScope)
	if not state.selectedUnitID then
		return
	end
	if requestedScope == "piece" and not state.pieceTreeSupported then
		setStatus("Piece-tree collision cannot be activated at runtime. Set usePieceCollisionVolumes=true in the unit definition and respawn the unit.", true)
		return
	end
	state.pieceMode = requestedScope == "piece"
	setModel("pieceMode", state.pieceMode)
	state.lastSliderValue = {}
	updatePieceLabel()
	refreshCurrentVolume(true)
end

local function onSelectPiece(_event, direction)
	if not state.pieceMode or #state.pieceNames == 0 then
		return
	end
	local count = #state.pieceNames
	state.selectedPieceIndex = ((state.selectedPieceIndex - 1 + direction) % count) + 1
	state.lastSliderValue = {}
	updatePieceLabel()
	refreshCurrentVolume(true)
end

local function onSetType(_event, volumeType)
	if not canEdit() then
		return
	end
	volumeType = tonumber(volumeType)
	if not VOLUME_TYPES[volumeType] then
		return
	end
	draft.volumeType = volumeType
	normalizeDraftForShape()
	projectDraftToModel()
	sendDraft()
end

local function onSetAxis(_event, axis)
	if not canEdit() then
		return
	end
	axis = tonumber(axis)
	if not AXIS_NAMES[axis] then
		return
	end
	draft.axis = axis
	normalizeDraftForShape()
	projectDraftToModel()
	sendDraft()
end

local function onSliderChange(event, field)
	if not FIELD_IDS[field] then
		return
	end
	local parameters = event and event.parameters
	local value = parameters and tonumber(parameters.value)
	if not value then
		return
	end
	value = field:sub(1, 1) == "s" and math.max(1, value) or value
	if math.abs(draft[field] - value) < 0.0001 then
		return
	end
	if not canEdit() then
		-- Reset the native control on the next Update boundary. Echo-writing a
		-- slider from inside its own change dispatch breaks thumb dragging.
		state.lastSliderValue[field] = nil
		state.projectNextUpdate = true
		return
	end
	state.lastSliderValue[field] = formatNumber(value)
	draft[field] = value
	normalizeDraftForShape(field)
	projectDraftToModel()
	sendDraft()
end

local function onStep(_event, field, amount)
	if not FIELD_IDS[field] or not canEdit() then
		return
	end
	amount = tonumber(amount) or 0
	local value = draft[field] + amount
	if field:sub(1, 1) == "s" then
		value = math.max(1, math.min(65536, value))
	else
		value = math.max(-65536, math.min(65536, value))
	end
	draft[field] = value
	normalizeDraftForShape(field)
	projectDraftToModel()
	sendDraft()
end

local function onTogglePiece(_event)
	if not state.pieceMode or not canEdit() then
		return
	end
	draft.enabled = not draft.enabled
	projectDraftToModel()
	sendDraft()
end

local function onReset(_event)
	if not canEdit() then
		return
	end
	sendPacket({
		"reset",
		tostring(state.selectedUnitID),
		volumeScope(),
		tostring(state.pieceMode and state.selectedPieceIndex or 0),
	})
	state.pendingAction = "reset"
	setStatus("Resetting to the volume captured when this unit was first edited...", false)
end

local function exportText()
	local scales = string.format("%s %s %s", formatNumber(draft.sx), formatNumber(draft.sy), formatNumber(draft.sz))
	local offsets = string.format("%s %s %s", formatNumber(draft.ox), formatNumber(draft.oy), formatNumber(draft.oz))
	if state.pieceMode then
		local line = string.format(
			"['%d'] = {%s, %s, %d, %d}, -- %s",
			state.selectedPieceIndex - 1,
			scales:gsub(" ", ", "), offsets:gsub(" ", ", "),
			draft.volumeType, draft.axis,
			state.pieceNames[state.selectedPieceIndex] or "piece"
		)
		if not draft.enabled then
			return "-- " .. line .. " (leave omitted to keep this piece disabled)"
		end
		return line
	end

	local typeName = TYPE_DEF_NAMES[draft.volumeType] or "Sphere"
	if draft.volumeType == 1 then
		typeName = typeName .. (AXIS_NAMES[draft.axis] or "Z")
	end
	return string.format(
		"collisionvolumeoffsets = \"%s\",\ncollisionvolumescales = \"%s\",\ncollisionvolumetype = \"%s\",",
		offsets, scales, typeName
	)
end

local function onExport(_event)
	if not state.selectedUnitID then
		setStatus("Select a unit before exporting.", true)
		return
	end
	local text = exportText()
	local clipboardOk = Spring.SetClipboard and pcall(Spring.SetClipboard, text)
	Spring.Echo("[Collision Volume Editor] Export:\n" .. text)
	setStatus(clipboardOk and "Copied Lua to the clipboard and infolog.txt." or "Clipboard unavailable; wrote Lua to infolog.txt.", false)
end

local function onClose(_event)
	widgetHandler:DisableWidget(widget:GetInfo().name)
end

local function makeInitialModel()
	return {
		hasUnit = false,
		unitLabel = "Select exactly one unit",
		pieceMode = false,
		pieceSupported = false,
		pieceLabel = "",
		pieceNotice = "",
		pieceEnabled = false,
		volumeType = 3,
		typeName = "Sphere",
		axis = 2,
		axisName = "Z",
		sxText = "1", syText = "1", szText = "1",
		oxText = "0", oyText = "0", ozText = "0",
		status = "Select exactly one visible unit to begin.",
		statusError = false,
		onSetScope = onSetScope,
		onSelectPiece = onSelectPiece,
		onSetType = onSetType,
		onSetAxis = onSetAxis,
		onSliderChange = onSliderChange,
		onStep = onStep,
		onTogglePiece = onTogglePiece,
		onReset = onReset,
		onExport = onExport,
		onClose = onClose,
	}
end

local function attachSliderTracking()
	for field, id in pairs(FIELD_IDS) do
		local slider = state.document:GetElementById(id)
		if slider then
			slider:AddEventListener("mousedown", function()
				state.draggingField = field
			end, false)
			slider:AddEventListener("mouseup", function()
				if state.draggingField == field then
					state.draggingField = nil
					state.lastSliderValue[field] = nil
					setSlider(field, draft[field])
				end
			end, false)
		end
	end
	state.document:AddEventListener("mouseup", function()
		local field = state.draggingField
		if field then
			state.draggingField = nil
			state.lastSliderValue[field] = nil
			setSlider(field, draft[field])
		end
	end, false)
end

function widget:Initialize()
	state.context = RmlUi.GetContext("shared")
	if not state.context then
		Spring.Echo("[Collision Volume Editor] Shared RmlUi context is unavailable")
		return false
	end

	state.dmHandle = state.context:OpenDataModel(MODEL_NAME, makeInitialModel(), self)
	if not state.dmHandle then
		Spring.Echo("[Collision Volume Editor] Failed to open data model")
		return false
	end

	state.document = state.context:LoadDocument(RML_PATH, self)
	if not state.document then
		widget:Shutdown()
		return false
	end
	state.document:ReloadStyleSheet()
	state.document:Show()
	state.rootElement = state.document:GetElementById("cve-root")

	if WG.TerraformerShared and WG.TerraformerShared.registerDocument then
		WG.TerraformerShared.registerDocument(DOCUMENT_NAME, state.document)
	end
	if WG.TerraformerShared and WG.TerraformerShared.attachDraggable and state.rootElement then
		state.dragHandle = WG.TerraformerShared.attachDraggable(
			state.document, "cve-drag-handle", state.rootElement,
			{ snapDocName = "terraform_brush", snapElementId = "tf-root" }
		)
	end

	attachSliderTracking()
	Spring.SendCommands("debugcolvol 1")
	state.debugViewActive = true
	updateSelection(Spring.GetSelectedUnits())
end

function widget:SelectionChanged(selection)
	updateSelection(selection)
end

function widget:UnitDestroyed(unitID)
	if unitID == state.selectedUnitID then
		clearSelection("Selected unit was destroyed")
	end
end

function widget:Update(dt)
	if state.dragHandle then
		state.dragHandle.tick()
	end
	if state.projectNextUpdate then
		state.projectNextUpdate = false
		projectDraftToModel()
	end
	if not state.selectedUnitID then
		return
	end

	state.refreshDelay = math.max(0, state.refreshDelay - (dt or 0))
	state.refreshClock = state.refreshClock + (dt or 0)
	if state.refreshDelay == 0 and state.refreshClock >= 0.2 then
		state.refreshClock = 0
		if refreshCurrentVolume(false) and state.pendingAction then
			setStatus(state.pendingAction == "reset" and "Initial volume restored." or "Live collision volume updated.", false)
			state.pendingAction = nil
		end
	end
end

function widget:KeyPress(key)
	if key == 27 then
		widgetHandler:DisableWidget(widget:GetInfo().name)
		return true
	end
	return false
end

function widget:RecvLuaMsg(message)
	if not state.document then
		return
	end
	if message:sub(1, 19) == "LobbyOverlayActive1" then
		state.lobbyHidden = true
		state.document:Hide()
	elseif message:sub(1, 19) == "LobbyOverlayActive0" then
		state.lobbyHidden = false
		state.document:Show()
	end
end

function widget:Shutdown()
	if state.debugViewActive then
		Spring.SendCommands("debugcolvol 0")
		state.debugViewActive = false
	end
	if WG.TerraformerShared and WG.TerraformerShared.unregisterDocument then
		WG.TerraformerShared.unregisterDocument(DOCUMENT_NAME)
	end
	if state.context and state.dmHandle then
		state.context:RemoveDataModel(MODEL_NAME)
		state.dmHandle = nil
	end
	if state.document then
		state.document:Close()
		state.document = nil
	end
	state.context = nil
	state.rootElement = nil
	state.dragHandle = nil
	state.selectedUnitID = nil
	state.draggingField = nil
	state.pendingAction = nil
end
