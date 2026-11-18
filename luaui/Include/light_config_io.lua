-- Text side of the GL4 light editor: writes lights back into DeferredLightsGL4config.lua
-- and builds the presets file. Pure string work, no engine calls.

local IO = {}

local floor = math.floor
local abs = math.abs

-- Slot of every lightConfig key in a runtime lightParamTable.
IO.SLOT = {
	posx = 1,
	posy = 2,
	posz = 3,
	radius = 4,
	r = 9,
	g = 10,
	b = 11,
	a = 12,
	modelfactor = 13,
	specular = 14,
	scattering = 15,
	lensflare = 16,
	lifetime = 18,
	sustain = 19,
	selfshadowing = 20,
	color2r = 21,
	color2g = 22,
	color2b = 23,
	colortime = 24,
}
local AIM_KEYS = { "dirx", "diry", "dirz", "theta" }
local BEAM_KEYS = { "pos2x", "pos2y", "pos2z" }

local PLACE_KEYS = { "posx", "posy", "posz", "radius" }
local FADE_KEYS = { "color2r", "color2g", "color2b", "colortime" }
local LOOK_KEYS = {
	"r",
	"g",
	"b",
	"a",
	"modelfactor",
	"specular",
	"scattering",
	"lensflare",
	"lifetime",
	"sustain",
	"selfshadowing",
}

-- Keys a preset never sets: where the light sits and where it points.
IO.PLACEMENT = {
	posx = true,
	posy = true,
	posz = true,
	dirx = true,
	diry = true,
	dirz = true,
	pos2x = true,
	pos2y = true,
	pos2z = true,
}
-- Keys a preset sets only when asked to carry the size.
IO.SIZE = { radius = true, theta = true }

-- Light table fields the editor owns or the renderer adds at load.
local INTERNAL = {
	lightType = true,
	pieceName = true,
	lightConfig = true,
	lightParamTable = true,
	pieceIndex = true,
	initComplete = true,
	_presetSource = true,
}

---Shortest text that reads back as the same number.
---@param n number
---@return string
function IO.formatNumber(n)
	if n ~= n or n == math.huge or n == -math.huge then
		return "0"
	end
	if n == floor(n) and abs(n) < 1e15 then
		return string.format("%d", n)
	end
	for precision = 1, 17 do
		local text = string.format("%." .. precision .. "g", n)
		if tonumber(text) == n then
			return text
		end
	end
	return string.format("%.17g", n)
end

local function formatValue(v)
	if type(v) == "number" then
		return IO.formatNumber(v)
	elseif type(v) == "boolean" then
		return tostring(v)
	end
	return string.format("%q", tostring(v))
end

local KEYWORDS = {}
for word in
	("and break do else elseif end false for function if in local nil not or repeat return then true until while"):gmatch(
		"%a+"
	)
do
	KEYWORDS[word] = true
end

local function formatKey(key)
	if type(key) == "string" and key:match("^[%a_][%w_]*$") and not KEYWORDS[key] then
		return key
	end
	return "[" .. string.format("%q", tostring(key)) .. "]"
end

