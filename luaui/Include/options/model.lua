-- The settings, without the window that shows them: the rows of every tab (rows/), what they hold, and
-- what changing one does. Nothing here draws or knows about pixels.
--
-- A window includes this once per widget and:
--   sets onListChanged and onRebuilt below,
--   calls init() once the other widgets are loaded (its first draw) and loadAllWidgetData() after that,
--   lists options, grouped by groups, filtered by showOption, and calls applyOptionValue on a change,
--   passes the callins on to this and to upkeep, and adds this to its saved config.
local upkeep = VFS.Include("luaui/Include/options/upkeep.lua")
local Search = require("luaui/Include/search")

local hardware, state = upkeep.hardware, upkeep.state

local types = {
	basic = 1,
	advanced = 2,
	dev = 3,
}
local presets = VFS.Include("luaui/Include/options/presets.lua")

local widgetOptionColor = "\255\160\160\160"

local customOptions = {}
local requireRestartDefaults = {}
local requireRestartDefaultsSet = false

local model = {
	upkeep = upkeep,
	hardware = hardware,
	state = state,
	types = types,
	presets = presets,
	devMode = BAR.Utilities.IsDevMode(),
	devUI = BAR.Utilities.ShowDevUI(),
	advSettings = false --[[@as boolean]],
	-- every row, and what to list: those again, or under a search only the matches
	allOptions = {} --[[@as table<integer, table>]],
	options = {} --[[@as table<integer, table>]],
	-- the tabs
	groups = {} --[[@as table<integer, table>]],
	searchText = "",
	changesRequireRestart = false --[[@as boolean]],
	-- off while a preset sets its rows, which then do not turn the preset into custom
	manualChange = true --[[@as boolean]],
	-- what to list changed: the rows, their values or the search
	onListChanged = function() end,
	-- every row and tab is new: what is held on to by table has to be looked up again by id
	onRebuilt = function() end,
}
-- values may have changed elsewhere: syncValues next, without waiting
model.forceUpdate = nil --[[@as boolean?]]
-- a widget was switched, which only happens later: init next
model.scheduleInit = nil --[[@as boolean?]]
-- { time, option id }: that option gets applied again with force then
model.scheduledApply = nil --[[@as table?]]

-- a slider's range: its lowest and highest step, or min and max
local function sliderRange(option)
	if option.steps then
		local min, max = option.steps[1], option.steps[1]
		for _, v in ipairs(option.steps) do
			if v > max then
				max = v
			end
			if v < min then
				min = v
			end
		end
		return min, max
	end
	return option.min, option.max
end
model.sliderRange = sliderRange

local function showOption(option)
	if
		not option.category
		or option.category == types.basic
		or (model.advSettings and option.category == types.advanced)
		or (model.devMode or model.devUI)
	then
		return true
	end
	return false
end
model.showOption = showOption

-- every option by id. During init() this is the list being built, afterwards the full list
-- (the search filter only changes what is shown).
local optionsById = {}
local function indexOptions()
	optionsById = {}
	for _, option in ipairs(model.options) do
		if option.id and not optionsById[option.id] then
			optionsById[option.id] = option
		end
	end
end
local function getOption(id)
	return optionsById[id]
end
model.getOption = getOption

local function getOptionLabel(option)
	return option.prefix and (option.prefix .. "  " .. option.name) or option.name
end
model.getOptionLabel = getOptionLabel

local function NearestValue(table, number)
	local smallestSoFar, smallestIndex
	for i, y in ipairs(table) do
		if not smallestSoFar or (math.abs(number - y) < smallestSoFar) then
			smallestSoFar = math.abs(number - y)
			smallestIndex = i
		end
	end
	return table[smallestIndex]
end
model.NearestValue = NearestValue

-- Decimals a number needs, up to 4. Counted, not read off tostring: Lua numbers are 32-bit floats in
-- the engine, which writes 0.15 as "0.15000001".
local function decimalsOf(x)
	for d = 0, 3 do
		local scaled = x * 10 ^ d
		if math.abs(scaled - math.floor(scaled + 0.5)) <= 0.00001 * math.max(1, math.abs(scaled)) then
			return d
		end
	end
	return 4
end

-- the value a slider shows, rounded to its step
local function sliderValueText(option)
	if option.steps then
		local value = NearestValue(option.steps, option.value)
		return string.format("%." .. decimalsOf(value) .. "f", value)
	end
	return string.format("%." .. decimalsOf(option.step or 1) .. "f", option.value)
end

-- A color option's value is { r, g, b }, each from 0 to max on its step. White is what shows as full
-- color (max when not given); up to max a channel goes brighter than the screen can show.
function model.shownColor(option)
	local white, value = option.white or option.max, option.value
	return { value[1] / white, value[2] / white, value[3] / white }
end

-- a channel of a color option, rounded to its step
function model.channelText(option, value)
	return string.format("%." .. decimalsOf(option.step or 1) .. "f", value)
end

local function sameColor(a, b)
	return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end
model.sameColor = sameColor
model.sliderValueText = sliderValueText

-- a sub-option of a widget that is switched off does nothing for now
local function inactive(option)
	local parent = option.parentOption
	while parent do
		if parent.type == "bool" and parent.widget and not parent.value then
			return true
		end
		parent = parent.parentOption
	end
	return false
end
model.inactive = inactive

local function saveOptionValue(
	widgetName,
	widgetApiName,
	widgetApiFunction,
	configVar,
	configValue,
	widgetApiFunctionParam
)
	-- if widgetApiFunctionParam not defined then it uses configValue
	if widgetHandler.configData[widgetName] == nil then
		widgetHandler.configData[widgetName] = {}
	end
	if widgetHandler.configData[widgetName][configVar[1]] == nil then
		widgetHandler.configData[widgetName][configVar[1]] = {}
	end
	if configVar[2] ~= nil and widgetHandler.configData[widgetName][configVar[1]][configVar[2]] == nil then
		widgetHandler.configData[widgetName][configVar[1]][configVar[2]] = {}
	end
	if configVar[2] ~= nil then
		if configVar[3] ~= nil then
			widgetHandler.configData[widgetName][configVar[1]][configVar[2]][configVar[3]] = configValue
		else
			widgetHandler.configData[widgetName][configVar[1]][configVar[2]] = configValue
		end
	else
		widgetHandler.configData[widgetName][configVar[1]] = configValue
	end
	if widgetApiName ~= nil and WG[widgetApiName] ~= nil and WG[widgetApiName][widgetApiFunction] ~= nil then
		if widgetApiFunctionParam ~= nil then
			WG[widgetApiName][widgetApiFunction](widgetApiFunctionParam)
		else
			WG[widgetApiName][widgetApiFunction](configValue)
		end
	end
