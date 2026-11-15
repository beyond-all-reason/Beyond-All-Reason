describe("Ghost Target single clicks", function()
	local widget, env, orders, command, kind, x, y, held, minimap, intercepted
	before_each(function()
		widget, orders = {}, {}
		command, kind, x, y, held, minimap, intercepted = 20, "ghost", 100, 100, true, false, false
		env = setmetatable({
			widget = widget,
			math = setmetatable({
				bit_or = function(a, b)
					return a + (a % 2 == 0 and b or 0)
				end,
			}, { __index = math }),
			CMD = { ATTACK = 20, OPT_KEEP_HEIGHT = 1 },
			GameCMD = { UNIT_SET_TARGET = 34923, UNIT_SET_TARGET_NO_GROUND = 34924 },
			Spring = {
				GetActiveCommand = function()
					return 1, command
				end,
				GetMouseState = function()
					return x, y, held
				end,
				GetConfigInt = function(_, default)
					return default
				end,
				IsAboveMiniMap = function()
					return minimap
				end,
				TraceScreenRay = function(...)
					assert.equals(true, select(8, ...))
					return kind, { 110, 80, 105 }
				end,
				GiveOrder = function(id, params, opts)
					orders[#orders + 1] = { id, params, opts }
				end,
			},
			widgetHandler = {
				CommandNotify = function(_, id, params, opts)
					assert.is_false(widget:CommandNotify(id, params, opts)) -- no recursion
					assert.is_true(opts.keepheight)
					return intercepted
				end,
			},
		}, { __index = _G })
		setfenv(assert(loadfile("luaui/Widgets/cmd_ghost_target.lua")), env)()
	end)
	local function click(params, options)
		widget:MousePress(100, 100, 1)
		return widget:CommandNotify(command, params or { 100, 0, 100 }, options or { coded = 32, shift = true })
	end
	it("uses the entire aimpoint for both commands and retains queue options", function()
		for _, id in ipairs({ 20, 34923, 34924 }) do
			command = id
			assert.is_true(click())
			assert.same({ id, { 110, 80, 105 }, 33 }, orders[#orders])
		end
	end)
	it("leaves visible units, radar contacts, and terrain to existing command handling", function()
		for _, targetKind in ipairs({ "unit", "ground", "feature" }) do
			kind = targetKind
			assert.is_false(click())
		end
		assert.same({}, orders)
	end)
	it("does not redirect area or rectangle commands", function()
		assert.is_false(click({ 100, 0, 100, 50 }))
		assert.is_false(click({ 100, 0, 100, 200, 0, 200 }))
		assert.same({}, orders)
	end)
	it("does not redirect a drag even if a widget emits a point command", function()
		x = 110
		assert.is_false(click())
		assert.same({}, orders)
	end)
	it("does not redirect automation or minimap clicks", function()
		assert.is_false(widget:CommandNotify(command, { 100, 0, 100 }, {}))
		assert.is_false(click(nil, { internal = true }))
		minimap = true
		assert.is_false(click())
		assert.same({}, orders)
	end)
	it("allows other widgets to insert the resolved command without issuing it twice", function()
		intercepted = true
		assert.is_true(click())
		assert.same({}, orders)
	end)
	it("expires a released click before unrelated later commands", function()
		widget:MousePress(100, 100, 1)
		held = false
		widget:Update()
		assert.is_false(widget:CommandNotify(command, { 100, 0, 100 }, {}))
	end)
end)
