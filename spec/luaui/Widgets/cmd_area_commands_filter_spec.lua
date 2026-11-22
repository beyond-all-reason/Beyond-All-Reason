---@diagnostic disable: undefined-field
local widgetPath = "luaui/Widgets/cmd_area_commands_filter.lua"

describe("Area Command Filter drag origin", function()
	---@type table<string, any>
	local widget
	---@type table<string, any>
	local env
	---@type integer[]
	local orders
	---@type { units: integer[], command: integer, options: string[] }[]
	local orderDetails
	local traceType, traceID, activeCommand, held
	local function notify(options, params, command)
		return widget:CommandNotify(command or 20, params or { 100, 0, 100, 200 }, options or { alt = true })
	end

	before_each(function()
		orders, orderDetails, held = {}, {}, true
		traceType, traceID, activeCommand = "unit", 101, 20
		widget = {}
		local defs = { [101] = 1, [102] = 1, [103] = 2 }
		env = setmetatable({
			widget = widget,
			table = setmetatable({
				new = function()
					return {}
				end,
			}, { __index = table }),
			BAR = {
				Utilities = {
					GetObjectPosition = function(id)
						return id, 0, 0
					end,
					GetObjectCentroid = function(ids, position)
						local x, z = 0, 0
						for _, id in ipairs(ids) do
							local px, _, pz = position(id)
							x, z = x + px, z + pz
						end
						return x / #ids, z / #ids
					end,
				},
			},
			VFS = {
				Include = function(path, _, mode)
					return VFS.Include(path, env, mode)
				end,
			},
			UnitDefs = {},
			UnitDefNames = {
				t1 = { customParams = { techlevel = "1" } },
				t2 = { customParams = { techlevel = "2" } },
			},
			Engine = { FeatureSupport = {} },
			Game = { maxUnits = 32000 },
			CMD = { ATTACK = 20, CAPTURE = 21, GUARD = 25, REPAIR = 40, RECLAIM = 90, LOAD_UNITS = 75, RESURRECT = 125 },
			GameCMD = { UNIT_SET_TARGET = 34923, UNIT_SET_TARGET_NO_GROUND = 34924 },
			Spring = {
				ENEMY_UNITS = -4,
				ALLY_UNITS = -2,
				ALL_UNITS = -1,
				GetActiveCommand = function()
					return 1, activeCommand
				end,
				GetMouseState = function()
					return 0, 0, held, false, held
				end,
				TraceScreenRay = function()
					return traceType, traceID
				end,
				WorldToScreenCoords = function()
					return 10, 20
				end,
				GetSelectedUnits = function()
					return { 1, 2 }
				end,
				GetUnitsInCylinder = function()
					return { 101, 102, 103 }
				end,
				GetUnitDefID = function(id)
					return defs[id]
				end,
				GetUnitAllyTeam = function()
					return 1
				end,
				GetLocalAllyTeamID = function()
					return 0
				end,
				GetSpectatingState = function()
					return false
				end,
				GetUnitArrayCentroid = function()
					return 0, 0, 0
				end,
				GetUnitPosition = function(id)
					return id, 0, 0
				end,
				GetFeatureDefID = function(id)
					return id == 203 and 2 or 1
				end,
				GetFeaturesInCylinder = function()
					return { 201, 202, 203 }
				end,
				GetFeatureResurrect = function(id)
					return id == 203 and "t2" or "t1"
				end,
				GetFeaturePosition = function(id)
					return id, 0, 0
				end,
				GiveOrderToUnitArray = function(units, command, params, options)
					orderDetails[#orderDetails + 1] = { units = units, command = command, options = options }
					orders[#orders + 1] = params[1]
				end,
			},
		}, { __index = _G })
		env.require = function(name)
			if name == "modules/split_targets" then
				local chunk = assert(loadfile(name .. ".lua"))
				setfenv(chunk, env)
				return chunk()
			end
			return require(name)
		end
		local chunk = assert(loadfile(widgetPath))
		setfenv(chunk, env)
		chunk()
		widget:Initialize()
	end)

	it("filters by the aircraft at press even when the release-time ray hits another type", function()
		if widget.MousePress then
			widget:MousePress(10, 20, 1)
		end
		traceID = 103
		assert.is_true(notify())
		assert.same({ 101, 102 }, orders)
	end)

	it("handles a release-time ray that misses all units", function()
		if widget.MousePress then
			widget:MousePress(10, 20, 1)
		end
		traceType, traceID = "ground", { 100, 0, 100 }
		assert.is_true(notify())
		assert.same({ 101, 102 }, orders)
	end)

	it("does not infer a filter unit when the drag started on empty ground", function()
		traceType, traceID = "ground", { 100, 0, 100 }
		widget:MousePress(10, 20, 1)
		traceType, traceID = "unit", 103
		assert.is_false(notify())
		assert.same({}, orders)
	end)

	it("preserves Ctrl's all-types behavior", function()
		activeCommand = 34923
		widget:MousePress(10, 20, 1)
		assert.is_true(notify({ ctrl = true }, nil, activeCommand))
		assert.same({ 101, 102, 103 }, orders)
	end)

	it("supports Set Target and right-button drags", function()
		activeCommand = env.GameCMD.UNIT_SET_TARGET
		widget:MousePress(10, 20, 3)
		traceType = "ground"
		assert.is_true(notify({ alt = true, right = true }, nil, activeCommand))
		assert.same({ 101, 102 }, orders)
	end)

	it("leaves direct clicks and unmodified areas alone", function()
		widget:MousePress(10, 20, 1)
		assert.is_false(notify({ alt = true }, { 101 }))
		widget:MousePress(10, 20, 1)
		assert.is_false(notify({}))
		assert.same({}, orders)
	end)

	it("expires a cancelled gesture after release", function()
		widget:MousePress(10, 20, 1)
		held = false
		widget:Update()
		traceID = 103
		assert.is_true(notify())
		assert.same({ 103 }, orders)
	end)

	it("does not reuse the origin for a different command", function()
		widget:MousePress(10, 20, 1)
		traceID = 103
		assert.is_true(notify(nil, nil, env.GameCMD.UNIT_SET_TARGET))
		assert.same({ 103 }, orders)
	end)

	it("retains the existing path without a recorded mouse press", function()
		assert.is_true(notify())
		assert.same({ 101, 102 }, orders)
	end)
	for _, command in ipairs({ 90, 125 }) do
		it("splits wrecks across tech levels without forwarding Ctrl for command " .. command, function()
			traceType, traceID = "feature", 201
			assert.is_true(notify({ ctrl = true, shift = true, meta = true }, nil, command))
			table.sort(orders)
			assert.same({ 32201, 32202, 32203 }, orders)
			local assignedUnits = {}
			for _, order in ipairs(orderDetails) do
				assert.same({ "shift" }, order.options)
				assert.equals(command, order.command)
				assert.equals(1, #order.units)
				assignedUnits[order.units[1]] = true
			end
			assert.same({ true, true }, assignedUnits)
		end)

		it("retains Ctrl tech filtering without splitting for command " .. command, function()
			traceType, traceID = "feature", 201
			assert.is_true(notify({ ctrl = true, shift = true }, nil, command))
			assert.same({ 32201, 32202 }, orders)
		end)

		it("retains Alt type filtering while splitting for command " .. command, function()
			traceType, traceID = "feature", 201
			assert.is_true(notify({ alt = true, ctrl = true, shift = true, meta = true }, nil, command))
			table.sort(orders)
			assert.same({ 32201, 32202 }, orders)
		end)
	end
end)
