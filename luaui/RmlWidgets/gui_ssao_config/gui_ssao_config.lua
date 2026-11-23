if not RmlUi then
	return
end

local widget = widget ---@type Widget
local WG = WG
local Spring = Spring
local RmlUi = RmlUi
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local stringFormat = string.format

function widget:GetInfo()
	return {
		name = "SSAO Configurator",
		desc = "Developer controls for SSAO shader parameters and quality presets",
		author = "PtaQ",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1000001,
		enabled = false,
	}
end

local MODEL_NAME = "ssao_config_model"
local RML_PATH = "luaui/RmlWidgets/gui_ssao_config/gui_ssao_config.rml"

---@class SSAOConfigRow
---@field name string
---@field tooltip string
---@field min number
---@field max number
---@field step number
---@field value number
---@field sliderValue number
---@field formatted string
---@field minimum string
---@field maximum string
---@field digits integer

---@class SSAOConfiguratorState
---@field rmlContext table?
---@field document table?
---@field dmHandle table?
---@field rows SSAOConfigRow[]
---@field api table?
---@field revision integer?
---@field visible boolean
---@field dragging string?
---@field keyboardEditing string?
---@field presetRequest integer?
---@field presetEditing boolean
---@field resetRequest boolean
---@field dragHandle table?
---@field registered boolean
local widgetState = {
	rows = {},
	visible = false,
	resetRequest = false,
	presetEditing = false,
	registered = false,
}

local function getAPI()
	local api = WG.ssao
	if
		api
		and api.getParameters
		and api.getConfiguration
		and api.getConfigurationRevision
		and api.getPresets
		and api.getPreset
		and api.setPreset
		and api.resetConfiguration
		and api.setParameter
	then
		return api
	end
	return nil
end

local function setVisible(visible)
	if widgetState.visible == visible or not widgetState.document then
		return
	end
	widgetState.visible = visible
	widgetState.dragging = nil
	widgetState.keyboardEditing = nil
	widgetState.presetEditing = false
	widgetState.revision = nil
	if visible then
		widgetState.document:Show()
	else
		widgetState.document:Hide()
	end
end

local function syncConfiguration()
	local dmHandle = widgetState.dmHandle
	if not dmHandle then
		return
	end
	local api = getAPI()
	if dmHandle.available ~= (api ~= nil) then
		dmHandle.available = api ~= nil
	end
	if not api then
		widgetState.api = nil
		return
	end
	local revision = api.getConfigurationRevision()
	if widgetState.api == api and widgetState.revision == revision then
		return
	end
	local configuration = api.getConfiguration()
	local rows = {}
	for i, parameter in ipairs(api.getParameters()) do
		local value = configuration[parameter.name]
		local previous = widgetState.rows[i]
		local editing = widgetState.dragging == parameter.name or widgetState.keyboardEditing == parameter.name
		rows[i] = {
			name = parameter.name,
			tooltip = parameter.tooltip,
			min = parameter.min,
			max = parameter.max,
			step = 10 ^ -parameter.digits,
			value = value,
			-- Preserve the bound attribute during native dragging; only the readout changes.
			sliderValue = editing and previous and previous.sliderValue or value,
			formatted = stringFormat("%." .. parameter.digits .. "f", value),
			minimum = tostring(parameter.min),
			maximum = tostring(parameter.max),
			digits = parameter.digits,
		}
	end
	widgetState.rows = rows
	dmHandle.rows = rows
	local presetRows = {}
	for i, name in ipairs(api.getPresets()) do
		presetRows[i] = { id = i, label = name, selected = i == api.getPreset() }
	end
	dmHandle.presets = presetRows
	widgetState.api = api
	widgetState.revision = revision
end

