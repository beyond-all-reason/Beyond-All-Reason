local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Transport Settings",
		desc = "Tractor beam transport settings for balance tests: gameplay values (with /cheat) and preview toggles",
		author = "PtaQ",
		version = "v1.0",
		date = "November 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if Spring.GetModOptions().beta_tractorbeam == "disabled" then
	return false
end

local MODEL_NAME = "transport_settings_model"
local RML_PATH = "luaui/RmlWidgets/gui_transport_settings/gui_transport_settings.rml"
local REFRESH_FRAMES = 15

local words = VFS.Include("luaui/Include/transport_strings.lua")

-- gameplay values the Transport Handler gadget takes live; step = what one click changes
-- min and max mirror the gadget's clamp; below 0 is "per transport", first the lowest value above it
local GAMEPLAY = {
	{ key = "enemyLoadMode", step = 1, min = 1, max = 5 },
	{ key = "loadRadius", step = 16, min = 32, max = 512 },
	{ key = "unloadRadius", step = 8, min = 16, max = 256 },
	{ key = "enemyRadiusMult", step = 0.05, min = 0.1, max = 1 },
	{ key = "enemyLoadFrames", step = 15, min = 1, max = 600 },
	{ key = "speedModMode", step = 1, min = -1, max = 2 },
	{ key = "speedModStrength", step = 0.05, min = -1, max = 1 },
	{ key = "comSpeedModStrength", step = 0.05, min = -1, max = 1 },
	{ key = "unloadSpeed", step = 10, min = -1, max = 300, first = 10 },
	{ key = "unloadTime", step = 0.1, min = 0.1, max = 1 },
}

local TOGGLES = { "ghosts", "rings", "claimLines", "rightClickLoad" }

-- read by Unload Snap and Tractor Beam Load
local settings = { ghosts = true, rings = true, claimLines = true, rightClickLoad = true }
local open = true

local rmlContext, document, dm ---@type table?, table?, table

local function rulesValue(key)
	return Spring.GetGameRulesParam("tractorbeam_" .. key)
end

local function formatValue(key, value)
	if value == nil then
		return "-"
	end
	if key == "enemyLoadMode" then
		return value .. ": " .. (words.enemyLoadModes[value] or "?")
	elseif key == "loadRadius" or key == "unloadRadius" then
		return string.format("%d", value)
	elseif key == "enemyRadiusMult" then
		return string.format("x%.2f", value)
	elseif key == "enemyLoadFrames" then
		return string.format("%.1f s", value / Game.gameSpeed)
	elseif key == "speedModMode" then
		return value < 0 and words.perTransport or words.speedModModes[value] or "?"
	elseif key == "unloadSpeed" then
		return value < 0 and words.unloadSpeedOwn or string.format("%d", value)
	end
	return value < 0 and words.perTransport or string.format("%d%%", value * 100 + 0.5)
end

local function buildRows()
	local rows = {}
	for i, g in ipairs(GAMEPLAY) do
		rows[i] = { key = g.key, label = words[g.key], value = formatValue(g.key, rulesValue(g.key)) }
	end
	return rows
end

local shown = {} -- last values put in the model, so it only changes when something did

local function refresh()
	local cheats = Spring.IsCheatingEnabled()
	if cheats ~= shown.cheats then
		shown.cheats = cheats
		dm.cheats = cheats
	end
	local changed = false
	for _, g in ipairs(GAMEPLAY) do
		local value = rulesValue(g.key)
		if value ~= shown[g.key] then
			shown[g.key] = value
			changed = true
		end
	end
	if changed then
		dm.rows = buildRows()
	end
end

local function step(_, key, direction)
	if not Spring.IsCheatingEnabled() then
		return
	end
	for _, g in ipairs(GAMEPLAY) do
		if g.key == key then
			local value = tonumber(rulesValue(key)) or 0
			local new = value
			if value >= 0 then
				-- back onto the step grid: rules params come back as 32 bit floats
				new = math.floor((value + direction * g.step) / g.step + 0.5) * g.step
				if new < (g.first or 0) then
					new = -1
				end
			elseif direction > 0 then
				new = g.first or 0 -- leave "per transport" upward only
			end
			new = math.clamp(new, g.min, g.max)
			if math.abs(new - value) >= g.step * 0.5 then
				Spring.SendLuaRulesMsg(string.format("tractorbeam_set %s %.4f", key, new))
			end
			return
		end
	end
end

local function toggle(_, key)
	settings[key] = not settings[key]
	dm[key] = settings[key]
end

local function toggleOpen()
	open = not open
	dm.open = open
end

function widget:Initialize()
	WG.TransportSettings = settings
	rmlContext = RmlUi.GetContext("shared")
	if not rmlContext then
		widgetHandler:RemoveWidget()
		return
	end
	local model = {
		title = words.settingsTitle,
		gameplayTitle = words.settingsGameplay,
		previewTitle = words.settingsPreview,
		cheatHint = words.settingsNeedsCheats,
		open = open,
		cheats = Spring.IsCheatingEnabled(),
		rows = buildRows(),
		step = step,
		toggle = toggle,
		toggleOpen = toggleOpen,
	}
	-- one plain value per toggle: the rows never get rebuilt
	for _, key in ipairs(TOGGLES) do
		model[key] = settings[key]
		model[key .. "Label"] = words[key]
		model[key .. "Hint"] = words[key .. "Hint"]
	end
	dm = rmlContext:OpenDataModel(MODEL_NAME, model, self)
	if not dm then
		widgetHandler:RemoveWidget()
		return
	end
	document = rmlContext:LoadDocument(RML_PATH, self)
	if not document then
		widgetHandler:RemoveWidget()
		return
	end
	document:Show()
end

local lastRefresh = -math.huge

function widget:Update()
	-- by draw frame, not game frame: the panel keeps up while paused
	local now = Spring.GetDrawFrame()
	if now - lastRefresh >= REFRESH_FRAMES then
		lastRefresh = now
		refresh()
	end
end

function widget:Shutdown()
	if document then
		document:Close()
		document = nil
	end
	if rmlContext and dm then
		rmlContext:RemoveDataModel(MODEL_NAME)
	end
	WG.TransportSettings = nil
end

function widget:GetConfigData()
	return { settings = settings, open = open }
end

function widget:SetConfigData(data)
	if type(data.settings) == "table" then
		for key, value in pairs(data.settings) do
			if settings[key] ~= nil and type(value) == "boolean" then
				settings[key] = value
			end
		end
	end
	if type(data.open) == "boolean" then
		open = data.open
	end
end
