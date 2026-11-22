describe("Ghost Target single clicks", function()
	---@type table<string, any>
	local widget = {}
	---@type table
	local env = {}
	---@type table[]
	local orders = {}
	---@type integer?
	local command
	---@type string
	local kind
	---@type boolean
	local radarContact
	local x, y, held, minimap, intercepted
	before_each(function()
		widget, orders = {}, {}
		radarContact = false
		command, kind, x, y, held, minimap, intercepted = 20, "ghost", 100, 100, true, false, false
		env = setmetatable({
			widget = widget,
			math = setmetatable({
				bit_or = function(a, b)
					return a + (a % 2 == 0 and b or 0)
				end,
			}, { __index = math }),
			CMD = { ATTACK = 20, OPT_KEEP_HEIGHT = 1 },
			GameCMD = {
				UNIT_SET_TARGET = 34923,
				UNIT_SET_TARGET_NO_GROUND = 34924,
				GHOST_ATTACK = 34926,
				GHOST_SET_TARGET = 34927,
			},
			Spring = {
				GetGhostPosition = function() end,
				IsGUIHidden = function()
					return false
				end,
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
					assert.is_true(select(8, ...) == true)
					if radarContact then
						return "unit", 321, 57
					end
					if kind == "ghost" then
						return kind, 57
					end
					return kind, 123
				end,
				GiveOrder = function(id, params, opts)
					orders[#orders + 1] = { id, params, opts }
				end,
			},
			widgetHandler = {
				ModalAllows = function()
					return true
				end,
				CommandNotify = function(_, id, params, opts)
					assert.is_false(widget:CommandNotify(id, params, opts)) -- no recursion
					if #params == 3 then
						assert.is_true(opts.keepheight)
					else
						assert.is_nil(opts.keepheight)
					end
					return intercepted
				end,
			},
		}, { __index = _G })
		local chunk = assert(loadfile("luaui/Widgets/cmd_ghost_target.lua"))
		setfenv(chunk, env)
		chunk()
	end)
	local function click(params, options)
		widget:MousePress(100, 100, 1)
		return widget:CommandNotify(command, params or { 100, 0, 100 }, options or { coded = 32, shift = true })
	end
	it("sends only the sighting ID for both commands and retains queue options", function()
		for _, id in ipairs({ 20, 34923, 34924 }) do
			command = id
			assert.is_true(click())
			assert.same({ id == 20 and 34926 or 34927, { 57 }, 32 }, orders[#orders])
		end
	end)
	it("retains ghost picking through the Ignore Self ray wrapper", function()
		---@type table<string, any>
		local ignoreSelf = {}
		env.widget = ignoreSelf
		env.UnitDefs = {}
		env.WG = {}
		env.widgetHandler.RegisterGlobal = function() end
		local chunk = assert(loadfile("luaui/Widgets/cmd_no_self_selection.lua"))
		setfenv(chunk, env)
		chunk()
		ignoreSelf:Initialize()
		env.widget = widget

		assert.is_true(click())
		assert.same({ 34926, { 57 }, 32 }, orders[1])
		radarContact = true
		local _, _, ghostID = env.Spring.TraceScreenRay(x, y, false, false, false, false, 0, true)
		assert.equals(57, ghostID)
		assert.is_true(click())
		assert.same({ 20, { 321 }, 32 }, orders[2])
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
	it("draws only the hovered sighting for Attack and Set Target, including on radar", function()
		local hover = {}
		local draws = 0
		local registrations = {}
		env.widgetHandler.UpdateCallIn = function(_, name)
			assert.equals("DrawGhost", name)
			table.insert(registrations, "add")
		end
		env.widgetHandler.RemoveCallIn = function(_, name)
			assert.equals("DrawGhost", name)
			table.insert(registrations, "remove")
		end
		env.widget = hover
		env.GL = {}
		env.VFS = {
			LoadFile = function()
				return ""
			end,
		}
		env.Spring.GetGameFrame = function()
			return 1
		end
		env.Spring.GetFrameTimeOffset = function()
			return 0
		end
		env.gl = setmetatable({
			CreateShader = function()
				return 1
			end,
			GetSun = function()
				return 1, 1, 1
			end,
			GhostRaw = function()
				draws = draws + 1
			end,
		}, {
			__index = function()
				return function() end
			end,
		})
		local chunk = assert(loadfile("luaui/Widgets/gfx_ghost_hover.lua"))
		setfenv(chunk, env)
		chunk()
		hover:Initialize()
		held = false
		local info = { ghostID = 57, teamColor = { 1, 1, 1, 1 } }
		for _, id in ipairs({ 20, 34923, 34924 }) do
			command = id
			for _, radar in ipairs({ false, true }) do
				radarContact = radar
				hover:Update()
				assert.is_true(hover:DrawGhost(info))
				assert.is_false(hover:DrawGhost({ ghostID = 321 }))
			end
		end
		radarContact, kind = false, "unit"
		hover:Update()
		assert.is_false(hover:DrawGhost(info))
		kind, minimap = "ghost", true
		hover:Update()
		assert.is_false(hover:DrawGhost(info))
		minimap, command = false, nil
		hover:Update()
		assert.is_false(hover:DrawGhost(info))
		command = 20
		hover:Update()
		assert.same({ "remove", "add" }, registrations)
		assert.equals(6, draws)
	end)

	it("uses the radar unit target for remembered-model clicks", function()
		radarContact = true
		for _, id in ipairs({ 20, 34923, 34924 }) do
			command = id
			assert.is_true(click())
			assert.same({ id, { 321 }, 32 }, orders[#orders])
		end
	end)
end)