local function initialModel()
	return {
		available = false,
		rows = {},
		presets = {},
		editing = "",
		error = "",
		onClose = function()
			setVisible(false)
		end,
		onPreset = function(event)
			if not widgetState.presetEditing then
				return
			end
			local value = tonumber(event.parameters.value)
			local api = getAPI()
			if api and value and value ~= api.getPreset() then
				widgetState.presetRequest = value
				widgetState.presetEditing = false
			end
		end,
		onPresetActivate = function()
			widgetState.presetEditing = true
		end,
		onPresetBlur = function()
			widgetState.presetEditing = false
		end,
		onReset = function()
			widgetState.resetRequest = true
		end,
		onSliderPress = function(event, name)
			if event.parameters.button == 0 then
				widgetState.dragging = name
				widgetState.keyboardEditing = nil
			end
		end,
		onSliderKey = function(_, name)
			widgetState.keyboardEditing = name
		end,
		onSliderBlur = function()
			widgetState.keyboardEditing = nil
			widgetState.revision = nil
		end,
		onParameter = function(event, name)
			local api = getAPI()
			if not api then
				widgetState.dmHandle.error = "SSAO is unavailable. Enable the SSAO widget first."
				Spring.Echo("[SSAO Configurator] SSAO API unavailable")
				return
			end
			local requested = tonumber(event.parameters.value)
			-- Attribute bindings emit change too; unchanged backend values are not edits.
			if requested == api.getConfiguration()[name] then
				return
			end
			local _, _, leftDown = Spring.GetMouseState()
			if leftDown then
				widgetState.dragging = name
				widgetState.keyboardEditing = nil
			end
			local value = api.setParameter(name, event.parameters.value)
			if value == nil then
				widgetState.dmHandle.error = "Invalid value for " .. name
				return
			end
			widgetState.dmHandle.error = ""
			syncConfiguration()
			for _, row in ipairs(widgetState.rows) do
				if row.name == name then
					widgetState.dmHandle.editing = name .. ": " .. stringFormat("%." .. row.digits .. "f", value)
					break
				end
			end
		end,
	}
end

function widget:Initialize()
	widgetState.rmlContext = RmlUi.GetContext("shared")
	if not widgetState.rmlContext then
		Spring.Echo("[SSAO Configurator] Shared RmlUi context unavailable")
		widgetHandler:RemoveWidget(self)
		return
	end
	widgetState.dmHandle = widgetState.rmlContext:OpenDataModel(MODEL_NAME, initialModel(), self)
	if not widgetState.dmHandle then
		Spring.Echo("[SSAO Configurator] Could not open data model")
		widgetHandler:RemoveWidget(self)
		return
	end
	widgetState.document = widgetState.rmlContext:LoadDocument(RML_PATH, self)
	if not widgetState.document then
		Spring.Echo("[SSAO Configurator] Could not load document")
		self:Shutdown()
		widgetHandler:RemoveWidget(self)
		return
	end
	widgetState.document:ReloadStyleSheet()
	local shared = WG.TerraformerShared
	if shared and shared.registerDocument and shared.attachDraggable then
		shared.registerDocument("ssao_config", widgetState.document)
		widgetState.registered = true
		-- rml-dom-escape: shared drag adapter needs the live panel geometry.
		local root = widgetState.document:GetElementById("ssao-root")
		widgetState.dragHandle = shared.attachDraggable(widgetState.document, "ssao-handle", root)
	end
	widgetHandler:AddAction("ssaoconfig", function()
		setVisible(not widgetState.visible)
		return true
	end, nil, "t")
	syncConfiguration()
	setVisible(true)
end

function widget:Update()
	if not widgetState.document then
		return
	end
	if widgetState.dragHandle then
		widgetState.dragHandle.tick()
	end
	if widgetState.dragging then
		local _, _, leftDown = Spring.GetMouseState()
		if not leftDown then
			widgetState.dragging = nil
			widgetState.revision = nil
		end
	end
	local api = getAPI()
	if widgetState.presetRequest or widgetState.resetRequest then
		if api then
			if widgetState.presetRequest then
				api.setPreset(widgetState.presetRequest)
			end
			if widgetState.resetRequest then
				api.resetConfiguration()
			end
			widgetState.dmHandle.editing = ""
			widgetState.dmHandle.error = ""
		else
			widgetState.dmHandle.error = "SSAO is unavailable. Enable the SSAO widget first."
			Spring.Echo("[SSAO Configurator] SSAO API unavailable")
		end
		widgetState.presetRequest = nil
		widgetState.resetRequest = false
	end
	if widgetState.visible then
		syncConfiguration()
	end
end

function widget:KeyPress(key)
	if key == 27 and widgetState.visible then
		setVisible(false)
		return true
	end
end

function widget:Shutdown()
	widgetHandler:RemoveAction("ssaoconfig")
	if widgetState.registered and WG.TerraformerShared and WG.TerraformerShared.unregisterDocument then
		WG.TerraformerShared.unregisterDocument("ssao_config")
	end
	widgetState.registered = false
	widgetState.presetRequest = nil
	widgetState.resetRequest = false
	widgetState.presetEditing = false
	widgetState.dragging = nil
	widgetState.keyboardEditing = nil
	widgetState.dragHandle = nil
	if widgetState.dmHandle then
		widgetState.rmlContext:RemoveDataModel(MODEL_NAME)
	end
	if widgetState.document then
		widgetState.document:Close()
	end
	widgetState.document = nil
	widgetState.dmHandle = nil
	widgetState.rmlContext = nil
	widgetState.api = nil
	widgetState.visible = false
end