end
model.saveOptionValue = saveOptionValue

local function GetWidgetToggleValue(widgetname)
	if widgetHandler.orderList[widgetname] == nil or widgetHandler.orderList[widgetname] == 0 then
		return false
	elseif
		widgetHandler.orderList[widgetname] >= 1
		and widgetHandler.knownWidgets ~= nil
		and widgetHandler.knownWidgets[widgetname] ~= nil
	then
		if widgetHandler.knownWidgets[widgetname].active then
			return true
		else
			return 0.5
		end
	end
end

-- A widget another takes the place of (GetInfo replaces, as FlowUI2's copies): an option made for it switches
-- the one taking its place when that one is known (the running one first)
local function WidgetToggleTarget(name)
	local found = nil
	for byName, ki in pairs(widgetHandler.knownWidgets or {}) do
		local replaces = ki.replaces
		if replaces ~= nil and byName ~= name then
			local hit = replaces == name
			if type(replaces) == "table" then
				for i = 1, #replaces do
					hit = hit or replaces[i] == name
				end
			end
			if hit and (found == nil or ki.active) then
				found = byName
			end
		end
	end
	return found or name
end

-- Switched off from here, a widget taking others' places leaves them off: no longer recorded as replaced by
-- it, they are not handed back now (FlowUI2's takeover) nor switched back on at the next start
local function KeepReplacedOff(name)
	local known = widgetHandler.knownWidgets and widgetHandler.knownWidgets[name]
	local replaces = known and known.replaces
	if replaces == nil then
		return
	end
	for _, replaced in ipairs(type(replaces) == "table" and replaces or { replaces }) do
		if widgetHandler.replacedList[replaced] == name then
			widgetHandler.replacedList[replaced] = nil
		end
	end
end

-- The build menu's grid layout: the Grid menu widget on, or the layout of a build menu taking its place
-- (Build Menu FlowUI2 shows both layouts itself: WG.buildmenu.getLayout/setLayout)
local function GridLayoutOn()
	local api = WG.buildmenu
	if api and api.getLayout then
		return api.getLayout() == "grid"
	end
	return GetWidgetToggleValue("Grid menu") and true or false
end

-- the value at a path in a widget's saved config data, e.g. {'Config','console','maxlines'}; nil when it is missing
local function widgetConfigValue(widgetName, path)
	local value = widgetHandler.configData[widgetName]
	for _, key in ipairs(path) do
		if type(value) ~= "table" then
			return nil
		end
		value = value[key]
	end
	return value
end

-- the option keeps its value when the path is missing
local function loadWidgetData(widgetName, optionId, configVar)
	local option = getOption(optionId)
	local value = widgetConfigValue(widgetName, configVar)
	if option and value ~= nil then
		option.value = value
	end
end

-- Most options only mirror one value, and declare where it lives instead of handling it:
--   widgetConfig = { widget name, config key or path, api = WG table, get = getter, set = setter, key = ... }
--     read from the API when the list is built, loaded from the widget's saved config, and on
--     change saved there and handed to the setter; with key, the getter gets key and the setter { key, value }
--   configInt / configFloat = engine config key; a toggle stores 1 or 0, a color has a key per channel
local function boundPath(config)
	return type(config[2]) == "table" and config[2] or { config[2] }
end

local function readBoundValue(option)
	local config = option.widgetConfig
	if config then
		local api = config.api and WG[config.api]
		if config.get and api and api[config.get] then
			local value = api[config.get](config.key)
			if value ~= nil then
				option.value = value
			end
		end
	elseif option.configInt then
		if option.type == "bool" then
			option.value = Spring.GetConfigInt(option.configInt, option.value and 1 or 0) == 1
		elseif option.type == "color" then
			-- a new table only when it changed, so a read that finds the same color changes nothing
			local value = {}
			for i, key in ipairs(option.configInt) do
				value[i] = Spring.GetConfigInt(key, option.value[i])
			end
			if not sameColor(value, option.value) then
				option.value = value
			end
		else
			option.value = Spring.GetConfigInt(option.configInt, option.value)
		end
	elseif option.configFloat then
		option.value = Spring.GetConfigFloat(option.configFloat, option.value)
	end
end

local function loadBoundValue(option)
	local config = option.widgetConfig
	local value = widgetConfigValue(config[1], boundPath(config))
	if value ~= nil then
		option.value = value
	end
end

-- Reads the bound settings again, as their widget or the engine config can change them by other means
-- while the window is open; not the ones isHeld says are being worked. Returns whether any changed.
local function rereadBound(isHeld)
	local changed = false --[[@as boolean]]
	for _, option in ipairs(model.allOptions) do
		if (option.widgetConfig or option.configInt or option.configFloat) and not isHeld(option) then
			local before = option.value
			readBoundValue(option)
			changed = changed or option.value ~= before
		end
	end
	return changed
end

local function saveBoundValue(option)
	local config = option.widgetConfig
	if config then
		local param = config.key and { config.key, option.value } or nil
		saveOptionValue(config[1], config.api, config.set, boundPath(config), option.value, param)
	elseif option.configInt and option.type == "color" then
		for i, key in ipairs(option.configInt) do
			Spring.SetConfigInt(key, option.value[i])
		end
	elseif option.configInt then
		Spring.SetConfigInt(option.configInt, option.type == "bool" and (option.value and 1 or 0) or option.value)
	elseif option.configFloat then
		Spring.SetConfigFloat(option.configFloat, option.value)
	end
end

-- dev mode, once: a binding to a widget the handler does not know, or to an API its running widget lacks
local bindingsChecked = false
local function checkBindings()
	bindingsChecked = true
	for _, option in ipairs(model.options) do
		local config = option.widgetConfig
		local known = config and widgetHandler.knownWidgets[config[1]]
		local api = config and config.api and WG[config.api]
		local problem
		if config and not known then
			problem = "unknown widget " .. config[1]
		elseif config and known.active and config.api then
			if not api then
				problem = "WG." .. config.api .. " missing"
			elseif config.get and not api[config.get] then
				problem = "WG." .. config.api .. "." .. config.get .. " missing"
			elseif config.set and not api[config.set] then
				problem = "WG." .. config.api .. "." .. config.set .. " missing"
			end
		end
		if problem then
			Spring.Echo("Options: '" .. option.id .. "' widgetConfig: " .. problem)
		end
	end
end

-- Ranks the options against the search text: exact substring > multi-word AND > fuzzy subsequence.
-- A match is shown below its parents, and the rows of one family stay together, ranked by their
-- best match.
local function applyFilter()
	if model.searchText ~= "" then
		local query = Search.query(model.searchText)
		-- Nothing but whitespace is not something anyone is searching for.
		if query.empty then
			model.options = model.allOptions
			model.onListChanged()
			return
		end

		local matched = {}
		-- Filled once and rewritten per option rather than allocated for each of them: a
		-- keystroke walks every setting there is.
		local primary, secondary = { "", "" }, { "", "" }

		for i, option in ipairs(model.allOptions) do
			if option.name and option.name ~= "" and option.type then
				local lowerId = string.lower(option.id)
				local lowerDesc = option.description and option.description ~= "" and string.lower(option.description)
					or ""

				-- Named by what it is called and by its id; found, but not on their own, by its
				-- description and again its id.
				primary[1], primary[2] = Search.normalize(getOptionLabel(option)), lowerId
				secondary[1], secondary[2] = lowerDesc, lowerId
				local score = Search.score(query, primary, secondary)
				if score > 0 then
					matched[#matched + 1] = { option = option, score = score, index = i }
				end
			end
		end

		table.sortStable(matched, function(a, b)
			if a.score ~= b.score then
				return a.score > b.score
			end
		end)

		local families, familyOf = {}, {}
		for _, entry in ipairs(matched) do
			local root = entry.option
			while root.parentOption do
				root = root.parentOption
			end
			local family = familyOf[root]
			if not family then
				family = {}
				familyOf[root] = family
				families[#families + 1] = family
			end
			family[#family + 1] = entry
		end

		local shown = {}
		local result = {}
		local function show(option)
			if not shown[option] then
				shown[option] = true
				if option.parentOption then
					show(option.parentOption)
				end
				result[#result + 1] = option
				if option.spacer then
					result[#result + 1] = option.spacer
				end
			end
		end
		for _, family in ipairs(families) do
			table.sort(family, function(a, b)
				return a.index < b.index
			end)
			for _, entry in ipairs(family) do
				show(entry.option)
			end
		end

		model.options = result
	else
		-- No filter, use the cached unfiltered options
		model.options = model.allOptions
	end
	model.onListChanged()
end

local function checkRequireRestart()
	model.changesRequireRestart = false
	for id, value in pairs(requireRestartDefaults) do
		local option = getOption(id)
		if option and option.value ~= value then
			model.changesRequireRestart = true
		end
	end
end

local function applyOptionValue(option, newValue, skipRedrawWindow, force)
	if option == nil then
		return
	end

	local id = option.id

	if newValue ~= nil then
		option.value = newValue
	end

	if option.restart and requireRestartDefaults[id] ~= nil then
		checkRequireRestart()
	end

	if id ~= "preset" and presets.lowest[id] ~= nil and model.manualChange then
		local preset = getOption("preset")
		if preset then
			preset.value = #preset.options -- custom
			Spring.SetConfigString("graphicsPreset", "custom")
		end
	end

	-- a toggle turns its widget on and off; other options only name the widget they belong to
	if option.widget ~= nil and option.type == "bool" and widgetHandler.orderList[option.widget] ~= nil then
		if option.value then
			if widgetHandler.orderList[option.widget] < 0.5 then
				widgetHandler:EnableWidget(option.widget)
			end
		else
			if widgetHandler.orderList[option.widget] > 0 then
				KeepReplacedOff(option.widget)
				widgetHandler:DisableWidget(option.widget)
			end
		end
		model.forceUpdate = true
		model.scheduleInit = true
		if id == "teamcolors" then
			Spring.SendCommands("luarules reloadluaui") -- cause several widgets are still using old colors
		end
	end

	saveBoundValue(option)
	if option.onchange then
		option.onchange(option, option.value, force)
	end

	if skipRedrawWindow == nil then
		-- also keeps the search results up to date
		applyFilter()
	end
end

local function applyOptionValueByID(id, newValue, skipRedrawWindow, force)
	applyOptionValue(getOption(id), newValue, skipRedrawWindow, force)
end

-- loads values via stored game config in luaui/configs
local function loadAllWidgetData()
	for _, option in ipairs(model.options) do
		if option.widgetConfig then
			loadBoundValue(option)
		end
		if option.onload then
			option.onload(option)
		end
	end
end

model.GetWidgetToggleValue = GetWidgetToggleValue
model.GridLayoutOn = GridLayoutOn
model.loadWidgetData = loadWidgetData
model.applyFilter = applyFilter
model.applyOptionValue = applyOptionValue
model.applyOptionValueByID = applyOptionValueByID
model.loadAllWidgetData = loadAllWidgetData

local function getSelectKey(option, value)
	for k, v in pairs(option.options) do
		if v == value then
			return k
		end
	end
	return false
end

local squadInclude = VFS.Include("luaui/Include/options/squad.lua")
local squadPreset, squadSelectValue = squadInclude(model)
model.squadPreset, model.squadSelectValue = squadPreset, squadSelectValue

-- each makes its tab's rows anew
local tabRows = {
	VFS.Include("luaui/Include/options/rows/gfx.lua"),
	VFS.Include("luaui/Include/options/rows/sound.lua"),
	VFS.Include("luaui/Include/options/rows/notif.lua"),
	VFS.Include("luaui/Include/options/rows/control.lua"),
	VFS.Include("luaui/Include/options/rows/ui.lua"),
	VFS.Include("luaui/Include/options/rows/game.lua"),
	VFS.Include("luaui/Include/options/rows/accessibility.lua"),
	VFS.Include("luaui/Include/options/rows/dev.lua"),
}

local function init()
	hardware.readInfolog()

	-- restrict options for potato systems
	if hardware.isPotatoCpu or hardware.isPotatoGpu then
		if hardware.isPotatoCpu then
			Spring.Echo("potato CPU detected")
		end
		if hardware.isPotatoGpu then
			Spring.Echo("potato Graphics Card detected")
		end
	end

	model.groups = {
		{ id = "gfx", name = BAR.I18N("ui.settings.group.graphics"), numOptions = 0 },
		{ id = "ui", name = BAR.I18N("ui.settings.group.interface"), numOptions = 0 },
		{ id = "game", name = BAR.I18N("ui.settings.group.game"), numOptions = 0 },
		{ id = "control", name = BAR.I18N("ui.settings.group.control"), numOptions = 0 },
		{ id = "sound", name = BAR.I18N("ui.settings.group.audio"), numOptions = 0 },
		{ id = "notif", name = BAR.I18N("ui.settings.group.notifications"), numOptions = 0 },
		{ id = "accessibility", name = BAR.I18N("ui.settings.group.accessibility"), numOptions = 0 },
		{ id = "custom", name = BAR.I18N("ui.settings.group.custom"), numOptions = 0 },
		{ id = "dev", name = BAR.I18N("ui.settings.group.dev"), numOptions = 0 },
	}

	local oldValues = {}
	for _, option in ipairs(model.allOptions) do
		if option.id ~= nil then -- labels from other widgets may have none
			oldValues[option.id] = option.value
		end
	end

	-- Rows show in this order within their tab; one without a type is a section label.
	-- parent: id of the option this sub-option belongs to (indented below it, found along with it)
	-- prefix: shown ahead of the name, which then takes the sub-option color
	-- compact: a plain toggle that shares a line with the ones beside it
	-- available: false leaves the row out
	-- widgetConfig, configInt, configFloat: where the value lives, see readBoundValue
	model.options = {}
	for _, rows in ipairs(tabRows) do
		table.append(model.options, rows(model))
	end

	model.options = table.filterArray(model.options, function(option)
		return option.available ~= false
	end)
	indexOptions()
	for _, option in ipairs(model.options) do
		readBoundValue(option)
	end
	if model.devMode and not bindingsChecked then
		checkBindings()
	end

	-- keeps the list without holes, so it stays in order and # and ipairs work on it
	local function removeOptions(ids)
		local remove = table.invert(ids)
		model.options = table.filterArray(model.options, function(option)
			return not remove[option.id]
		end)
		indexOptions()
	end

	if not hardware.isPotatoGpu and not model.devMode and not model.devUI then
		removeOptions({ "advmapshading" })
		Spring.SetConfigInt("AdvMapShading", 1)
		Spring.SendCommands("advmapshading 1")
	end

	-- reset tonemap defaults (only once)
	if not state.resettedTonemapDefault then
		local tonemapDefaults = getOption("tonemapDefaults")
		if tonemapDefaults then
			applyOptionValue(tonemapDefaults, true, true)
			state.resettedTonemapDefault = true
		end
	end

	-- Squad selection: the playstyle preset decides how much of the section is drawn. Off leaves just the preset select, Custom shows everything, and any other preset hides the rows it owns because it writes them itself.
	if not widgetHandler.knownWidgets["Squad Selection"] then
		removeOptions(squadPreset.allOptions)
		removeOptions({ "squad_preset", "label_squad" })
	else
		local activePreset = squadPreset.get()
		if activePreset == "off" then
			removeOptions(squadPreset.allOptions)
		else
			if activePreset ~= "custom" then
				removeOptions(squadPreset.ownedOptions)
			end
			if not GetWidgetToggleValue("Squad Selection Hull") then
				removeOptions(squadPreset.hullOptions)
			end
		end
	end

	if
		getOption("spectator_hud_config").options[getOption("spectator_hud_config").value]
		~= BAR.I18N("ui.settings.option.spectator_hud_config_custom")
	then
		removeOptions({
			"spectator_hud_metric_metalIncome",
			"spectator_hud_metric_energyIncome",
			"spectator_hud_metric_buildPower",
			"spectator_hud_metric_metalProduced",
			"spectator_hud_metric_energyProduced",
			"spectator_hud_metric_metalExcess",
			"spectator_hud_metric_energyExcess",
			"spectator_hud_metric_armyValue",
			"spectator_hud_metric_defenseValue",
			"spectator_hud_metric_utilityValue",
			"spectator_hud_metric_economyValue",
			"spectator_hud_metric_damageDealt",
		})
	end

	-- outside its event, an event soundtrack is switched back on
	local holidays = BAR.Utilities.Gametype.GetCurrentHolidays()
	if not holidays.aprilfools then
		Spring.SetConfigInt("UseSoundtrackAprilFools", 1)
	end
	if not holidays.halloween then
		Spring.SetConfigInt("UseSoundtrackHalloween", 1)
	end
	if not holidays.xmas then
		Spring.SetConfigInt("UseSoundtrackXmas", 1)
	end

	-- add fonts
	if getOption("font") then
		local fonts = {}
		local fontsFull = {}
		local fontsn = {}
		local files = VFS.DirList("fonts", "*")
		for k, file in ipairs(files) do
			local name = string.sub(file, 7)
			local ext = string.sub(name, string.len(name) - 2)
			if ext == "otf" or ext == "ttf" or ext == "ttc" then
				name = string.sub(name, 1, string.len(name) - 4)
				if not fontsn[name:lower()] then
					fonts[#fonts + 1] = name
					fontsFull[#fontsFull + 1] = string.sub(file, 7)
					fontsn[name:lower()] = true
				end
			end
		end

		getOption("font").options = fonts
		getOption("font").optionsFont = fontsFull
		local fname = Spring.GetConfigString("bar_font", "Poppins-Regular.otf"):lower()
		getOption("font").value = getSelectKey(getOption("font"), string.sub(fname, 1, string.len(fname) - 4))

		getOption("font2").options = fonts
		getOption("font2").optionsFont = fontsFull
		local fname = Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf"):lower()
		getOption("font2").value = getSelectKey(getOption("font2"), string.sub(fname, 1, string.len(fname) - 4))
	end

	-- check if cus is disabled by auto disable cus widget (in case options widget has been reloaded)
	if getOption("sun_y") then
		local sunX, sunY, sunZ = gl.GetSun("pos")
		if sunY < getOption("sun_y").min then
			Spring.SetSunDirection(sunX, getOption("sun_y").min, sunZ)
		end
	end

	-- set minimal shadow opacity
	if getOption("shadows_opacity") then
		if gl.GetSun("shadowDensity") < getOption("shadows_opacity").min then
			Spring.SetSunLighting({
				groundShadowDensity = getOption("shadows_opacity").min,
				modelShadowDensity = getOption("shadows_opacity").min,
			})
		end
	end

	if Spring.GetGameFrame() == 0 then
		upkeep.detectWater()

		-- set vsync
		Spring.SetConfigInt("VSync", Spring.GetConfigInt("VSyncGame", -1) * Spring.GetConfigInt("VSyncFraction", 1))
	end
	if not state.waterDetected then
		Spring.SendCommands("water 0")
	end

	-- reduce options for potatoes (skip in dev mode to keep all options available)
	if (hardware.isPotatoGpu or hardware.isPotatoCpu) and not model.devMode and not model.devUI then
		--local id = getOption('shadowslider')
		--options[id].options = { 1, 2, 3 }
		--if options[id].value > 3 then
		--	options[id].value = 3
		--	options[id].onchange(id, options[id].value)
		--end

		-- disable engine decals (footprints)
		removeOptions({ "decals" })
		if Spring.GetConfigInt("GroundDecals", 3) > 0 then
			Spring.SendCommands("GroundDecals 0")
			Spring.SetConfigInt("GroundDecals", 0)
		end

		if hardware.isPotatoGpu then
			-- limit available msaa levels to 'off' and 'x2'
			if getOption("msaa") then
				for k, v in pairs(getOption("msaa").options) do
					if k >= 3 then
						getOption("msaa").options[k] = nil
					end
				end
			end

			-- turn off and drop these effects with their sub-options
			for _, ids in ipairs({ { "ssao", "ssao_strength", "ssao_quality" }, { "clouds", "clouds_opacity" } }) do
				local effect = getOption(ids[1])
				if effect and GetWidgetToggleValue(effect.widget) then
					widgetHandler:DisableWidget(effect.widget)
				end
				removeOptions(ids)
			end

			-- set lowest quality shadows for Intel GPU (they eat fps but dont show)
			--if Platform ~= nil and Platform.gpuVendor == 'Intel' and gpuMem < 2500 then
			--	Spring.SendCommands("advmapshading 0")
			--end
		end
	elseif hardware.gpuMem >= 3000 then
		if Spring.GetConfigInt("cus2", 1) ~= 1 then
			local cus = getOption("cusgl4")
			cus.onchange(cus, 1)
		end

		--local id = getOption('shadowslider')
		--options[id].options[1] = nil
		--if options[id].value == 1 then
		--	options[id].value = 2
		--	options[id].onchange(id, options[id].value)
		--end

		if not model.devMode and not model.devUI then
			removeOptions({ "cusgl4", "water" })
		else
			if Spring.GetConfigInt("Water", 0) ~= 4 then
				Spring.SendCommands("water 4")
				Spring.SetConfigInt("Water", 4)
			end
		end
	end

	if not hardware.isPotatoGpu and not model.devMode and not model.devUI then
		removeOptions({ "cusgl4" })
	end

	-- loads values via stored game config in luaui/configs
	loadAllWidgetData()

	-- remove widget-options that are unknown widgets
	local unknownWidgetOptions = {}
	for _, option in ipairs(model.options) do
		if option.widget and not widgetHandler.knownWidgets[option.widget] then
			unknownWidgetOptions[#unknownWidgetOptions + 1] = option.id
		end
	end
	removeOptions(unknownWidgetOptions)

	-- a toggle made for a widget another takes the place of switches that one (WidgetToggleTarget)
	for _, option in ipairs(model.options) do
		local target = option.widget and WidgetToggleTarget(option.widget)
		if target and target ~= option.widget then
			option.widget = target
			if option.type == "bool" then
				option.value = GetWidgetToggleValue(target)
			end
		end
	end

	-- add music tracks options
	local trackList
	if WG.music ~= nil then
		trackList = WG.music.getTracksConfig()
	end
	if type(trackList) == "table" then
		local newOptions = {}
		local count = 0
		local prevCategory = ""
		local categoryID
		local categories = 0
		for i, option in ipairs(model.options) do
			count = count + 1
			newOptions[count] = option
			if option.id == "soundtrackFades" then
				count = count + 1
				newOptions[count] = {
					id = "label_sound_music",
					group = "sound",
					name = BAR.I18N("ui.settings.option.label_playlist"),
					category = types.basic,
				}

				for k, v in pairs(trackList) do
					if prevCategory ~= v[1] then
						prevCategory = v[1]
						categories = categories + 1
						categoryID = "music_category_" .. categories
						count = count + 1
						newOptions[count] =
							{ id = categoryID, group = "sound", category = types.basic, name = v[1], type = "text" }
					end
					count = count + 1
					newOptions[count] = {
						id = "music_track_" .. count,
						parent = categoryID,
						compact = true,
						group = "sound",
						category = types.basic,
						name = v[2],
						type = "bool",
						value = Spring.GetConfigInt("MusicSwitch " .. v[2], 1) == 1, --..'\n'..v[4],
						onclick = function()
							if WG.music ~= nil and WG.music.playTrack then
								WG.music.playTrack(v[3])
							end
						end,
						onchange = function(_, value)
							Spring.SetConfigInt("MusicSwitch " .. v[2], value and 1 or 0)
							--Spring.Echo(value, v[1], v[2], v[3], Spring.GetConfigInt("MusicSwitch " .. v[2], 1))
						end,
					}
				end
			end
		end
		model.options = newOptions
		indexOptions()
	end

	-- add sound notification sets
	if getOption("notifications_set") then
		local voiceset = Spring.GetConfigString("voiceset", "en/cephis")
		local currentVoiceSetOption
		local sets = {}
		local languageDirs = VFS.SubDirs("sounds/voice", "*")
		local setCount = 0
		for k, f in ipairs(languageDirs) do
			local langDir = string.gsub(string.sub(f, 14, string.len(f) - 1), "\\", "/")
			local files = VFS.SubDirs("sounds/voice/" .. langDir, "*")
			for k, file in ipairs(files) do
				local dirname = string.gsub(string.sub(file, 14, string.len(file) - 1), "\\", "/")
				local setAlreadyIn = false
				for i = 1, #sets do
					if dirname == sets[i] then
						setAlreadyIn = true
						break
					end
				end
				if not setAlreadyIn then
					sets[#sets + 1] = dirname
					setCount = setCount + 1
					if dirname == voiceset then
						currentVoiceSetOption = #sets
					end
				end
			end
		end
		if setCount == 0 then
			removeOptions({ "notifications_set", "notifications_spoken", "notifications_volume" })
		else
			getOption("notifications_set").options = sets
			if currentVoiceSetOption then
				getOption("notifications_set").value = currentVoiceSetOption
			end
		end
	end

	-- add sound notification widget sound toggle options
	local notificationList
	if WG.notifications ~= nil then
		notificationList = WG.notifications.getNotificationList()
	elseif
		widgetHandler.configData.Notifications ~= nil
		and widgetHandler.configData.Notifications.notificationList ~= nil
	then
		notificationList = widgetHandler.configData.Notifications.notificationList
	end
	if type(notificationList) == "table" then
		local newOptions = {}
		local count = 0
		for i, option in ipairs(model.options) do
			count = count + 1
			newOptions[count] = option
			if option.id == "label_notif_messages" then
				for k, v in pairs(notificationList) do
					if type(v) == "table" then
						count = count + 1
						newOptions[count] = {
							id = "notifications_notif_" .. v[1],
							parent = "label_notif_messages",
							compact = true,
							group = "notif",
							category = types.basic,
							name = BAR.I18N(v[3]),
							dimmed = v[4] == 0, -- no voice lines in this set
							type = "bool",
							value = v[2], --description = v[3] and Spring.I18N(v[3]) or "",
							onchange = function(_, value)
								saveOptionValue(
									"Notifications",
									"notifications",
									"setNotification" .. v[1],
									{ "notificationList", v[1] },
									value
								)
							end,
							onclick = function()
								if WG.notifications ~= nil and WG.notifications.playNotification then
									WG.notifications.playNotification(v[1])
								end
							end,
						}
					end
				end
			end
		end
		model.options = newOptions
		indexOptions()
	end

	-- add auto cloak toggles
	local defaultUnitdefConfig = { -- copy pasted defaults from the widget
		[UnitDefNames.armdecom and UnitDefNames.armdecom.id or -1] = false,
		[UnitDefNames.cordecom and UnitDefNames.cordecom.id or -1] = false,
		[UnitDefNames.armferret and UnitDefNames.armferret.id or -1] = false,
		[UnitDefNames.armamb and UnitDefNames.armamb.id or -1] = false,
		[UnitDefNames.armpb and UnitDefNames.armpb.id or -1] = false,
		[UnitDefNames.armsnipe and UnitDefNames.armsnipe.id or -1] = false,
		[UnitDefNames.corsktl and UnitDefNames.corsktl.id or -1] = false,
		[UnitDefNames.armgremlin and UnitDefNames.armgremlin.id or -1] = true,
		[UnitDefNames.armamex and UnitDefNames.armamex.id or -1] = true,
		[UnitDefNames.armshockwave and UnitDefNames.armshockwave.id or -1] = true,
		[UnitDefNames.armckfus and UnitDefNames.armckfus.id or -1] = true,
		[UnitDefNames.armspy and UnitDefNames.armspy.id or -1] = true,
		[UnitDefNames.corspy and UnitDefNames.corspy.id or -1] = true,
		[UnitDefNames.corphantom and UnitDefNames.corphantom.id or -1] = true,
		[UnitDefNames.legaspy and UnitDefNames.legaspy.id or -1] = true,
	}
	local unitdefConfig = {}
	if WG.autocloak ~= nil then
		unitdefConfig = WG.autocloak.getUnitdefConfig()
	elseif
		widgetHandler.configData["Auto Cloak Units"] ~= nil
		and widgetHandler.configData["Auto Cloak Units"].unitdefConfig ~= nil
	then
		for unitName, value in pairs(widgetHandler.configData["Auto Cloak Units"].unitdefConfig) do
			if UnitDefNames[unitName] then
				local unitDefID = UnitDefNames[unitName].id
				unitdefConfig[unitDefID] = value
			end
		end
	end
	unitdefConfig = table.merge(defaultUnitdefConfig, unitdefConfig)
	if type(unitdefConfig) == "table" then
		local newOptions = {}
		local count = 0
		for i, option in ipairs(model.options) do
			count = count + 1
			newOptions[count] = option
			if option.id == "autocloak" then
				for k, v in pairs(unitdefConfig) do
					if UnitDefs[k] then
						local faction = BAR.I18N("units.factions." .. string.sub(UnitDefs[k].name, 1, 3))
						if faction then
							count = count + 1
							newOptions[count] = {
								id = "autocloak_" .. k,
								parent = "autocloak",
								compact = true,
								group = "game",
								category = types.basic,
								name = UnitDefs[k].translatedHumanName .. "  (" .. faction .. ")",
								type = "bool",
								value = v,
								description = UnitDefs[k].translatedTooltip,
								onchange = function(_, value)
									saveOptionValue(
										"Auto Cloak Units",
										"autocloak",
										"setUnitdefConfig",
										{ "unitdefConfig", UnitDefs[k].name },
										value,
										{ k, value }
									)
								end,
							}
						end
					end
				end
			end
		end
		model.options = newOptions
		indexOptions()
	end

	-- cursors
	if WG.cursors ~= nil and WG.cursors.getsizemult then
		getOption("cursorsize").value = WG.cursors.getsizemult()
	else
		removeOptions({ "cursorsize" })
	end

	if WG.smartselect == nil then
		removeOptions({
			"smartselect_includebuildings",
			"smartselect_includebuilders",
			"smartselect_includeresurrectors",
			"smartselect_includeantinuke",
			"smartselect_includeradar",
			"smartselect_includejammer",
		})
	else
		getOption("smartselect_includebuildings").value = WG.smartselect.getIncludeBuildings()
		getOption("smartselect_includebuilders").value = WG.smartselect.getIncludeBuilders()
		getOption("smartselect_includeresurrectors").value = WG.smartselect.getIncludeResurrectors()
		getOption("smartselect_includeantinuke").value = WG.smartselect.getIncludeAntinuke()
		getOption("smartselect_includeradar").value = WG.smartselect.getIncludeRadar()
		getOption("smartselect_includejammer").value = WG.smartselect.getIncludeJammer()
	end

	if WG.snow ~= nil and WG.snow.getSnowMap ~= nil then
		getOption("snowmap").value = WG.snow.getSnowMap()
	end

	-- doing this in order to detect if vsync is actually on due to the only when spectator setting
	local vsync = getOption("vsync")
	vsync.onchange(vsync, vsync.value)

	-- add user widgets

	-- look for custom widget options
	local userwidgetOptions = {}
	local usedCustomOptions = {}
	for k, option in ipairs(customOptions) do
		if not getOption(option.id) and option.widgetname then -- prevent adding duplicate
			if not userwidgetOptions[option.widgetname] then
				userwidgetOptions[option.widgetname] = {}
			end
			userwidgetOptions[option.widgetname][#userwidgetOptions[option.widgetname] + 1] = k
		end
	end
	local userwidgetsDetected = false
	for name, data in pairs(widgetHandler.knownWidgets) do
		if not data.fromZip then
			if not userwidgetsDetected then
				userwidgetsDetected = true
				model.options[#model.options + 1] = {
					id = "label_custom_widgets",
					group = "custom",
					name = BAR.I18N("ui.settings.option.label_widgets"),
					category = types.basic,
				}
			end
			local desc = data.desc or ""
			if desc ~= "" and WG.tooltip then
				local maxWidth = WG.tooltip.getFontsize() * 90
				local textLines, _ = WG.fonts.getFont():WrapText(desc, maxWidth)
				desc = string.gsub(textLines, "[\n]", "\n")
			end
			if data.author and data.author ~= "" then
				desc = desc
					.. (desc ~= "" and "\n" or "")
					.. widgetOptionColor
					.. BAR.I18N("ui.settings.option.author")
					.. ": "
					.. data.author
			end
			local widgetOptionID = "widget_" .. string.gsub(data.basename, ".lua", "")
			model.options[#model.options + 1] = {
				id = widgetOptionID,
				group = "custom",
				category = types.basic,
				widget = name,
				name = name,
				type = "bool",
				value = GetWidgetToggleValue(name),
				description = desc,
			}
			if userwidgetOptions[name] then
				for k, customOption in pairs(userwidgetOptions[name]) do
					local option = table.copy(customOptions[customOption])
					if oldValues[option.id] ~= nil then
						option.value = oldValues[option.id]
					end
					option.parent = option.parent or widgetOptionID
					model.options[#model.options + 1] = option
					usedCustomOptions[customOption] = true
				end
			end
		end
	end

	indexOptions()

	-- add custom added options (done via WG.options.addOption)
	local otherCustomOptions, otherCustomIDs = {}, {}
	for k, option in ipairs(customOptions) do
		-- prevent adding duplicate (a label may come without an id)
		local duplicate = option.id ~= nil and (otherCustomIDs[option.id] or getOption(option.id))
		if not usedCustomOptions[k] and not duplicate then
			if option.id ~= nil then
				otherCustomIDs[option.id] = true
			end
			otherCustomOptions[#otherCustomOptions + 1] = option
		end
	end
	if otherCustomOptions[1] then
		model.options[#model.options + 1] = {
			id = "label_custom_options",
			group = "custom",
			name = BAR.I18N("ui.settings.option.label_options"),
			category = types.basic,
		}
		table.append(model.options, otherCustomOptions)
	end

	-- The full list in tab order. A sub-option sits one level below its parent, or moves up when the
	-- parent was removed, and every label gets an empty row below it for its text to run into.
	local groupRows = {}
	for _, group in ipairs(model.groups) do
		groupRows[group.id] = {}
	end
	local placed = {}
	for _, option in ipairs(model.options) do
		local rows = groupRows[option.group]
		-- rows with neither type nor name are spacers, which the labels bring along now
		if rows and (option.type or option.name) then
			-- keep slider knobs within their slider
			if option.type == "slider" and not option.steps then
				if type(option.value) ~= "number" then
					option.value = option.min
				end
				option.value = math.max(option.min, math.min(option.max, option.value))
			end
			option.parentOption = option.parent and placed[option.parent]
			option.depth = option.parentOption and option.parentOption.depth + 1 or 0
			-- depth does the indenting; some translations still start with the old indent spaces
			if type(option.name) == "string" then
				option.name = option.name:gsub("^%s+", "")
			end
			if option.id and not placed[option.id] then
				placed[option.id] = option
			end
			rows[#rows + 1] = option
			if not option.type then
				option.spacer =
					{ id = option.id and option.id .. "_spacer", group = option.group, category = option.category }
				rows[#rows + 1] = option.spacer
			end
		end
	end
	model.allOptions = {}
	for _, group in ipairs(model.groups) do
		group.numOptions = #groupRows[group.id]
		table.append(model.allOptions, groupRows[group.id])
	end
	model.options = model.allOptions
	indexOptions()

	if not requireRestartDefaultsSet then
		requireRestartDefaultsSet = true
		for i, option in pairs(model.options) do
			if option.restart and requireRestartDefaults[option.id] == nil then
				requireRestartDefaults[option.id] = option.value
			end
		end
	end

	model.changesRequireRestart = false
	for id, value in pairs(requireRestartDefaults) do
		if getOption(id) and getOption(id).value ~= value then
			model.changesRequireRestart = true
		end
	end

	model.onRebuilt()
	-- Filter last, the checks above need every option. Also rebuilds the window.
	applyFilter()
end
model.init = init

-- Reads again what can change elsewhere while the window is open, except what isHeld says the user has
-- hold of. Returns whether anything changed.
function model.syncValues(isHeld)
	local changes = false
	-- Sync widget toggle values in allOptions (the authoritative list)
	-- so changes persist across filter apply/clear cycles.
	for _, option in ipairs(model.allOptions) do
		if option.widget ~= nil and option.type == "bool" and option.value ~= GetWidgetToggleValue(option.widget) then
			option.value = GetWidgetToggleValue(option.widget)
			changes = true
		end
	end
	local resolution = getOption("resolution")
	if resolution and resolution.onload then
		local before = resolution.options[resolution.value]
		resolution.onload(resolution)
		changes = changes or resolution.options[resolution.value] ~= before
	end
	if rereadBound(isHeld) then
		changes = true
	end
	local masterVolume, musicVolume = getOption("sndvolmaster"), getOption("sndvolmusic")
	if masterVolume then
		local value = tonumber(Spring.GetConfigInt("snd_volmaster", 40) or 40) -- update value because other widgets can adjust this too
		changes = changes or value ~= masterVolume.value
		masterVolume.value = value
	end
	if musicVolume then
		local value
		if WG.music and WG.music.GetMusicVolume then
			value = WG.music.GetMusicVolume()
		else
			value = tonumber(Spring.GetConfigInt("snd_volmusic", 50) or 50)
		end
		changes = changes or value ~= musicVolume.value
		musicVolume.value = value
	end
	return changes
end

-- What was put off to the next update: pickingId is the option whose color is still being picked, and
-- whose scheduled apply waits for that.
function model.runScheduled(pickingId)
	-- widgetHandler:EnableWidget/DisableWidget are deferred but are used to change displayed options. This is a solution to update the options list after next frame.
	if model.scheduleInit then
		model.scheduleInit = nil
		init()
	end

	local scheduled = model.scheduledApply
	if scheduled and scheduled[1] <= os.clock() and scheduled[2] ~= pickingId then
		applyOptionValueByID(scheduled[2], nil, true, true)
		model.scheduledApply = nil
	end
end

-- /option <id> [value]: without a value a toggle flips
function model.applyCommand(option, params)
	if not params[2] then
		applyOptionValueByID(option.id, not option.value)
		return
	end
	if option.type == "select" then
		local selectKey = getSelectKey(option, params[2])
		if selectKey then
			applyOptionValueByID(option.id, selectKey)
		end
	elseif option.type == "bool" then
		local value
		if params[2] == "0" then
			value = false
		elseif params[2] == "0.5" then
			value = 0.5
		else
			value = true
		end
		applyOptionValueByID(option.id, value)
	elseif option.type == "color" then
		-- the three channels, as the strip shows them
		local value = {}
		for i = 1, 3 do
			local channel = tonumber(params[i + 1])
			if not channel then
				return
			end
			value[i] = math.max(0, math.min(option.max, channel))
		end
		applyOptionValueByID(option.id, value)
	else
		applyOptionValueByID(option.id, tonumber(params[2]))
	end
end

-- WG.options, as far as it is not about the window
function model.api()
	local api = {}
	api.getOptionsList = function()
		local optionList = {}
		for i, option in pairs(model.allOptions) do
			optionList[#optionList + 1] = option.id
		end
		return optionList
	end
	api.getOptionValue = function(id)
		local option = getOption(id)
		if option then
			return option.value
		end
	end
	api.getCameraSmoothness = function()
		return state.cameraTransitionTime
	end
	api.addOptions = function(newOptions)
		for _, option in ipairs(newOptions) do
			option.group = "custom"
			-- FIXME: Applying an option with a widget enables or disables that widget. Remove from user widgets.
			option.widget = nil
			customOptions[#customOptions + 1] = option
		end

		init()
	end
	api.removeOptions = function(names)
		local remove = table.invert(names)
		customOptions = table.filterArray(customOptions, function(option)
			return not remove[option.id]
		end)

		init()
	end
	api.addOption = function(option)
		return api.addOptions({ option })
	end
	api.removeOption = function(name)
		return api.removeOptions({ name })
	end
	api.applyOptionValue = function(id, value)
		local option = getOption(id)
		if not option then
			Spring.Echo("Options widget: applyOptionValue: option '" .. id .. "' not found")
			return
		end
		if option.widget then
			Spring.Echo("Options widget: applyOptionValue: option '" .. id .. "' denied by sandboxing")
			return
		end
		if option.type == "color" then
			if type(value) == "table" and tonumber(value[1]) and tonumber(value[2]) and tonumber(value[3]) then
				applyOptionValueByID(id, { tonumber(value[1]), tonumber(value[2]), tonumber(value[3]) })
			end
			return
		end
		applyOptionValueByID(id, tonumber(value))
	end
	return api
end

function model.getConfigData()
	local data = upkeep.getConfigData()
	data.advSettings = model.advSettings
	data.changesRequireRestart = model.changesRequireRestart
	data.requireRestartDefaults = requireRestartDefaults
	return data
end

function model.setConfigData(data)
	upkeep.setConfigData(data)
	if Spring.GetGameFrame() > 0 then
		if data.requireRestartDefaults then
			requireRestartDefaults = data.requireRestartDefaults
		end
		if data.changesRequireRestart then
			model.changesRequireRestart = data.changesRequireRestart
		end
	end
	if data.advSettings ~= nil then
		model.advSettings = data.advSettings
	end
end

return model
