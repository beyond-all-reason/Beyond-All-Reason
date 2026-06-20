local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Game Modes JSON Export",
		desc = "Exports all game mode presets (modes/<category>/*.lua) to structured JSON.\nCommand: /exportgamemodes",
		author = "Daniel Harvey",
		date = "June 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = false
	}
end

-- Single source of truth = the Lua mode presets (modes/<category>/*.lua) overlaid
-- on the modoptions.lua defaults, emitted as JSON so out-of-engine consumers (e.g.
-- the SPADS ModeCommand plugin) can expand a bare mode selection into its full
-- option set without re-reading the game's Lua. Run headless and quit; see
-- tools/headless_testing/startscript_modes_export.txt.

local spEcho = Spring.Echo

local SCHEMA_VERSION = 1
local OUTPUT_PATH = "game_modes.json"

-- modoptions are strings on the wire; booleans map to the engine's "1"/"0".
-- Engine Lua numbers are float32, so plain tostring leaks precision noise
-- ("0.60000002"). Round at float32's ~7-digit precision with %.7f, then strip
-- trailing zeros manually (the engine's %g does not trim them). Yields "0.6",
-- "30", "-1" rather than "0.6000000".
local function toModOptionValue(v)
	if type(v) == "boolean" then return v and "1" or "0" end
	if type(v) == "number" then
		local s = string.format("%.7f", v):gsub("0+$", ""):gsub("%.$", "")
		return s
	end
	return tostring(v)
end

-- Each modoption section becomes a mode category's default base: section name == category.
local function collectDefaultsBySection()
	local bySection = {}
	for _, o in ipairs(VFS.Include("modoptions.lua")) do
		if o.key and o.section and o.def ~= nil
			and o.type ~= "section" and o.type ~= "subheader" and o.type ~= "separator" then
			bySection[o.section] = bySection[o.section] or {}
			bySection[o.section][o.key] = toModOptionValue(o.def)
		end
	end
	return bySection
end

-- Discover every mode under modes/<category>/*.lua. Helper files at modes/ root are
-- skipped (we only descend into subdirs), as are any returns lacking key/category.
local function collectModesByCategory()
	local byCategory = {}
	for _, dir in ipairs(VFS.SubDirs("modes/") or {}) do
		for _, modeFile in ipairs(VFS.DirList(dir, "*.lua") or {}) do
			local ok, mode = pcall(VFS.Include, modeFile)
			if ok and type(mode) == "table" and mode.key and mode.category then
				byCategory[mode.category] = byCategory[mode.category] or {}
				byCategory[mode.category][mode.key] = mode
			end
		end
	end
	return byCategory
end

-- Full effective option set for a mode: section defaults, then the mode's overrides.
-- Emitting defaults too means applying a mode resets whatever a previous one changed.
local function buildEffectiveModOptions(defaults, mode, selector)
	local effective = {}
	for key, value in pairs(defaults) do
		if key ~= selector then
			effective[key] = { value = value, locked = false }
		end
	end
	for key, rule in pairs(mode.modOptions or {}) do
		if key ~= selector and rule.value ~= nil then
			effective[key] = { value = toModOptionValue(rule.value), locked = rule.locked == true }
		end
	end
	return effective
end

local function buildExport()
	local defaultsBySection = collectDefaultsBySection()
	local modesByCategory = collectModesByCategory()

	local categories = {}
	for category, modes in pairs(modesByCategory) do
		local selector = category .. "_mode"
		local defaults = defaultsBySection[category] or {}
		local presets = {}
		for modeKey, mode in pairs(modes) do
			presets[modeKey] = {
				name = mode.name,
				desc = mode.desc,
				allowRanked = mode.allowRanked,
				modOptions = buildEffectiveModOptions(defaults, mode, selector),
			}
		end
		categories[category] = { selector = selector, presets = presets }
	end

	return { schemaVersion = SCHEMA_VERSION, categories = categories }
end

local function ExportGameModes()
	local file, err = io.open(OUTPUT_PATH, "w")
	if not file then
		spEcho("Game Modes JSON Export: could not open " .. OUTPUT_PATH .. ": " .. tostring(err))
		return
	end
	file:write(Json.encode(buildExport()))
	file:close()
	spEcho("Game Modes JSON Export: wrote " .. OUTPUT_PATH)
end

function widget:TextCommand(command)
	if command == "exportgamemodes" then
		ExportGameModes()
	end
end
