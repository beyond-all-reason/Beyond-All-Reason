-- Unit BLUEPRINTS (refactor plan, U9): a group of placed units saved under a name, picked
-- from the unit library and placed again anywhere, as many times as wanted.
--
-- Pure: this is the format and nothing else -- writing a blueprint as text, reading one back
-- (in an empty sandbox: a blueprint file is shared data, never code to run), and the file name
-- a blueprint's name becomes. The library widget does the disk. Specs:
-- spec/mission_editor/unit_blueprints_spec.lua.
--
-- A blueprint is:
--   { name = "Forward base", units = { { unitDefName, dx, dz, facing, extra = { ... } }, ... } }
-- offsets from the group's middle, so it drops wherever the pointer is; no team (it lands on
-- whichever team is being placed for) and no names or keys (a placed copy is new units).

local Blueprints = {}

Blueprints.VERSION = 1

local function isIdentifier(key)
	return type(key) == "string" and key:match("^[%a_][%w_]*$") ~= nil
end

local function writeValue(out, value, indent)
	local kind = type(value)
	if kind == "string" then
		out[#out + 1] = string.format("%q", value)
	elseif kind == "number" then
		out[#out + 1] = (value == math.floor(value) and math.abs(value) < 1e15) and string.format("%d", value)
			or string.format("%.6g", value)
	elseif kind == "boolean" then
		out[#out + 1] = tostring(value)
	elseif kind == "table" then
		local pad = string.rep("\t", indent + 1)
		out[#out + 1] = "{\n"
		local count = #value
		for index = 1, count do
			out[#out + 1] = pad
			writeValue(out, value[index], indent + 1)
			out[#out + 1] = ",\n"
		end
		local keys = {}
		for key in pairs(value) do
			if not (type(key) == "number" and key >= 1 and key <= count and key == math.floor(key)) then
				keys[#keys + 1] = key
			end
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		for _, key in ipairs(keys) do
			out[#out + 1] = pad
			if isIdentifier(key) then
				out[#out + 1] = key .. " = "
			else
				out[#out + 1] = "["
				writeValue(out, key, indent + 1)
				out[#out + 1] = "] = "
			end
			writeValue(out, value[key], indent + 1)
			out[#out + 1] = ",\n"
		end
		out[#out + 1] = string.rep("\t", indent) .. "}"
	else
		-- Functions, userdata: a blueprint is plain data, and cannot carry them.
		out[#out + 1] = "nil"
	end
end

--- A blueprint as the text of its file: `return { ... }`, sorted, so a file is stable.
function Blueprints.serialise(blueprint)
	local out = { "-- A unit blueprint for the mission editor / terraform brush (U9).\nreturn " }
	writeValue(out, {
		version = Blueprints.VERSION,
		name = tostring(blueprint.name or "blueprint"),
		units = blueprint.units or {},
	}, 0)
	out[#out + 1] = "\n"
	return table.concat(out)
end

--- A blueprint from the text of its file, or nil and why. Runs in an EMPTY environment: a
--- blueprint that tries to reach anything reads nil and fails, rather than doing it.
---@param loader function|nil `loadstring` (handed in: the spec and the game both have one)
function Blueprints.parse(text, loader)
	loader = loader or loadstring
	local chunk, problem = loader(tostring(text or ""))
	if not chunk then
		return nil, "not readable: " .. tostring(problem)
	end
	setfenv(chunk, {})
	local ok, value = pcall(chunk)
	if not ok then
		return nil, "not a blueprint: " .. tostring(value)
	end
	if type(value) ~= "table" or type(value.units) ~= "table" or #value.units == 0 then
		return nil, "not a blueprint: no units"
	end
	for index, unit in ipairs(value.units) do
		if type(unit) ~= "table" or type(unit.unitDefName) ~= "string" then
			return nil, "unit " .. index .. " has no unitDefName"
		end
		unit.dx, unit.dz = tonumber(unit.dx) or 0, tonumber(unit.dz) or 0
		unit.facing = math.floor(tonumber(unit.facing) or 0) % 4
		unit.extra = type(unit.extra) == "table" and unit.extra or {}
	end
	value.name = tostring(value.name or "blueprint")
	return value
end

--- The file a blueprint's name is stored in: lower case, letters, digits and _ only.
function Blueprints.fileName(name)
	local base = tostring(name or ""):lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
	if base == "" then
		base = "blueprint"
	end
	return base .. ".lua"
end

return Blueprints
