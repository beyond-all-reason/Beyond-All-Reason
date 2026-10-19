local SpringUnsyncedBuilder = VFS.Include("spec/builders/spring_unsynced_builder.lua")

local WIDGET_PATH = "luaui/Widgets/api_player_input_lock.lua"

describe("luaui.Widgets.api_player_input_lock", function()
	local config ---@type table<string, integer>
	local configWrites ---@type table<integer, { key: string, value: integer, overlay: boolean }>
	local handlerCalls ---@type table<integer, any[]>
	local activeCommandSets ---@type integer[]
	local windowOpen = false

	local function loadWidget()
		local loaded = SpringUnsyncedBuilder.new()
			:WithSpringFn("GetConfigInt", function(key, default)
				return config[key] or default
			end)
			:WithSpringFn("SetConfigInt", function(key, value, overlay)
				config[key] = value
				configWrites[#configWrites + 1] = { key = key, value = value, overlay = overlay }
			end)
			:WithSpringFn("SetActiveCommand", function(index)
				activeCommandSets[#activeCommandSets + 1] = index
			end)
			:LoadWidget(WIDGET_PATH)
		local handler = loaded.env.widgetHandler
		for _, name in ipairs({ "HideInterface", "ShowInterface", "LockKeyboard", "UnlockKeyboard" }) do
			handler[name] = function(_, ...)
				handlerCalls[#handlerCalls + 1] = { name, ... }
				return true
			end
		end
		handler.IsAnyWindowOpen = function()
			return windowOpen
		end
		return loaded
	end

	before_each(function()
		config = { WindowedEdgeMove = 1, FullscreenEdgeMove = 0 }
		configWrites = {}
		handlerCalls = {}
		activeCommandSets = {}
		windowOpen = false
	end)

	it("hides all but the menu buttons, passes only Esc and the quit menu, stops edge scrolling", function()
		local loaded = loadWidget()

		loaded.WG.playerInputLock.Lock({ "Chat" })

		assert.is_true(loaded.WG.playerInputLock.IsLocked())
		assert.are.same({
			{ "HideInterface", "playerInputLock", { "Top Bar Buttons", "Player Input Lock", "Chat" } },
			{ "LockKeyboard", "playerInputLock", { 27, "quitmenu" } },
		}, handlerCalls)
		assert.are.same({ 0 }, activeCommandSets)
		assert.are.same({
			{ key = "WindowedEdgeMove", value = 0, overlay = true },
			{ key = "FullscreenEdgeMove", value = 0, overlay = true },
		}, configWrites)
	end)

	it("eats the mouse wheel only while locked", function()
		local loaded = loadWidget()
		local function wheelConsumed()
			local consumed = loaded.env.widget:MouseWheel(true, 1)
			return consumed == true
		end
		assert.is_false(wheelConsumed())
		loaded.WG.playerInputLock.Lock()
		assert.is_true(wheelConsumed())
		windowOpen = true -- a showing window gets the wheel, as it gets the keys
		assert.is_false(wheelConsumed())
	end)

	it("puts everything back on unlock", function()
		local loaded = loadWidget()
		loaded.WG.playerInputLock.Lock()
		handlerCalls = {}
		configWrites = {}

		loaded.WG.playerInputLock.Unlock()

		assert.is_false(loaded.WG.playerInputLock.IsLocked())
		assert.are.same(
			{ { "ShowInterface", "playerInputLock" }, { "UnlockKeyboard", "playerInputLock" } },
			handlerCalls
		)
		assert.are.equal(1, config.WindowedEdgeMove)
		assert.are.equal(0, config.FullscreenEdgeMove)
		for _, write in ipairs(configWrites) do
			assert.is_true(write.overlay)
		end
	end)

	it("releases its handler requests even when it never locked, and touches no setting", function()
		local loaded = loadWidget()
		loaded.WG.playerInputLock.Unlock()
		assert.are.same(
			{ { "ShowInterface", "playerInputLock" }, { "UnlockKeyboard", "playerInputLock" } },
			handlerCalls
		)
		assert.are.same({}, configWrites)
		assert.are.same({}, activeCommandSets)
		assert.is_false(loaded.WG.playerInputLock.IsLocked())
	end)

	it("replaces the keep list when locked again and keeps the original settings", function()
		local loaded = loadWidget()
		loaded.WG.playerInputLock.Lock({ "Chat" })
		loaded.WG.playerInputLock.Lock()

		assert.are.same({ "Top Bar Buttons", "Player Input Lock" }, handlerCalls[3][3])
		assert.are.equal(2, #configWrites) -- the edge-move settings were saved once, not overwritten with zeros

		loaded.WG.playerInputLock.Unlock()
		assert.are.equal(1, config.WindowedEdgeMove)
	end)

	it("unlocks on shutdown", function()
		local loaded = loadWidget()
		loaded.WG.playerInputLock.Lock()

		loaded.env.widget:Shutdown()

		assert.are.equal(1, config.WindowedEdgeMove)
		assert.are.same({ "ShowInterface", "playerInputLock" }, handlerCalls[3])
		assert.are.same({ "UnlockKeyboard", "playerInputLock" }, handlerCalls[4])
		assert.is_nil(loaded.WG.playerInputLock)
	end)

	it("saves the settings afresh when locked again after an unlock", function()
		local loaded = loadWidget()
		loaded.WG.playerInputLock.Lock()
		loaded.WG.playerInputLock.Unlock()
		config.WindowedEdgeMove = 0 -- the player turned it off in between

		loaded.WG.playerInputLock.Lock()
		loaded.WG.playerInputLock.Unlock()

		assert.are.equal(0, config.WindowedEdgeMove)
		assert.are.equal(0, config.FullscreenEdgeMove)
	end)
end)