---lightConfig keys of one light type, in the order they are written.
---@param lightType string
---@param config table<string, number>
---@param base table<string, number>? fade or aim keys this sets count as in use too
---@return string[]
function IO.keyOrder(lightType, config, base)
	local order = {}
	local function add(keys)
		for i = 1, #keys do
			order[#order + 1] = keys[i]
		end
	end
	local function anySet(keys)
		for i = 1, #keys do
			if (config[keys[i]] or 0) ~= 0 or (base and (base[keys[i]] or 0) ~= 0) then
				return true
			end
		end
		return false
	end
	add(PLACE_KEYS)
	if lightType == "cone" then
		add(AIM_KEYS)
	elseif lightType == "beam" then
		add(BEAM_KEYS)
	elseif anySet(AIM_KEYS) then
		add(AIM_KEYS)
	end
	if anySet(FADE_KEYS) then
		add(FADE_KEYS)
	end
	add(LOOK_KEYS)
	return order
end

---A plain description of a light table from the renderer.
---@param lt table runtime light, before or after its late init
---@return table light { lightType, pieceName, config, extra, preset }
function IO.describe(lt)
	local lightType = lt.lightType or "point"
	local config = {}
	local p = lt.lightParamTable
	if p then
		for key, slot in pairs(IO.SLOT) do
			config[key] = p[slot] or 0
		end
		local slotKeys = lightType == "beam" and BEAM_KEYS or AIM_KEYS
		for i = 1, #slotKeys do
			config[slotKeys[i]] = p[4 + i] or 0
		end
	elseif lt.lightConfig then
		for key, value in pairs(lt.lightConfig) do
			if type(value) == "number" then
				config[key] = value
			end
		end
	end
	local extra = {}
	for key, value in pairs(lt) do
		local kind = type(value)
		if not INTERNAL[key] and (kind == "number" or kind == "string" or kind == "boolean") then
			extra[key] = value
		end
	end
	return {
		lightType = lightType,
		pieceName = lt.pieceName,
		config = config,
		extra = extra,
		preset = lt._presetSource,
	}
end

local function sortedKeys(t)
	local keys = {}
	for key in pairs(t) do
		keys[#keys + 1] = key
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return keys
end

---The lightConfig keys a preset-built light still has to spell out.
local function presetOverrides(light, presetDef)
	local base = presetDef.lightConfig or {}
	local lightType = light.lightType or presetDef.lightType or "point"
	local keys = {}
	local order = IO.keyOrder(lightType, light.config, base)
	for i = 1, #order do
		local key = order[i]
		local value = light.config[key] or 0
		local always = IO.PLACEMENT[key] or (key == "radius" and base.radius == nil)
		if always or value ~= (base[key] or 0) then
			keys[#keys + 1] = key
		end
	end
	return keys
end

---One light as config text, at `indent` tabs.
---@param name string
---@param light table from IO.describe
---@param presets table<string, table>? known presets; a light whose preset is missing is written in full
---@param indent integer?
---@return string[] lines
function IO.serializeLight(name, light, presets, indent)
	local tabs = string.rep("\t", indent or 2)
	local lines = {}
	local presetDef = light.preset and presets and presets[light.preset] or nil
	local lightType = light.lightType or "point"

	if presetDef then
		lines[#lines + 1] = tabs .. formatKey(name) .. " = preset(" .. formatValue(light.preset) .. ", {"
		if lightType ~= (presetDef.lightType or "point") then
			lines[#lines + 1] = tabs .. "\tlightType = " .. formatValue(lightType) .. ","
		end
	else
		lines[#lines + 1] = tabs .. formatKey(name) .. " = {"
		lines[#lines + 1] = tabs .. "\tlightType = " .. formatValue(lightType) .. ","
	end
	if light.pieceName and light.pieceName ~= "" then
		lines[#lines + 1] = tabs .. "\tpieceName = " .. formatValue(light.pieceName) .. ","
	end
	local extraKeys = sortedKeys(light.extra or {})
	for i = 1, #extraKeys do
		local key = extraKeys[i]
		lines[#lines + 1] = tabs .. "\t" .. formatKey(key) .. " = " .. formatValue(light.extra[key]) .. ","
	end

	local keys = presetDef and presetOverrides(light, presetDef) or IO.keyOrder(lightType, light.config)
	if #keys > 0 then
		lines[#lines + 1] = tabs .. "\tlightConfig = {"
		for i = 1, #keys do
			local key = keys[i]
			lines[#lines + 1] = tabs .. "\t\t" .. key .. " = " .. IO.formatNumber(light.config[key] or 0) .. ","
		end
		lines[#lines + 1] = tabs .. "\t},"
	end
	lines[#lines + 1] = tabs .. (presetDef and "})," or "},")
	return lines
end

---@param text string
---@return string[] lines, string eol
local function splitLines(text)
	local eol = text:find("\r\n", 1, true) and "\r\n" or "\n"
	local lines = {}
	for line in (text .. "\n"):gmatch("(.-)\r?\n") do
		lines[#lines + 1] = line
	end
	if lines[#lines] == "" then
		lines[#lines] = nil
	end
	return lines, eol
end

-- The key of a table entry opened at exactly `depth` tabs, or nil.
local function entryKey(line, depth)
	local tabs, rest = line:match("^(\t*)(.*)$")
	if #tabs ~= depth then
		return nil
	end
	local key = rest:match('^%["(.-)"%]%s*=') or rest:match("^%['(.-)'%]%s*=") or rest:match("^([%a_][%w_]*)%s*=")
	return key
end

-- Last line of the entry opened on line `first` at `depth` tabs.
local function entryEnd(lines, first, depth, limit)
	local head = lines[first]
	local code = head:gsub("%-%-.*$", "")
	local _, opens = code:gsub("[{(]", "")
	local _, closes = code:gsub("[})]", "")
	if opens <= closes then
		return first
	end
	local closer = "^" .. string.rep("\t", depth) .. "}"
	for i = first + 1, limit do
		if lines[i]:find(closer) then
			return i
		end
	end
	return nil
end

-- Lines of a top level table's body: after its opening line, before its closing brace.
local function tableRegion(lines, tableName)
	local first
	for i = 1, #lines do
		if lines[i]:find("^local " .. tableName .. "%s*=%s*{") then
			first = i
			break
		end
	end
	if not first or lines[first]:find("}") then
		return nil
	end
	for i = first + 1, #lines do
		if lines[i]:find("^}") then
			return first + 1, i - 1
		end
	end
	return nil
end

local function unitsRegion(lines)
	return tableRegion(lines, "unitLights")
end

-- Calls fn(key, firstLine, lastLine) for each entry at `depth` tabs between two lines.
local function eachEntry(lines, from, to, depth, fn)
	local i = from
	local inComment = false
	while i <= to do
		local line = lines[i]
		if inComment then
			if line:find("]", 1, true) and line:find("%]=*%]") then
				inComment = false
			end
			i = i + 1
		elseif line:find("^%s*%-%-%[=*%[") and not line:find("%]=*%]") then
			inComment = true
			i = i + 1
		else
			local key = entryKey(line, depth)
			if key then
				local last = entryEnd(lines, i, depth, to)
				if not last then
					return false
				end
				if fn(key, i, last) == false then
					return true
				end
				i = last + 1
			else
				i = i + 1
			end
		end
	end
	return true
end

local function findEntry(lines, from, to, depth, wanted)
	local first, last
	eachEntry(lines, from, to, depth, function(key, a, b)
		-- the same key twice: Lua keeps the last
		if key == wanted then
			first, last = a, b
		end
	end)
	return first, last
end

---Every unit block in the config text, with the names of its lights.
---@param text string
---@return table<string, string[]>? units, string? err
function IO.listUnits(text)
	local lines = splitLines(text)
	local from, to = unitsRegion(lines)
	if not from then
		return nil, "no unitLights table in the config"
	end
	local units = {}
	local ok = eachEntry(lines, from, to, 1, function(unitName, first, last)
		local names = {}
		if last > first then
			eachEntry(lines, first + 1, last - 1, 2, function(lightName)
				names[#names + 1] = lightName
			end)
		end
		units[unitName] = names
	end)
	if not ok then
		return nil, "a unit block in the config has no closing line"
	end
	return units
end

---The unit a name gets its lights from, when the config assigns them after the table:
---`unitLights.armdecom = unitLights.armcom`.
---@param text string
---@param unitName string
---@return string? source
function IO.aliasSource(text, unitName)
	local pattern = "\nunitLights%." .. unitName:gsub("%p", "%%%0") .. "%s*=%s*([^\r\n]+)"
	local source = text:match(pattern)
	if not source then
		return nil
	end
	return source:match("unitLights%.([%w_]+)") or source
end

---Writes edited lights of one unit into the config text. Lights not named stay as they are.
---@param text string the config file
---@param unitName string
---@param edits table { set = { [name] = light }, remove = { [name] = true } }
---@param presets table<string, table>?
---@return string? newText, string? err
function IO.applyEdits(text, unitName, edits, presets)
	local lines, eol = splitLines(text)
	local from, to = unitsRegion(lines)
	if not from then
		return nil, "no unitLights table in the config"
	end
	to = to or from
	local set = edits.set or {}
	local remove = edits.remove or {}

	local uFirst, uLast = findEntry(lines, from, to, 1, unitName)
	if not uFirst then
		if next(set) == nil then
			return text
		end
		local plain = unitName:gsub("%p", "%%%0")
		for i = from, to do
			local line = lines[i] or ""
			if line:find("^%s*" .. plain .. "%s*=") or line:find('^%s*%["' .. plain .. '"%]%s*=') then
				return nil, unitName .. " has a block this editor cannot read: indent it with tabs"
			end
		end
		local block = { "\t" .. formatKey(unitName) .. " = {" }
		local names = sortedKeys(set)
		for i = 1, #names do
			local lightLines = IO.serializeLight(names[i], set[names[i]], presets, 2)
			for j = 1, #lightLines do
				block[#block + 1] = lightLines[j]
			end
		end
		block[#block + 1] = "\t},"
		local out = {}
		for i = 1, to do
			out[#out + 1] = lines[i]
		end
		for i = 1, #block do
			out[#out + 1] = block[i]
		end
		for i = to + 1, #lines do
			out[#out + 1] = lines[i]
		end
		return table.concat(out, eol) .. eol
	end

	uLast = uLast or uFirst
	if uLast == uFirst then
		-- `name = {},`: open it up; one with lights in it is not split here
		local head, rest = lines[uFirst]:match("^(.-{)(.*)$")
		if not (head and rest:gsub("%-%-.*$", ""):find("^%s*}%s*,?%s*$")) then
			return nil, "the block of " .. unitName .. " is on one line: split it first"
		end
		table.remove(lines, uFirst)
		table.insert(lines, uFirst, "\t}," .. (rest:match("(%-%-.*)$") and (" " .. rest:match("(%-%-.*)$")) or ""))
		table.insert(lines, uFirst, head)
		uLast = uFirst + 1
	end

	local spans = {}
	local ok = eachEntry(lines, uFirst + 1, uLast - 1, 2, function(lightName, first, last)
		spans[#spans + 1] = { name = lightName, first = first, last = last }
	end)
	if not ok then
		return nil, "a light of " .. unitName .. " has no closing line"
	end

	local out = {}
	for i = 1, uFirst do
		out[#out + 1] = lines[i]
	end
	local cursor = uFirst + 1
	local written = {}
	for _, span in ipairs(spans) do
		local gapEnd = span.first - 1
		if remove[span.name] and not set[span.name] then
			-- comment lines right above a removed light go with it
			while gapEnd >= cursor do
				local line = lines[gapEnd] or ""
				if not line:find("^%s*%-%-") or line:find("^%s*%-%-%[") or line:find("%]=*%]") then
					break
				end
				gapEnd = gapEnd - 1
			end
		end
		for i = cursor, gapEnd do
			out[#out + 1] = lines[i]
		end
		if set[span.name] then
			local lightLines = IO.serializeLight(span.name, set[span.name], presets, 2)
			for j = 1, #lightLines do
				out[#out + 1] = lightLines[j]
			end
			written[span.name] = true
		elseif not remove[span.name] then
			for i = span.first, span.last do
				out[#out + 1] = lines[i]
			end
		end
		cursor = span.last + 1
	end
	for i = cursor, uLast - 1 do
		out[#out + 1] = lines[i]
	end
	local names = sortedKeys(set)
	for i = 1, #names do
		if not written[names[i]] then
			local lightLines = IO.serializeLight(names[i], set[names[i]], presets, 2)
			for j = 1, #lightLines do
				out[#out + 1] = lightLines[j]
			end
		end
	end
	for i = uLast, #lines do
		out[#out + 1] = lines[i]
	end
	return table.concat(out, eol) .. eol
end

---A whole unit block as text, for the clipboard.
---@param unitName string
---@param lights table<string, table> name to light
---@param presets table<string, table>?
---@return string
function IO.serializeUnit(unitName, lights, presets)
	local out = { "\t" .. formatKey(unitName) .. " = {" }
	local names = sortedKeys(lights)
	for i = 1, #names do
		local lightLines = IO.serializeLight(names[i], lights[names[i]], presets, 2)
		for j = 1, #lightLines do
			out[#out + 1] = lightLines[j]
		end
	end
	out[#out + 1] = "\t},"
	return table.concat(out, "\n")
end

-- The config tables that hold the lights of each weapon, by kind.
IO.WEAPON_TABLE = {
	muzzle = "muzzleFlashLightsNames",
	projectile = "projectileDefLightsNames",
	explosion = "explosionLightsNames",
}

---The base classes of the weapon light config and the light type of each.
---@param text string DeferredLightsGL4WeaponsConfig.lua
---@return table<string, string> lightTypes class name to "point", "cone" or "beam"
function IO.listBaseClasses(text)
	local lines = splitLines(text)
	local classes = {}
	local from, to = tableRegion(lines, "BaseClasses")
	if from and to then
		eachEntry(lines, from, to, 1, function(className, first, last)
			local lightType = "point"
			for i = first, last do
				lightType = lines[i]:match('^\t\tlightType%s*=%s*"(%a+)"') or lightType
			end
			classes[className] = lightType
		end)
	end
	return classes
end

---The base class a weapon light was built from, read off its class name.
---@param classes table<string, string> from IO.listBaseClasses
---@param lightClassName string? the runtime light's lightClassName
---@param lightType string
---@param kind string "muzzle", "projectile" or "explosion"
---@return string? baseClass
function IO.baseClassFor(classes, lightClassName, lightType, kind)
	local best
	for className, classType in pairs(classes) do
		local isPrefix = lightClassName and lightClassName:sub(1, #className) == className
		if isPrefix and classType == lightType and (not best or #className > #best) then
			best = className
		end
	end
	if best then
		return best
	end
	local wanted = kind == "muzzle" and "MuzzleFlash" or kind == "explosion" and "Explosion" or "Projectile"
	local names = sortedKeys(classes)
	for i = 1, #names do
		if classes[names[i]] == lightType and names[i]:find(wanted, 1, true) then
			return names[i]
		end
	end
	for i = 1, #names do
		if classes[names[i]] == lightType then
			return names[i]
		end
	end
	return nil
end

---One weapon light as an override statement of the weapon light config.
---@param kind string "muzzle", "projectile" or "explosion"
---@param weaponName string weapon def name
---@param baseClass string
---@param light table from IO.describe
---@return string[] lines
function IO.serializeWeaponLight(kind, weaponName, baseClass, light)
	local key = formatKey(weaponName)
	local target = IO.WEAPON_TABLE[kind] .. (key == weaponName and ("." .. key) or key)
	local lines = { target .. " = GetLightClass(" .. formatValue(baseClass) .. ", nil, nil, {" }
	local order = IO.keyOrder(light.lightType, light.config)
	for i = 1, #order do
		local value = light.config[order[i]]
		if value ~= nil then
			lines[#lines + 1] = "\t" .. order[i] .. " = " .. IO.formatNumber(value) .. ","
		end
	end
	lines[#lines + 1] = "})"
	return lines
end

-- First and last line of the last statement that assigns a weapon's light, or nil.
local function weaponStatement(lines, kind, weaponName)
	local tableName = IO.WEAPON_TABLE[kind]
	local heads = { tableName .. "." .. weaponName, tableName .. '["' .. weaponName .. '"]' }
	local found, inComment = nil, false
	for i = 1, #lines do
		local line = lines[i]
		if inComment then
			inComment = not line:find("%]=*%]")
		elseif line:find("^%s*%-%-%[=*%[") and not line:find("%]=*%]") then
			inComment = true
		else
			for h = 1, #heads do
				local head = heads[h]
				if line:sub(1, #head) == head and line:sub(#head + 1):find("^%s*=") then
					found = i
				end
			end
		end
	end
	if not found then
		return nil
	end
	-- `X.a = X.b`: one line, no call to follow
	local head = lines[found]:gsub("%-%-.*$", "")
	if not head:find("[({]") and not head:find("=%s*$") then
		return found, found
	end
	local depth, opened = 0, false
	for i = found, #lines do
		local code = lines[i]:gsub("%-%-.*$", "")
		for paren in code:gmatch("[()]") do
			depth = depth + (paren == "(" and 1 or -1)
			opened = true
		end
		if opened and depth <= 0 then
			return found, i
		end
	end
	return nil
end

---Writes one weapon's light into the weapon light config, in place of its override or as a new one.
---@param text string DeferredLightsGL4WeaponsConfig.lua
---@param kind string "muzzle", "projectile" or "explosion"
---@param weaponName string
---@param baseClass string
---@param light table from IO.describe
---@return string? newText, string? err
function IO.applyWeaponEdit(text, kind, weaponName, baseClass, light)
	local lines, eol = splitLines(text)
	local statement = IO.serializeWeaponLight(kind, weaponName, baseClass, light)
	local first, last = weaponStatement(lines, kind, weaponName)
	local out = {}
	if first and last then
		for i = 1, first - 1 do
			out[#out + 1] = lines[i]
		end
		for i = 1, #statement do
			out[#out + 1] = statement[i]
		end
		for i = last + 1, #lines do
			out[#out + 1] = lines[i]
		end
		return table.concat(out, eol) .. eol
	end

	-- a new override goes right above the code that turns weapon names into ids
	local anchor
	for i = 1, #lines do
		if
			lines[i]:find("^function applyScavVariants")
			or lines[i]:find("^for name, params in pairs%(%a+LightsNames%)")
		then
			anchor = i
			break
		end
	end
	if not anchor then
		return nil, "no place for weapon overrides in the config"
	end
	while anchor > 1 and lines[anchor - 1]:find("^%-%-") do
		anchor = anchor - 1
	end
	for i = 1, anchor - 1 do
		out[#out + 1] = lines[i]
	end
	for i = 1, #statement do
		out[#out + 1] = statement[i]
	end
	out[#out + 1] = ""
	for i = anchor, #lines do
		out[#out + 1] = lines[i]
	end
	return table.concat(out, eol) .. eol
end

---The look of a light as a preset: no placement, size only on request.
---@param light table from IO.describe
---@param withSize boolean
---@return table preset { lightType, lightConfig }
function IO.presetFromLight(light, withSize)
	local config = {}
	local order = IO.keyOrder(light.lightType, light.config)
	for i = 1, #order do
		local key = order[i]
		if not IO.PLACEMENT[key] and (withSize or not IO.SIZE[key]) then
			config[key] = light.config[key] or 0
		end
	end
	return { lightType = light.lightType, lightConfig = config }
end

local PRESET_HEADER = {
	"-- Light presets: looks shared by many unit lights.",
	"-- DeferredLightsGL4config.lua builds a light from one with preset(name, overrides).",
	"-- The GL4 Light Editor writes this file.",
	"",
}

---The presets file as text.
---@param presets table<string, table>
---@return string
function IO.serializePresets(presets)
	local out = {}
	for i = 1, #PRESET_HEADER do
		out[#out + 1] = PRESET_HEADER[i]
	end
	out[#out + 1] = "return {"
	local names = sortedKeys(presets)
	for i = 1, #names do
		local def = presets[names[i]]
		local lightType = def.lightType or "point"
		local config = def.lightConfig or {}
		out[#out + 1] = "\t" .. formatKey(names[i]) .. " = {"
		out[#out + 1] = "\t\tlightType = " .. formatValue(lightType) .. ","
		out[#out + 1] = "\t\tlightConfig = {"
		local order = IO.keyOrder(lightType, config)
		for j = 1, #order do
			local key = order[j]
			if config[key] ~= nil then
				out[#out + 1] = "\t\t\t" .. key .. " = " .. IO.formatNumber(config[key]) .. ","
			end
		end
		out[#out + 1] = "\t\t},"
		out[#out + 1] = "\t},"
	end
	out[#out + 1] = "}"
	return table.concat(out, "\r\n") .. "\r\n"
end

return IO
