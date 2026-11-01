---@diagnostic disable: undefined-field
local widgetPath = "luaui/Widgets/cmd_area_commands_filter.lua"

describe("Area Command Filter drag origin", function()
	local widget, env, orders, traceType, traceID, activeCommand, held
	local function notify(options, params, command)
		return widget:CommandNotify(command or 20, params or { 100, 0, 100, 200 }, options or { alt = true })
	end

	before_each(function()
		orders, held = {}, true
		traceType, traceID, activeCommand = "unit", 101, 20
		widget = {}
		local defs = { [101] = 1, [102] = 1, [103] = 2 }
		env = setmetatable({
			widget = widget,
			BAR = { Utilities = {} },
			VFS = {
				Include = function(path, _, mode)
					return VFS.Include(path, env, mode)
				end,
			},
			UnitDefs = {},
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
					return { 1 }
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
				GiveOrderToUnitArray = function(_, _, params)
					orders[#orders + 1] = params[1]
				end,
			},
		}, { __index = _G })
		setfenv(assert(loadfile(widgetPath)), env)()
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
end)
