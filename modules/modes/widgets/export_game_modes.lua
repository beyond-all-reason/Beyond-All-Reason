local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Game Modes JSON Export",
		desc = "Exports all game mode presets (modes/<category>/*.lua) to structured JSON.\nCommand: /exportgamemodes",
		author = "Daniel Harvey",
		date = "June 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = false,
	}
end

-- Emit the Lua mode presets overlaid on modoptions.lua defaults as JSON so out-of-engine
-- consumers (SPADS ModeCommand plugin) can expand a mode selection into its full option set.

local spEcho = Spring.Echo

local SCHEMA_VERSION = 1
local OUTPUT_PATH = "game_modes.json"

-- modoptions are strings; booleans -> "1"/"0", numbers rounded at float32 precision to avoid noise.
local function toModOptionValue(v)
	if type(v) == "boolean" then
		return v and "1" or "0"
	end
	if type(v) == "number" then
		local s = string.format("%.7f", v):gsub("0+$", ""):gsub("%.$", "")
		return s
	end
	return tostring(v)
end

-- A category's default base is every option in the sections it governs. A
-- section is governed by its `mode_category` when it declares one (a flavor's
-- dials handing the choice to the game axis), else by its own key.
local function collectDefaultsByCategory()
	local defs = VFS.Include("modoptions.lua")
	local sectionCategory = {}
	for _, o in ipairs(defs) do
		if o.key and o.type == "section" then
			sectionCategory[o.key] = o.mode_category or o.key
		end
	end
	local byCategory = {}
	for _, o in ipairs(defs) do
		if o.key and o.section and o.def ~= nil and o.type ~= "section" and o.type ~= "subheader" and o.type ~= "separator" then
			local category = sectionCategory[o.section] or o.section
			byCategory[category] = byCategory[category] or {}
			byCategory[category][o.key] = toModOptionValue(o.def)
		end
	end
	return byCategory
end

-- Discover every mode under modules/<name>/modes/*.lua; key/category-less returns are skipped.
local function collectModesByCategory()
	local ModuleHandler = VFS.Include("modules/module_handler.lua")
	local byCategory = {}
	for _, dir in ipairs(ModuleHandler.ModeDirs()) do
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

-- Full effective option set (defaults then overrides), so applying a mode resets the previous one.
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
	local defaultsByCategory = collectDefaultsByCategory()
	local modesByCategory = collectModesByCategory()

	local categories = {}
	for category, modes in pairs(modesByCategory) do
		local selector = category .. "_mode"
		local defaults = defaultsByCategory[category] or {}
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
