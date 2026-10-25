-- The real regions tool, loaded with the engine stubbed out, and the few moves a spec makes with it.
local Support = {}

local function upvalue(fn, wanted)
	for index = 1, 200 do
		local name, value = debug.getupvalue(fn, index)
		if name == nil then
			break
		end
		if name == wanted then
			return value
		end
	end
	error("missing upvalue " .. wanted)
end

---@param at number where its corner sits, on both axes
---@return { x: number, z: number }[]
function Support.Square(at)
	return { { x = at, z = at }, { x = at + 100, z = at }, { x = at + 100, z = at + 100 }, { x = at, z = at + 100 } }
end

---@return table R the tool's own state
---@return table api what the tool exports to the panel
function Support.Tool()
	local function noop() end
	local anything = {
		__index = function()
			return noop
		end,
	}
	local environment = setmetatable({
		widget = {},
		WG = {},
		gl = setmetatable({}, anything),
		GL = setmetatable({}, {
			__index = function()
				return 0
			end,
		}),
		Game = { mapSizeX = 2000, mapSizeZ = 2000, mapName = "spec map", extractorRadius = 80 },
		UnitDefs = { { name = "armcom", moveDef = { maxSlope = 0.5 } } },
		Spring = setmetatable({
			GetGroundHeight = function()
				return 0
			end,
			GetMapSize = function()
				return 2000, 2000
			end,
			GetModOptions = function()
				return {}
			end,
		}, anything),
		widgetHandler = setmetatable({}, anything),
	}, { __index = _G })
	require("luaui/Widgets/cmd_regions_tool", environment)
	local widget = environment.widget
	widget:Initialize()
	return upvalue(widget.Shutdown, "R"), environment.WG.RegionsTool
end

-- Draw a shape into the form, opening a new one when none is open, the way finishing a shape with the tools does.
---@param R table
---@param vertices { x: number, z: number }[]
---@return table region the form's copy, with the shape drawn
function Support.Draw(R, vertices)
	R.setFormShape({ vertices = vertices })
	return R.form.region
end

-- Draw a shape in a new form, set its fields, and submit it.
---@param R table
---@param vertices { x: number, z: number }[]
---@param fields table<string, string>|nil
---@return boolean created
function Support.Create(R, vertices, fields)
	R.openNew()
	for key, value in pairs(fields or {}) do
		R.setFormField(key, value)
	end
	Support.Draw(R, vertices)
	return R.submitForm()
end

return Support
